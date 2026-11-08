import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../store.dart';
import '../wealth.dart';
import 'add_account.dart';
import 'net_worth.dart';

class AccountDetailScreen extends StatelessWidget {
  final AppStore store;
  final String id;
  const AccountDetailScreen({super.key, required this.store, required this.id});

  Future<void> _update(BuildContext context, Account a) async {
    final ctrl = TextEditingController(
        text: a.value.toStringAsFixed(a.value % 1 == 0 ? 0 : 2));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(a.kind.isDebt ? 'Update amount owed' : 'Update value'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Value today',
            prefixText: store.currency,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    final v = result == null ? null : double.tryParse(result.replaceAll(',', '').trim());
    if (v == null || v < 0) return;
    await store.updateAccountValue(a.id, v);
  }

  Future<void> _remove(BuildContext context, Account a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${a.name}?'),
        content: const Text('It will no longer count towards your net worth, and its history is deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await store.removeAccount(a.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final a = store.wealth.byId(id);
        if (a == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Removed.')));
        }
        final text = Theme.of(context).textTheme;
        final color = kindColor(a.kind);
        final first = a.history.isEmpty ? 0.0 : a.history.first.value;
        final change = a.value - first;
        final pct = first == 0 ? null : change / first * 100;
        final fmt = DateFormat('d MMM yyyy');
        return Scaffold(
          appBar: AppBar(
            title: Text(a.name),
            actions: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AddAccountScreen(store: store, existing: a))),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    color: color,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.kind.isDebt ? 'Amount owed' : 'Current value',
                            style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(wMoney(store, a.value),
                            style: text.headlineLarge?.copyWith(
                                color: Colors.white, fontWeight: FontWeight.bold)),
                        if (a.history.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${change >= 0 ? '▲' : '▼'} ${wMoney(store, change.abs())}'
                              '${pct == null ? '' : ' (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)'}'
                              ' since ${fmt.format(a.history.first.date)}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                WealthLine(
                  values: [for (final p in a.history) p.value],
                  labels: [for (final p in a.history) DateFormat('MMM yy').format(p.date)],
                  color: color,
                ),
                const SizedBox(height: 12),
                _row(context, 'Type', a.kind.label),
                if (a.provider.isNotEmpty) _row(context, 'Held with', a.provider),
                if (a.weight != null)
                  _row(context, 'Weight', '${a.weight!.toStringAsFixed(a.weight! % 1 == 0 ? 0 : 2)} g'),
                _row(context, 'In net worth', a.include ? 'Yes' : 'No'),
                const SizedBox(height: 12),
                Text('History', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                for (final p in a.history.reversed)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(fmt.format(p.date)),
                    trailing: Text(wMoney(store, p.value),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _update(context, a),
                  child: Text(a.kind.isDebt ? 'Update amount owed' : 'Update value'),
                ),
                TextButton(
                  onPressed: () => _remove(context, a),
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  child: const Text('Remove from net worth'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Theme.of(context).textTheme.bodyMedium)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
