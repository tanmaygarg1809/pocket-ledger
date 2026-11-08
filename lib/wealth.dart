/// Net worth: accounts (cash, savings, investments, pensions, gold, property,
/// debts) with a value history, plus insurance policies kept for reference.
library;

enum AccountKind {
  bank,
  savings,
  cash,
  investment,
  pension,
  gold,
  jewellery,
  property,
  other,
  loan,
}

extension AccountKindX on AccountKind {
  String get label {
    switch (this) {
      case AccountKind.bank:
        return 'Bank';
      case AccountKind.savings:
        return 'Savings';
      case AccountKind.cash:
        return 'Cash';
      case AccountKind.investment:
        return 'Investment';
      case AccountKind.pension:
        return 'Pension';
      case AccountKind.gold:
        return 'Gold';
      case AccountKind.jewellery:
        return 'Jewellery';
      case AccountKind.property:
        return 'Property';
      case AccountKind.other:
        return 'Other';
      case AccountKind.loan:
        return 'Loan / card';
    }
  }

  bool get isDebt => this == AccountKind.loan;

  /// Heading used on the Net worth page.
  String get group {
    switch (this) {
      case AccountKind.bank:
      case AccountKind.savings:
      case AccountKind.cash:
        return 'Cash & bank';
      case AccountKind.investment:
        return 'Investments';
      case AccountKind.pension:
        return 'Pensions';
      case AccountKind.gold:
      case AccountKind.jewellery:
        return 'Gold & valuables';
      case AccountKind.property:
        return 'Property';
      case AccountKind.other:
        return 'Other assets';
      case AccountKind.loan:
        return 'Debts';
    }
  }
}

const wealthGroups = <String>[
  'Cash & bank',
  'Investments',
  'Pensions',
  'Gold & valuables',
  'Property',
  'Other assets',
  'Debts',
];

const policyTypes = <String>[
  'Life',
  'Home',
  'Car',
  'Health',
  'Income',
  'Travel',
  'Pet',
  'Other',
];

class ValuePoint {
  final DateTime date;
  final double value;
  const ValuePoint(this.date, this.value);

  Map<String, dynamic> toJson() => {'d': date.millisecondsSinceEpoch, 'v': value};

  factory ValuePoint.fromJson(Map<String, dynamic> j) => ValuePoint(
        DateTime.fromMillisecondsSinceEpoch((j['d'] as num).toInt()),
        (j['v'] as num).toDouble(),
      );
}

class Account {
  final String id;
  final AccountKind kind;
  final String name;
  final String provider;
  final double? weight; // grams, for gold
  final bool include; // counts towards net worth
  final List<ValuePoint> history; // oldest first
  final int updatedAt;
  final bool deleted;

  const Account({
    required this.id,
    required this.kind,
    required this.name,
    this.provider = '',
    this.weight,
    this.include = true,
    this.history = const [],
    this.updatedAt = 0,
    this.deleted = false,
  });

  /// Latest value (for debts: the amount owed, as a positive number).
  double get value => history.isEmpty ? 0 : history.last.value;
  DateTime? get updated => history.isEmpty ? null : history.last.date;

  /// Value on or before [d], or null if it had no value yet.
  double? valueOn(DateTime d) {
    double? r;
    for (final p in history) {
      if (p.date.isAfter(d)) break;
      r = p.value;
    }
    return r;
  }

  Account copyWith({
    AccountKind? kind,
    String? name,
    String? provider,
    double? weight,
    bool clearWeight = false,
    bool? include,
    List<ValuePoint>? history,
    int? updatedAt,
    bool? deleted,
  }) =>
      Account(
        id: id,
        kind: kind ?? this.kind,
        name: name ?? this.name,
        provider: provider ?? this.provider,
        weight: clearWeight ? null : (weight ?? this.weight),
        include: include ?? this.include,
        history: history ?? this.history,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'name': name,
        'provider': provider,
        'weight': weight,
        'include': include,
        'history': history.map((e) => e.toJson()).toList(),
        'u': updatedAt,
        'del': deleted,
      };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String,
        kind: AccountKind.values.firstWhere((k) => k.name == j['kind'],
            orElse: () => AccountKind.other),
        name: (j['name'] as String?) ?? '',
        provider: (j['provider'] as String?) ?? '',
        weight: (j['weight'] as num?)?.toDouble(),
        include: (j['include'] as bool?) ?? true,
        history: ((j['history'] as List?) ?? [])
            .map((e) => ValuePoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date)),
        updatedAt: (j['u'] as num?)?.toInt() ?? 0,
        deleted: (j['del'] as bool?) ?? false,
      );
}

