import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../budget_tips.dart';
import '../models.dart';
import '../store.dart';
import 'drill.dart';
import 'month_bar.dart';
import 'year.dart';

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
                child: Text('Tap a category to see its entries, or the pencil to set a limit.'),
              ),
            if (limits.isNotEmpty) ...[
              _SectionTitle(
                  'Spending against budget',
                  period == BudgetPeriod.month
                      ? 'by week'
                      : 'by month'),
              _SpendChart(store: store, period: period),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.list_alt),
                label: Text('See every entry for ${_periodLabel()}'),
                onPressed: () => _drill(context, null),
              ),
            ),
            _SectionTitle('How to bring it down', 'tips from your numbers'),
            for (final t in store.tips(period, store.budgetAnchor)) _TipCard(tip: t),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.bar_chart),
                label: const Text('See the full year view'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Year')),
                    body: SafeArea(child: YearScreen(store: store)),
                  ),
                )),
              ),
            ),
            const _SectionTitle('Your categories', 'tap to see entries, pencil to set a limit'),
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
      onTap: () => _drill(context, c.name),
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
                  Text(
                    over
                        ? 'Over by ${store.money(spent - limit)} · ${store.money(spent)} of ${store.money(limit)}'
                        : '${store.money(limit - spent)} left to spend · ${store.money(spent)} of ${store.money(limit)}',
                    style: TextStyle(
                        color: over ? Colors.red.shade700 : Colors.green.shade800,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
      ),
      trailing: IconButton(
        tooltip: 'Set limit',
        icon: const Icon(Icons.edit_outlined, size: 18),
        onPressed: () => _edit(context, c.name),
      ),
    );
  }

  String _periodLabel() {
    final p = store.budgetPeriod;
    final a = store.budgetAnchor;
    if (p == BudgetPeriod.month) return DateFormat('MMMM yyyy').format(a);
    if (p == BudgetPeriod.quarter) return 'Q${(a.month - 1) ~/ 3 + 1} ${a.year}';
    return '${a.year}';
  }

  /// Every entry in this period: for one category, or all spending when [category] is null.
  void _drill(BuildContext context, String? category) {
    final p = store.budgetPeriod;
    final start = AppStore.periodStart(p, store.budgetAnchor);
    final end = AppStore.periodEnd(p, store.budgetAnchor);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DrillScreen(
        store: store,
        title: category ?? 'All spending',
        subtitle: _periodLabel(),
        test: (t) =>
            t.type == TxType.expense &&
            (category == null ? !store.isSaving(t.category) : t.category == category) &&
            !t.date.isBefore(start) &&
            t.date.isBefore(end),
      ),
    ));
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final String sub;
  const _SectionTitle(this.title, this.sub);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Text(sub, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SpendChart extends StatelessWidget {
  final AppStore store;
  final BudgetPeriod period;
  const _SpendChart({required this.store, required this.period});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = store.spendBuckets(period, store.budgetAnchor);
    final bars = data.bars;
    final line = data.budgetPerBar;
    final top = [
      line,
      for (final b in bars) b.spent,
    ].reduce((a, b) => a > b ? a : b);
    final maxY = top <= 0 ? 1.0 : top * 1.25;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        height: 170,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(i >= 0 && i < bars.length ? bars[i].label : '',
                          style: const TextStyle(fontSize: 11)),
                    );
                  },
                ),
              ),
            ),
            extraLinesData: ExtraLinesData(horizontalLines: [
              if (line > 0)
                HorizontalLine(
                  y: line,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                ),
            ]),
            barGroups: [
              for (var i = 0; i < bars.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: bars[i].spent,
                    width: bars.length > 6 ? 14 : 28,
                    borderRadius: BorderRadius.circular(5),
                    color: line > 0 && bars[i].spent > line
                        ? const Color(0xFFFF6B5E)
                        : scheme.primary,
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final Tip tip;
  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      color: tip.good ? const Color(0xFFE6F7EE) : scheme.secondaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                    tip.good ? Icons.thumb_up_alt_outlined : Icons.lightbulb_outline,
                    size: 20,
                    color: tip.good ? const Color(0xFF1B7F4B) : scheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(tip.title,
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(tip.body, style: text.bodyMedium),
            if (tip.saving != null) ...[
              const SizedBox(height: 8),
              Text('Could save ${tip.saving}',
                  style: text.labelLarge?.copyWith(
                      color: const Color(0xFF1B7F4B), fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }
}
