import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import 'add_txn.dart';
import 'month_bar.dart';
import 'review.dart';

class TransactionsScreen extends StatelessWidget {
  final AppStore store;
  const TransactionsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final txns = store.monthTxns;
        final review = store.needsReview.length;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: MonthBar(store: store),
            ),
            if (review > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.rule),
                    title: Text(
                        '$review ${review == 1 ? 'entry is' : 'entries are'} in "Other"'),
                    subtitle: const Text('Tap to sort them into categories'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ReviewScreen(store: store))),
                  ),
                ),
              ),
            Expanded(
              child: txns.isEmpty
                  ? const Center(child: Text('No transactions this month.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: txns.length,
                      itemBuilder: (context, i) {
                        final t = txns[i];
                        final cat = store.categoryByName(t.category);
                        final isIncome = t.type == TxType.income;
                        final isRefund = !isIncome && t.amount < 0;
                        final positive = isIncome || isRefund;
                        final saving = !isIncome && !isRefund && cat.saving;
                        final color = positive
                            ? Colors.green.shade700
                            : (saving ? Colors.blue.shade700 : Colors.red.shade700);
                        final title = t.payee.isNotEmpty
                            ? t.payee
                            : (t.note.isNotEmpty ? t.note : t.category);
                        final extra = t.payee.isNotEmpty && t.note.isNotEmpty
                            ? ' · ${t.note}'
                            : '';
                        return Dismissible(
                          key: ValueKey(t.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red.shade400,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            store.remove(t.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Transaction deleted'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () => store.upsert(t),
                                ),
                              ),
                            );
                          },
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: cat.colorValue,
                              child: Icon(cat.iconData,
                                  color: Colors.white, size: 20),
                            ),
                            title: Text(title),
                            subtitle: Text(
                                '${t.category}${isRefund ? ' · refund' : ''}${saving ? ' · saving' : ''} · ${DateFormat('d MMM').format(t.date)}$extra'),
                            trailing: Text(
                              '${positive ? '+' : '-'}${store.money(t.amount.abs())}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, color: color),
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    AddTxnScreen(store: store, existing: t),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
