import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../store.dart';
import '../wealth.dart';
import 'net_worth.dart';

/// Compare today's net worth with an earlier date and see what changed.
class CompareWorthScreen extends StatefulWidget {
  final AppStore store;
  const CompareWorthScreen({super.key, required this.store});

  @override
  State<CompareWorthScreen> createState() => _CompareWorthScreenState();
}

class _CompareWorthScreenState extends State<CompareWorthScreen> {
  int _months = 12;

  AppStore get store => widget.store;

  DateTime? get _earliest {
    DateTime? first;
    for (final a in store.wealth.listed) {
      for (final p in a.history) {
        if (first == null || p.date.isBefore(first)) first = p.date;
      }
    }
    return first;
  }

  @override
  Widget build(BuildContext context) {
    final w = store.wealth;
    final o0 = store.wealthFilter;
    final String? owner =
        (o0 != null && o0 != Wealth.joint && !w.people.any((m) => m.id == o0)) ? null : o0;
    final now = DateTime.now();
    final text = Theme.of(context).textTheme;
    var from = DateTime(now.year, now.month - _months, now.day);
    final earliest = _earliest;
    var clipped = false;
    if (earliest != null && from.isBefore(earliest)) {
      from = earliest;
      clipped = true;
    }
    final then = w.netWorthAt(from, owner: owner);
    final today = w.netWorthOf(owner);
    final diff = today - then;
    final pct = then == 0 ? null : diff / then.abs() * 100;
    final span = ((now.year - from.year) * 12 + now.month - from.month).clamp(1, 240).toInt();
    final series = w.series(span + 1, owner: owner);
    final changes = w.changeByGroup(from, owner: owner).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxAbs = changes.isEmpty
        ? 1.0
        : changes.map((e) => e.value.abs()).reduce((a, b) => a > b ? a : b);
    final fmt = DateFormat('MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: Text(owner == null ? 'Growth' : 'Growth · ${w.ownerName(owner)}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Compare today with', style: text.bodySmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final e in const [
                  MapEntry('1 month', 1),
                  MapEntry('3 months', 3),
                  MapEntry('6 months', 6),
                  MapEntry('1 year', 12),
                ])
                  ChoiceChip(
                    label: Text(e.key),
                    selected: _months == e.value,
                    onSelected: (_) => setState(() => _months = e.value),
                  ),
              ],
            ),
            if (clipped)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('You started tracking in ${fmt.format(from)}, so that is the furthest back.',
                    style: text.bodySmall),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _Box(fmt.format(from), wMoney(store, then), false)),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward)),
                Expanded(child: _Box('Now', wMoney(store, today), true)),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Container(
                color: diff >= 0 ? const Color(0xFF2EAD6B) : const Color(0xFFFF6B5E),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(diff >= 0 ? 'You grew by' : 'You are down by',
                        style: const TextStyle(color: Colors.white)),
                    Text(
                      '${wMoney(store, diff.abs())}${pct == null ? '' : '  (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)'}',
                      style: text.headlineSmall?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text('about ${wMoney(store, diff / span)} a month',
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            WealthLine(
              values: [for (final p in series) p.value],
              labels: [for (final p in series) DateFormat('MMM').format(p.date)],
            ),
            const SizedBox(height: 12),
            Text('What changed', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            if (changes.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Nothing has changed over this period yet.'),
              ),
            for (final e in changes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(e.key)),
                        Text(wMoney(store, e.value, sign: true),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: e.value >= 0
                                    ? const Color(0xFF2EAD6B)
                                    : const Color(0xFFFF6B5E))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: (e.value.abs() / maxAbs).clamp(0.0, 1.0).toDouble(),
                        minHeight: 10,
                        color: groupColor(e.key),
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                    'Tip: update your values on the 1st of each month so the chart stays accurate. It takes about a minute.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const _Box(this.label, this.value, this.strong);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: strong ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
