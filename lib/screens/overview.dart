import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import 'add_txn.dart';
import 'drill.dart';
import 'income.dart';
import 'spend_calendar.dart';
import 'debts.dart';
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
            _HeroBanner(store: store),
            const SizedBox(height: 10),
            _QuickRow(store: store),
            const SizedBox(height: 12),
            _ModeSwitch(store: store),
            const SizedBox(height: 4),
            if (store.weekView)
              ..._weekChildren(context, store)
            else ...[
            MonthBar(store: store),
            const SizedBox(height: 8),
            SpendCalendar(store: store),
            const SizedBox(height: 12),
            _SpendMonthCard(store: store),
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
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 56,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (event is! FlTapUpEvent) return;
                            final i = response?.touchedSection?.touchedSectionIndex ?? -1;
                            if (i >= 0 && i < entries.length) {
                              store.selectDonut(entries[i].key);
                            } else {
                              store.selectDonut(null);
                            }
                          },
                        ),
                        sections: [
                          for (final e in entries)
                            PieChartSectionData(
                              value: e.value,
                              color: store.categoryByName(e.key).colorValue.withValues(
                                  alpha: (store.donutSel == null || store.donutSel == e.key) ? 1 : 0.35),
                              radius: store.donutSel == e.key ? 48 : 36,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                    IgnorePointer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entries.any((e) => e.key == store.donutSel) ? store.donutSel! : 'Spent',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            store.money(entries.any((e) => e.key == store.donutSel)
                                ? entries.firstWhere((e) => e.key == store.donutSel).value
                                : total),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (entries.any((e) => e.key == store.donutSel))
                            Text(
                              '${(entries.firstWhere((e) => e.key == store.donutSel).value / total * 100).toStringAsFixed(0)}%',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: Text(
                  store.donutSel == null
                      ? 'Tap a slice to focus a category'
                      : 'Tap the slice again to clear it. Tap a row below for its entries',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 8),
              for (final e in entries)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  selected: store.donutSel == e.key,
                  selectedTileColor:
                      store.categoryByName(e.key).colorValue.withValues(alpha: 0.12),
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
                  onTap: () {
                    final m = store.month;
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => DrillScreen(
                              store: store,
                              title: e.key,
                              subtitle: DateFormat('MMMM yyyy').format(m),
                              test: (t) =>
                                  t.type == TxType.expense &&
                                  t.category == e.key &&
                                  t.date.year == m.year &&
                                  t.date.month == m.month,
                            )));
                  },
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
                                r.$2!.over
                                    ? 'Over by ${store.money(r.$2!.spent - r.$2!.limit)}'
                                    : '${store.money(r.$2!.limit - r.$2!.spent)} left of ${store.money(r.$2!.limit)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: r.$2!.over ? scheme.error : Colors.green.shade800,
                                    fontWeight: FontWeight.w600),
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
      crossAxisAlignment: CrossAxisAlignment.center,
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
                      maxLines: 2,
                      style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
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
  final sel = store.selectedDay;
  final selStart = sel == null ? start : DateTime(start.year, start.month, start.day + sel);
  final selEnd = sel == null
      ? DateTime(start.year, start.month, start.day + 7)
      : DateTime(start.year, start.month, start.day + sel + 1);
  final byCat = store
      .spendBreakdown(selStart, selEnd, merchant: store.byMerchant)
      .entries
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final shownTotal = byCat.fold(0.0, (a, e) => a + e.value);
  final shownLabel = sel == null
      ? 'the week'
      : (isCurrent && sel == todayIndex ? 'today' : DateFormat('EEE d MMM').format(selStart));
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
              versus: 'last week (same days)',
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 16),
    Row(
      children: [
        Expanded(
          child: Text('Day by day', style: Theme.of(context).textTheme.titleMedium),
        ),
        TextButton.icon(
          icon: const Icon(Icons.event, size: 18),
          label: const Text('Pick a date'),
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: sel == null ? DateTime.now() : selStart,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (d != null) store.pickDate(d);
          },
        ),
      ],
    ),
    const SizedBox(height: 8),
    SizedBox(
      height: 170,
      child: BarChart(
        BarChartData(
          maxY: hi <= 0 ? 1 : hi * 1.3,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                store.money(rod.toY),
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            touchCallback: (event, response) {
              if (event is FlTapUpEvent && response?.spot != null) {
                store.selectDay(response!.spot!.touchedBarGroupIndex);
              }
            },
          ),
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
                  color: (sel != null && sel != i)
                      ? scheme.primary.withValues(alpha: 0.3)
                      : (i == todayIndex ? const Color(0xFFFF6B5E) : scheme.primary),
                ),
              ]),
          ],
        ),
      ),
    ),
    const SizedBox(height: 4),
    Text('Dashed line: your daily average. Tap a bar to see that day.',
        style: Theme.of(context).textTheme.bodySmall),
    const SizedBox(height: 16),
    Row(
      children: [
        Expanded(
          child: Text(
              'Where $shownLabel went · ${store.money(shownTotal)}',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        if (sel != null)
          TextButton(
              onPressed: () => store.selectDay(null), child: const Text('Whole week')),
      ],
    ),
    const SizedBox(height: 4),
    SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: false, label: Text('By category')),
        ButtonSegment(value: true, label: Text('By merchant')),
      ],
      selected: {store.byMerchant},
      onSelectionChanged: (s) => store.setByMerchant(s.first),
    ),
    if (byCat.isEmpty)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Nothing spent $shownLabel.')),
      ),
    for (final e in byCat.take(store.byMerchant ? 30 : 12))
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: store.byMerchant
            ? const CircleAvatar(radius: 16, child: Icon(Icons.storefront, size: 16))
            : CircleAvatar(
                radius: 16,
                backgroundColor: store.categoryByName(e.key).colorValue,
                child: Icon(store.categoryByName(e.key).iconData, size: 16, color: Colors.white),
              ),
        title: Text(e.key),
        subtitle: Text(
            '${(e.value / (shownTotal <= 0 ? 1 : shownTotal) * 100).toStringAsFixed(0)}% of $shownLabel'),
        trailing: Text(store.money(e.value)),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DrillScreen(
                  store: store,
                  title: e.key,
                  subtitle: sel == null
                      ? '${DateFormat('d MMM').format(selStart)} – ${DateFormat('d MMM').format(selEnd.subtract(const Duration(days: 1)))}'
                      : DateFormat('EEE d MMM').format(selStart),
                  test: (t) =>
                      t.type == TxType.expense &&
                      !store.isSaving(t.category) &&
                      !t.date.isBefore(selStart) &&
                      t.date.isBefore(selEnd) &&
                      (store.byMerchant
                          ? (e.key == 'No merchant'
                              ? t.payee.trim().isEmpty
                              : t.payee.trim() == e.key)
                          : t.category == e.key),
                ))),
      ),
  ];
}

