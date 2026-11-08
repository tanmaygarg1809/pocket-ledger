import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../forecast.dart';
import '../store.dart';

/// Where your cash is heading over the next 30 / 60 / 90 days.
class ForecastScreen extends StatefulWidget {
  final AppStore store;
  const ForecastScreen({super.key, required this.store});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  int _days = 60;
  double _extra = 0;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final f = store.forecast(_days, extraDaily: _extra);
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final df = DateFormat('EEE d MMM');
    final lowDate = DateTime(today.year, today.month, today.day + f.lowDay);
    final spots = [
      FlSpot(0, f.start),
      for (var i = 0; i < f.balances.length; i++) FlSpot((i + 1).toDouble(), f.balances[i]),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Cash forecast')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 30, label: Text('30 days')),
              ButtonSegment(value: 60, label: Text('60 days')),
              ButtonSegment(value: 90, label: Text('90 days')),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat(context, 'Now', store.money(f.start)),
              _stat(context, 'In $_days days', store.money(f.end),
                  color: f.end < f.start ? Colors.red.shade700 : Colors.green.shade800),
              _stat(context, 'Lowest', store.money(f.low),
                  sub: f.low < f.start ? df.format(lowDate) : null,
                  color: f.low < 0 ? Colors.red.shade700 : null),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: (_days / 3).roundToDouble(),
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                            DateFormat('d MMM').format(DateTime(today.year, today.month, today.day + v.toInt())),
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(y: 0, color: Colors.red.shade300, strokeWidth: 1, dashArray: [5, 4]),
                ]),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: scheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: scheme.primary.withValues(alpha: 0.12)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('What if I spend more or less each day?',
              style: Theme.of(context).textTheme.titleSmall),
          Slider(
            value: _extra,
            min: -20,
            max: 20,
            divisions: 40,
            label: '${_extra >= 0 ? '+' : '-'}${store.money(_extra.abs())} a day',
            onChanged: (v) => setState(() => _extra = v),
          ),
          Text(
            'Everyday spending assumed: ${store.money(f.dailySpend)} a day (your last 90 days, excluding recurring bills)'
            '${_extra == 0 ? '' : ', adjusted by ${_extra > 0 ? '+' : '-'}${store.money(_extra.abs())}'}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (f.unknownPayMonth != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Pay for ${DateFormat('MMMM').format(f.unknownPayMonth!)} is not in the forecast because its date is not set. Set it in Settings → Pay date.',
                style: TextStyle(color: Colors.orange.shade800),
              ),
            ),
          if (f.start == 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Add your bank, savings or cash accounts in Net worth so the forecast starts from your real balance.'),
            ),
          const SizedBox(height: 16),
          Text('Coming up', style: Theme.of(context).textTheme.titleMedium),
          if (f.events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No recurring bills or pay in this period.'),
            ),
          for (final e in f.events)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(e.amount >= 0 ? Icons.south_west : Icons.north_east,
                  color: e.amount >= 0 ? Colors.green.shade700 : Colors.red.shade700),
              title: Text(e.label),
              subtitle: Text(df.format(e.date)),
              trailing: Text('${e.amount >= 0 ? '+' : '-'}${store.money(e.amount.abs())}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 16),
          Text(
            'An estimate: it uses your account balances, recurring bills, your last three salaries and your usual daily spending.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, {String? sub, Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: color)),
          if (sub != null) Text(sub, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
