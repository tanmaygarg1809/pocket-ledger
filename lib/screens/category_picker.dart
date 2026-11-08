import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

/// Category chips grouped under their group headings.
class CategoryPicker extends StatelessWidget {
  final AppStore store;
  final TxType type;
  final String selected;
  final ValueChanged<String> onChanged;
  const CategoryPicker({
    super.key,
    required this.store,
    required this.type,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cats = store.categoriesFor(type);
    final groups = store.groupsFor(type);
    final grey = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(g,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: grey)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cats.where((c) => c.group == g))
                ChoiceChip(
                  avatar: Icon(c.iconData, size: 18, color: c.colorValue),
                  label: Text(c.name),
                  selected: selected == c.name,
                  onSelected: (_) => onChanged(c.name),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
