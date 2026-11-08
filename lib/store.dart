import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'wealth.dart';
import 'widget_bridge.dart';

const currencies = <String>['£', '\$', '€', '₹', '¥', '₦', 'R\$', 'A\$', 'C\$'];

/// "How much can I safely spend today" based on monthly category budgets.
class SafeToSpend {
  final double dailyAllowance;
  final double leftToday;
  final double remainingMonth;
  final int daysLeft;
  bool get overBudget => remainingMonth < 0;
  const SafeToSpend({
    required this.dailyAllowance,
    required this.leftToday,
    required this.remainingMonth,
    required this.daysLeft,
  });
}

/// Total spent vs total limit for one budget period.
class BudgetProgress {
  final double limit;
  final double spent;
  const BudgetProgress(this.limit, this.spent);
  double get fraction => limit <= 0 ? 0 : (spent / limit).clamp(0.0, 1.0).toDouble();
  bool get over => spent > limit;
}

/// One line of the year "ledger": budget-to-date vs actual for a category.
class LedgerRow {
  final String category;
  final double? budgetToDate; // null = no budget set
  final double actual;
  const LedgerRow(this.category, this.budgetToDate, this.actual);
  bool get hasBudget => budgetToDate != null && budgetToDate! > 0;
  double get diff => actual - (budgetToDate ?? 0);
  double get ratio => hasBudget ? actual / budgetToDate! : 0;
}

class Insight {
  final String title;
  final String body;
  final bool warn;
  const Insight(this.title, this.body, {this.warn = false});
}

class YearTotals {
  final double income;
  final double consumption; // spending, excluding saving/investing
  final double saving;
  const YearTotals(this.income, this.consumption, this.saving);

  /// Income minus spending. Money moved to savings is still yours.
  double get trueNet => income - consumption;
}

class Pace {
  final double perDay;
  final double monthProjection;
  final double? yearProjection; // null while it is too early in the year
  final double? yearBudget; // null if no budgets set
  const Pace(this.perDay, this.monthProjection, this.yearProjection, this.yearBudget);
}

