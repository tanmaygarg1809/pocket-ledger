import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import 'add_txn.dart';

/// The entries behind a number: tap a category or merchant on the Overview
/// to see exactly what it is made of. Tap a row to edit or delete it.
class DrillScreen extends StatelessWidget {
  final AppStore store;
  final String title;
  final String subtitle;
  final bool Function(Txn) test;
  const DrillScreen({
    super.key,
    required this.store,
    required this.title,
    required this.subtitle,
    required this.test,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.all.where(test).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          final total = items.fold(0.0, (a, t) => a + t.amount);
          if (items.isEmpty) return const Center(child: Text('No entries.'));
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '$subtitle · ${items.length} ${items.length == 1 ? 'entry' : 'entries'} · ${store.money(total)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final t in items)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: store.categoryByName(t.category).colorValue,
                    child: Icon(store.categoryByName(t.category).iconData,
                        color: Colors.white, size: 20),
                  ),
                  title: Text(t.payee.isNotEmpty
                      ? t.payee
                      : (t.note.isNotEmpty ? t.note : t.category)),
                  subtitle: Text(
                      '${DateFormat('EEE d MMM yyyy').format(t.date)} · ${t.category}${t.note.isNotEmpty && t.payee.isNotEmpty ? ' · ${t.note}' : ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (t.files.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.attach_file, size: 16),
                        ),
                      Text(store.money(t.amount),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
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
