import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'month_bar.dart';

class OverviewScreen extends StatelessWidget {
  final AppStore store;
  const OverviewScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final income = store.monthIncome;
        final expense = store.monthExpense;
        final saved = store.monthSaving;
        final net = store.monthTrueNet;
        final byCat = store.monthExpenseByCategory;
        final entries = byCat.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final total = entries.fold(0.0, (a, e) => a + e.value);
        final scheme = Theme.of(context).colorScheme;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            MonthBar(store: store),
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0A8A7C), Color(0xFF19B59E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('True net this month (after saving)',
                        style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      '${net >= 0 ? '+' : ''}${store.money(net)}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _Stat(
                            label: 'Income',
                            value: store.money(income),
                            icon: Icons.arrow_downward,
                            color: Colors.green.shade700,
                          ),
                        ),
                        Expanded(
                          child: _Stat(
                            label: 'Spent',
                            value: store.money(expense),
                            icon: Icons.arrow_upward,
                            color: Colors.red.shade700,
                          ),
                        ),
                        Expanded(
                          child: _Stat(
                            label: 'Saved',
                            value: store.money(saved),
                            icon: Icons.savings_outlined,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (store.isCurrentMonth) ...[
              const SizedBox(height: 12),
              _SafeToSpendCard(store: store),
              const SizedBox(height: 12),
              _BudgetProgressCard(store: store),
              const SizedBox(height: 12),
              _PaceCard(store: store),
            ],
            const SizedBox(height: 16),
            Text('Spending by category',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('No spending recorded this month.')),
              )
            else ...[
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 48,
                    sections: [
                      for (final e in entries)
                        PieChartSectionData(
                          value: e.value,
                          color: store.categoryByName(e.key).colorValue,
                          radius: 36,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final e in entries)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: store.categoryByName(e.key).colorValue,
                    child: Icon(store.categoryByName(e.key).iconData,
                        size: 16, color: Colors.white),
                  ),
                  title: Text(e.key),
                  subtitle: Text(
                      '${(e.value / total * 100).toStringAsFixed(0)}% of spending'),
                  trailing: Text(store.money(e.value)),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Stat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.white,
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Colors.white70)),
              Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SafeToSpendCard extends StatelessWidget {
  final AppStore store;
  const _SafeToSpendCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store.safeToSpend;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (s == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.savings_outlined),
          title: Text('Safe to spend today'),
          subtitle: Text(
              'Set category budgets (Budgets tab) to see how much you can spend each day.'),
        ),
      );
    }
    final over = s.overBudget;
    final overToday = !over && s.leftToday < 0;
    final headline = over
        ? 'Over budget by ${store.money(-s.remainingMonth)}'
        : overToday
            ? 'Over today by ${store.money(-s.leftToday)}'
            : '${store.money(s.leftToday)} left today';
    final bad = over || overToday;
    final fg = bad ? scheme.onErrorContainer : scheme.onSecondaryContainer;
    return Card(
      color: bad ? scheme.errorContainer : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Safe to spend today',
                style: text.labelMedium?.copyWith(color: fg)),
            const SizedBox(height: 4),
            Text(headline,
                style: text.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold, color: fg)),
            if (!over) ...[
              const SizedBox(height: 4),
              Text(
                'Daily allowance ${store.money(s.dailyAllowance)} · '
                '${store.money(s.remainingMonth)} left this month · '
                '${s.daysLeft} day${s.daysLeft == 1 ? '' : 's'} to go',
                style: text.bodySmall?.copyWith(color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetProgressCard extends StatelessWidget {
  final AppStore store;
  const _BudgetProgressCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final rows = <(String, BudgetProgress?)>[
      ('This month', store.budgetProgress(BudgetPeriod.month)),
      ('Q${(now.month - 1) ~/ 3 + 1} ${now.year}',
          store.budgetProgress(BudgetPeriod.quarter)),
      ('${now.year}', store.budgetProgress(BudgetPeriod.year)),
    ];
    if (rows.every((r) => r.$2 == null)) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Budget progress',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: r.$2 == null
                    ? Text('${r.$1}: no budget set',
                        style: Theme.of(context).textTheme.bodySmall)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(r.$1),
                              const Spacer(),
                              Text(
                                '${store.money(r.$2!.spent)} of ${store.money(r.$2!.limit)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: r.$2!.fraction,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                            color: r.$2!.over ? scheme.error : null,
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Average daily spend and where this month / year are heading.
class _PaceCard extends StatelessWidget {
  final AppStore store;
  const _PaceCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final p = store.pace();
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pace', style: text.titleSmall),
            const SizedBox(height: 8),
            Text('${store.money(p.perDay)} per day so far this month',
                style: text.bodyLarge),
            const SizedBox(height: 4),
            Text('On pace for ${store.money(p.monthProjection)} this month',
                style: text.bodyMedium),
            const SizedBox(height: 4),
            Text(
              p.yearProjection == null
                  ? 'Year projection appears after the first few weeks.'
                  : 'On pace for ${store.money(p.yearProjection!)} this year'
                      '${p.yearBudget == null ? '' : ' (budget ${store.money(p.yearBudget!)})'}',
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
