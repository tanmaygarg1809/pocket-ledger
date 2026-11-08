import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'month_bar.dart';

class BudgetsScreen extends StatelessWidget {
  final AppStore store;
  const BudgetsScreen({super.key, required this.store});

  static String _name(BudgetPeriod p) => p == BudgetPeriod.month
      ? 'Monthly'
      : (p == BudgetPeriod.quarter ? 'Quarterly' : 'Yearly');

  Future<void> _edit(BuildContext context, String category) async {
    final period = store.budgetPeriod;
    final current = store.budgetsFor(period)[category];
    final monthly = store.budgets[category];
    final ctrl = TextEditingController(
        text: current == null ? '' : current.toStringAsFixed(0));
    String? tip;
    if (period == BudgetPeriod.quarter && monthly != null) {
      tip = 'Monthly × 3 = ${store.money(monthly * 3)}';
    } else if (period == BudgetPeriod.year && monthly != null) {
      tip = 'Monthly × 12 = ${store.money(monthly * 12)}';
    }
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$category · ${_name(period).toLowerCase()} budget'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '${_name(period)} limit',
            prefixText: store.currency,
            helperText:
                tip == null ? 'Leave empty to remove' : '$tip · empty removes',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    store.setBudget(category, double.tryParse(result.replaceAll(',', '.').trim()),
        period: period);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final period = store.budgetPeriod;
        final spent = store.spentByCategory(period, store.budgetAnchor);
        final limits = store.budgetsFor(period);
        final totalLimit = limits.values.fold(0.0, (a, b) => a + b);
        final totalSpent =
            limits.keys.fold(0.0, (a, k) => a + (spent[k] ?? 0));
        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<BudgetPeriod>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: BudgetPeriod.month, label: Text('Month')),
                  ButtonSegment(
                      value: BudgetPeriod.quarter, label: Text('Quarter')),
                  ButtonSegment(value: BudgetPeriod.year, label: Text('Year')),
                ],
                selected: {period},
                onSelectionChanged: (s) => store.setBudgetPeriod(s.first),
              ),
            ),
            PeriodBar(store: store),
            if (limits.isNotEmpty)
              _Summary(
                store: store,
                label: 'Total ${_name(period).toLowerCase()} budget',
                limit: totalLimit,
                spent: totalSpent,
              )
            else
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Tap a category to set a limit for this period.'),
              ),
            for (final g in store.groupsFor(TxType.expense)) ...[
              _groupHeader(context, g, spent, limits),
              for (final c in store.categoriesFor(TxType.expense)
                  .where((c) => c.group == g))
                _row(context, c, spent[c.name] ?? 0, limits[c.name]),
            ],
          ],
        );
      },
    );
  }

  Widget _groupHeader(BuildContext context, String group,
      Map<String, double> spent, Map<String, double> limits) {
    final cats = store
        .categoriesFor(TxType.expense)
        .where((c) => c.group == group)
        .toList();
    final limit = cats.fold(0.0, (a, c) => a + (limits[c.name] ?? 0));
    final used = cats.fold(0.0, (a, c) => a + (spent[c.name] ?? 0));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(group, style: Theme.of(context).textTheme.titleSmall),
          ),
          Text(
            limit > 0
                ? '${store.money(used)} of ${store.money(limit)}'
                : store.money(used),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Category c, double spent, double? limit) {
    final over = limit != null && spent > limit;
    final progress =
        limit == null ? 0.0 : (spent / limit).clamp(0.0, 1.0).toDouble();
    return ListTile(
      onTap: () => _edit(context, c.name),
      leading: CircleAvatar(
        backgroundColor: c.colorValue,
        child: Icon(c.iconData, color: Colors.white, size: 20),
      ),
      title: Text(c.name),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: limit == null
            ? Text('Spent ${store.money(spent)} · no limit')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                    color: over ? Colors.red.shade600 : null,
                  ),
                  const SizedBox(height: 4),
                  Text(over
                      ? 'Over by ${store.money(spent - limit)}'
                      : '${store.money(spent)} of ${store.money(limit)}'),
                ],
              ),
      ),
      trailing: const Icon(Icons.edit_outlined, size: 18),
    );
  }
}

class _Summary extends StatelessWidget {
  final AppStore store;
  final String label;
  final double limit;
  final double spent;
  const _Summary(
      {required this.store,
      required this.label,
      required this.limit,
      required this.spent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final over = spent > limit;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      color: over ? scheme.errorContainer : scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              over
                  ? 'Over by ${store.money(spent - limit)}'
                  : '${store.money(limit - spent)} left',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (spent / limit).clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: over ? scheme.error : null,
            ),
            const SizedBox(height: 6),
            Text('${store.money(spent)} of ${store.money(limit)}'),
          ],
        ),
      ),
    );
  }
}