/// Friendly colourful strip at the top: greeting, what is left this month, and payday.
class _HeroBanner extends StatelessWidget {
  final AppStore store;
  const _HeroBanner({required this.store});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hello = now.hour < 12 ? 'Good morning' : (now.hour < 18 ? 'Good afternoon' : 'Good evening');
    final lines = <String>[];
    if (lines.isEmpty) lines.add('Record income and spending whenever suits you');
    return Row(
      children: [
        Expanded(
          child: Text('$hello',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF3B2A99))),
        ),
        Text(DateFormat('EEE d MMM').format(now),
            style: const TextStyle(fontSize: 14, color: Colors.black54)),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
        ),
      ],
    );
  }
}

void _openIncome(BuildContext context, AppStore store) {
  final m = store.month;
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DrillScreen(
            store: store,
            title: 'Income',
            subtitle: DateFormat('MMMM yyyy').format(m),
            test: (t) =>
                t.type == TxType.income && t.date.year == m.year && t.date.month == m.month,
          )));
}

/// Money coming in this month: total, each payment, and the next expected pay.
class _IncomeCard extends StatelessWidget {
  final AppStore store;
  const _IncomeCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final m = store.month;
    final items = store.all
        .where((t) => t.type == TxType.income && t.date.year == m.year && t.date.month == m.month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = items.fold(0.0, (a, t) => a + t.amount);
    const teal = Color(0xFF0F766E);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFD3F5F0),
                  child: Icon(Icons.south_west, size: 18, color: teal),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Income this ${store.isCurrentMonth ? 'month' : 'period'}',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                Text(store.money(total),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: teal, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text('No income recorded yet.',
                  style: Theme.of(context).textTheme.bodyMedium),
            for (final t in items.take(4))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(t.payee.isNotEmpty ? t.payee : (t.note.isNotEmpty ? t.note : t.category)),
                subtitle: Text('${t.category} · ${DateFormat('EEE d MMM').format(t.date)}'),
                trailing: Text('+${store.money(t.amount)}',
                    style: const TextStyle(color: teal, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AddTxnScreen(store: store, existing: t))),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AddTxnScreen(store: store, initialMode: 1))),
                  icon: const Icon(Icons.add),
                  label: const Text('Add income'),
                ),
                const Spacer(),
                TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => IncomeScreen(store: store))),
                    child: const Text('Year view')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One-tap buttons for the side-menu sections.
