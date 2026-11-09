import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import 'add_txn.dart';
import 'drill.dart';

/// Everything that came in: this year by month and by source.
class IncomeScreen extends StatelessWidget {
  final AppStore store;
  const IncomeScreen({super.key, required this.store});

  static const teal = Color(0xFF0F766E);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final year = store.month.year;
        final inc = store.all.where((t) => t.type == TxType.income && t.date.year == year).toList();
        final byMonth = List<double>.filled(12, 0);
        final bySource = <String, double>{};
        for (final t in inc) {
          byMonth[t.date.month - 1] += t.amount;
          final k = t.payee.isNotEmpty ? t.payee : (t.note.isNotEmpty ? t.note : t.category);
          bySource[k] = (bySource[k] ?? 0) + t.amount;
        }
        final total = byMonth.fold(0.0, (a, b) => a + b);
        final spent = store.all
            .where((t) => t.type == TxType.expense && t.date.year == year)
            .fold(0.0, (a, t) => a + t.amount);
        final months = byMonth.where((v) => v > 0).length;
        final maxM = byMonth.fold(0.0, (a, b) => a > b ? a : b);
        final sources = bySource.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: Text('Income $year')),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF14B8A6),
            foregroundColor: Colors.white,
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AddTxnScreen(store: store, initialMode: 1))),
            icon: const Icon(Icons.add),
            label: const Text('Add income'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Card(
                color: const Color(0xFFD3F5F0),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Earned this year', style: TextStyle(color: teal)),
                    const SizedBox(height: 4),
                    Text(store.money(total),
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold, color: teal)),
                    const SizedBox(height: 4),
                    Text(
                        [
                          if (months > 0) 'average ${store.money(total / months)} a month',
                          'spent ${store.money(spent)}',
                          'kept ${store.money(total - spent)}',
                        ].join(' · '),
                        style: const TextStyle(color: teal)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Text('By month', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              for (var i = 0; i < 12; i++)
                InkWell(
                  onTap: byMonth[i] == 0
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => DrillScreen(
                                store: store,
                                title: 'Income',
                                subtitle: DateFormat('MMMM yyyy').format(DateTime(year, i + 1)),
                                test: (t) =>
                                    t.type == TxType.income && t.date.year == year && t.date.month == i + 1,
                              ))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      SizedBox(width: 36, child: Text(DateFormat('MMM').format(DateTime(year, i + 1)))),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxM <= 0 ? 0 : byMonth[i] / maxM,
                            minHeight: 14,
                            color: const Color(0xFF14B8A6),
                            backgroundColor: const Color(0xFFEAF7F5),
                          ),
                        ),
                      ),
                      SizedBox(
                          width: 90,
                          child: Text(byMonth[i] == 0 ? '-' : store.money(byMonth[i]),
                              textAlign: TextAlign.right)),
                    ]),
                  ),
                ),
              const SizedBox(height: 16),
              Text('By source', style: theme.textTheme.titleSmall),
              if (sources.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No income yet.')),
              for (final e in sources.take(10))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.key),
                  trailing: Text(store.money(e.value),
                      style: const TextStyle(color: teal, fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DrillScreen(
                            store: store,
                            title: e.key,
                            subtitle: 'Income $year',
                            test: (t) =>
                                t.type == TxType.income &&
                                t.date.year == year &&
                                (t.payee.isNotEmpty ? t.payee : (t.note.isNotEmpty ? t.note : t.category)) == e.key,
                          ))),
                ),
            ],
          ),
        );
      },
    );
  }
}