class Policy {
  final String id;
  final String type;
  final String provider;
  final String number;
  final double cover;
  final double premium; // per month
  final DateTime? renewal;
  final String covered;
  final bool remind;
  final double? cashValue; // counted in net worth if set
  final int updatedAt;
  final bool deleted;

  const Policy({
    required this.id,
    required this.type,
    required this.provider,
    this.number = '',
    this.cover = 0,
    this.premium = 0,
    this.renewal,
    this.covered = '',
    this.remind = true,
    this.cashValue,
    this.updatedAt = 0,
    this.deleted = false,
  });

  Policy copyWith({int? updatedAt, bool? deleted}) => Policy(
        id: id,
        type: type,
        provider: provider,
        number: number,
        cover: cover,
        premium: premium,
        renewal: renewal,
        covered: covered,
        remind: remind,
        cashValue: cashValue,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'provider': provider,
        'number': number,
        'cover': cover,
        'premium': premium,
        'renewal': renewal?.millisecondsSinceEpoch,
        'covered': covered,
        'remind': remind,
        'cash': cashValue,
        'u': updatedAt,
        'del': deleted,
      };

  factory Policy.fromJson(Map<String, dynamic> j) => Policy(
        id: j['id'] as String,
        type: (j['type'] as String?) ?? 'Other',
        provider: (j['provider'] as String?) ?? '',
        number: (j['number'] as String?) ?? '',
        cover: (j['cover'] as num?)?.toDouble() ?? 0,
        premium: (j['premium'] as num?)?.toDouble() ?? 0,
        renewal: j['renewal'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((j['renewal'] as num).toInt()),
        covered: (j['covered'] as String?) ?? '',
        remind: (j['remind'] as bool?) ?? true,
        cashValue: (j['cash'] as num?)?.toDouble(),
        updatedAt: (j['u'] as num?)?.toInt() ?? 0,
        deleted: (j['del'] as bool?) ?? false,
      );
}

class WealthPoint {
  final DateTime date;
  final double value;
  const WealthPoint(this.date, this.value);
}

/// All net-worth data. Pure Dart so it is easy to test.
class Wealth {
  final List<Account> accounts = []; // includes deleted tombstones
  final List<Policy> policies = [];

  List<Account> get listed =>
      accounts.where((a) => !a.deleted).toList(growable: false);
  List<Policy> get listedPolicies =>
      policies.where((p) => !p.deleted).toList(growable: false);
  List<Account> get counted => listed.where((a) => a.include).toList(growable: false);

  double get _policyCash =>
      listedPolicies.fold(0.0, (a, p) => a + (p.cashValue ?? 0));

  double get assets =>
      counted.where((a) => !a.kind.isDebt).fold(0.0, (a, b) => a + b.value) +
      _policyCash;
  double get debts =>
      counted.where((a) => a.kind.isDebt).fold(0.0, (a, b) => a + b.value);
  double get netWorth => assets - debts;
  bool get isEmpty => listed.isEmpty;

  double get totalCover => listedPolicies.fold(0.0, (a, p) => a + p.cover);
  double get monthlyPremiums => listedPolicies.fold(0.0, (a, p) => a + p.premium);

  Account? byId(String id) {
    for (final a in accounts) {
      if (a.id == id && !a.deleted) return a;
    }
    return null;
  }

  /// Net worth as it stood on [d], from each account's value history.
  double netWorthAt(DateTime d) {
    var total = _policyCash;
    for (final a in counted) {
      final v = a.valueOn(d) ?? 0;
      total += a.kind.isDebt ? -v : v;
    }
    return total;
  }