class _QuickRow extends StatelessWidget {
  final AppStore store;
  const _QuickRow({required this.store});

  @override
  Widget build(BuildContext context) {
    Widget b(IconData i, String l, Widget Function() page) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page())),
              icon: Icon(i, size: 18),
              label: Text(l, overflow: TextOverflow.ellipsis),
            ),
          ),
        );
    return Row(children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                backgroundColor: const Color(0xFFD3F5F0),
                foregroundColor: const Color(0xFF0F766E),
                padding: const EdgeInsets.symmetric(horizontal: 4)),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AddTxnScreen(store: store, initialMode: 1))),
            icon: const Icon(Icons.south_west, size: 18),
            label: const Text('Money in'),
          ),
        ),
      ),
      b(Icons.account_balance_outlined, 'Debts', () => DebtsScreen(store: store)),
    ]);
  }
}

/// Spending for the selected month as one number, plus a bar per week of the month.
class _SpendMonthCard extends StatelessWidget {
  final AppStore store;
  const _SpendMonthCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final m = store.month;
    final days = DateUtils.getDaysInMonth(m.year, m.month);
    final nWeeks = (days / 7).ceil();
    final weeks = List<double>.filled(nWeeks, 0);
    for (final t in store.monthTxns) {
      if (t.type == TxType.expense && !store.isSaving(t.category)) {
        weeks[((t.date.day - 1) ~/ 7).clamp(0, nWeeks - 1).toInt()] += t.amount;
      }
    }
    final total = store.monthExpense;
    final maxW = weeks.fold(0.0, (a, b) => a > b ? a : b);
    const bar = Color(0xFF5B3FD9);
    const barH = 110.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spent in ${DateFormat('MMMM').format(m)}',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(store.money(total),
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: bar)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < nWeeks; i++)
                  Expanded(
                    child: InkWell(
                      onTap: weeks[i] == 0
                          ? null
                          : () {
                              final from = i * 7 + 1;
                              final to = (i + 1) * 7 > days ? days : (i + 1) * 7;
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => DrillScreen(
                                        store: store,
                                        title: 'Week ${i + 1}',
                                        subtitle: '$from-$to ${DateFormat('MMMM').format(m)}',
                                        test: (t) =>
                                            t.type == TxType.expense &&
                                            !store.isSaving(t.category) &&
                                            t.date.year == m.year &&
                                            t.date.month == m.month &&
                                            t.date.day >= from &&
                                            t.date.day <= to,
                                      )));
                            },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(weeks[i] == 0 ? '' : store.money(weeks[i]).replaceAll('.00', ''),
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Container(
                            height: maxW <= 0 ? 4 : (4 + (barH - 4) * weeks[i] / maxW),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: weeks[i] == maxW && maxW > 0 ? bar : const Color(0xFFB7A8F5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Week ${i + 1}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _TrendRow(
              trend: store.monthTrend(store.month),
              series: store.monthlySpendSeries(store.month),
              versus: 'last month (same days)',
            ),
          ],
        ),
      ),
    );
  }
}
