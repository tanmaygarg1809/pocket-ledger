import 'package:flutter/material.dart' hide Category;
import 'package:flutter/services.dart';

import 'models.dart';
import 'store.dart';

/// Small bottom-sheet style popup shown over the home screen by the
/// widget / launcher shortcut. Saves one entry and closes.
class QuickAddApp extends StatelessWidget {
  final AppStore store;
  const QuickAddApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF00796B);
    return MaterialApp(
      title: 'Quick add',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: seed),
      darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: seed,
          brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: QuickAddSheet(store: store),
    );
  }
}

class QuickAddSheet extends StatefulWidget {
  final AppStore store;
  const QuickAddSheet({super.key, required this.store});

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _amount = TextEditingController();
  TxType _type = TxType.expense;
  late String _category;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.store.suggestedCategory(_type);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  List<Category> get _cats {
    // Put the suggested category first so it is visible without scrolling.
    final all = widget.store.categoriesFor(_type);
    return [
      ...all.where((c) => c.name == _category),
      ...all.where((c) => c.name != _category),
    ];
  }

  void _close() => SystemNavigator.pop();

  Future<void> _save() async {
    final n = double.tryParse(_amount.text.replaceAll(',', '.').trim());
    if (n == null || n <= 0 || n > 1e9) {
      setState(() => _error = 'Enter an amount above 0');
      return;
    }
    setState(() => _saving = true);
    await widget.store.upsert(Txn(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: _type,
      amount: n,
      category: _category,
      note: '',
      date: DateTime.now(),
    ));
    HapticFeedback.lightImpact();
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = widget.store.lastTxn(_type);
    return Scaffold(
      backgroundColor: Colors.black54,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {}, // taps inside the card must not close it
            child: Material(
              color: scheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<TxType>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                              value: TxType.expense, label: Text('Expense')),
                          ButtonSegment(
                              value: TxType.income, label: Text('Income')),
                        ],
                        selected: {_type},
                        onSelectionChanged: (s) => setState(() {
                          _type = s.first;
                          _category = widget.store.suggestedCategory(_type);
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amount,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _save(),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        style: Theme.of(context).textTheme.headlineSmall,
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText: widget.store.currency,
                          errorText: _error,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (last != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ActionChip(
                                  avatar: const Icon(Icons.replay, size: 18),
                                  label: Text(
                                      'Last: ${widget.store.money(last.amount)} · ${last.category}'),
                                  onPressed: () => setState(() {
                                    _amount.text =
                                        last.amount.toStringAsFixed(2);
                                    _category = last.category;
                                  }),
                                ),
                              ),
                            for (final c in _cats)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  avatar: Icon(c.iconData, size: 18, color: c.colorValue),
                                  label: Text(c.name),
                                  selected: _category == c.name,
                                  onSelected: (_) =>
                                      setState(() => _category = c.name),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton(
                              onPressed: _close, child: const Text('Cancel')),
                          const Spacer(),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
