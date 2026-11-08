import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import 'category_picker.dart';

/// Every entry in one category, with a way to move them to another category:
/// tick several (or all) and move them together, or tap one to move just it.
class MoveEntriesScreen extends StatefulWidget {
  final AppStore store;
  final String category;
  final TxType type;
  const MoveEntriesScreen(
      {super.key, required this.store, required this.category, required this.type});

  @override
  State<MoveEntriesScreen> createState() => _MoveEntriesScreenState();
}

class _MoveEntriesScreenState extends State<MoveEntriesScreen> {
  final Set<String> _picked = {};

  Future<void> _move(List<String> ids) async {
    var target = '';
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Move ${ids.length} ${ids.length == 1 ? 'entry' : 'entries'} to…',
                    style: Theme.of(ctx).textTheme.titleMedium),
                CategoryPicker(
                  store: widget.store,
                  type: widget.type,
                  selected: target,
                  onChanged: (c) => setS(() => target = c),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: target.isEmpty || target == widget.category
                      ? null
                      : () => Navigator.pop(ctx, true),
                  child: Text(target.isEmpty ? 'Choose a category' : 'Move to $target'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (go != true || !mounted) return;
    final n = await widget.store.moveTxns(ids, target);
    if (!mounted) return;
    setState(() => _picked.removeAll(ids));
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved $n ${n == 1 ? 'entry' : 'entries'} to $target')));
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(title: Text('Entries in ${widget.category}')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.all.where((t) => t.category == widget.category).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          if (items.isEmpty) {
            return const Center(child: Text('No entries in this category.'));
          }
          final allIds = items.map((t) => t.id).toList();
          final everything = _picked.length == items.length;
          return Column(
            children: [
              CheckboxListTile(
                value: everything,
                onChanged: (v) => setState(() {
                  _picked
                    ..clear()
                    ..addAll(v == true ? allIds : const <String>[]);
                }),
                title: Text('Select all (${items.length})'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final t = items[i];
                    return CheckboxListTile(
                      value: _picked.contains(t.id),
                      onChanged: (v) => setState(() {
                        v == true ? _picked.add(t.id) : _picked.remove(t.id);
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(t.payee.isNotEmpty
                          ? t.payee
                          : (t.note.isNotEmpty ? t.note : t.category)),
                      subtitle: Text(DateFormat('d MMM yyyy').format(t.date)),
                      secondary: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(store.money(t.amount),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          IconButton(
                            tooltip: 'Move this one',
                            icon: const Icon(Icons.drive_file_move_outline),
                            onPressed: () => _move([t.id]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _picked.isEmpty ? null : () => _move(_picked.toList()),
                      icon: const Icon(Icons.drive_file_move_outline),
                      label: Text(_picked.isEmpty
                          ? 'Tick entries to move'
                          : 'Move ${_picked.length} selected'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
