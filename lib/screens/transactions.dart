import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import 'add_txn.dart';
import 'month_bar.dart';
import 'review.dart';

class TransactionsScreen extends StatefulWidget {
  final AppStore store;
  const TransactionsScreen({super.key, required this.store});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _q = TextEditingController();
  String _query = '';
  String? _category;
  int _type = 0; // 0 all, 1 expenses, 2 income
  bool _withFiles = false;
  bool _showFilters = false;

  AppStore get store => widget.store;
  bool get _searching =>
      _query.isNotEmpty || _category != null || _type != 0 || _withFiles;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  /// Everything, newest first, matching the search and filters.
  List<Txn> _matches() {
    final q = _query.toLowerCase();
    final amt = double.tryParse(_query.replaceAll(',', '.'));
    return store.all.where((t) {
      if (_category != null && t.category != _category) return false;
      if (_type == 1 && t.type != TxType.expense) return false;
      if (_type == 2 && t.type != TxType.income) return false;
      if (_withFiles && t.files.isEmpty) return false;
      if (q.isEmpty) return true;
      return t.payee.toLowerCase().contains(q) ||
          t.note.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q) ||
          (amt != null && (t.amount.abs() - amt).abs() < 0.005);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Widget _filters(BuildContext context) {
    final cats = (store.categoriesFor(TxType.expense) + store.categoriesFor(TxType.income))
        .map((c) => c.name)
        .toSet()
        .toList()
      ..sort();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          TextField(
            controller: _q,
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search payee, note, category or amount',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                tooltip: 'Filters',
                icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
            ),
          ),
          if (_showFilters)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final e in const [(0, 'All'), (1, 'Spending'), (2, 'Income')])
                    ChoiceChip(
                      label: Text(e.$2),
                      selected: _type == e.$1,
                      onSelected: (_) => setState(() => _type = e.$1),
                    ),
                  FilterChip(
                    label: const Text('With files'),
                    avatar: const Icon(Icons.attach_file, size: 16),
                    selected: _withFiles,
                    onSelected: (v) => setState(() => _withFiles = v),
                  ),
                  DropdownButton<String?>(
                    value: _category,
                    hint: const Text('Any category'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Any category')),
                      for (final c in cats) DropdownMenuItem<String?>(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final txns = _searching ? _matches() : store.monthTxns;
        final review = store.needsReview.length;
        final total = txns.fold(0.0, (a, t) => a + (t.type == TxType.income ? t.amount : -t.amount));
        return Column(
          children: [
            _filters(context),
            if (!_searching)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: MonthBar(store: store),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${txns.length} ${txns.length == 1 ? 'entry' : 'entries'} found · net ${store.money(total)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _q.clear();
                        _query = '';
                        _category = null;
                        _type = 0;
                        _withFiles = false;
                      }),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            if (review > 0 && !_searching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.rule),
                    title: Text(
                        '$review ${review == 1 ? 'entry is' : 'entries are'} in "Other"'),
                    subtitle: const Text('Tap to sort them into categories'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ReviewScreen(store: store))),
                  ),
                ),
              ),
            Expanded(
              child: txns.isEmpty
                  ? Center(
                      child: Text(_searching
                          ? 'Nothing matches.'
                          : 'No transactions this month.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: txns.length,
                      itemBuilder: (context, i) {
                        final t = txns[i];
                        final cat = store.categoryByName(t.category);
                        final isIncome = t.type == TxType.income;
                        final isRefund = !isIncome && t.amount < 0;
                        final positive = isIncome || isRefund;
                        final saving = !isIncome && !isRefund && cat.saving;
                        final color = positive
                            ? Colors.green.shade700
                            : (saving ? Colors.blue.shade700 : Colors.red.shade700);
                        final title = t.payee.isNotEmpty
                            ? t.payee
                            : (t.note.isNotEmpty ? t.note : t.category);
                        final extra = t.payee.isNotEmpty && t.note.isNotEmpty
                            ? ' · ${t.note}'
                            : '';
                        return Dismissible(
                          key: ValueKey(t.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red.shade400,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            store.remove(t.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Transaction deleted'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () => store.upsert(t),
                                ),
                              ),
                            );
                          },
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: cat.colorValue,
                              child: Icon(cat.iconData,
                                  color: Colors.white, size: 20),
                            ),
                            title: Text(title),
                            subtitle: Text(
                                '${t.category}${isRefund ? ' · refund' : ''}${saving ? ' · saving' : ''} · ${DateFormat(_searching ? 'd MMM yyyy' : 'd MMM').format(t.date)}$extra'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (t.files.isNotEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.attach_file, size: 16),
                                  ),
                                if (t.split == 1)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.call_split, size: 16),
                                  ),
                                Text(
                                  '${positive ? '+' : '-'}${store.money(t.amount.abs())}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600, color: color),
                                ),
                              ],
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    AddTxnScreen(store: store, existing: t),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
