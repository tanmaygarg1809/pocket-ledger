import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import 'category_picker.dart';

/// Sort entries filed under "Other" into real categories. Choosing
/// "apply to all" fixes every entry from the same payee at once.
class ReviewScreen extends StatelessWidget {
  final AppStore store;
  const ReviewScreen({super.key, required this.store});

  Future<void> _sort(BuildContext context, Txn t) async {
    var picked = '';
    var applyAll = t.payee.isNotEmpty;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.payee.isNotEmpty ? t.payee : (t.note.isNotEmpty ? t.note : 'Entry')} · ${store.money(t.amount)}',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                CategoryPicker(
                  store: store,
                  type: TxType.expense,
                  selected: picked,
                  onChanged: (c) => setS(() => picked = c),
                ),
                if (t.payee.isNotEmpty)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: applyAll,
                    onChanged: (v) => setS(() => applyAll = v ?? false),
                    title: Text('Apply to all "${t.payee}" entries'),
                    subtitle: const Text('Also fixes older ones from this payee'),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: picked.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          final n = await store.recategorize(t, picked,
                              allFromPayee: applyAll);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                    'Moved $n ${n == 1 ? 'entry' : 'entries'} to $picked')));
                          }
                        },
                  child: const Text('Move'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.needsReview;
          if (items.isEmpty) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Nothing to review. Everything is in a category.',
                  textAlign: TextAlign.center),
            ));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final t = items[i];
              return ListTile(
                title: Text(t.payee.isNotEmpty
                    ? t.payee
                    : (t.note.isNotEmpty ? t.note : t.category)),
                subtitle: Text(
                    '${DateFormat('d MMM yyyy').format(t.date)} · currently ${t.category}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(store.money(t.amount),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                        onPressed: () => _sort(context, t),
                        child: const Text('Sort')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
