import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import 'category_detail.dart';

const _monthLetters = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
const _monthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// The year at a glance: totals, plain-language insights, cash-flow chart,
/// a budget-to-date ledger and a month-by-month grid.
class YearScreen extends StatefulWidget {
  final AppStore store;
  const YearScreen({super.key, required this.store});

  @override
  State<YearScreen> createState() => _YearScreenState();
}

class _YearScreenState extends State<YearScreen> {
  int _view = 0; // 0 = ledger, 1 = grid

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final y = store.year;
        final totals = store.yearTotals(y);
        final insights = store.insights(y);
        final scheme = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous year',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => store.shiftYear(-1),
                ),
                SizedBox(
                  width: 120,
                  child: Text('$y',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: 'Next year',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: store.canShiftYearNext ? () => store.shiftYear(1) : null,
                ),
              ],
            ),
            Row(children: [
              Expanded(child: _Tile('Income', store.money(totals.income), Colors.green.shade700)),
              const SizedBox(width: 8),
              Expanded(child: _Tile('Spent', store.money(totals.consumption), Colors.red.shade700)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Tile('Saved', store.money(totals.saving), Colors.blue.shade700)),
              const SizedBox(width: 8),
              Expanded(
                  child: _Tile(
                      'True net',
                      '${totals.trueNet >= 0 ? '+' : ''}${store.money(totals.trueNet)}',
                      totals.trueNet >= 0 ? Colors.green.shade700 : Colors.red.shade700)),
            ]),
            const SizedBox(height: 12),
            for (final i in insights)
              Card(
                color: i.warn ? scheme.tertiaryContainer : scheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(i.body, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text('Cash flow', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 14, children: [
              _Dot('Income', Colors.green.shade600),
              _Dot('Spending', Colors.red.shade400),
              _Dot('Saved', Colors.blue.shade500),
            ]),
            const SizedBox(height: 8),
            SizedBox(height: 190, child: _cashFlow(store, y)),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('Ledger')),
                ButtonSegment(value: 1, label: Text('Month grid')),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
            const SizedBox(height: 8),
            if (_view == 0) _ledger(context, store, y) else _grid(context, store, y),
          ],
        );
      },
    );
  }

  Widget _cashFlow(AppStore store, int y) {
    final inc = store.incomeByMonth(y);
    final cons = store.consumptionByMonth(y);
    final sav = store.savingByMonth(y);
    double nz(double v) => math.max(v, 0.0);
    return BarChart(
      BarChartData(
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
              reservedSize: 22,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_monthLetters[v.toInt().clamp(0, 11)],
                    style: const TextStyle(fontSize: 11)),
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < 12; i++)
            BarChartGroupData(x: i, barsSpace: 1, barRods: [
              BarChartRodData(toY: nz(inc[i]), width: 4, color: Colors.green.shade600),
              BarChartRodData(toY: nz(cons[i]), width: 4, color: Colors.red.shade400),
              BarChartRodData(toY: nz(sav[i]), width: 4, color: Colors.blue.shade500),
            ]),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ ledger
  Widget _ledger(BuildContext context, AppStore store, int y) {
    final rows = store.ledger(y);
    final months = store.monthsWithData(y);
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No spending recorded this year yet.')),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Budget to date ($months ${months == 1 ? 'month' : 'months'} of data) vs actual, worst first. '
            'The dark tick is where your budget says you should be. Tap a row for its entries.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        for (final r in rows) _LedgerTile(store: store, row: r, year: y),
      ],
    );
  }

  // ------------------------------------------------------------ grid
  Widget _grid(BuildContext context, AppStore store, int y) {
    final income = store.yearByCategory(y, TxType.income);
    final spend = store.yearByCategory(y, TxType.expense);
    final zero = List<double>.filled(12, 0.0);
    double sum(List<double> v) => v.fold(0.0, (a, b) => a + b);

    final rows = <_GridRow>[];

    List<String> names(List<Category> cats, Map<String, List<double>> m) =>
        [for (final c in cats) if (m.containsKey(c.name) || store.yearBudget(c.name) != null) c.name];

    // Income
    rows.add(_GridRow('Income', store.incomeByMonth(y), header: true));
    final incCats = store.categoriesFor(TxType.income);
    for (final n in names(incCats, income)) {
      rows.add(_GridRow(n, income[n] ?? zero));
    }
    for (final k in income.keys.where((k) => !incCats.any((c) => c.name == k))) {
      rows.add(_GridRow(k, income[k]!));
    }

    // Spending by group
    final expCats = store.categoriesFor(TxType.expense);
    for (final g in store.groupsFor(TxType.expense)) {
      final inGroup = expCats.where((c) => c.group == g).toList();
      final used = names(inGroup, spend);
      if (used.isEmpty) continue;
      final gv = List<double>.filled(12, 0.0);
      double? gBudget;
      var gSpentBudgeted = 0.0;
      for (final n in used) {
        final v = spend[n] ?? zero;
        for (var i = 0; i < 12; i++) {
          gv[i] += v[i];
        }
        final b = store.isSaving(n) ? null : store.yearBudget(n);
        if (b != null) {
          gBudget = (gBudget ?? 0) + b;
          gSpentBudgeted += sum(v);
        }
      }
      rows.add(_GridRow(g, gv,
          header: true,
          budget: gBudget,
          left: gBudget == null ? null : gBudget - gSpentBudgeted));
      for (final n in used) {
        final v = spend[n] ?? zero;
        final b = store.isSaving(n) ? null : store.yearBudget(n);
        rows.add(_GridRow(n, v, budget: b, left: b == null ? null : b - sum(v)));
      }
    }
    final stray = spend.keys.where((k) => !expCats.any((c) => c.name == k)).toList();
    if (stray.isNotEmpty) {
      rows.add(_GridRow('Uncategorised', zero, header: true));
      for (final k in stray) {
        rows.add(_GridRow(k, spend[k]!));
      }
    }

    // Totals
    final inc = store.incomeByMonth(y);
    final cons = store.consumptionByMonth(y);
    final sav = store.savingByMonth(y);
    rows.add(_GridRow('Total spending', cons, total: true));
    rows.add(_GridRow('Saved', sav, total: true));
    rows.add(_GridRow('True net', [for (var i = 0; i < 12; i++) inc[i] - cons[i]],
        total: true));

    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final hl = y == now.year ? now.month - 1 : -1;
    final fmt = NumberFormat('#,##0');
    String f(double? v) => (v == null || v.abs() < 0.005) ? '–' : fmt.format(v.round());

    Widget cell(String text,
        {double w = 62, bool bold = false, Color? color, Color? bg}) {
      return Container(
        width: w,
        height: 36,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        color: bg,
        child: Text(text,
            maxLines: 1,
            style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: color)),
      );
    }

    Color? bgFor(_GridRow r) =>
        (r.header || r.total) ? scheme.surfaceContainerHighest : null;

    final head = Row(children: [
      for (var i = 0; i < 12; i++)
        cell(_monthShort[i],
            bold: true, bg: i == hl ? scheme.primaryContainer : null),
      cell('Total', w: 78, bold: true),
      cell('Budget', w: 78, bold: true),
      cell('Left', w: 78, bold: true),
    ]);

    final body = <Widget>[head];
    final labels = <Widget>[
      Container(
          width: 130,
          height: 36,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 4),
          child: const Text('Category',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
    ];
    for (final r in rows) {
      final t = sum(r.values);
      final bg = bgFor(r);
      final bold = r.header || r.total;
      labels.add(Container(
        width: 130,
        height: 36,
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.only(left: bold ? 4 : 14, right: 4),
        color: bg,
        child: Text(r.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      ));
      body.add(Row(children: [
        for (var i = 0; i < 12; i++)
          cell(f(r.values[i]),
              bold: bold,
              bg: bg ?? (i == hl ? scheme.primaryContainer.withValues(alpha: 0.4) : null)),
        cell(f(t), w: 78, bold: true, bg: bg),
        cell(f(r.budget), w: 78, bold: bold, bg: bg),
        cell(r.left == null ? '–' : fmt.format(r.left!.round()),
            w: 78,
            bold: bold,
            bg: bg,
            color: r.left == null
                ? null
                : (r.left! < 0 ? Colors.red.shade700 : Colors.green.shade700)),
      ]));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: labels),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(children: body),
          ),
        ),
      ],
    );
  }
}

