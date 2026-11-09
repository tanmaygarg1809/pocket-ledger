import 'package:flutter/material.dart' hide Category;

enum TxType { expense, income }

enum BudgetPeriod { month, quarter, year }

/// Icons and colors a category can use (stored by index so they sync and
/// stay tree-shakeable).
const categoryIcons = <IconData>[
  Icons.restaurant, Icons.shopping_basket, Icons.directions_bus, Icons.receipt_long,
  Icons.shopping_bag, Icons.favorite, Icons.movie, Icons.school, Icons.flight,
  Icons.category, Icons.work, Icons.laptop_mac, Icons.trending_up,
  Icons.card_giftcard, Icons.savings, Icons.home, Icons.directions_car,
  Icons.local_gas_station, Icons.bolt, Icons.water_drop, Icons.wifi,
  Icons.phone_android, Icons.child_care, Icons.pets, Icons.fitness_center,
  Icons.local_parking, Icons.account_balance, Icons.sell, Icons.coffee,
  Icons.beach_access,
];

const categoryColors = <Color>[
  Color(0xFFEF6C00), Color(0xFF7CB342), Color(0xFF1E88E5), Color(0xFF8E24AA),
  Color(0xFFD81B60), Color(0xFFE53935), Color(0xFF00ACC1), Color(0xFF5E35B1),
  Color(0xFF00897B), Color(0xFF757575), Color(0xFF2E7D32), Color(0xFF1565C0),
  Color(0xFFAD1457), Color(0xFF6D4C41),
];

/// A user-editable category. [group] is a free-text heading used for
/// subtotals (e.g. "Fixed bills", "Car", "Day to day").
class Category {
  final String name;
  final int icon; // index into categoryIcons
  final int color; // index into categoryColors
  final String group;
  final TxType type;

  /// Money moved into savings/investments: counted separately from spending.
  final bool saving;

  const Category({
    required this.name,
    required this.icon,
    required this.color,
    required this.group,
    required this.type,
    this.saving = false,
  });

  IconData get iconData => categoryIcons[icon % categoryIcons.length];
  Color get colorValue => categoryColors[color % categoryColors.length];

  Category copyWith(
          {String? name, int? icon, int? color, String? group, bool? saving}) =>
      Category(
        name: name ?? this.name,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        group: group ?? this.group,
        type: type,
        saving: saving ?? this.saving,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'icon': icon,
        'color': color,
        'group': group,
        'type': type.name,
        'saving': saving,
      };

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        name: j['name'] as String,
        icon: (j['icon'] as num?)?.toInt() ?? 9,
        color: (j['color'] as num?)?.toInt() ?? 9,
        group: (j['group'] as String?) ?? 'Other',
        type: j['type'] == 'income' ? TxType.income : TxType.expense,
        saving: j['saving'] == true,
      );
}

/// Starter set for new users; fully editable in Settings > Categories.
List<Category> defaultCategories() => const [
      Category(name: 'Rent & Bills', icon: 3, color: 3, group: 'Fixed bills', type: TxType.expense),
      Category(name: 'Food', icon: 0, color: 0, group: 'Day to day', type: TxType.expense),
      Category(name: 'Groceries', icon: 1, color: 1, group: 'Day to day', type: TxType.expense),
      Category(name: 'Health', icon: 5, color: 5, group: 'Day to day', type: TxType.expense),
      Category(name: 'Shopping', icon: 4, color: 4, group: 'Day to day', type: TxType.expense),
      Category(name: 'Transport', icon: 2, color: 2, group: 'Getting around', type: TxType.expense),
      Category(name: 'Travel', icon: 8, color: 8, group: 'Getting around', type: TxType.expense),
      Category(name: 'Entertainment', icon: 6, color: 6, group: 'Fun & learning', type: TxType.expense),
      Category(name: 'Education', icon: 7, color: 7, group: 'Fun & learning', type: TxType.expense),
      Category(name: 'Savings', icon: 14, color: 10, group: 'Savings & investing', type: TxType.expense, saving: true),
      Category(name: 'Other', icon: 9, color: 9, group: 'Other', type: TxType.expense),
      Category(name: 'Salary', icon: 10, color: 10, group: 'Income', type: TxType.income),
      Category(name: 'Freelance', icon: 11, color: 8, group: 'Income', type: TxType.income),
      Category(name: 'Investments', icon: 12, color: 11, group: 'Income', type: TxType.income),
      Category(name: 'Gift', icon: 13, color: 12, group: 'Income', type: TxType.income),
      Category(name: 'Other income', icon: 14, color: 9, group: 'Income', type: TxType.income),
    ];

