import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import 'category_picker.dart';

class RecurringScreen extends StatelessWidget {
  final AppStore store;
  const RecurringScreen({super.key, required this.store});

  void _open(BuildContext context, [RecurringRule? rule]) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RuleEditor(store: store, existing: rule)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final rules = store.rules;
          if (rules.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Add rent, subscriptions or salary once and they are '
                  'recorded automatically every month.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: rules.length,
            itemBuilder: (context, i) {
              final r = rules[i];
              final cat = store.categoryByName(r.category);
              final income = r.type == TxType.income;
              return ListTile(
                onTap: () => _open(context, r),
                leading: CircleAvatar(
                  backgroundColor: cat.colorValue,
                  child: Icon(cat.iconData, color: Colors.white, size: 20),
                ),
                title: Text(r.note.isEmpty ? r.category : r.note),
                subtitle: Text(
                    '${income ? '+' : '-'}${store.money(r.amount)} · day ${r.day} of each month'),
                trailing: Switch(
                  value: r.active,
                  onChanged: (v) => store.upsertRule(r.copyWith(active: v)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class RuleEditor extends StatefulWidget {
  final AppStore store;
  final RecurringRule? existing;
  const RuleEditor({super.key, required this.store, this.existing});

  @override
  State<RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<RuleEditor> {
  final _form = GlobalKey<FormState>();
  late TxType _type;
  late String _category;
  late int _day;
  late final TextEditingController _amount;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? TxType.expense;
    _category = e?.category ?? widget.store.suggestedCategory(TxType.expense);
    _day = e?.day ?? DateTime.now().day.clamp(1, 28);
    _amount =
        TextEditingController(text: e == null ? '' : e.amount.toStringAsFixed(2));
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final now = DateTime.now();
    final e = widget.existing;
    await widget.store.upsertRule(RecurringRule(
      id: e?.id ?? now.microsecondsSinceEpoch.toString(),
      type: _type,
      amount: double.parse(_amount.text.replaceAll(',', '.').trim()),
      category: _category,
      note: _note.text.trim(),
      day: _day,
      startMonth: e?.startMonth ?? DateFormat('yyyy-MM').format(now),
      active: e?.active ?? true,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this recurring item?'),
        content: const Text(
            'Transactions already recorded stay; no new ones will be added.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.removeRule(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit recurring' : 'New recurring')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<TxType>(
              segments: const [
                ButtonSegment(value: TxType.expense, label: Text('Expense')),
                ButtonSegment(value: TxType.income, label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _category = widget.store.suggestedCategory(_type);
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: widget.store.currency,
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
            Text('Category', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            CategoryPicker(
              store: widget.store,
              type: _type,
              selected: _category,
              onChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Name / payee (e.g. Rent, Netflix)',
                border: OutlineInputBorder(),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.event_repeat),
                const SizedBox(width: 12),
                Expanded(child: Text('Day $_day of each month')),
                IconButton(
                  tooltip: 'Earlier day',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _day > 1 ? () => setState(() => _day--) : null,
                ),
                IconButton(
                  tooltip: 'Later day',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _day < 28 ? () => setState(() => _day++) : null,
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'It is added automatically the first time you open the app '
                'on or after that day. Days go up to 28 so every month has one.',
              ),
            ),
            FilledButton(onPressed: _save, child: const Text('Save')),
            if (editing)
              TextButton(
                onPressed: _delete,
                child: Text('Delete',
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}
