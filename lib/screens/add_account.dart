import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../store.dart';
import '../wealth.dart';
import 'net_worth.dart';

/// Add an account / asset / debt, or edit an existing one.
class AddAccountScreen extends StatefulWidget {
  final AppStore store;
  final Account? existing;
  const AddAccountScreen({super.key, required this.store, this.existing});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  late AccountKind _kind;
  late final TextEditingController _name;
  late final TextEditingController _provider;
  late final TextEditingController _weight;
  late final TextEditingController _value;
  late bool _include;
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _kind = e?.kind ?? AccountKind.bank;
    _name = TextEditingController(text: e?.name ?? '');
    _provider = TextEditingController(text: e?.provider ?? '');
    _weight = TextEditingController(
        text: e?.weight == null ? '' : e!.weight!.toStringAsFixed(e.weight! % 1 == 0 ? 0 : 2));
    _value = TextEditingController(
        text: e == null || e.history.isEmpty ? '' : e.value.toStringAsFixed(e.value % 1 == 0 ? 0 : 2));
    _include = e?.include ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _provider.dispose();
    _weight.dispose();
    _value.dispose();
    super.dispose();
  }

  double? _num(String s) => double.tryParse(s.replaceAll(',', '').trim());

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final value = _num(_value.text);
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name.');
      return;
    }
    if (value == null || value < 0) {
      setState(() => _error = 'Enter the current value as a number.');
      return;
    }
    final w = _kind == AccountKind.gold ? _num(_weight.text) : null;
    final e = widget.existing;
    final List<ValuePoint> history;
    if (e == null) {
      history = [ValuePoint(DateTime(_date.year, _date.month, _date.day), value)];
    } else if (e.history.isNotEmpty && e.value == value) {
      history = e.history; // value unchanged: keep the readings as they are
    } else {
      history = Wealth.withReading(e.history, _date, value);
    }
    final a = Account(
      id: e?.id ?? widget.store.newId(),
      kind: _kind,
      name: name,
      provider: _provider.text.trim(),
      weight: w,
      include: _include,
      history: history,
    );
    await widget.store.saveAccount(a);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDebt = _kind.isDebt;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.existing == null ? 'Add to net worth' : 'Edit account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('What is it?', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in AccountKind.values)
                  ChoiceChip(
                    avatar: Icon(kindIcon(k),
                        size: 18,
                        color: _kind == k ? cs.onPrimaryContainer : kindColor(k)),
                    label: Text(k.label),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: isDebt ? 'Mortgage' : 'Gold coins',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _provider,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Held with / where (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_kind == AccountKind.gold) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Weight in grams (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isDebt ? 'Amount owed' : 'Current value',
                prefixText: widget.store.currency,
                helperText: 'Update it any time to see growth.',
                border: const OutlineInputBorder(),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text('As of ${DateFormat('d MMM yyyy').format(_date)}'),
              subtitle: const Text('Use an earlier date for a past value'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDate,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include in net worth'),
              subtitle: const Text('Counts towards your total'),
              value: _include,
              onChanged: (v) => setState(() => _include = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
