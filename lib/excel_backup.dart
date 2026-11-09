import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'store.dart';
import 'wealth.dart';

/// Everything in the app, as one Excel workbook (one sheet per kind of data),
/// and the way back: a workbook made by [build] can be loaded again with
/// [restore]. You can also add or edit rows in Excel before loading.
class ExcelBackup {
  static final _stamp = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final _day = DateFormat('yyyy-MM-dd');

  static CellValue _cell(Object? v) {
    if (v == null) return TextCellValue('');
    if (v is num) return DoubleCellValue(v.toDouble());
    if (v is bool) return TextCellValue(v ? 'yes' : 'no');
    return TextCellValue(v.toString());
  }

  static void _sheet(Excel ex, String name, List<String> head, List<List<Object?>> rows) {
    final sh = ex[name];
    sh.appendRow([for (final h in head) TextCellValue(h)]);
    for (final r in rows) {
      sh.appendRow([for (final v in r) _cell(v)]);
    }
  }

  /// The workbook as bytes (an .xlsx file).
  static List<int>? build(AppStore s) {
    final ex = Excel.createExcel();
    final first = ex.tables.keys.first;

    _sheet(ex, 'About', [
      'Kharcha backup'
    ], [
      ['Made on ${_stamp.format(DateTime.now())}'],
      ['Load this file back with Settings > Restore from a file.'],
      ['You can add or edit rows before loading. Keep the headings and sheet names as they are.'],
      ['Transactions: leave ID empty on new rows. Dates look like 2026-11-08 or 2026-11-08 14:30:00.'],
    ]);

    _sheet(ex, 'Transactions', ['Date', 'Type', 'Category', 'Amount', 'Payee', 'Note', 'ID'], [
      for (final t in s.all)
        [_stamp.format(t.date), t.type.name, t.category, t.amount, t.payee, t.note, t.id],
    ]);

    _sheet(ex, 'Categories', ['Name', 'Group', 'Type', 'Saving', 'Icon', 'Colour'], [
      for (final c in s.categoriesFor(TxType.expense) + s.categoriesFor(TxType.income))
        [c.name, c.group, c.type.name, c.saving ? 'yes' : 'no', c.icon, c.color],
    ]);

    final budgetRows = <List<Object?>>[];
    for (final e in const [
      MapEntry(BudgetPeriod.month, 'Monthly'),
      MapEntry(BudgetPeriod.quarter, 'Quarterly'),
      MapEntry(BudgetPeriod.year, 'Yearly'),
    ]) {
      s.budgetsFor(e.key).forEach((cat, amt) => budgetRows.add([cat, e.value, amt]));
    }
    _sheet(ex, 'Budgets', ['Category', 'Period', 'Amount'], budgetRows);

    _sheet(ex, 'Recurring', ['ID', 'Type', 'Amount', 'Category', 'Note', 'Day', 'Start month', 'Active'], [
      for (final r in s.rules)
        [r.id, r.type.name, r.amount, r.category, r.note, r.day, r.startMonth, r.active ? 'yes' : 'no'],
    ]);

    final w = s.wealth;
    _sheet(ex, 'Members', ['ID', 'Name'], [
      for (final m in w.people) [m.id, m.name],
    ]);
    _sheet(ex, 'Accounts', ['ID', 'Kind', 'Name', 'Held with', 'Weight (g)', 'In net worth', 'Owner'], [
      for (final a in w.listed)
        [a.id, a.kind.name, a.name, a.provider, a.weight, a.include ? 'yes' : 'no', w.ownerName(a.owner)],
    ]);
    _sheet(ex, 'Account values', ['Account ID', 'Account', 'Date', 'Value'], [
      for (final a in w.listed)
        for (final p in a.history) [a.id, a.name, _day.format(p.date), p.value],
    ]);
    _sheet(ex, 'Policies', [
      'ID', 'Type', 'Provider', 'Policy number', 'Cover', 'Monthly premium',
      'Renewal date', 'Covered', 'Cash-in value'
    ], [
      for (final p in w.listedPolicies)
        [
          p.id, p.type, p.provider, p.number, p.cover, p.premium,
          p.renewal == null ? '' : _day.format(p.renewal!), p.covered, p.cashValue
        ],
    ]);
    _sheet(ex, 'Settings', ['Setting', 'Value'], [
      ['Currency', s.currency],
    ]);

    if (first != 'About') ex.delete(first);
    return ex.save();
  }

