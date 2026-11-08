import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

/// Settings > Categories & groups.
class CategoriesScreen extends StatelessWidget {
  final AppStore store;
  const CategoriesScreen({super.key, required this.store});

  void _open(BuildContext context, [Category? c]) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CategoryEditor(store: store, existing: c)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories & groups')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final grey = Theme.of(context).colorScheme.onSurfaceVariant;
          final children = <Widget>[];
          for (final type in TxType.values) {
            children.add(Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(type == TxType.expense ? 'SPENDING' : 'INCOME',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: grey, letterSpacing: 1)),
            ));
            for (final g in store.groupsFor(type)) {
              children.add(Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(g, style: Theme.of(context).textTheme.titleSmall),
              ));
              for (final c
                  in store.categoriesFor(type).where((c) => c.group == g)) {
                children.add(ListTile(
                  onTap: () => _open(context, c),
                  leading: CircleAvatar(
                    backgroundColor: c.colorValue,
                    child: Icon(c.iconData, color: Colors.white, size: 20),
                  ),
                  title: Text(c.name),
                  subtitle: c.saving ? const Text('Counts as saving, not spending') : null,
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                ));
              }
            }
          }
          children.add(const SizedBox(height: 96));
          return ListView(children: children);
        },
      ),
    );
  }
}

class CategoryEditor extends StatefulWidget {
  final AppStore store;
  final Category? existing;
  const CategoryEditor({super.key, required this.store, this.existing});

  @override
  State<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<CategoryEditor> {
  late final TextEditingController _name;
  late final TextEditingController _group;
  late TxType _type;
  late int _icon;
  late int _color;
  late bool _saving;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _group = TextEditingController(text: e?.group ?? '');
    _type = e?.type ?? TxType.expense;
    _icon = e?.icon ?? 9;
    _color = e?.color ?? 0;
    _saving = e?.saving ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _group.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final err = await widget.store.saveCategory(
      Category(
        name: _name.text,
        icon: _icon,
        color: _color,
        group: _group.text,
        type: _type,
        saving: _type == TxType.expense && _saving,
      ),
      oldName: widget.existing?.name,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${widget.existing!.name}"?'),
        content: const Text(
            'Entries already recorded keep this name, shown in grey, and show up in Review so you can move them. Its budgets are removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.deleteCategory(widget.existing!.name);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final scheme = Theme.of(context).colorScheme;
    final groups = widget.store.groupsFor(_type);
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit category' : 'New category')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!editing) ...[
            SegmentedButton<TxType>(
              segments: const [
                ButtonSegment(value: TxType.expense, label: Text('Spending')),
                ButtonSegment(value: TxType.income, label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _name,
            maxLength: 30,
            decoration: const InputDecoration(
                labelText: 'Name (e.g. House EMI, Council Tax)',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _group,
            maxLength: 30,
            decoration: const InputDecoration(
                labelText: 'Group (e.g. Fixed bills, Car, Day to day)',
                border: OutlineInputBorder()),
          ),
          if (groups.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                for (final g in groups)
                  ActionChip(
                      label: Text(g),
                      onPressed: () => setState(() => _group.text = g)),
              ],
            ),
          if (_type == TxType.expense)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Counts as saving or investing'),
              subtitle: const Text(
                  'Shown separately and not counted as spending, so it will not hurt your totals.'),
              value: _saving,
              onChanged: (v) => setState(() => _saving = v),
            ),
          const SizedBox(height: 12),
          Text('Icon', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < categoryIcons.length; i++)
                InkResponse(
                  onTap: () => setState(() => _icon = i),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _icon ? scheme.primaryContainer : null,
                      border: Border.all(
                          color: i == _icon ? scheme.primary : scheme.outlineVariant),
                    ),
                    child: Icon(categoryIcons[i], size: 22),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Colour', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < categoryColors.length; i++)
                InkResponse(
                  onTap: () => setState(() => _color = i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: categoryColors[i]),
                    child: i == _color
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Save')),
          if (editing)
            TextButton(
              onPressed: _delete,
              child: Text('Delete', style: TextStyle(color: scheme.error)),
            ),
        ],
      ),
    );
  }
}
