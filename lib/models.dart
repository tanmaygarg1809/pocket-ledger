import 'package:flutter/material.dart';

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
  });

  Txn copyWith({int? updatedAt, bool? deleted, String? category}) => Txn(
        id: id,
        type: type,
        amount: amount,
        category: category ?? this.category,
        note: note,
        date: date,
        payee: payee,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
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