  // ------------------------------------------------------------ reading back
  static String _s(Data? d) => (d?.value ?? '').toString().trim();

  static double? _n(String s) => double.tryParse(s.replaceAll(',', '').trim());

  static bool _yes(String s) {
    final v = s.toLowerCase();
    return v == 'yes' || v == 'y' || v == 'true' || v == '1';
  }

  static List<Map<String, String>> _table(Excel ex, String name) {
    final sh = ex.tables[name];
    if (sh == null) return [];
    final rows = sh.rows;
    if (rows.isEmpty) return [];
    final head = [for (final c in rows.first) _s(c).toLowerCase()];
    final out = <Map<String, String>>[];
    for (var i = 1; i < rows.length; i++) {
      final m = <String, String>{};
      var any = false;
      for (var j = 0; j < head.length && j < rows[i].length; j++) {
        final v = _s(rows[i][j]);
        if (v.isNotEmpty) any = true;
        m[head[j]] = v;
      }
      if (any) out.add(m);
    }
    return out;
  }

  static TxType _type(String s) => s.toLowerCase() == 'income' ? TxType.income : TxType.expense;

  /// Loads a workbook made by [build] (possibly edited). Returns a message.
  static Future<String> restore(AppStore store, List<int> bytes) async {
    final Excel ex;
    try {
      ex = Excel.decodeBytes(bytes);
    } catch (_) {
      return 'Could not read this Excel file.';
    }
    if (!ex.tables.containsKey('Transactions')) {
      return 'This is not a Kharcha backup (no Transactions sheet).';
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    var skipped = 0;
    var seq = 0;

    // Transactions
    final txns = <Map<String, dynamic>>[];
    for (final r in _table(ex, 'Transactions')) {
      final date = DateTime.tryParse(r['date'] ?? '');
      final amount = _n(r['amount'] ?? '');
      final cat = r['category'] ?? '';
      if (date == null || amount == null || cat.isEmpty) {
        skipped++;
        continue;
      }
      final id = (r['id'] ?? '').isNotEmpty
          ? r['id']!
          : 'xl${DateTime.now().microsecondsSinceEpoch}_${seq++}';
      txns.add(Txn(
        id: id,
        type: _type(r['type'] ?? ''),
        amount: amount,
        category: cat,
        note: r['note'] ?? '',
        payee: r['payee'] ?? '',
        date: date,
        updatedAt: now,
      ).toJson());
    }

    // Settings (categories, budgets, recurring, net worth, currency)
    final settings = <String, dynamic>{'u': now};
    for (final r in _table(ex, 'Settings')) {
      if ((r['setting'] ?? '').toLowerCase() == 'currency' && (r['value'] ?? '').isNotEmpty) {
        settings['currency'] = r['value'];
      }
    }

    final cats = <Map<String, dynamic>>[];
    for (final r in _table(ex, 'Categories')) {
      final name = r['name'] ?? '';
      if (name.isEmpty || name.contains(':')) continue;
      cats.add(Category(
        name: name,
        group: (r['group'] ?? '').isEmpty ? 'Other' : r['group']!,
        type: _type(r['type'] ?? ''),
        saving: _yes(r['saving'] ?? ''),
        icon: (_n(r['icon'] ?? '') ?? 9).toInt(),
        color: (_n(r['colour'] ?? '') ?? 0).toInt(),
      ).toJson());
    }
    if (cats.isNotEmpty) settings['categories'] = cats;

    final budgets = <String, double>{};
    for (final r in _table(ex, 'Budgets')) {
      final cat = r['category'] ?? '';
      final amt = _n(r['amount'] ?? '');
      if (cat.isEmpty || amt == null || amt <= 0) continue;
      final p = (r['period'] ?? '').toLowerCase();
      final prefix = p.startsWith('q') ? 'Q:' : (p.startsWith('y') ? 'Y:' : '');
      budgets['$prefix$cat'] = amt;
    }
    if (budgets.isNotEmpty) settings['budgets'] = budgets;

    final rules = <Map<String, dynamic>>[];
    for (final r in _table(ex, 'Recurring')) {
      final amt = _n(r['amount'] ?? '');
      final cat = r['category'] ?? '';
      if (amt == null || cat.isEmpty) continue;
      rules.add(RecurringRule(
        id: (r['id'] ?? '').isNotEmpty ? r['id']! : 'xlr${DateTime.now().microsecondsSinceEpoch}_${seq++}',
        type: _type(r['type'] ?? ''),
        amount: amt,
        category: cat,
        note: r['note'] ?? '',
        day: ((_n(r['day'] ?? '') ?? 1).toInt()).clamp(1, 28),
        startMonth: (r['start month'] ?? '').isEmpty
            ? DateFormat('yyyyMM').format(DateTime.now())
            : r['start month']!,
        active: (r['active'] ?? 'yes').isEmpty ? true : _yes(r['active'] ?? 'yes'),
      ).toJson());
    }
    if (rules.isNotEmpty) settings['recurring'] = rules;

    // Net worth
    final history = <String, List<ValuePoint>>{};
    for (final r in _table(ex, 'Account values')) {
      final id = r['account id'] ?? '';
      final d = DateTime.tryParse(r['date'] ?? '');
      final v = _n(r['value'] ?? '');
      if (id.isEmpty || d == null || v == null) continue;
      (history[id] ??= []).add(ValuePoint(d, v));
    }
    // People: names in the Owner column are matched to the Members sheet;
    // a new name creates a new family member.
    final members = <Map<String, dynamic>>[];
    final nameToId = <String, String>{'me': 'me', 'joint': 'joint'};
    for (final r in _table(ex, 'Members')) {
      final name = r['name'] ?? '';
      final id = r['id'] ?? '';
      if (name.isEmpty || id.isEmpty) continue;
      nameToId[name.toLowerCase()] = id;
      members.add(Member(id: id, name: name, updatedAt: now).toJson());
    }
    String ownerId(String name) {
      final key = name.trim().toLowerCase();
      if (key.isEmpty) return 'me';
      final known = nameToId[key];
      if (known != null) return known;
      final id = 'xlm${DateTime.now().microsecondsSinceEpoch}_${seq++}';
      nameToId[key] = id;
      members.add(Member(id: id, name: name.trim(), updatedAt: now).toJson());
      return id;
    }

    final accounts = <Map<String, dynamic>>[];
    for (final r in _table(ex, 'Accounts')) {
      final name = r['name'] ?? '';
      if (name.isEmpty) continue;
      final id = (r['id'] ?? '').isNotEmpty ? r['id']! : 'xla${DateTime.now().microsecondsSinceEpoch}_${seq++}';
      final kind = AccountKind.values.firstWhere(
          (k) => k.name == (r['kind'] ?? '').toLowerCase(),
          orElse: () => AccountKind.other);
      accounts.add(Account(
        id: id,
        kind: kind,
        name: name,
        provider: r['held with'] ?? '',
        weight: _n(r['weight (g)'] ?? ''),
        include: (r['in net worth'] ?? 'yes').isEmpty ? true : _yes(r['in net worth'] ?? 'yes'),
        owner: ownerId(r['owner'] ?? ''),
        history: (history[id] ?? [])..sort((a, b) => a.date.compareTo(b.date)),
        updatedAt: now,
      ).toJson());
    }
    final policies = <Map<String, dynamic>>[];
    for (final r in _table(ex, 'Policies')) {
      final prov = r['provider'] ?? '';
      if (prov.isEmpty) continue;
      policies.add(Policy(
        id: (r['id'] ?? '').isNotEmpty ? r['id']! : 'xlp${DateTime.now().microsecondsSinceEpoch}_${seq++}',
        type: (r['type'] ?? '').isEmpty ? 'Other' : r['type']!,
        provider: prov,
        number: r['policy number'] ?? '',
        cover: _n(r['cover'] ?? '') ?? 0,
        premium: _n(r['monthly premium'] ?? '') ?? 0,
        renewal: DateTime.tryParse(r['renewal date'] ?? ''),
        covered: r['covered'] ?? '',
        cashValue: _n(r['cash-in value'] ?? ''),
        updatedAt: now,
      ).toJson());
    }
    settings['wealth'] = {'accounts': accounts, 'policies': policies, 'members': members};

    final msg = await store.restoreBackup(jsonEncode({
      'app': 'pocket_ledger',
      'version': 4,
      'txns': txns,
      'settings': settings,
    }));
    final extra = skipped > 0 ? ' $skipped row${skipped == 1 ? '' : 's'} could not be read and were skipped.' : '';
    return '$msg Also loaded ${accounts.length} account${accounts.length == 1 ? '' : 's'}, '
        '${policies.length} polic${policies.length == 1 ? 'y' : 'ies'}, budgets and categories.$extra';
  }
}