  /// One point per month for the last [months] months (the last is "now").
  List<WealthPoint> series(int months, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final out = <WealthPoint>[];
    for (var i = months - 1; i >= 0; i--) {
      final end = i == 0
          ? n
          : DateTime(n.year, n.month - i + 1, 0, 23, 59, 59);
      out.add(WealthPoint(DateTime(end.year, end.month), netWorthAt(end)));
    }
    return out;
  }

  /// Value of each group of assets (no debts), for the split bar.
  Map<String, double> allocation() {
    final out = <String, double>{};
    for (final a in counted.where((a) => !a.kind.isDebt)) {
      out[a.kind.group] = (out[a.kind.group] ?? 0) + a.value;
    }
    if (_policyCash > 0) out['Other assets'] = (out['Other assets'] ?? 0) + _policyCash;
    out.removeWhere((_, v) => v <= 0);
    return out;
  }

  /// Change since [from], by group. Paying debt down counts as growth.
  Map<String, double> changeByGroup(DateTime from) {
    final out = <String, double>{};
    for (final a in counted) {
      final now = a.value;
      final before = a.valueOn(from) ?? 0;
      var d = now - before;
      var key = a.kind.group;
      if (a.kind.isDebt) {
        d = -d;
        key = 'Debts paid down';
      }
      out[key] = (out[key] ?? 0) + d;
    }
    out.removeWhere((_, v) => v.abs() < 0.005);
    return out;
  }

  // ------------------------------------------------------------ editing
  void upsertAccount(Account a) {
    final i = accounts.indexWhere((x) => x.id == a.id);
    if (i < 0) {
      accounts.add(a);
    } else {
      accounts[i] = a;
    }
  }

  void upsertPolicy(Policy p) {
    final i = policies.indexWhere((x) => x.id == p.id);
    if (i < 0) {
      policies.add(p);
    } else {
      policies[i] = p;
    }
  }

  /// Adds (or replaces, if on the same day) a value reading.
  static List<ValuePoint> withReading(
      List<ValuePoint> history, DateTime date, double value) {
    final day = DateTime(date.year, date.month, date.day);
    final out = history
        .where((p) =>
            !(p.date.year == day.year &&
                p.date.month == day.month &&
                p.date.day == day.day))
        .toList()
      ..add(ValuePoint(day, value))
      ..sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  void clear() {
    accounts.clear();
    policies.clear();
  }

  // ------------------------------------------------------------ saving
  Map<String, dynamic> toJson() => {
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'policies': policies.map((e) => e.toJson()).toList(),
      };

  void loadJson(Map<String, dynamic> j) {
    clear();
    for (final e in (j['accounts'] as List? ?? [])) {
      accounts.add(Account.fromJson(Map<String, dynamic>.from(e as Map)));
    }
    for (final e in (j['policies'] as List? ?? [])) {
      policies.add(Policy.fromJson(Map<String, dynamic>.from(e as Map)));
    }
  }

  /// Merges another copy in; the newer edit of each item wins. Returns true
  /// if anything here changed.
  bool merge(Map<String, dynamic> j) {
    var changed = false;
    for (final e in (j['accounts'] as List? ?? [])) {
      final r = Account.fromJson(Map<String, dynamic>.from(e as Map));
      final i = accounts.indexWhere((x) => x.id == r.id);
      if (i < 0) {
        accounts.add(r);
        changed = true;
      } else if (r.updatedAt > accounts[i].updatedAt) {
        accounts[i] = r;
        changed = true;
      }
    }
    for (final e in (j['policies'] as List? ?? [])) {
      final r = Policy.fromJson(Map<String, dynamic>.from(e as Map));
      final i = policies.indexWhere((x) => x.id == r.id);
      if (i < 0) {
        policies.add(r);
        changed = true;
      } else if (r.updatedAt > policies[i].updatedAt) {
        policies[i] = r;
        changed = true;
      }
    }
    return changed;
  }
}
