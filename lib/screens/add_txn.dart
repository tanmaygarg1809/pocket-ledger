import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../attachments.dart';
import '../models.dart';
import '../store.dart';
import 'category_picker.dart';

class AddTxnScreen extends StatefulWidget {
  final AppStore store;
  final Txn? existing;
  /// 0 = expense, 1 = income (used when adding a new entry).
  final int initialMode;
  const AddTxnScreen({super.key, required this.store, this.existing, this.initialMode = 0});

  @override
  State<AddTxnScreen> createState() => _AddTxnScreenState();
}

class _AddTxnScreenState extends State<AddTxnScreen> {
  final _formKey = GlobalKey<FormState>();

  /// 0 = expense, 1 = income, 2 = refund (an expense entered as a negative
  /// amount, so it nets back into the category it was spent from).
  late int _mode;
  late String _category;
  late DateTime _date;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  TextEditingController? _payeeCtrl; // owned by the Autocomplete field
  bool _repeat = false;
  bool _splitwise = false;
  late List<String> _files;
  final List<String> _removedFiles = [];
  final List<String> _addedFiles = [];
  bool _saved = false;
  bool _categoryTouched = false;

  TxType get _type => _mode == 1 ? TxType.income : TxType.expense;
  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) {
      _mode = widget.initialMode;
    } else if (e.type == TxType.income) {
      _mode = 1;
    } else {
      _mode = e.amount < 0 ? 2 : 0;
    }
    _category = e?.category ?? widget.store.suggestedCategory(_type);
    _date = e?.date ?? DateTime.now();
    _amount = TextEditingController(
        text: e == null ? '' : e.amount.abs().toStringAsFixed(2));
    _note = TextEditingController(text: e?.note ?? '');
    _splitwise = (e?.split ?? 0) > 0;
    _files = List<String>.from(e?.files ?? const []);
  }

  @override
  void dispose() {
    // Left without saving: drop files that were attached just now.
    if (!_saved) {
      for (final f in _addedFiles) {
        Attachments.delete(f);
      }
    }
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  /// "Tesco" -> the category you usually file Tesco under.
  void _autoCategory(String payee) {
    if (_editing || _categoryTouched) return;
    final c = widget.store.categoryForPayee(payee, _type);
    if (c != null && c != _category) setState(() => _category = c);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final raw = double.parse(_amount.text.replaceAll(',', '.').trim());
    final amount = _mode == 2 ? -raw : raw;
    final payee = (_payeeCtrl?.text ?? widget.existing?.payee ?? '').trim();
    widget.store.upsert(Txn(
      id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: _type,
      amount: amount,
      category: _category,
      payee: payee,
      note: _note.text.trim(),
      date: _date,
      files: _files,
      split: (_splitwise && _mode == 0)
          ? ((widget.existing?.split ?? 0) == 2 ? 2 : 1)
          : 0,
    ));
    _saved = true;
    for (final f in _removedFiles) {
      Attachments.delete(f);
    }
    if (_repeat && !_editing && _mode != 2) {
      // Start next month: this month's entry was just added by hand.
      final next = DateTime(_date.year, _date.month + 1);
      widget.store.upsertRule(RecurringRule(
        id: 'r${DateTime.now().microsecondsSinceEpoch}',
        type: _type,
        amount: raw,
        category: _category,
        note: payee.isNotEmpty ? payee : _note.text.trim(),
        day: _date.day.clamp(1, 28),
        startMonth: DateFormat('yyyy-MM').format(next),
      ));
    }
    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text('It will be removed from this phone and from your synced devices.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final t = widget.existing!;
    await widget.store.remove(t.id);
    for (final f in t.files) {
      Attachments.delete(f);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _addFiles() async {
    final names = await Attachments.pick();
    if (names.isEmpty || !mounted) return;
    setState(() {
      _files.addAll(names);
      _addedFiles.addAll(names);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit transaction' : 'New transaction'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Expense')),
                ButtonSegment(value: 1, label: Text('Income')),
                ButtonSegment(value: 2, label: Text('Refund')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.first;
                _categoryTouched = false;
                _category = (widget.existing != null &&
                        widget.existing!.type == _type)
                    ? widget.existing!.category
                    : store.suggestedCategory(_type);
              }),
            ),
            if (_mode == 2)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'A refund is taken off the category it was spent from, so you see what you really spent.'),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              autofocus: !_editing,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: store.currency,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.').trim());
                if (n == null || n <= 0) return 'Enter an amount above 0';
                if (n > 1e9) return 'Amount is too large';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Focus(
              onFocusChange: (has) {
                if (!has) _autoCategory(_payeeCtrl?.text ?? '');
              },
              child: Autocomplete<String>(
                initialValue:
                    TextEditingValue(text: widget.existing?.payee ?? ''),
                optionsBuilder: (v) =>
                    store.payeeSuggestions(v.text, category: _category),
                onSelected: _autoCategory,
                fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                  _payeeCtrl = controller;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Payee (optional)',
                      hintText: 'e.g. Tesco, Deliveroo',
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (v) {
                      _autoCategory(v);
                      onSubmit();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text('Category', style: Theme.of(context).textTheme.labelLarge),
            CategoryPicker(
              store: store,
              type: _type,
              selected: _category,
              onChanged: (c) => setState(() {
                _category = c;
                _categoryTouched = true;
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Receipts & documents', style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addFiles,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach'),
                ),
              ],
            ),
            if (_files.isEmpty)
              Text('Add a receipt photo, warranty or PDF to keep with this entry.',
                  style: Theme.of(context).textTheme.bodySmall),
            Wrap(
              spacing: 8,
              children: [
                for (final f in _files)
                  InputChip(
                    avatar: Icon(Attachments.isImage(f) ? Icons.image_outlined : Icons.description_outlined, size: 18),
                    label: SizedBox(
                      width: 120,
                      child: Text(Attachments.label(f), overflow: TextOverflow.ellipsis),
                    ),
                    onPressed: () => Attachments.open(context, f),
                    onDeleted: () => setState(() {
                      _files.remove(f);
                      if (_addedFiles.contains(f)) {
                        _addedFiles.remove(f);
                        Attachments.delete(f);
                      } else {
                        _removedFiles.add(f);
                      }
                    }),
                  ),
              ],
            ),
            if (!_editing && _mode != 2)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Repeat every month'),
                subtitle: Text(
                    'On day ${_date.day.clamp(1, 28)}, starting next month'),
                value: _repeat,
                onChanged: (v) => setState(() => _repeat = v),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
