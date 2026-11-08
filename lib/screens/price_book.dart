import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';

/// Prices you have seen for items at different shops. Search an item and see
/// where it was cheapest.
class PriceBookScreen extends StatefulWidget {
  final AppStore store;
  const PriceBookScreen({super.key, required this.store});

  @override
  State<PriceBookScreen> createState() => _PriceBookScreenState();
}

class _PriceBookScreenState extends State<PriceBookScreen> {
  String _q = '';

  Future<void> _add() async {
    final item = TextEditingController();
    final price = TextEditingController();
    final shop = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a price'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: item,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Item (e.g. Milk 2L)'),
              ),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Price', prefixText: widget.store.currency),
              ),
              Autocomplete<String>(
                optionsBuilder: (v) => widget.store.knownShops
                    .where((s) => s.toLowerCase().contains(v.text.toLowerCase())),
                onSelected: (v) => shop.text = v,
                fieldViewBuilder: (context, c, f, _) {
                  c.addListener(() => shop.text = c.text);
                  return TextField(
                    controller: c,
                    focusNode: f,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Shop (e.g. Tesco)'),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final p = double.tryParse(price.text.replaceAll(',', '.').trim());
    final i = item.text.trim();
    final s = shop.text.trim();
    item.dispose();
    price.dispose();
    shop.dispose();
    if (ok != true || i.isEmpty || p == null || p <= 0 || s.isEmpty) return;
    await widget.store.addPrices([
      PricePoint(
          id: 'p${DateTime.now().microsecondsSinceEpoch}',
          item: i,
          price: p,
          shop: s,
          date: DateTime.now()),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(title: const Text('Price book')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add price'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final q = _q.toLowerCase();
          // Group by item, then keep the newest price per shop.
          final groups = <String, List<PricePoint>>{};
          for (final p in store.prices) {
            if (q.isNotEmpty && !p.item.toLowerCase().contains(q)) continue;
            groups.putIfAbsent(p.key, () => []).add(p);
          }
          final cards = groups.values.toList()
            ..sort((a, b) {
              final la = a.map((e) => e.date).reduce((x, y) => x.isAfter(y) ? x : y);
              final lb = b.map((e) => e.date).reduce((x, y) => x.isAfter(y) ? x : y);
              return lb.compareTo(la);
            });
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              TextField(
                onChanged: (v) => setState(() => _q = v.trim()),
                decoration: const InputDecoration(
                  hintText: 'Search an item, e.g. milk',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              if (store.prices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                      'No prices yet. Scan a receipt when you add an expense and choose "Save prices", or tap Add price. Next time, search an item to see the cheapest shop.'),
                )
              else if (cards.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('Nothing found for that item yet.'),
                ),
              for (final list in cards.take(60)) _ItemCard(store: store, list: list),
            ],
          );
        },
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final AppStore store;
  final List<PricePoint> list;
  const _ItemCard({required this.store, required this.list});

  @override
  Widget build(BuildContext context) {
    // Newest price at each shop.
    final byShop = <String, PricePoint>{};
    for (final p in list) {
      final k = p.shop.toLowerCase();
      final cur = byShop[k];
      if (cur == null || p.date.isAfter(cur.date)) byShop[k] = p;
    }
    final rows = byShop.values.toList()..sort((a, b) => a.price.compareTo(b.price));
    final cheapest = rows.first;
    final dearest = rows.last;
    final saving = dearest.price - cheapest.price;
    final scheme = Theme.of(context).colorScheme;
    final df = DateFormat('d MMM yyyy');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(list.first.item, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              rows.length == 1
                  ? 'Only seen at ${cheapest.shop} so far'
                  : 'Cheapest at ${cheapest.shop}: ${store.money(cheapest.price)}'
                      '${saving > 0.004 ? ' · saves ${store.money(saving)} vs ${dearest.shop}' : ''}',
              style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            for (final p in rows)
              InkWell(
                onLongPress: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Remove ${p.item} at ${p.shop}?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    for (final x in list.where((x) => x.shop.toLowerCase() == p.shop.toLowerCase())) {
                      await store.removePrice(x.id);
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(identical(p, cheapest) ? Icons.star : Icons.storefront_outlined,
                          size: 18, color: identical(p, cheapest) ? Colors.amber.shade700 : scheme.outline),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${p.shop} · ${df.format(p.date)}')),
                      Text(store.money(p.price), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            Text('Long-press a shop to remove its prices',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
