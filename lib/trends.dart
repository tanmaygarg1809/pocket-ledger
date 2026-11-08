import 'models.dart';
import 'store.dart';

typedef Trend = ({double now, double before, double? pct});

/// Spending trends and the week view. "Spending" excludes money moved to
/// savings, and refunds reduce it.
extension Trends on AppStore {
  double spentBetween(DateTime start, DateTime end) {
    var t = 0.0;
    for (final x in all) {
      if (x.type != TxType.expense || isSaving(x.category)) continue;
      if (x.date.isBefore(start) || !x.date.isBefore(end)) continue;
      t += x.amount;
    }
    return t;
  }

  /// This month against the previous month. For the current month, only
  /// the days so far are compared, so it is a fair like-for-like.
  Trend monthTrend(DateTime month) {
    final start = DateTime(month.year, month.month);
    final n = DateTime.now();
    final current = month.year == n.year && month.month == n.month;
    final days = current ? n.day : DateTime(month.year, month.month + 1, 0).day;
    final now = spentBetween(start, DateTime(month.year, month.month, days + 1));
    final pStart = DateTime(month.year, month.month - 1);
    final pDays = DateTime(pStart.year, pStart.month + 1, 0).day;
    final take = days > pDays ? pDays : days;
    final before = spentBetween(pStart, DateTime(pStart.year, pStart.month, take + 1));
    return (now: now, before: before, pct: before > 0 ? (now - before) / before * 100 : null);
  }

  /// Spending per month for the last [n] months up to [month] (for the sparkline).
  List<double> monthlySpendSeries(DateTime month, {int n = 6}) {
    return [
      for (var i = n - 1; i >= 0; i--)
        spentBetween(DateTime(month.year, month.month - i), DateTime(month.year, month.month - i + 1)),
    ];
  }

  /// Spending for each day, Monday to Sunday, of the week starting [weekStart].
  List<double> daySpend(DateTime weekStart) {
    return [
      for (var i = 0; i < 7; i++)
        spentBetween(DateTime(weekStart.year, weekStart.month, weekStart.day + i),
            DateTime(weekStart.year, weekStart.month, weekStart.day + i + 1)),
    ];
  }

  Map<String, double> weekByCategory(DateTime weekStart) {
    final end = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
    final out = <String, double>{};
    for (final x in all) {
      if (x.type != TxType.expense || isSaving(x.category)) continue;
      if (x.date.isBefore(weekStart) || !x.date.isBefore(end)) continue;
      out[x.category] = (out[x.category] ?? 0) + x.amount;
    }
    return out;
  }

  /// This week against the previous week (like-for-like days if the week
  /// is still in progress).
  Trend weekTrend(DateTime weekStart) {
    final n = DateTime.now();
    final isCurrent = weekStartOf(n) == weekStart;
    final days = isCurrent ? n.weekday : 7;
    final now = spentBetween(weekStart, DateTime(weekStart.year, weekStart.month, weekStart.day + days));
    final pStart = DateTime(weekStart.year, weekStart.month, weekStart.day - 7);
    final before = spentBetween(pStart, DateTime(pStart.year, pStart.month, pStart.day + days));
    return (now: now, before: before, pct: before > 0 ? (now - before) / before * 100 : null);
  }
}
