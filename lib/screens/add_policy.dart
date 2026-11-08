import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../store.dart';
import '../wealth.dart';

/// Add or edit an insurance policy. Policies are kept for reference
/// (cover, cost, renewal date) and are not counted in net worth unless
/// you enter a cash-in value.
class AddPolicyScreen extends StatefulWidget {
  final AppStore store;
  final Policy? existing;
  const AddPolicyScreen({super.key, required this.store, this.existing});

  @override
  State<AddPolicyScreen> createState() => _AddPolicyScreenState();
}

class _AddPolicyScreenState extends State<AddPolicyScreen> {
  late String _type;
  late final TextEditingController _provider;
  late final TextEditingController _number;
  late final TextEditingController _cover;
  late final TextEditingController _premium;
  late final TextEditingController _covered;
  late final TextEditingController _cash;
  DateTime? _renewal;
  String? _error;

  String _fmt(double? v) =>
      v == null || v == 0 ? '' : v.toStringAsFixed(v % 1 == 0 ? 0 : 2);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? policyTypes.first;
    _provider = TextEditingController(text: e?.provider ?? '');
    _number = TextEditingController(text: e?.number ?? '');
    _cover = TextEditingController(text: _fmt(e?.cover));
    _premium = TextEditingController(text: _fmt(e?.premium));
    _covered = TextEditingController(text: e?.covered ?? '');
    _cash = TextEditingController(text: _fmt(e?.cashValue));
    _renewal = e?.renewal;
  }

  @override
  void dispose() {
    for (final c in [_provider, _number, _cover, _premium, _covered, _cash]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(String s) => double.tryParse(s.replaceAll(',', '').trim());

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _renewal ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 40),
    );
    if (d != null) setState(() => _renewal = d);
  }

  Future<void> _save() async {
    if (_provider.text.trim().isEmpty) {
      setState(() => _error = 'Enter the provider, for example Aviva.');
      return;
    }
    final p = Policy(
      id: widget.existing?.id ?? widget.store.newId(),
      type: _type,
      provider: _provider.text.trim(),
      number: _number.text.trim(),
      cover: _num(_cover.text) ?? 0,
      premium: _num(_premium.text) ?? 0,
      renewal: _renewal,
      covered: _covered.text.trim(),
      cashValue: _num(_cash.text),
    );
    await widget.store.savePolicy(p);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this policy?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.store.removePolicy(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cur = widget.store.currency;
    InputDecoration dec(String label, {String? prefix, String? helper}) => InputDecoration(
        labelText: label,
        prefixText: prefix,
        helperText: helper,
        border: const OutlineInputBorder());
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add a policy' : 'Policy'),
        actions: [
          if (widget.existing != null)
            IconButton(
                tooltip: 'Remove', icon: const Icon(Icons.delete_outline), onPressed: _remove),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Type of policy', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in policyTypes)
                  ChoiceChip(
                    label: Text(t),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
                controller: _provider,
                textCapitalization: TextCapitalization.words,
                decoration: dec('Provider')),
            const SizedBox(height: 12),
            TextField(controller: _number, decoration: dec('Policy number (optional)')),
            const SizedBox(height: 12),
            TextField(
              controller: _cover,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: dec('Cover amount', prefix: cur),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _premium,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: dec('Premium per month', prefix: cur),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_renewal == null
                  ? 'Renewal / end date (optional)'
                  : 'Renews ${DateFormat('d MMM yyyy').format(_renewal!)}'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDate,
            ),
            TextField(
                controller: _covered,
                textCapitalization: TextCapitalization.words,
                decoration: dec('Who is covered? (optional)')),
            const SizedBox(height: 12),
            TextField(
              controller: _cash,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: dec('Cash-in value (optional)',
                  prefix: cur,
                  helper: 'Only fill this if it has a surrender value. It is then counted in net worth.'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Save policy')),
          ],
        ),
      ),
    );
  }
}
