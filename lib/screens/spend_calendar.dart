import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import 'drill.dart';

String _short(double v) {
  final a = v.abs();
  if (a >= 10000000) return '${(a / 10000000).toStringAsFixed(1)}Cr';
  if (a >= 100000) return '${(a / 100000).toStringAsFixed(1)}L';
  if (a >= 1000) return '${(a / 1000).toStringAsFixed(a >= 10000 ? 0 : 1)}k';
  return a.round().toString();
}

/// Month calendar showing how much was spent on each day. Tap a day for its entries.
class SpendCalendar extends StatelessWidget {
  final AppStore store;
  const SpendCalendar({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final m = store.month;
    final days = DateUtils.getDaysInMonth(m.year, m.month);
    final lead = DateTime(m.year, m.month, 1).weekday % 7; // Sunday first
    final perDay = List<double>.filled(days + 1, 0);
    for (final t in store.monthTxns) {
      if (t.type == TxType.expense && !store.isSaving(t.category)) perDay[t.date.day] += t.amount;
    }
    final maxV = perDay.fold(0.0, (a, b) => a > b ? a : b);
    final now = DateTime.now();
    const purple = Color(0xFF5B3FD9);
    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= days; d++) {
      final v = perDay[d];
      final isToday = now.year == m.year && now.month == m.month && now.day == d;
      final shade = maxV <= 0 ? 0.0 : (v / maxV);
      cells.add(InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DrillScreen(
                  store: store,
                  title: DateFormat('EEEE d MMMM').format(DateTime(m.year, m.month, d)),
                  subtitle: 'Spent ${store.money(v)}',
                  test: (t) =>
                      t.type == TxType.expense &&
                      !store.isSaving(t.category) &&
                      t.date.year == m.year &&
                      t.date.month == m.month &&
                      t.date.day == d,
                ))),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: v > 0 ? purple.withOpacity(0.10 + 0.40 * shade) : const Color(0xFFF3F1FA),
            borderRadius: BorderRadius.circular(10),
            border: isToday ? Border.all(color: purple, width: 2) : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$d', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(v > 0 ? _short(v) : '·',
                  style: TextStyle(fontSize: 11, color: v > 0 ? const Color(0xFF3B2A99) : Colors.black38)),
            ],
          ),
        ),
      ));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(children: [
              for (final w in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                    child: Center(
                        child: Text(w, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)))),
            ]),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.95,
              children: cells,
            ),
            const SizedBox(height: 4),
            const Text('Tap a day to see what was paid', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
