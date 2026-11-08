import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';

/// Savings goals with progress, milestones and badges.
class GoalsScreen extends StatelessWidget {
  final AppStore store;
  const GoalsScreen({super.key, required this.store});

  Future<void> _edit(BuildContext context, [Goal? g]) async {
    final name = TextEditingController(text: g?.name ?? '');
    final target = TextEditingController(text: g == null ? '' : g.target.toStringAsFixed(0));
    DateTime? deadline = g?.deadline;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(g == null ? 'New goal' : 'Edit goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Goal (e.g. India trip)'),
              ),
              TextField(
                controller: target,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Target', prefixText: store.currency),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(deadline == null
                        ? 'No deadline'
                        : 'By ${DateFormat('d MMM yyyy').format(deadline!)}'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: deadline ?? DateTime.now().add(const Duration(days: 180)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setS(() => deadline = d);
                    },
                    child: const Text('Set date'),
                  ),
                  if (deadline != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setS(() => deadline = null),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    final t = double.tryParse(target.text.replaceAll(',', '.').trim());
    final n = name.text.trim();
    name.dispose();
    target.dispose();
    if (ok != true || n.isEmpty || t == null || t <= 0) return;
    if (g == null) {
      await store.saveGoal(Goal(
          id: 'g${DateTime.now().microsecondsSinceEpoch}',
          name: n,
          target: t,
          deadline: deadline));
    } else {
      await store.saveGoal(g.copyWith(
          name: n, target: t, deadline: deadline, clearDeadline: deadline == null));
    }
  }

  Future<void> _addMoney(BuildContext context, Goal g, {required bool take}) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(take ? 'Take money out of ${g.name}' : 'Add to ${g.name}'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Amount', prefixText: store.currency),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final v = double.tryParse(c.text.replaceAll(',', '.').trim());
    c.dispose();
    if (ok != true || v == null || v <= 0) return;
    final before = g.milestones.length;
    await store.addToGoal(g.id, take ? -v : v);
    if (!take && context.mounted) {
      final after = store.goals.firstWhere((e) => e.id == g.id).milestones.length;
      if (after > before) {
        final reached = store.goals.firstWhere((e) => e.id == g.id).reached;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(reached
                ? 'Goal reached! ${g.name} is fully funded.'
                : 'New milestone on ${g.name}!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final goals = store.goals;
        final badges = store.badges;
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(title: const Text('Savings goals')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add),
            label: const Text('New goal'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text('Badges', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final b in badges)
                    Tooltip(
                      message: b.$2,
                      child: Chip(
                        avatar: Icon(
                          b.$3 ? Icons.emoji_events : Icons.lock_outline,
                          size: 18,
                          color: b.$3 ? Colors.amber.shade800 : scheme.outline,
                        ),
                        label: Text(b.$1),
                        backgroundColor:
                            b.$3 ? Colors.amber.shade100 : scheme.surfaceContainerHighest,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Tap a badge to see how to earn it',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              if (goals.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('No goals yet. Add one to start earning badges.')),
                ),
              for (final g in goals) _GoalCard(
                store: store,
                goal: g,
                onEdit: () => _edit(context, g),
                onAdd: () => _addMoney(context, g, take: false),
                onTake: () => _addMoney(context, g, take: true),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  final AppStore store;
  final Goal goal;
  final VoidCallback onEdit;
  final VoidCallback onAdd;
  final VoidCallback onTake;
  const _GoalCard({
    required this.store,
    required this.goal,
    required this.onEdit,
    required this.onAdd,
    required this.onTake,
  });

  String? _pace() {
    final d = goal.deadline;
    if (d == null || goal.reached) return null;
    final now = DateTime.now();
    final months = (d.year - now.year) * 12 + d.month - now.month;
    if (d.isBefore(now)) return 'Deadline passed';
    final m = months < 1 ? 1 : months;
    return 'Save ${store.money((goal.target - goal.saved) / m)} a month to finish by ${DateFormat('MMM yyyy').format(d)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pace = _pace();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(goal.name, style: Theme.of(context).textTheme.titleMedium),
                ),
                if (goal.reached) const Icon(Icons.emoji_events, color: Colors.amber),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'take') onTake();
                    if (v == 'delete') store.removeGoal(goal.id);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'take', child: Text('Take money out')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            Text('${store.money(goal.saved)} of ${store.money(goal.target)}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: goal.fraction,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
              color: goal.reached ? Colors.green : scheme.primary,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final p in const [25, 50, 75, 100])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('$p%'),
                      avatar: Icon(
                        goal.milestones.contains(p) ? Icons.check_circle : Icons.circle_outlined,
                        size: 16,
                        color: goal.milestones.contains(p) ? Colors.green : scheme.outline,
                      ),
                    ),
                  ),
              ],
            ),
            if (pace != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(pace, style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add money'),
            ),
          ],
        ),
      ),
    );
  }
}
