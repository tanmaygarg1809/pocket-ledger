import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../attachments.dart';
import '../models.dart';
import '../receipt_scan.dart';
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
    final qty = TextEditingController();
    final shop = TextEditingController();
    final place = TextEditingController();
    var unit = 'g';
    String? photo;
    var reading = false;

    void applyGuess() {
      final g = guessPack(item.text);
      if (g != null && qty.text.isEmpty) {
        qty.text = g.$1 == g.$1.roundToDouble() ? g.$1.toStringAsFixed(0) : g.$1.toString();
        unit = g.$2;
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add a price'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: reading
                      ? null
                      : () async {
                          final gallery = await showModalBottomSheet<bool>(
                            context: ctx,
                            builder: (c) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.photo_camera),
                                    title: const Text('Take a photo of the label or item'),
                                    onTap: () => Navigator.pop(c, false),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.photo_library),
                                    title: const Text('Choose from gallery'),
                                    onTap: () => Navigator.pop(c, true),
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (gallery == null) return;
                          setS(() => reading = true);
                          try {
                            final r = await scanLabel(gallery: gallery);
                            if (r != null) {
                              final (path, info) = r;
                              photo = await Attachments.saveFromPath(
                                  path, 'Price ${DateFormat('d MMM yyyy').format(DateTime.now())}.jpg');
                              if (info.name != null && item.text.isEmpty) item.text = info.name!;
                              if (info.price != null && price.text.isEmpty) price.text = info.price!.toStringAsFixed(2);
                              if (info.pack != null && qty.text.isEmpty) {
                                final q = info.pack!.$1;
                                qty.text = q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
                                unit = info.pack!.$2;
                              }
                              applyGuess();
                            }
                          } finally {
                            setS(() => reading = false);
                          }
                        },
                  icon: reading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.photo_camera_outlined),
                  label: Text(photo == null ? 'Add a photo (reads the label)' : 'Photo added · tap to replace'),
                ),
                TextField(
                  controller: item,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setS(applyGuess),
                  decoration: const InputDecoration(labelText: 'Item (e.g. Basmati rice 5kg)'),
                ),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Price paid', prefixText: widget.store.currency),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qty,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Pack size'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: unit,
                      items: const [
                        DropdownMenuItem(value: 'g', child: Text('g')),
                        DropdownMenuItem(value: 'kg', child: Text('kg')),
                        DropdownMenuItem(value: 'ml', child: Text('ml')),
                        DropdownMenuItem(value: 'l', child: Text('litres')),
                        DropdownMenuItem(value: 'pc', child: Text('pieces')),
                      ],
                      onChanged: (v) => setS(() => unit = v ?? 'g'),
                    ),
                  ],
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
                TextField(
                  controller: place,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Place / branch (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    final p = double.tryParse(price.text.replaceAll(',', '.').trim());
    final q = double.tryParse(qty.text.replaceAll(',', '.').trim());
    final i = item.text.trim();
    final s = shop.text.trim();
    final pl = place.text.trim();
    item.dispose();
    price.dispose();
    qty.dispose();
    shop.dispose();
    place.dispose();
    if (ok != true || i.isEmpty || p == null || p <= 0 || s.isEmpty) {
      if (photo != null) Attachments.delete(photo!);
      return;
    }
    await widget.store.addPrices([
      PricePoint(
        id: 'p${DateTime.now().microsecondsSinceEpoch}',
        item: i,
        price: p,
        shop: s,
        date: DateTime.now(),
        qty: (q != null && q > 0) ? q : null,
        unit: (q != null && q > 0) ? unit : '',
        place: pl,
        photo: photo,
      ),
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
    final all = byShop.values.toList();
    // Compare per kg / litre / piece when every shop's pack size is known and comparable.
    final fam = all.first.family;
    final byUnit = fam.isNotEmpty && all.every((p) => p.family == fam);
    final rows = all
      ..sort((a, b) => byUnit ? a.perBase!.compareTo(b.perBase!) : a.price.compareTo(b.price));
    final cheapest = rows.first;
    final dearest = rows.last;
    final saving = byUnit ? dearest.perBase! - cheapest.perBase! : dearest.price - cheapest.price;
    String unitName(PricePoint p) => p.family == 'each' ? 'piece' : p.family;
    String perText(PricePoint p) {
      final b = p.perBase;
      if (b == null) return '';
      return '${store.money(b)}/${unitName(p)}${p.per100 != null && p.per100! < 1 ? ' (${store.money(p.per100!)}/100${p.family == 'kg' ? 'g' : 'ml'})' : ''}';
    }
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
                  : 'Cheapest at ${cheapest.shop}: ${byUnit ? perText(cheapest) : store.money(cheapest.price)}'
                      '${saving > 0.004 ? ' · saves ${store.money(saving)}${byUnit ? '/${unitName(cheapest)}' : ''} vs ${dearest.shop}' : ''}',
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
                      Expanded(
                        child: Text(
                            '${p.shop}${p.place.isNotEmpty ? ' (${p.place})' : ''} · ${df.format(p.date)}${p.packLabel.isNotEmpty ? ' · ${p.packLabel}' : ''}${p.perBase != null && !byUnit ? ' · ${perText(p)}' : ''}'),
                      ),
                      if (p.photo != null)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.image_outlined, size: 18),
                          onPressed: () => Attachments.open(context, p.photo!),
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(store.money(p.price), style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (byUnit) Text(perText(p), style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
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
