import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';

/// Expenses you flagged "Split on Splitwise": what is still to add, and what is done.
class SplitwiseScreen extends StatelessWidget {
  final AppStore store;
  const SplitwiseScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final pending = store.splitTxns(1);
        final done = store.splitTxns(2);
        final total = pending.fold(0.0, (a, t) => a + t.amount);
        return Scaffold(
          appBar: AppBar(title: const Text('Splitwise')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Still to add',
                                style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(height: 4),
                            Text(store.money(total),
                                style: Theme.of(context).textTheme.headlineSmall),
                            Text('${pending.length} expense${pending.length == 1 ? '' : 's'}'),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Done',
                              style: Theme.of(context).textTheme.labelLarge),
                          Text('${done.length}',
                              style: Theme.of(context).textTheme.headlineSmall),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('To do', style: Theme.of(context).textTheme.titleMedium),
              if (pending.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Nothing waiting. Switch on "Split on Splitwise" when adding an expense.'),
                ),
              for (final t in pending) _row(context, t, false),
              if (done.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Done', style: Theme.of(context).textTheme.titleMedium),
                for (final t in done.take(50)) _row(context, t, true),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, Txn t, bool isDone) {
    final title = t.payee.isNotEmpty ? t.payee : t.category;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isDone ? Colors.green : null),
      title: Text(title),
      subtitle: Text('${DateFormat('d MMM yyyy').format(t.date)} · ${t.category}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(store.money(t.amount)),
          const SizedBox(width: 8),
          isDone
              ? TextButton(
                  onPressed: () => store.setSplit(t.id, 1), child: const Text('Undo'))
              : FilledButton.tonal(
                  onPressed: () => store.setSplit(t.id, 2),
                  child: const Text('Done')),
        ],
      ),
    );
  }
}
