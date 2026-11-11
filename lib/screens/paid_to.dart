import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import 'add_txn.dart';
import 'month_bar.dart';

String _who(Txn t) => t.payee.trim().isNotEmpty ? t.payee.trim() : '(no name)';

/// Who was paid: this month vs last month, when and how much last time.
class PaidToScreen extends StatefulWidget {
  final AppStore store;
  const PaidToScreen({super.key, required this.store});

  @override
  State<PaidToScreen> createState() => _PaidToScreenState();
}

class _Row {
  final String name;
  double thisM = 0, lastM = 0;
  int count = 0;
  Txn? last;
  _Row(this.name);
}

class _PaidToScreenState extends State<PaidToScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final m = store.month;
        final prev = DateTime(m.year, m.month - 1);
        final rows = <String, _Row>{};
        for (final t in store.all) {
          if (t.type != TxType.expense || store.isSaving(t.category)) continue;
          final r = rows.putIfAbsent(_who(t), () => _Row(_who(t)));
          if (t.date.year == m.year && t.date.month == m.month) {
            r.thisM += t.amount;
            r.count++;
          } else if (t.date.year == prev.year && t.date.month == prev.month) {
            r.lastM += t.amount;
          }
          if (r.last == null || t.date.isAfter(r.last!.date)) r.last = t;
        }
        final q = _q.trim().toLowerCase();
        final list = rows.values
            .where((r) => (r.thisM != 0 || r.lastM != 0 || q.isNotEmpty) &&
                (q.isEmpty || r.name.toLowerCase().contains(q)))
            .toList()
          ..sort((a, b) => (b.thisM + b.lastM).compareTo(a.thisM + a.lastM));
        final totalThis = list.fold(0.0, (a, r) => a + r.thisM);
        final totalLast = list.fold(0.0, (a, r) => a + r.lastM);
        final mn = DateFormat('MMM');
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Text('Report: who was paid', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            MonthBar(store: store),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search), hintText: 'Search a name', border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(mn.format(m)),
                    Text(store.money(totalThis),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ])),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(mn.format(prev)),
                    Text(store.money(totalLast),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ])),
                ]),
              ),
            ),
            if (list.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No payments in these two months. Add a name in "Paid to" when you record an expense.')),
            for (final r in list)
              Card(
                child: ListTile(
                  title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${mn.format(m)} ${store.money(r.thisM)} · ${mn.format(prev)} ${store.money(r.lastM)}\n'
                      'Last: ${store.money(r.last!.amount)} on ${DateFormat('d MMM yyyy').format(r.last!.date)}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PayeeHistoryScreen(store: store, name: r.name))),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Everything paid to one person: month totals and each payment with its date.
class PayeeHistoryScreen extends StatelessWidget {
  final AppStore store;
  final String name;
  const PayeeHistoryScreen({super.key, required this.store, required this.name});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.all
            .where((t) => t.type == TxType.expense && _who(t) == name)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        final byMonth = <String, double>{};
        for (final t in items) {
          final k = DateFormat('MMM yyyy').format(t.date);
          byMonth[k] = (byMonth[k] ?? 0) + t.amount;
        }
        final total = items.fold(0.0, (a, t) => a + t.amount);
        return Scaffold(
          appBar: AppBar(title: Text(name)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Total paid: ${store.money(total)} (${items.length} payment${items.length == 1 ? '' : 's'})',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final e in byMonth.entries.take(12))
                  Chip(label: Text('${e.key}: ${store.money(e.value)}'), visualDensity: VisualDensity.compact),
              ]),
              const Divider(height: 24),
              for (final t in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(store.money(t.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${DateFormat('EEE d MMM yyyy').format(t.date)} · ${t.category}${t.note.isNotEmpty ? ' · ${t.note}' : ''}'),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => AddTxnScreen(store: store, existing: t))),
                ),
            ],
          ),
        );
      },
    );
  }
}