/// Monday of the week containing [d], at midnight.
DateTime weekStartOf(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// App state. Local-first: everything is saved on the device; if the user
/// signs in, CloudService syncs changes to their account.
class AppStore extends ChangeNotifier {
  static const _kTxns = 'txns_v1';
  static const _kBudgets = 'budgets_v1';
  static const _kCurrency = 'currency_v1';
  static const _kRules = 'rules_v1';
  static const _kCats = 'cats_v1';
  static const _kDirty = 'dirty_v1';
  static const _kSettingsU = 'settings_u_v1';
  static const _kSettingsDirty = 'settings_dirty_v1';
  static const _kTheme = 'theme_v1';
  static const _kWealth = 'wealth_v1';
  static const _kGoals = 'goals_v1';
  static const _kPay = 'pay_v1';
  static const _kLock = 'app_lock_v1';
  static const _kRemind = 'remind_v1';
  static const _kRemindDays = 'remind_days_v1';

  SharedPreferences? _prefs;
  final List<Txn> _txns = []; // includes deleted tombstones
  final Map<String, double> _budgets = {};
  final List<Goal> _goals = [];

  /// Local to this phone (not synced): ask for fingerprint / screen lock on open.
  bool appLock = false;

  /// Local to this phone: notify before recurring bills fall due.
  bool remindOn = false;
  int remindDays = 1;

  Future<void> setAppLock(bool v) async {
    appLock = v;
    await _prefs?.setBool(_kLock, v);
    notifyListeners();
  }

  Future<void> setReminders({bool? on, int? days}) async {
    if (on != null) remindOn = on;
    if (days != null) remindDays = days;
    await _prefs?.setBool(_kRemind, remindOn);
    await _prefs?.setInt(_kRemindDays, remindDays);
    notifyListeners();
  }

  /// Salary day of the month (moved back to Friday if it lands on a weekend).
  int payDay = 25;

  /// Months whose pay date is not predictable (e.g. December), so you set
  /// them yourself. Month numbers 1..12.
  Set<int> payManualMonths = {12};

  /// 'yyyy-MM' -> 'yyyy-MM-dd': a date you chose for that month.
  final Map<String, String> payOverrides = {};
  final List<RecurringRule> _rules = [];
  List<Category> _cats = defaultCategories();
  final Wealth wealth = Wealth(); // net worth: accounts + policies
  final Set<String> _dirty = {}; // txn ids not yet pushed to the cloud
  int _settingsU = 0;
  bool _settingsDirty = false;

  BudgetPeriod budgetPeriod = BudgetPeriod.month;
  DateTime budgetAnchor = DateTime(DateTime.now().year, DateTime.now().month);

  String currency = '£';
  /// 'light' (default), 'dark' or 'system'. Kept on this phone only.
  String themeMode = 'light';
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  int year = DateTime.now().year; // for the Year tab
  bool weekView = false; // Overview: week instead of month
  /// Net worth page: null = whole family, else a member id (or 'joint').
  String? wealthFilter;
  DateTime weekAnchor = weekStartOf(DateTime.now());

  /// Set by CloudService: called after a change made on this device.
  VoidCallback? onLocalChange;

  // ------------------------------------------------------------ reading
  List<Txn> get all => _txns.where((t) => !t.deleted).toList(growable: false);
  List<RecurringRule> get rules => List.unmodifiable(_rules);

  // ------------------------------------------------------------ pay date
  Map<String, dynamic> _payJson() =>
      {'day': payDay, 'manual': payManualMonths.toList(), 'ov': payOverrides};

  void _applyPay(Map<String, dynamic> j) {
    payDay = ((j['day'] as num?)?.toInt() ?? 25).clamp(1, 31).toInt();
    payManualMonths = ((j['manual'] as List?) ?? const [12]).map((e) => (e as num).toInt()).toSet();
    payOverrides
      ..clear()
      ..addAll(((j['ov'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, v as String)));
  }

  Future<void> setPay({int? day, Set<int>? manualMonths}) {
    if (day != null) payDay = day.clamp(1, 31).toInt();
    if (manualMonths != null) payManualMonths = manualMonths;
    _touchSettings();
    return _changed();
  }

  Future<void> setPayOverride(int year, int month, DateTime? date) {
    final k = '$year-${month.toString().padLeft(2, '0')}';
    if (date == null) {
      payOverrides.remove(k);
    } else {
      payOverrides[k] = DateFormat('yyyy-MM-dd').format(date);
    }
    _touchSettings();
    return _changed();
  }

  bool hasPayOverride(int year, int month) =>
      payOverrides.containsKey('$year-${month.toString().padLeft(2, '0')}');

  /// Pay date for a month: your own date if set, else the pay day moved back
  /// to the last working day (Mon-Fri) when it falls on a weekend. Null for
  /// months you said are unpredictable until you set them.
  DateTime? payDateFor(int year, int month) {
    final o = payOverrides['$year-${month.toString().padLeft(2, '0')}'];
    if (o != null) {
      final d = DateTime.tryParse(o);
      if (d != null) return DateTime(d.year, d.month, d.day);
    }
    if (payManualMonths.contains(month)) return null;
    final last = DateTime(year, month + 1, 0).day;
    var d = DateTime(year, month, payDay > last ? last : payDay);
    while (d.weekday > 5) {
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return d;
  }

  /// Next pay date today or later; [needsDate] is the month that still needs
  /// a date when the next one is unknown.
  (DateTime?, DateTime?) get nextPay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 14; i++) {
      final m = DateTime(now.year, now.month + i);
      final d = payDateFor(m.year, m.month);
      if (d == null) return (null, m);
      if (!d.isBefore(today)) return (d, null);
    }
    return (null, null);
  }

  /// Most recent pay date before or on today.
  DateTime? get lastPay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 14; i++) {
      final m = DateTime(now.year, now.month - i);
      final d = payDateFor(m.year, m.month);
      if (d != null && !d.isAfter(today)) return d;
    }
    return null;
  }

  // ------------------------------------------------------------ savings goals
  List<Goal> get goals => List.unmodifiable(_goals);

  Future<void> saveGoal(Goal g) {
    final i = _goals.indexWhere((e) => e.id == g.id);
    if (i >= 0) {
      _goals[i] = g;
    } else {
      _goals.add(g);
    }
    _touchSettings();
    return _changed();
  }

  Future<void> removeGoal(String id) {
    _goals.removeWhere((e) => e.id == id);
    _touchSettings();
    return _changed();
  }

  /// Puts [amount] towards a goal (negative takes money back out).
  Future<void> addToGoal(String id, double amount) {
    final i = _goals.indexWhere((e) => e.id == id);
    if (i < 0) return Future.value();
    final v = _goals[i].saved + amount;
    return saveGoal(_goals[i].copyWith(saved: v < 0 ? 0 : v));
  }

  /// Badges earned across all goals: (title, description).
  List<(String, String, bool)> get badges {
    final total = _goals.fold(0.0, (a, g) => a + g.saved);
    final reached = _goals.where((g) => g.reached).length;
    final half = _goals.any((g) => g.fraction >= 0.5);
    return [
      ('First goal', 'Create a savings goal', _goals.isNotEmpty),
      ('Getting started', 'Save your first £100', total >= 100),
      ('Halfway there', 'Get any goal to 50%', half),
      ('Goal reached', 'Fully fund a goal', reached >= 1),
      ('£1,000 club', 'Save £1,000 across goals', total >= 1000),
      ('Triple', 'Reach 3 goals', reached >= 3),
      ('£5,000 club', 'Save £5,000 across goals', total >= 5000),
    ];
  }

  // ------------------------------------------------------------ loading
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    await p.reload(); // pick up changes made by the quick-add popup
    _prefs = p;
    currency = p.getString(_kCurrency) ?? '£';
    themeMode = p.getString(_kTheme) ?? 'light';

    _txns.clear();
    final t = p.getString(_kTxns);
    if (t != null) {
      try {
        _txns.addAll((jsonDecode(t) as List)
            .map((e) => Txn.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        // Corrupt data: start clean rather than crash.
      }
    }
    _budgets.clear();
    final b = p.getString(_kBudgets);
    if (b != null) {
      try {
        (jsonDecode(b) as Map<String, dynamic>)
            .forEach((k, v) => _budgets[k] = (v as num).toDouble());
      } catch (_) {}
    }
    _rules.clear();
    final r = p.getString(_kRules);
    if (r != null) {
      try {
        _rules.addAll((jsonDecode(r) as List)
            .map((e) => RecurringRule.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    _cats = defaultCategories();
    final c = p.getString(_kCats);
    if (c != null) {
      try {
        final list = (jsonDecode(c) as List)
            .map((e) => Category.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (list.isNotEmpty) _cats = list;
      } catch (_) {}
    }
    appLock = p.getBool(_kLock) ?? false;
    remindOn = p.getBool(_kRemind) ?? false;
    remindDays = p.getInt(_kRemindDays) ?? 1;
    payDay = 25;
    payManualMonths = {12};
    payOverrides.clear();
    final pj = p.getString(_kPay);
    if (pj != null) {
      try {
        _applyPay(Map<String, dynamic>.from(jsonDecode(pj) as Map));
      } catch (_) {}
    }
    _goals.clear();
    final gj = p.getString(_kGoals);
    if (gj != null) {
      try {
        _goals.addAll((jsonDecode(gj) as List)
            .map((e) => Goal.fromJson(Map<String, dynamic>.from(e as Map))));
      } catch (_) {}
    }
    wealth.clear();
    final w = p.getString(_kWealth);
    if (w != null) {
      try {
        wealth.loadJson(Map<String, dynamic>.from(jsonDecode(w) as Map));
      } catch (_) {}
    }
    _dirty.clear();
    final d = p.getString(_kDirty);
    if (d != null) {
      try {
        _dirty.addAll((jsonDecode(d) as List).cast<String>());
      } catch (_) {}
    }
    _settingsU = p.getInt(_kSettingsU) ?? 0;
    _settingsDirty = p.getBool(_kSettingsDirty) ?? false;

    _sort();
    final created = materializeRecurring();
    if (created) await _save();
    notifyListeners();
    if (created) onLocalChange?.call();
  }

  void _sort() => _txns.sort((a, b) => b.date.compareTo(a.date));

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_kTxns, jsonEncode(_txns.map((e) => e.toJson()).toList()));
    await p.setString(_kBudgets, jsonEncode(_budgets));
    await p.setString(_kRules, jsonEncode(_rules.map((e) => e.toJson()).toList()));
    await p.setString(_kCats, jsonEncode(_cats.map((e) => e.toJson()).toList()));
    await p.setString(_kCurrency, currency);
    await p.setString(_kTheme, themeMode);
    await p.setString(_kWealth, jsonEncode(wealth.toJson()));
    await p.setString(_kGoals, jsonEncode(_goals.map((e) => e.toJson()).toList()));
    await p.setString(_kPay, jsonEncode(_payJson()));
    await p.setString(_kDirty, jsonEncode(_dirty.toList()));
    await p.setInt(_kSettingsU, _settingsU);
    await p.setBool(_kSettingsDirty, _settingsDirty);

    // For the home-screen widget (read natively by Android): which
    // categories are saving, so "today" and "this week" show spending only.
    await p.setString('widget_saving',
        jsonEncode(_cats.where((c) => c.saving).map((c) => c.name).toList()));
  }

  /// Save + notify + refresh the widget, without triggering a cloud sync.
  Future<void> _persist() async {
    notifyListeners();
    await _save();
    await refreshWidget();
  }

  // ------------------------------------------------------------ net worth
  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> saveAccount(Account a) {
    wealth.upsertAccount(a.copyWith(updatedAt: _now));
    _touchSettings();
    return _changed();
  }

  /// Records a new value reading (default: today) for an account.
  Future<void> updateAccountValue(String id, double value, {DateTime? date}) {
    final a = wealth.byId(id);
    if (a == null) return Future.value();
    return saveAccount(a.copyWith(
        history: Wealth.withReading(a.history, date ?? DateTime.now(), value)));
  }

  Future<void> removeAccount(String id) {
    final a = wealth.byId(id);
    if (a == null) return Future.value();
    wealth.upsertAccount(a.copyWith(deleted: true, updatedAt: _now));
    _touchSettings();
    return _changed();
  }

  Future<void> savePolicy(Policy p) {
    wealth.upsertPolicy(p.copyWith(updatedAt: _now));
    _touchSettings();
    return _changed();
  }

  Future<void> removePolicy(String id) {
    final i = wealth.policies.indexWhere((p) => p.id == id);
    if (i < 0) return Future.value();
    wealth.policies[i] = wealth.policies[i].copyWith(deleted: true, updatedAt: _now);
    _touchSettings();
    return _changed();
  }

  void setWealthFilter(String? f) {
    wealthFilter = f;
    notifyListeners();
  }

  Future<void> saveMember(Member m) {
    wealth.upsertMember(m.copyWith(updatedAt: _now));
    _touchSettings();
    return _changed();
  }

  /// Returns an error message, or null if removed.
  Future<String?> removeMember(String id) async {
    if (id == Wealth.me) return 'You cannot remove yourself.';
    if (wealth.listed.any((a) => a.owner == id)) {
      return 'Move or remove their accounts first.';
    }
    final i = wealth.members.indexWhere((m) => m.id == id);
    if (i < 0) return null;
    wealth.members[i] = wealth.members[i].copyWith(deleted: true, updatedAt: _now);
    if (wealthFilter == id) wealthFilter = null;
    _touchSettings();
    await _changed();
    return null;
  }

  void setWeekView(bool v) {
    weekView = v;
    notifyListeners();
  }

  void shiftWeek(int d) {
    weekAnchor = DateTime(weekAnchor.year, weekAnchor.month, weekAnchor.day + 7 * d);
    selectedDay = null;
    notifyListeners();
  }

  /// Week view: tapped day (0 = Monday ... 6 = Sunday); null = whole week.
  int? selectedDay;

  /// Week view breakdown: false = by category, true = by merchant (payee).
  bool byMerchant = false;

  /// Overview donut: the focused category (null = none).
  String? donutSel;

  void selectDonut(String? c) {
    donutSel = (c == donutSel) ? null : c;
    notifyListeners();
  }

  void selectDay(int? i) {
    selectedDay = (i == selectedDay) ? null : i;
    notifyListeners();
  }

  void setByMerchant(bool v) {
    byMerchant = v;
    notifyListeners();
  }

  /// Jump to any date: shows its week with that day selected.
  void pickDate(DateTime d) {
    weekAnchor = weekStartOf(d);
    selectedDay = d.weekday - 1;
    notifyListeners();
  }

  /// Spending in [from, to) grouped by category or by merchant.
  Map<String, double> spendBreakdown(DateTime from, DateTime to, {required bool merchant}) {
    final out = <String, double>{};
    for (final x in all) {
      if (x.type != TxType.expense || isSaving(x.category)) continue;
      if (x.date.isBefore(from) || !x.date.isBefore(to)) continue;
      final k = merchant ? (x.payee.trim().isEmpty ? 'No merchant' : x.payee.trim()) : x.category;
      out[k] = (out[k] ?? 0) + x.amount;
    }
    return out;
  }

  /// That day's individual transactions, newest first.
  List<Txn> txnsOnDay(DateTime day) {
    final end = DateTime(day.year, day.month, day.day + 1);
    return all
        .where((x) =>
            x.type == TxType.expense &&
            !isSaving(x.category) &&
            !x.date.isBefore(day) &&
            x.date.isBefore(end))
        .toList();
  }

  bool get canWeekNext => !DateTime(weekAnchor.year, weekAnchor.month, weekAnchor.day + 7)
      .isAfter(DateTime.now());

  Future<void> setThemeMode(String m) async {
    themeMode = m;
    await _persist();
  }

  /// A change made by the user on this device.
  Future<void> _changed() async {
    await _persist();
    onLocalChange?.call();
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  void _touchSettings() {
    _settingsU = _now;
    _settingsDirty = true;
  }

  // ------------------------------------------------------------ categories
  List<Category> categoriesFor(TxType type) =>
      _cats.where((c) => c.type == type).toList(growable: false);

  /// Group headings in the order they first appear.
  List<String> groupsFor(TxType type) {
    final out = <String>[];
    for (final c in categoriesFor(type)) {
      if (!out.contains(c.group)) out.add(c.group);
    }
    return out;
  }

  Category categoryByName(String name) {
    for (final c in _cats) {
      if (c.name == name) return c;
    }
    // A category that was deleted but still has entries.
    return Category(
        name: name, icon: 9, color: 9, group: 'Other', type: TxType.expense);
  }

  bool isSaving(String category) => categoryByName(category).saving;

  /// Adds or edits a category. Returns an error message, or null on success.
  Future<String?> saveCategory(Category c, {String? oldName}) async {
    final name = c.name.trim();
    if (name.isEmpty) return 'Give the category a name.';
    if (name.contains(':')) return 'Names cannot contain ":".';
    final clash = _cats.any((x) =>
        x.name.toLowerCase() == name.toLowerCase() &&
        x.name != (oldName ?? '\u0000'));
    if (clash) return 'A category called "$name" already exists.';
    final fixed = c.copyWith(name: name, group: c.group.trim().isEmpty ? 'Other' : c.group.trim());

    if (oldName == null) {
      _cats = [..._cats, fixed];
    } else {
      final i = _cats.indexWhere((x) => x.name == oldName);
      if (i < 0) return 'Category not found.';
      _cats = [..._cats]..[i] = fixed;
      if (oldName != name) {
        for (var k = 0; k < _txns.length; k++) {
          if (_txns[k].category == oldName) {
            _txns[k] = _txns[k].copyWith(category: name, updatedAt: _now);
            _dirty.add(_txns[k].id);
          }
        }
        for (final prefix in ['', 'Q:', 'Y:']) {
          final v = _budgets.remove('$prefix$oldName');
          if (v != null) _budgets['$prefix$name'] = v;
        }
        for (var k = 0; k < _rules.length; k++) {
          if (_rules[k].category == oldName) {
            _rules[k] = _rules[k].copyWith(category: name);
          }
        }
      }
    }
    _touchSettings();
    await _changed();
    return null;
  }

  /// Moves the given entries to [category]. Returns how many changed.
  Future<int> moveTxns(List<String> ids, String category) async {
    final set = ids.toSet();
    var n = 0;
    for (var i = 0; i < _txns.length; i++) {
      final x = _txns[i];
      if (x.deleted || !set.contains(x.id) || x.category == category) continue;
      _txns[i] = x.copyWith(category: category, updatedAt: _now);
      _dirty.add(x.id);
      n++;
    }
    if (n > 0) await _changed();
    return n;
  }

  /// Existing entries keep their category name (shown in grey).
  Future<void> deleteCategory(String name) {
    _cats = _cats.where((c) => c.name != name).toList();
    for (final prefix in ['', 'Q:', 'Y:']) {
      _budgets.remove('$prefix$name');
    }
    _touchSettings();
    return _changed();
  }

  // ------------------------------------------------------------ months
  void shiftMonth(int delta) {
    month = DateTime(month.year, month.month + delta);
    notifyListeners();
  }

  bool get isCurrentMonth {
    final n = DateTime.now();
    return month.year == n.year && month.month == n.month;
  }

  void shiftYear(int delta) {
    year += delta;
    notifyListeners();
  }

  bool get canShiftYearNext => year < DateTime.now().year;

  // ------------------------------------------------------------ transactions
  /// Expenses flagged for Splitwise. [state] 1 = still to split, 2 = done.
  List<Txn> splitTxns(int state) =>
      _txns.where((t) => !t.deleted && t.split == state).toList();

  Future<void> setSplit(String id, int state) {
    final i = _txns.indexWhere((e) => e.id == id);
    if (i < 0) return Future.value();
    return upsert(_txns[i].copyWith(split: state));
  }

  Future<void> upsert(Txn t) {
    final stamped = t.copyWith(updatedAt: _now, deleted: false);
    final i = _txns.indexWhere((e) => e.id == stamped.id);
    if (i >= 0) {
      _txns[i] = stamped;
    } else {
      _txns.add(stamped);
    }
    _dirty.add(stamped.id);
    _sort();
    return _changed();
  }

  Future<void> remove(String id) {
    final i = _txns.indexWhere((e) => e.id == id);
    if (i < 0) return Future.value();
    _txns[i] = _txns[i].copyWith(updatedAt: _now, deleted: true);
    _dirty.add(id);
    return _changed();
  }

  List<Txn> get monthTxns => _txnsInMonth(month);

  List<Txn> _txnsInMonth(DateTime m) => _txns
      .where((t) => !t.deleted && t.date.year == m.year && t.date.month == m.month)
      .toList();

  double get monthIncome => monthTxns
      .where((t) => t.type == TxType.income)
      .fold(0.0, (s, t) => s + t.amount);

  /// Spending this month, NOT counting money moved into savings.
  /// Refunds (negative amounts) reduce it.
  double get monthExpense => monthTxns
      .where((t) => t.type == TxType.expense && !isSaving(t.category))
      .fold(0.0, (s, t) => s + t.amount);

  double get monthSaving => monthTxns
      .where((t) => t.type == TxType.expense && isSaving(t.category))
      .fold(0.0, (s, t) => s + t.amount);

  /// Income minus spending (savings are still yours).
  double get monthTrueNet => monthIncome - monthExpense;

  Map<String, double> get monthExpenseByCategory {
    final m = <String, double>{};
    for (final t in monthTxns
        .where((t) => t.type == TxType.expense && !isSaving(t.category))) {
      m[t.category] = (m[t.category] ?? 0) + t.amount;
    }
    m.removeWhere((_, v) => v <= 0);
    return m;
  }

  /// Average spend per day for the shown month (elapsed days only for the
  /// current month).
  double get monthPerDay {
    final days = isCurrentMonth
        ? DateTime.now().day
        : DateTime(month.year, month.month + 1, 0).day;
    return days <= 0 ? 0 : monthExpense / days;
  }

  // ------------------------------------------------------------ budgets
  static String _prefix(BudgetPeriod p) =>
      p == BudgetPeriod.month ? '' : (p == BudgetPeriod.quarter ? 'Q:' : 'Y:');

  /// Monthly limits by category. Quarterly/yearly limits are stored in the
  /// same map as 'Q:<category>' / 'Y:<category>' (so sync needs no changes).
  Map<String, double> get budgets => budgetsFor(BudgetPeriod.month);

  Map<String, double> budgetsFor(BudgetPeriod p) {
    final prefix = _prefix(p);
    final out = <String, double>{};
    // Quarterly/yearly limits follow the monthly budget automatically
    // (x3 / x12) unless you set one of your own for that period.
    if (prefix.isNotEmpty) {
      final mult = p == BudgetPeriod.quarter ? 3 : 12;
      _budgets.forEach((k, v) {
        if (!k.contains(':')) out[k] = v * mult;
      });
    }
    _budgets.forEach((k, v) {
      if (prefix.isEmpty) {
        if (!k.contains(':')) out[k] = v;
      } else if (k.startsWith(prefix)) {
        out[k.substring(prefix.length)] = v;
      }
    });
    return out;
  }

  Future<void> setBudget(String category, double? amount,
      {BudgetPeriod period = BudgetPeriod.month}) {
    final key = '${_prefix(period)}$category';
    if (amount == null || amount <= 0) {
      _budgets.remove(key);
    } else {
      _budgets[key] = amount;
    }
    _touchSettings();
    return _changed();
  }

  // ---- budget periods (Budgets tab) ----
  static DateTime periodStart(BudgetPeriod p, DateTime a) {
    switch (p) {
      case BudgetPeriod.month:
        return DateTime(a.year, a.month);
      case BudgetPeriod.quarter:
        return DateTime(a.year, ((a.month - 1) ~/ 3) * 3 + 1);
      case BudgetPeriod.year:
        return DateTime(a.year);
    }
  }

  static DateTime periodEnd(BudgetPeriod p, DateTime a) {
    final s = periodStart(p, a);
    switch (p) {
      case BudgetPeriod.month:
        return DateTime(s.year, s.month + 1);
      case BudgetPeriod.quarter:
        return DateTime(s.year, s.month + 3);
      case BudgetPeriod.year:
        return DateTime(s.year + 1);
    }
  }

  static String periodLabel(BudgetPeriod p, DateTime a) {
    switch (p) {
      case BudgetPeriod.month:
        return DateFormat('MMMM yyyy').format(a);
      case BudgetPeriod.quarter:
        return 'Q${(a.month - 1) ~/ 3 + 1} ${a.year}';
      case BudgetPeriod.year:
        return '${a.year}';
    }
  }

  static DateTime _shiftAnchor(BudgetPeriod p, DateTime a, int d) => DateTime(
      a.year,
      a.month +
          d * (p == BudgetPeriod.month ? 1 : (p == BudgetPeriod.quarter ? 3 : 12)));

  void setBudgetPeriod(BudgetPeriod p) {
    budgetPeriod = p;
    final n = DateTime.now();
    budgetAnchor = DateTime(n.year, n.month);
    notifyListeners();
  }

  void shiftBudget(int d) {
    budgetAnchor = _shiftAnchor(budgetPeriod, budgetAnchor, d);
    notifyListeners();
  }

  bool get canBudgetNext => !periodStart(
          budgetPeriod, _shiftAnchor(budgetPeriod, budgetAnchor, 1))
      .isAfter(DateTime.now());

  /// Expense totals per category within the period containing [anchor]
  /// (includes savings categories; refunds reduce a category).
  Map<String, double> spentByCategory(BudgetPeriod p, DateTime anchor) {
    final start = periodStart(p, anchor);
    final end = periodEnd(p, anchor);
    final out = <String, double>{};
    for (final t in _txns) {
      if (t.deleted || t.type != TxType.expense) continue;
      if (t.date.isBefore(start) || !t.date.isBefore(end)) continue;
      out[t.category] = (out[t.category] ?? 0) + t.amount;
    }
    return out;
  }

  /// Spent vs limit across the categories that have a limit for [p]
  /// (current period). Savings goals are excluded. Null if none set.
  BudgetProgress? budgetProgress(BudgetPeriod p) {
    final lims = Map<String, double>.from(budgetsFor(p))
      ..removeWhere((k, _) => isSaving(k));
    if (lims.isEmpty) return null;
    final spent = spentByCategory(p, DateTime.now());
    final limit = lims.values.fold(0.0, (a, b) => a + b);
    final used = lims.keys.fold(0.0, (a, k) => a + (spent[k] ?? 0));
    return BudgetProgress(limit, used);
  }

  /// Daily allowance from monthly budgets, for the real current month.
  SafeToSpend? get safeToSpend {
    final monthly = Map<String, double>.from(budgets)
      ..removeWhere((k, _) => isSaving(k));
    if (monthly.isEmpty) return null;
    final now = DateTime.now();
    final nowMonth = DateTime(now.year, now.month);
    final totalBudget = monthly.values.fold(0.0, (a, b) => a + b);
    var spent = 0.0;
    var spentToday = 0.0;
    for (final t in _txnsInMonth(nowMonth)) {
      if (t.type != TxType.expense || !monthly.containsKey(t.category)) continue;
      spent += t.amount;
      if (t.date.day == now.day) spentToday += t.amount;
    }
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day + 1;
    final remaining = totalBudget - spent;
    final allowance = (remaining + spentToday) / daysLeft;
    return SafeToSpend(
      dailyAllowance: allowance,
      leftToday: allowance - spentToday,
      remainingMonth: remaining,
      daysLeft: daysLeft,
    );
  }

  // ------------------------------------------------------------ year view
  /// 12 monthly totals per category for [y].
  Map<String, List<double>> yearByCategory(int y, TxType type) {
    final out = <String, List<double>>{};
    for (final t in _txns) {
      if (t.deleted || t.type != type || t.date.year != y) continue;
      (out[t.category] ??= List<double>.filled(12, 0.0))[t.date.month - 1] +=
          t.amount;
    }
    return out;
  }

  List<double> _sumMonths(Map<String, List<double>> m, bool Function(String) keep) {
    final out = List<double>.filled(12, 0.0);
    m.forEach((cat, vals) {
      if (!keep(cat)) return;
      for (var i = 0; i < 12; i++) {
        out[i] += vals[i];
      }
    });
    return out;
  }

  List<double> incomeByMonth(int y) =>
      _sumMonths(yearByCategory(y, TxType.income), (_) => true);
  List<double> consumptionByMonth(int y) =>
      _sumMonths(yearByCategory(y, TxType.expense), (c) => !isSaving(c));
  List<double> savingByMonth(int y) =>
      _sumMonths(yearByCategory(y, TxType.expense), isSaving);

  YearTotals yearTotals(int y) => YearTotals(
      incomeByMonth(y).fold(0.0, (a, b) => a + b),
      consumptionByMonth(y).fold(0.0, (a, b) => a + b),
      savingByMonth(y).fold(0.0, (a, b) => a + b));

  /// The last month (1-12) of [y] that has any entry, up to today. 0 if none.
  /// Budget-to-date scales with this, like a ledger that fills in as the year goes.
  int monthsWithData(int y) {
    var last = 0;
    final cap = y == DateTime.now().year ? DateTime.now().month : 12;
    for (final t in _txns) {
      if (t.deleted || t.date.year != y) continue;
      if (t.date.month <= cap && t.date.month > last) last = t.date.month;
    }
    return last;
  }

  /// Yearly budget for a category: its yearly limit, else monthly × 12.
  double? yearBudget(String category) {
    final y = budgetsFor(BudgetPeriod.year)[category];
    if (y != null) return y;
    final m = budgets[category];
    return m == null ? null : m * 12;
  }

  double? budgetToDate(String category, int y) {
    final months = monthsWithData(y);
    final m = budgets[category];
    if (m != null) return m * months;
    final yr = budgetsFor(BudgetPeriod.year)[category];
    if (yr != null) return yr * months / 12;
    return null;
  }

  /// Every spending category with budget-to-date vs actual, worst first.
  List<LedgerRow> ledger(int y) {
    final spent = yearByCategory(y, TxType.expense);
    final names = <String>{
      ...spent.keys,
      ...budgets.keys,
      ...budgetsFor(BudgetPeriod.year).keys,
    }..removeWhere(isSaving);
    final rows = <LedgerRow>[];
    for (final n in names) {
      final actual = (spent[n] ?? List<double>.filled(12, 0.0))
          .fold(0.0, (a, b) => a + b);
      final b = budgetToDate(n, y);
      if (actual == 0 && b == null) continue;
      rows.add(LedgerRow(n, b, actual));
    }
    rows.sort((a, b) => b.diff.compareTo(a.diff));
    return rows;
  }

  /// Plain-language findings, like "Eating out is running 2.2x budget".
  List<Insight> insights(int y) {
    final months = monthsWithData(y);
    if (months == 0) return [];
    final rows = ledger(y);
    final mat = yearByCategory(y, TxType.expense);
    final out = <Insight>[];
    final leaks =
        rows.where((r) => r.hasBudget && r.actual > r.budgetToDate!).toList();
    for (var i = 0; i < leaks.length && i < 2; i++) {
      final r = leaks[i];
      final avg = r.actual / months;
      final plan = r.budgetToDate! / months;
      final over = avg - plan;
      final vals = mat[r.category] ?? List<double>.filled(12, 0.0);
      final idx = List<int>.generate(12, (k) => k)
          .where((k) => vals[k] > 0)
          .toList()
        ..sort((a, b) => vals[b].compareTo(vals[a]));
      String mn(int k) => DateFormat('MMMM').format(DateTime(y, k + 1));
      final worst = idx.length >= 2
          ? ' Worst months: ${mn(idx[0])} (${money(vals[idx[0]])}) and ${mn(idx[1])} (${money(vals[idx[1]])}).'
          : '';
      out.add(Insight(
        i == 0
            ? 'Biggest leak: ${r.category} is running ${r.ratio.toStringAsFixed(1)}× budget'
            : '${r.category} is over too: ${r.ratio.toStringAsFixed(1)}× budget',
        '${money(r.actual)} spent against ${money(r.budgetToDate!)} budgeted so far, '
        'averaging ${money(avg)}/month vs ${money(plan)} planned. '
        'Trimming to budget frees about ${money(over)}/month, ~${money(over * 12)}/year.$worst',
        warn: true,
      ));
    }
    final unbudgeted =
        rows.where((r) => !r.hasBudget && r.actual > 0).toList();
    if (unbudgeted.isNotEmpty) {
      final total = unbudgeted.fold(0.0, (a, r) => a + r.actual);
      final names = unbudgeted.take(3).map((r) => r.category).join(', ');
      out.add(Insight(
        'Spending with no budget',
        '${money(total)} went on $names${unbudgeted.length > 3 ? ' and more' : ''}. '
        'Set a monthly limit in Budgets to keep an eye on it.',
      ));
    }
    final t = yearTotals(y);
    if (t.income > 0 || t.consumption > 0) {
      final up = t.trueNet >= 0;
      out.add(Insight(
        up
            ? 'You are up ${money(t.trueNet)} this year'
            : 'You are down ${money(-t.trueNet)} this year',
        'Income ${money(t.income)} minus spending ${money(t.consumption)}.'
        '${t.saving > 0 ? ' ${money(t.saving)} was moved into savings and investing, which is not counted as spending.' : ''}',
        warn: !up,
      ));
    }
    return out;
  }

  /// Average daily spend and projections, for the real current month/year.
  Pace pace() {
    final now = DateTime.now();
    final monthSpent = consumptionByMonth(now.year)[now.month - 1];
    final perDay = monthSpent / now.day;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dayOfYear = now.difference(DateTime(now.year)).inDays + 1;
    final daysInYear = DateTime(now.year + 1).difference(DateTime(now.year)).inDays;
    final fraction = dayOfYear / daysInYear;
    final ytd = consumptionByMonth(now.year).fold(0.0, (a, b) => a + b);
    double? yearBudgetTotal;
    for (final c in categoriesFor(TxType.expense).where((c) => !c.saving)) {
      final b = yearBudget(c.name);
      if (b != null) yearBudgetTotal = (yearBudgetTotal ?? 0) + b;
    }
    return Pace(
      perDay,
      perDay * daysInMonth,
      fraction >= 0.1 ? ytd / fraction : null,
      yearBudgetTotal,
    );
  }

  // ------------------------------------------------------------ recurring
  Future<void> upsertRule(RecurringRule r) {
    final i = _rules.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      _rules[i] = r;
    } else {
      _rules.add(r);
    }
    _touchSettings();
    materializeRecurring();
    return _changed();
  }

  Future<void> removeRule(String id) {
    _rules.removeWhere((e) => e.id == id);
    _touchSettings();
    return _changed();
  }

  /// Creates the transactions that are due. Ids are deterministic
  /// (rec_<rule>_<yyyyMM>) so two devices never create duplicates, and a
  /// deleted one (tombstone) is never re-created. Returns true if any added.
  bool materializeRecurring([DateTime? at]) {
    final now = at ?? DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final earliest = DateTime(now.year, now.month - 36);
    final existing = _txns.map((t) => t.id).toSet();
    final fmt = DateFormat('yyyyMM');
    var added = false;
    for (final r in _rules.where((r) => r.active)) {
      final parts = r.startMonth.split('-');
      if (parts.length != 2) continue;
      var m = DateTime(int.tryParse(parts[0]) ?? now.year,
          int.tryParse(parts[1]) ?? now.month);
      if (m.isBefore(earliest)) m = earliest;
      while (!m.isAfter(thisMonth)) {
        final date = DateTime(m.year, m.month, r.day);
        if (!date.isAfter(now)) {
          final id = 'rec_${r.id}_${fmt.format(m)}';
          if (!existing.contains(id)) {
            _txns.add(Txn(
              id: id,
              type: r.type,
              amount: r.amount,
              category: r.category,
              payee: r.note,
              note: '',
              date: date,
              updatedAt: _now,
            ));
            _dirty.add(id);
            existing.add(id);
            added = true;
          }
        }
        m = DateTime(m.year, m.month + 1);
      }
    }
    if (added) _sort();
    return added;
  }

  // ------------------------------------------------------------ quick entry helpers
  /// The most recently entered (not auto-generated) transaction of a type.
  Txn? lastTxn(TxType type) {
    Txn? best;
    for (final t in _txns) {
      if (t.deleted || t.type != type || t.id.startsWith('rec_')) continue;
      if (best == null || t.updatedAt > best.updatedAt) best = t;
    }
    return best;
  }

  /// Category you most often use at this time of day (morning / midday /
  /// evening / night); falls back to the first category.
  String suggestedCategory(TxType type, [DateTime? at]) {
    final cats = categoriesFor(type);
    final fallback = cats.isEmpty ? 'Other' : cats.first.name;
    int bucket(int h) => h < 5 ? 3 : h < 11 ? 0 : h < 16 ? 1 : h < 22 ? 2 : 3;
    final now = at ?? DateTime.now();
    final counts = <String, int>{};
    var seen = 0;
    for (final t in _txns) {
      if (t.deleted || t.type != type || t.id.startsWith('rec_') || t.updatedAt == 0) {
        continue;
      }
      if (++seen > 300) break;
      final entered = DateTime.fromMillisecondsSinceEpoch(t.updatedAt);
      if (bucket(entered.hour) == bucket(now.hour) &&
          cats.any((c) => c.name == t.category)) {
        counts[t.category] = (counts[t.category] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return fallback;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ------------------------------------------------------------ payees
  /// Payees you have used before, most relevant first. Payees used with
  /// [category] rank higher.
  List<String> payeeSuggestions(String query, {String? category}) {
    final q = query.trim().toLowerCase();
    final counts = <String, int>{};
    final display = <String, String>{};
    var seen = 0;
    for (final t in _txns) {
      if (t.deleted || t.payee.isEmpty) continue;
      if (++seen > 800) break;
      final k = t.payee.toLowerCase();
      display.putIfAbsent(k, () => t.payee);
      counts[k] = (counts[k] ?? 0) + (category != null && t.category == category ? 3 : 1);
    }
    final keys = counts.keys.where((k) => q.isEmpty || k.contains(q)).toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return keys.take(6).map((k) => display[k]!).toList();
  }

  /// The category you usually file this payee under (never "Other" if a
  /// better one exists), so entering "Tesco" can pick Groceries for you.
  String? categoryForPayee(String payee, TxType type) {
    final key = payee.trim().toLowerCase();
    if (key.isEmpty) return null;
    final valid = categoriesFor(type).map((c) => c.name).toSet();
    final counts = <String, int>{};
    var seen = 0;
    for (final t in _txns) {
      if (t.deleted || t.type != type || t.payee.trim().toLowerCase() != key) continue;
      if (++seen > 200) break;
      if (valid.contains(t.category)) {
        counts[t.category] = (counts[t.category] ?? 0) + (t.category == 'Other' ? 0 : 2) + 1;
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ------------------------------------------------------------ review
  /// Spending filed under "Other" (or a deleted category): worth sorting.
  List<Txn> get needsReview {
    final names = _cats.map((c) => c.name).toSet();
    return _txns
        .where((t) =>
            !t.deleted &&
            t.type == TxType.expense &&
            (t.category == 'Other' || !names.contains(t.category)))
        .toList();
  }

  /// Moves [t] to [newCategory]; with [allFromPayee] also every entry from
  /// the same payee that is in the same old category. Returns how many moved.
  Future<int> recategorize(Txn t, String newCategory,
      {bool allFromPayee = false}) async {
    final key = t.payee.trim().toLowerCase();
    final old = t.category;
    var n = 0;
    for (var i = 0; i < _txns.length; i++) {
      final x = _txns[i];
      if (x.deleted || x.category == newCategory) continue;
      final match = x.id == t.id ||
          (allFromPayee &&
              key.isNotEmpty &&
              x.payee.trim().toLowerCase() == key &&
              x.category == old);
      if (match) {
        _txns[i] = x.copyWith(category: newCategory, updatedAt: _now);
        _dirty.add(x.id);
        n++;
      }
    }
    if (n > 0) await _changed();
    return n;
  }

  // ------------------------------------------------------------ settings
  Future<void> setCurrency(String c) {
    currency = c;
    _touchSettings();
    return _changed();
  }

  /// Deletes every transaction, budget and recurring rule (also in the
  /// cloud account, because deletes sync). Categories are kept.
  Future<void> clearAll() {
    for (var i = 0; i < _txns.length; i++) {
      if (_txns[i].deleted) continue;
      _txns[i] = _txns[i].copyWith(updatedAt: _now, deleted: true);
      _dirty.add(_txns[i].id);
    }
    _budgets.clear();
    _rules.clear();
    _goals.clear();
    for (final a in wealth.listed) {
      wealth.upsertAccount(a.copyWith(deleted: true, updatedAt: _now));
    }
    for (final p in wealth.listedPolicies) {
      wealth.upsertPolicy(p.copyWith(deleted: true, updatedAt: _now));
    }
    _touchSettings();
    return _changed();
  }

  // ------------------------------------------------------------ sync API
  /// Removes this phone's copy only (used on sign-out). Nothing is queued
  /// for the cloud.
  Future<void> wipeLocalOnly() async {
    _txns.clear();
    _budgets.clear();
    _rules.clear();
    _goals.clear();
    _cats = defaultCategories();
    wealth.clear();
    _dirty.clear();
    _settingsU = 0;
    _settingsDirty = false;
    await _persist();
  }

  List<Txn> get dirtyTxns =>
      _txns.where((t) => _dirty.contains(t.id)).toList(growable: false);
  bool get settingsDirty => _settingsDirty;

  /// First sign-in on this device: queue everything for upload.
  Future<void> markAllDirty() async {
    _dirty.addAll(_txns.map((t) => t.id));
    if (_settingsU == 0) _settingsU = _now;
    _settingsDirty = true;
    await _save();
  }

  Future<void> markPushed(Iterable<String> ids, {bool settings = false}) async {
    _dirty.removeAll(ids);
    if (settings) _settingsDirty = false;
    await _save();
  }

  /// Merges transactions from the cloud or a backup. Newest edit wins.
  /// Returns how many were added/updated here.
  Future<int> mergeTxns(List<Txn> incoming, {bool markDirty = false}) async {
    final byId = {for (final t in _txns) t.id: t};
    var n = 0;
    for (var r in incoming) {
      if (markDirty && r.updatedAt == 0) r = r.copyWith(updatedAt: _now);
      final l = byId[r.id];
      if (l == null || r.updatedAt > l.updatedAt) {
        byId[r.id] = r;
        if (markDirty) {
          _dirty.add(r.id);
        } else {
          _dirty.remove(r.id);
        }
        n++;
      }
    }
    if (n > 0) {
      _txns
        ..clear()
        ..addAll(byId.values);
      _sort();
      await _persist();
    }
    return n;
  }

  Map<String, dynamic> settingsJson() => {
        'currency': currency,
        'budgets': _budgets,
        'recurring': _rules.map((e) => e.toJson()).toList(),
        'categories': _cats.map((e) => e.toJson()).toList(),
        'wealth': wealth.toJson(),
        'goals': _goals.map((e) => e.toJson()).toList(),
        'pay': _payJson(),
        'u': _settingsU,
      };

  /// Applies settings if they are newer than ours. Returns true if applied.
  Future<bool> applySettingsJson(Map<String, dynamic> j,
      {bool markDirty = false}) async {
    final u = (j['u'] as num?)?.toInt() ?? 0;
    var wealthChanged = false;
    final w = j['wealth'];
    if (w is Map) {
      try {
        wealthChanged = wealth.merge(Map<String, dynamic>.from(w));
      } catch (_) {}
    }
    if (u <= _settingsU) {
      if (wealthChanged) {
        if (markDirty) _touchSettings();
        await _persist();
        return true;
      }
      return false;
    }
    try {
      currency = (j['currency'] as String?) ?? currency;
      if (j['budgets'] != null) {
        _budgets
          ..clear()
          ..addAll((j['budgets'] as Map)
              .map((k, v) => MapEntry(k as String, (v as num).toDouble())));
      }
      if (j['pay'] is Map) {
        _applyPay(Map<String, dynamic>.from(j['pay'] as Map));
      }
      if (j['goals'] != null) {
        _goals
          ..clear()
          ..addAll((j['goals'] as List)
              .map((e) => Goal.fromJson(Map<String, dynamic>.from(e as Map))));
      }
      if (j['recurring'] != null) {
        _rules
          ..clear()
          ..addAll((j['recurring'] as List)
              .map((e) => RecurringRule.fromJson(Map<String, dynamic>.from(e as Map))));
      }
      final cats = (j['categories'] as List?)
          ?.map((e) => Category.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (cats != null && cats.isNotEmpty) _cats = cats;
      _settingsU = u;
      _settingsDirty = markDirty;
      materializeRecurring();
      await _persist();
      return true;
    } catch (_) {
      return false;
    }
  }

  int lastPull(String uid) => _prefs?.getInt('last_pull_$uid') ?? 0;
  Future<void> setLastPull(String uid, int ms) async {
    await _prefs?.setInt('last_pull_$uid', ms);
  }

  // ------------------------------------------------------------ backup
  Map<String, dynamic> backupJson() => {
        'app': 'pocket_ledger',
        'version': 3,
        'exportedAt': DateTime.now().toIso8601String(),
        'txns': all.map((t) => t.toJson()).toList(),
        'settings': settingsJson(),
      };

  /// Merges a backup file into the current data (nothing is overwritten
  /// unless the backup's entry is newer). Returns a message for the user.
  Future<String> restoreBackup(String text) async {
    try {
      final j = jsonDecode(text);
      if (j is! Map || j['app'] != 'pocket_ledger') {
        return 'This is not a Pocket Ledger backup.';
      }
      final list = (j['txns'] as List)
          .map((e) => Txn.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final n = await mergeTxns(list, markDirty: true);
      final s = j['settings'];
      if (s is Map) {
        final sm = Map<String, dynamic>.from(s);
        // An explicit restore always wins over the settings already on the phone.
        final fileU = (sm['u'] as num?)?.toInt() ?? 0;
        sm['u'] = fileU > _settingsU ? fileU : _settingsU + 1;
        await applySettingsJson(sm, markDirty: true);
      }
      onLocalChange?.call();
      final b = _budgets.length;
      return n == 0
          ? 'No new transactions. Budgets and categories restored ($b budgets).'
          : 'Restored $n transaction${n == 1 ? '' : 's'}, $b budgets.';
    } catch (_) {
      return 'Could not read this file.';
    }
  }

  // ------------------------------------------------------------ formatting / export
  String money(double v) =>
      '${v < 0 ? '-' : ''}$currency${NumberFormat('#,##0.00').format(v.abs())}';

  String toCsv() {
    String esc(String s) => '"${s.replaceAll('"', '""')}"';
    final rows = <String>['date,type,category,amount,payee,note'];
    for (final t in all) {
      rows.add([
        DateFormat('yyyy-MM-dd').format(t.date),
        t.type.name,
        esc(t.category),
        t.amount.toStringAsFixed(2),
        esc(t.payee),
        esc(t.note),
      ].join(','));
    }
    return rows.join('\n');
  }
}