class Txn {
  final String id;
  final TxType type;
  final double amount;
  final String category;
  final String note;
  final DateTime date;

  /// Who it was paid to / received from (e.g. Tesco, Deliveroo).
  final String payee;

  /// Last-modified time (ms since epoch). Newest wins when syncing.
  final int updatedAt;

  /// Deleted entries are kept as tombstones so deletes sync too.
  final bool deleted;

  /// Splitwise follow-up: 0 = none, 1 = still to split, 2 = done.
  final int split;

  /// Attached receipts/documents (file names inside the app's attachments folder).
  final List<String> files;

  const Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    this.payee = '',
    this.updatedAt = 0,
    this.deleted = false,
    this.split = 0,
    this.files = const [],
  });

  Txn copyWith({int? updatedAt, bool? deleted, String? category, int? split, List<String>? files}) => Txn(
        id: id,
        type: type,
        amount: amount,
        category: category ?? this.category,
        note: note,
        date: date,
        payee: payee,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        split: split ?? this.split,
        files: files ?? this.files,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date.toIso8601String(),
        'payee': payee,
        'u': updatedAt,
        'd': deleted,
        's': split,
        'f': files,
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        type: j['type'] == 'income' ? TxType.income : TxType.expense,
        amount: (j['amount'] as num).toDouble(),
        category: j['category'] as String,
        note: (j['note'] as String?) ?? '',
        date: DateTime.parse(j['date'] as String),
        payee: (j['payee'] as String?) ?? '',
        updatedAt: (j['u'] as num?)?.toInt() ?? 0,
        deleted: j['d'] == true,
        split: (j['s'] as num?)?.toInt() ?? 0,
        files: ((j['f'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

/// A monthly repeating income/expense (rent, subscription, salary...).
class RecurringRule {
  final String id;
  final TxType type;
  final double amount;
  final String category;
  final String note;

  /// Day of month, 1..28 (28 max so every month has it).
  final int day;

  /// First month it applies, as 'yyyy-MM'.
  final String startMonth;
  final bool active;

  const RecurringRule({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.note,
    required this.day,
    required this.startMonth,
    this.active = true,
  });

  RecurringRule copyWith({bool? active, String? category}) => RecurringRule(
        id: id,
        type: type,
        amount: amount,
        category: category ?? this.category,
        note: note,
        day: day,
        startMonth: startMonth,
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'category': category,
        'note': note,
        'day': day,
        'startMonth': startMonth,
        'active': active,
      };

  factory RecurringRule.fromJson(Map<String, dynamic> j) => RecurringRule(
        id: j['id'] as String,
        type: j['type'] == 'income' ? TxType.income : TxType.expense,
        amount: (j['amount'] as num).toDouble(),
        category: j['category'] as String,
        note: (j['note'] as String?) ?? '',
        day: ((j['day'] as num?)?.toInt() ?? 1).clamp(1, 28),
        startMonth: j['startMonth'] as String,
        active: j['active'] != false,
      );
}

/// A savings goal. [saved] is what you have put towards it so far.
class Goal {
  final String id;
  final String name;
  final double target;
  final double saved;
  final DateTime? deadline;
  final int icon; // index into categoryIcons

  const Goal({
    required this.id,
    required this.name,
    required this.target,
    this.saved = 0,
    this.deadline,
    this.icon = 14,
  });

  double get fraction => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0).toDouble();
  bool get reached => target > 0 && saved >= target;

  /// Milestones passed: 25, 50, 75, 100 (percent).
  List<int> get milestones => [
        for (final p in const [25, 50, 75, 100])
          if (target > 0 && saved * 100 >= target * p) p
      ];

  Goal copyWith({String? name, double? target, double? saved, DateTime? deadline, bool clearDeadline = false, int? icon}) => Goal(
        id: id,
        name: name ?? this.name,
        target: target ?? this.target,
        saved: saved ?? this.saved,
        deadline: clearDeadline ? null : (deadline ?? this.deadline),
        icon: icon ?? this.icon,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'saved': saved,
        'deadline': deadline?.toIso8601String(),
        'icon': icon,
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        name: j['name'] as String,
        target: (j['target'] as num).toDouble(),
        saved: (j['saved'] as num?)?.toDouble() ?? 0,
        deadline: j['deadline'] == null ? null : DateTime.tryParse(j['deadline'] as String),
        icon: (j['icon'] as num?)?.toInt() ?? 14,
      );
}

/// One price seen for an item at a shop (from a receipt, a shelf label or typed in).
class PricePoint {
  final String id;
  final String item;
  final double price;
  final String shop;
  final DateTime date;

  /// Pack size: [qty] in [unit] ('g', 'kg', 'ml', 'l', 'pc'); null when unknown.
  final double? qty;
  final String unit;

  /// Branch or area, e.g. "Hounslow".
  final String place;

  /// Photo of the item or shelf label (file name in the attachments folder).
  final String? photo;

  const PricePoint({
    required this.id,
    required this.item,
    required this.price,
    required this.shop,
    required this.date,
    this.qty,
    this.unit = '',
    this.place = '',
    this.photo,
  });

  /// Same product, whatever the capitalisation or spacing, ignoring the pack size.
  String get key => item
      .toLowerCase()
      .replaceAll(RegExp(r'\b\d+(\.\d+)?\s*(kg|g|ml|l|ltr|litres?|pack|pk|pcs?|x)\b'), '')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// 'kg' (weight), 'l' (volume), 'each' (pieces) or '' when the pack size is unknown.
  String get family {
    if (qty == null || qty! <= 0) return '';
    if (unit == 'g' || unit == 'kg') return 'kg';
    if (unit == 'ml' || unit == 'l') return 'l';
    if (unit == 'pc') return 'each';
    return '';
  }

  /// Price per kg, per litre or per piece.
  double? get perBase {
    if (family.isEmpty) return null;
    final base = (unit == 'g' || unit == 'ml') ? qty! / 1000 : qty!;
    return price / base;
  }

  /// Price per 100 g or per 100 ml, for small packs.
  double? get per100 {
    final b = perBase;
    if (b == null || family == 'each') return null;
    return b / 10;
  }

  String get packLabel {
    if (family.isEmpty) return '';
    final q = qty! == qty!.roundToDouble() ? qty!.toStringAsFixed(0) : qty!.toString();
    return unit == 'pc' ? '$q pack' : '$q$unit';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item': item,
        'price': price,
        'shop': shop,
        'date': date.toIso8601String(),
        'qty': qty,
        'unit': unit,
        'place': place,
        'photo': photo,
      };

  factory PricePoint.fromJson(Map<String, dynamic> j) => PricePoint(
        id: j['id'] as String,
        item: j['item'] as String,
        price: (j['price'] as num).toDouble(),
        shop: (j['shop'] as String?) ?? '',
        date: DateTime.tryParse((j['date'] as String?) ?? '') ?? DateTime.now(),
        qty: (j['qty'] as num?)?.toDouble(),
        unit: (j['unit'] as String?) ?? '',
        place: (j['place'] as String?) ?? '',
        photo: j['photo'] as String?,
      );
}

/// Finds a pack size in an item name: "Milk 2L", "Flour 1.5kg", "Cheese 400g", "Eggs 6 pack".
(double, String)? guessPack(String name) {
  final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*(kg|g|ml|cl|ltr|litres?|l|pack|pk|pcs?|x)\b', caseSensitive: false)
      .firstMatch(name);
  if (m == null) return null;
  var q = double.tryParse(m.group(1)!.replaceAll(',', '.'));
  if (q == null || q <= 0) return null;
  switch (m.group(2)!.toLowerCase()) {
    case 'kg':
      return (q, 'kg');
    case 'g':
      return (q, 'g');
    case 'ml':
      return (q, 'ml');
    case 'cl':
      return (q * 10, 'ml');
    case 'l':
    case 'ltr':
    case 'litre':
    case 'litres':
      return (q, 'l');
    default:
      return (q, 'pc');
  }
}
