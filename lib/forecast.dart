import 'models.dart';
import 'store.dart';
import 'wealth.dart';

class ForecastEvent {
  final DateTime date;
  final String label;
  final double amount; // + money in, - money out
  const ForecastEvent(this.date, this.label, this.amount);
}

class Forecast {
  final double start;
  final double dailySpend;
  final double salaryGuess;
  final List<double> balances; // balance at the end of day 1..n
  final List<ForecastEvent> events;
  final DateTime? unknownPayMonth;
  const Forecast(this.start, this.dailySpend, this.salaryGuess, this.balances,
      this.events, this.unknownPayMonth);

  double get end => balances.isEmpty ? start : balances.last;
  double get low {
    var m = start;
    for (final b in balances) {
      if (b < m) m = b;
    }
    return m;
  }

  int get lowDay => balances.isEmpty ? 0 : balances.indexOf(balances.reduce((a, b) => a < b ? a : b)) + 1;
}

extension ForecastX on AppStore {
  /// Money in current accounts, savings and cash.
  double get liquidNow => wealth.counted
      .where((a) =>
          a.kind == AccountKind.bank ||
          a.kind == AccountKind.savings ||
          a.kind == AccountKind.cash)
      .fold(0.0, (s, a) => s + a.value);

  /// Typical daily spending that is not covered by a recurring bill.
  double get dailyBaseline {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day - 90);
    final bills = rules.where((r) => r.active && r.type == TxType.expense).map((r) => r.category).toSet();
    var sum = 0.0;
    DateTime? first;
    for (final t in all) {
      if (t.type != TxType.expense || isSaving(t.category) || bills.contains(t.category)) continue;
      if (t.date.isBefore(from) || t.date.isAfter(now)) continue;
      sum += t.amount;
      if (first == null || t.date.isBefore(first)) first = t.date;
    }
    if (first == null) return 0;
    final days = now.difference(first).inDays.clamp(14, 90);
    return sum / days;
  }

  /// Average of your last three salary entries.
  double get salaryGuess {
    final s = all.where((t) => t.type == TxType.income && t.category == 'Salary').toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (s.isEmpty) return 0;
    final top = s.take(3).toList();
    return top.fold(0.0, (a, t) => a + t.amount) / top.length;
  }

  Forecast forecast(int days, {double extraDaily = 0}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(today.year, today.month, today.day + days);
    final events = <ForecastEvent>[];

    final activeRules = rules.where((r) => r.active).toList();
    for (final r in activeRules) {
      final digits = r.startMonth.replaceAll(RegExp(r'[^0-9]'), '');
      final start = digits.length >= 6 ? int.tryParse(digits.substring(0, 6)) ?? 0 : 0;
      for (var i = 0; i <= days ~/ 28 + 1; i++) {
        final m = DateTime(today.year, today.month + i);
        if (m.year * 100 + m.month < start) continue;
        final d = DateTime(m.year, m.month, r.day);
        if (!d.isAfter(today) || d.isAfter(end)) continue;
        final label = r.note.isNotEmpty ? r.note : r.category;
        events.add(ForecastEvent(d, label, r.type == TxType.income ? r.amount : -r.amount));
      }
    }

    final salary = salaryGuess;
    final hasIncomeRule = activeRules.any((r) => r.type == TxType.income);
    DateTime? unknown;
    if (!hasIncomeRule) {
      for (var i = 0; i <= days ~/ 28 + 1; i++) {
        final m = DateTime(today.year, today.month + i);
        final d = payDateFor(m.year, m.month);
        if (d == null) {
          unknown ??= DateTime(m.year, m.month);
          continue;
        }
        if (!d.isAfter(today) || d.isAfter(end)) continue;
        if (salary > 0) events.add(ForecastEvent(d, 'Pay (estimate)', salary));
      }
    }
    events.sort((a, b) => a.date.compareTo(b.date));

    final daily = dailyBaseline + extraDaily;
    var bal = liquidNow;
    final out = <double>[];
    var k = 0;
    for (var i = 1; i <= days; i++) {
      final d = DateTime(today.year, today.month, today.day + i);
      bal -= daily < 0 ? 0 : daily;
      while (k < events.length && !events[k].date.isAfter(d)) {
        bal += events[k].amount;
        k++;
      }
      out.add(bal);
    }
    return Forecast(liquidNow, daily < 0 ? 0 : daily, salary, out, events, unknown);
  }
}
