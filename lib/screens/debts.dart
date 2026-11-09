import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';

/// Money you owe: add a loan, record repayments, see what is left.
class DebtsScreen extends StatelessWidget {
  final AppStore store;
  const DebtsScreen({super.key, required this.store});

  Future<void> _edit(BuildContext context, [Debt? d]) async {
    final lender = TextEditingController(text: d?.lender ?? '');
    final amount = TextEditingController(text: d == null ? '' : d.amount.toStringAsFixed(0));
    final monthly = TextEditingController(
        text: d == null || d.monthly == 0 ? '' : d.monthly.toStringAsFixed(0));
    final note = TextEditingController(text: d?.note ?? '');
    DateTime? due = d?.due;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(d == null ? 'Add a debt' : 'Edit debt'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: lender,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Who do you owe?'),
              ),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Total borrowed', prefixText: store.currency),
              ),
              TextField(
                controller: monthly,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Monthly repayment (optional)', prefixText: store.currency),
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text(due == null ? 'No due date' : 'Due ${DateFormat('d MMM yyyy').format(due!)}'),
                ),
                TextButton(
                  onPressed: () async {
                    final x = await showDatePicker(
                      context: ctx,
                      initialDate: due ?? DateTime.now().add(const Duration(days: 180)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (x != null) setS(() => due = x);
                  },
                  child: const Text('Set date'),
                ),
                if (due != null)
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setS(() => due = null)),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final a = double.tryParse(amount.text.trim()) ?? 0;
    if (lender.text.trim().isEmpty || a <= 0) return;
    final m = double.tryParse(monthly.text.trim()) ?? 0;
    if (d == null) {
      await store.saveDebt(Debt(
          id: store.newId(), lender: lender.text.trim(), amount: a, monthly: m, due: due, note: note.text.trim()));
    } else {
      await store.saveDebt(d.copyWith(
          lender: lender.text.trim(), amount: a, monthly: m, due: due, clearDue: due == null, note: note.text.trim()));
    }
  }

  Future<void> _pay(BuildContext context, Debt d) async {
    final c = TextEditingController(text: d.monthly > 0 ? d.monthly.toStringAsFixed(0) : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Repayment to ${d.lender}'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Amount paid', prefixText: store.currency),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record')),
        ],
      ),
    );
    final v = double.tryParse(c.text.trim()) ?? 0;
    if (ok == true && v > 0) await store.payDebt(d.id, v);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final debts = store.debts.toList()
          ..sort((a, b) => a.cleared == b.cleared ? b.left.compareTo(a.left) : (a.cleared ? 1 : -1));
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: const Text('Debts')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add),
            label: const Text('Add debt'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Card(
                color: const Color(0xFFFFE9E6),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Total you still owe', style: TextStyle(color: Color(0xFF8A2F25))),
                    const SizedBox(height: 4),
                    Text(store.money(store.totalOwed),
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFFB3382B))),
                    if (store.monthlyDebtPayments > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${store.money(store.monthlyDebtPayments)} a month in repayments',
                            style: const TextStyle(color: Color(0xFF8A2F25))),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              if (debts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No debts added. Tap "Add debt" to track a loan and what you have repaid.'),
                ),
              for (final d in debts)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Text(d.lender,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        if (d.cleared)
                          const Chip(label: Text('Cleared'), visualDensity: VisualDensity.compact),
                        PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await _edit(context, d);
                            } else if (v == 'del') {
                              final sure = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('Delete ${d.lender}?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (sure == true) await store.removeDebt(d.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'del', child: Text('Delete')),
                          ],
                        ),
                      ]),
                      Text('${store.money(d.left)} left of ${store.money(d.amount)}',
                          style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: d.fraction, minHeight: 8, borderRadius: BorderRadius.circular(4)),
                      const SizedBox(height: 6),
                      Text(
                        [
                          '${(d.fraction * 100).round()}% repaid (${store.money(d.paid)})',
                          if (d.monthly > 0 && !d.cleared)
                            'about ${(d.left / d.monthly).ceil()} months at ${store.money(d.monthly)}',
                          if (d.due != null) 'due ${DateFormat('d MMM yyyy').format(d.due!)}',
                          if (d.note.isNotEmpty) d.note,
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (!d.cleared)
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonalIcon(
                            onPressed: () => _pay(context, d),
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Record repayment'),
                          ),
                        ),
                    ]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
