import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import '../trends.dart';
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
            _ModeSwitch(store: store),
            const SizedBox(height: 4),
            if (store.weekView)
              ..._weekChildren(context, store)
            else ...[
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
                    const SizedBox(height: 14),
                    _TrendRow(
                      trend: store.monthTrend(store.month),
                      series: store.monthlySpendSeries(store.month),
                      versus: 'last month',
                    ),
                  ],
                ),
              ),
            ),
            if (store.isCurrentMonth) ...[
              const SizedBox(height: 12),
              _BudgetProgressCard(store: store),
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

class _ModeSwitch extends StatelessWidget {
  final AppStore store;
  const _ModeSwitch({required this.store});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: true, label: Text('Week')),
        ButtonSegment(value: false, label: Text('Month')),
      ],
      selected: {store.weekView},
      onSelectionChanged: (v) => store.setWeekView(v.first),
    );
  }
}

/// "12% lower than last month" with a small trend graph. Spending going
/// down is shown as good news (green), going up as a heads-up (coral).
class _TrendRow extends StatelessWidget {
  final Trend trend;
  final List<double> series;
  final String versus;
  const _TrendRow({required this.trend, required this.series, required this.versus});

  @override
  Widget build(BuildContext context) {
    final pct = trend.pct;
    final down = pct != null && pct < 0;
    final flat = pct == null || pct.abs() < 1;
    final bg = flat
        ? Colors.white.withValues(alpha: 0.22)
        : (down ? const Color(0xFFCFF5E2) : const Color(0xFFFFE3DF));
    final fg = flat
        ? Colors.white
        : (down ? const Color(0xFF14663C) : const Color(0xFF8A2A20));
    final text = pct == null
        ? 'No spending $versus to compare'
        : (flat
            ? 'About the same as $versus'
            : '${pct.abs().toStringAsFixed(0)}% ${down ? 'lower' : 'higher'} than $versus');
    return Row(
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    flat
                        ? Icons.trending_flat
                        : (down ? Icons.trending_down : Icons.trending_up),
                    size: 18,
                    color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(text,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        if (series.length > 1) _Sparkline(values: series),
      ],
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> values;
  const _Sparkline({required this.values});

  @override
  Widget build(BuildContext context) {
    var hi = 0.0;
    for (final v in values) {
      if (v > hi) hi = v;
    }
    return SizedBox(
      width: 84,
      height: 30,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: hi <= 0 ? 1 : hi * 1.15,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
              isCurved: true,
              color: Colors.white,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  final AppStore store;
  const _WeekBar({required this.store});

  @override
  Widget build(BuildContext context) {
    final start = store.weekAnchor;
    final end = DateTime(start.year, start.month, start.day + 6);
    final f = DateFormat('d MMM');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous week',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => store.shiftWeek(-1),
        ),
        SizedBox(
          width: 170,
          child: Text(
            '${f.format(start)} – ${f.format(end)}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Next week',
          icon: const Icon(Icons.chevron_right),
          onPressed: store.canWeekNext ? () => store.shiftWeek(1) : null,
        ),
      ],
    );
  }
}

/// How the week is going: total, per-day bars and top categories.
List<Widget> _weekChildren(BuildContext context, AppStore store) {
  final start = store.weekAnchor;
  final days = store.daySpend(start);
  final total = days.fold(0.0, (a, b) => a + b);
  final now = DateTime.now();
  final isCurrent = weekStartOf(now) == start;
  final elapsed = isCurrent ? now.weekday : 7;
  final todayIndex = isCurrent ? now.weekday - 1 : -1;
  final scheme = Theme.of(context).colorScheme;
  final byCat = store.weekByCategory(start).entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  var hi = 0.0;
  for (final v in days) {
    if (v > hi) hi = v;
  }
  final avg = total / elapsed;
  const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  return [
    _WeekBar(store: store),
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
            Text(isCurrent ? 'Spent so far this week' : 'Spent this week',
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 4),
            Text(store.money(total),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('About ${store.money(avg)} a day',
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 14),
            _TrendRow(
              trend: store.weekTrend(start),
              series: const [],
              versus: 'last week',
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 16),
    Text('Day by day', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    SizedBox(
      height: 170,
      child: BarChart(
        BarChartData(
          maxY: hi <= 0 ? 1 : hi * 1.3,
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
                    child: Text(i >= 0 && i < 7 ? letters[i] : '',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: i == todayIndex ? FontWeight.bold : FontWeight.normal)),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(horizontalLines: [
            if (avg > 0)
              HorizontalLine(
                y: avg,
                color: scheme.onSurface.withValues(alpha: 0.5),
                strokeWidth: 1.5,
                dashArray: [6, 4],
              ),
          ]),
          barGroups: [
            for (var i = 0; i < 7; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: days[i],
                  width: 22,
                  borderRadius: BorderRadius.circular(6),
                  color: i == todayIndex
                      ? const Color(0xFFFF6B5E)
                      : scheme.primary,
                ),
              ]),
          ],
        ),
      ),
    ),
    const SizedBox(height: 4),
    Text('Dashed line: your daily average',
        style: Theme.of(context).textTheme.bodySmall),
    const SizedBox(height: 16),
    Text('Where it went', style: Theme.of(context).textTheme.titleMedium),
    if (byCat.isEmpty)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Nothing spent this week yet.')),
      ),
    for (final e in byCat.take(6))
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: store.categoryByName(e.key).colorValue,
          child: Icon(store.categoryByName(e.key).iconData, size: 16, color: Colors.white),
        ),
        title: Text(e.key),
        subtitle: Text('${(e.value / (total <= 0 ? 1 : total) * 100).toStringAsFixed(0)}% of the week'),
        trailing: Text(store.money(e.value)),
      ),
  ];
}
