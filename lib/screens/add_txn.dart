import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import 'category_picker.dart';

class AddTxnScreen extends StatefulWidget {
  final AppStore store;
  final Txn? existing;
  const AddTxnScreen({super.key, required this.store, this.existing});

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
  bool _categoryTouched = false;

  TxType get _type => _mode == 1 ? TxType.income : TxType.expense;
  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) {
      _mode = 0;
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
  }

  @override
  void dispose() {
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
    ));
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

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final last = _editing || _mode == 2 ? null : store.lastTxn(_type);
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit transaction' : 'New transaction')),
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
            if (last != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.replay, size: 18),
                  label: Text(
                      'Same as last time: ${store.money(last.amount)} · ${last.payee.isNotEmpty ? last.payee : last.category}'),
                  onPressed: () => setState(() {
                    _amount.text = last.amount.toStringAsFixed(2);
                    _category = last.category;
                    _categoryTouched = true;
                    _note.text = last.note;
                    _payeeCtrl?.text = last.payee;
                  }),
                ),
              ),
            ],
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
