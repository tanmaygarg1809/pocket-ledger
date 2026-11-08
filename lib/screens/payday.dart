import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../store.dart';

/// Pay date: the day you are paid, moved back to the last working day when it
/// lands on a weekend, with your own date for months that vary (e.g. December).
class PaydayScreen extends StatelessWidget {
  final AppStore store;
  const PaydayScreen({super.key, required this.store});

  Future<void> _setDay(BuildContext context) async {
    final c = TextEditingController(text: '${store.payDay}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pay day of the month'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              helperText: 'If it is a weekend, the Friday before is used'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final v = int.tryParse(c.text.trim());
    c.dispose();
    if (ok == true && v != null && v >= 1 && v <= 31) await store.setPay(day: v);
  }

  Future<void> _pick(BuildContext context, DateTime m) async {
    final cur = store.payDateFor(m.year, m.month);
    final d = await showDatePicker(
      context: context,
      initialDate: cur ?? DateTime(m.year, m.month, 20),
      firstDate: DateTime(m.year, m.month, 1),
      lastDate: DateTime(m.year, m.month + 1, 0),
    );
    if (d != null) await store.setPayOverride(m.year, m.month, d);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final months = [for (var i = 0; i < 12; i++) DateTime(now.year, now.month + i)];
        return Scaffold(
          appBar: AppBar(title: const Text('Pay date')),
          body: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.event_repeat),
                title: Text('Paid on day ${store.payDay} of the month'),
                subtitle: const Text('Weekend? Paid the last working day before'),
                trailing: const Icon(Icons.edit),
                onTap: () => _setDay(context),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Next 12 months', style: Theme.of(context).textTheme.titleSmall),
              ),
              for (final m in months)
                Builder(builder: (_) {
                  final d = store.payDateFor(m.year, m.month);
                  final manual = store.payManualMonths.contains(m.month);
                  final custom = store.hasPayOverride(m.year, m.month);
                  return ListTile(
                    title: Text(DateFormat('MMMM yyyy').format(m)),
                    subtitle: Text(d == null
                        ? 'Not set. Tap to choose the date'
                        : '${DateFormat('EEE d MMM').format(d)}${custom ? ' · your date' : (manual ? '' : '')}'),
                    trailing: custom
                        ? IconButton(
                            tooltip: 'Back to automatic',
                            icon: const Icon(Icons.restart_alt),
                            onPressed: () => store.setPayOverride(m.year, m.month, null),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () => _pick(context, m),
                  );
                }),
              SwitchListTile(
                title: const Text('December pay date varies'),
                subtitle: const Text('Ask me to set it each year instead of guessing'),
                value: store.payManualMonths.contains(12),
                onChanged: (v) {
                  final s = Set<int>.from(store.payManualMonths);
                  v ? s.add(12) : s.remove(12);
                  store.setPay(manualMonths: s);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
