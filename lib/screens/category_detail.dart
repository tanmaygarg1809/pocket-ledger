import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import 'add_txn.dart';

/// Every entry in one category for a year (tap a ledger row to open).
class CategoryDetailScreen extends StatelessWidget {
  final AppStore store;
  final String category;
  final int year;
  const CategoryDetailScreen(
      {super.key, required this.store, required this.category, required this.year});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$category · $year')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.all
              .where((t) => t.category == category && t.date.year == year)
              .toList();
          final total = items.fold(0.0, (a, t) => a + t.amount);
          if (items.isEmpty) {
            return const Center(child: Text('No entries.'));
          }
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${items.length} ${items.length == 1 ? 'entry' : 'entries'} · ${store.money(total)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final t in items)
                ListTile(
                  title: Text(t.payee.isNotEmpty
                      ? t.payee
                      : (t.note.isNotEmpty ? t.note : t.category)),
                  subtitle: Text(DateFormat('d MMM yyyy').format(t.date) +
                      (t.amount < 0 && t.type == TxType.expense ? ' · refund' : '')),
                  trailing: Text(store.money(t.amount),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AddTxnScreen(store: store, existing: t))),
                ),
            ],
          );
        },
      ),
    );
  }
}