class _GridRow {
  final String label;
  final List<double> values;
  final bool header;
  final bool total;
  final double? budget;
  final double? left;
  const _GridRow(this.label, this.values,
      {this.header = false, this.total = false, this.budget, this.left});
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Tile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 2),
            Text(value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final String label;
  final Color color;
  const _Dot(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _LedgerTile extends StatelessWidget {
  final AppStore store;
  final LedgerRow row;
  final int year;
  const _LedgerTile({required this.store, required this.row, required this.year});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cat = store.categoryByName(row.category);
    final b = row.budgetToDate ?? 0;
    final scale = math.max(row.actual, b);
    final over = row.hasBudget && row.actual > b;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CategoryDetailScreen(
              store: store, category: row.category, year: year))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: cat.colorValue,
                child: Icon(cat.iconData, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(row.category, style: text.bodyLarge)),
              Text(
                !row.hasBudget
                    ? 'no budget'
                    : (over
                        ? '${store.money(row.diff)} over'
                        : '${store.money(-row.diff)} under'),
                style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: !row.hasBudget
                        ? scheme.onSurfaceVariant
                        : (over ? Colors.red.shade700 : Colors.green.shade700)),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Text('Actual ${store.money(row.actual)}', style: text.bodySmall),
              const Spacer(),
              if (row.hasBudget)
                Text('Budget ${store.money(b)}', style: text.bodySmall),
            ]),
            if (scale > 0) ...[
              const SizedBox(height: 6),
              LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth;
                return SizedBox(
                  height: 10,
                  width: w,
                  child: Stack(children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: w * (math.max(row.actual, 0) / scale).clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: over ? scheme.error : scheme.primary,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    if (row.hasBudget)
                      Positioned(
                        left: math.max(0.0, w * (b / scale) - 1),
                        top: 0,
                        bottom: 0,
                        width: 2,
                        child: ColoredBox(color: scheme.onSurface),
                      ),
                  ]),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
