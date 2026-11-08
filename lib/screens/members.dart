import 'package:flutter/material.dart' hide Category;

import '../store.dart';
import '../wealth.dart';

/// Family members whose accounts you track. Everyone is entered here, on
/// this phone. (Separate logins sharing one ledger is a later step.)
class MembersScreen extends StatelessWidget {
  final AppStore store;
  const MembersScreen({super.key, required this.store});

  Future<String?> _ask(BuildContext context, String title, String initial) async {
    final ctrl = TextEditingController(text: initial);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    return (r == null || r.isEmpty) ? null : r;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final w = store.wealth;
        return Scaffold(
          appBar: AppBar(title: const Text('Family')),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add person'),
            onPressed: () async {
              final n = await _ask(context, 'Add a family member', '');
              if (n == null) return;
              await store.saveMember(Member(id: store.newId(), name: n));
            },
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                      'Add your wife, children or anyone else. When adding an account you choose whose it is, '
                      'and the Net worth page shows each person and the whole family together. '
                      'Mark shared accounts as Joint.'),
                ),
                for (final m in w.people)
                  ListTile(
                    leading: CircleAvatar(
                      child: Text(m.name.isEmpty ? '?' : m.name.substring(0, 1).toUpperCase()),
                    ),
                    title: Text(m.name),
                    subtitle: Text(() {
                      final n = w.listed.where((a) => a.owner == m.id).length;
                      return '$n account${n == 1 ? '' : 's'} · ${wMoneyShort(store, w.netWorthOf(m.id))}';
                    }()),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Rename',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () async {
                            final n = await _ask(context, 'Rename', m.name);
                            if (n == null) return;
                            await store.saveMember(m.copyWith(name: n));
                          },
                        ),
                        if (m.id != Wealth.me)
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final err = await store.removeMember(m.id);
                              if (err != null && context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text(err)));
                              }
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String wMoneyShort(AppStore s, double v) =>
    '${v < 0 ? '-' : ''}${s.currency}${v.abs().round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';
