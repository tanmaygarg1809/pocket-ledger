import 'models.dart';
import 'store.dart';

class SpendBucket {
  final String label;
  final double spent;
  const SpendBucket(this.label, this.spent);
}

class Tip {
  final String title;
  final String body;
  final String? saving; // e.g. "£80 a month"
  final bool good;
  const Tip(this.title, this.body, {this.saving, this.good = false});
}

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Charts and rule-based tips for the Budgets tab. Everything here is
/// calculated on the phone from your own entries.
extension BudgetTips on AppStore {
  double _consumed(DateTime start, DateTime end) {
    var t = 0.0;
    for (final x in all) {
      if (x.type != TxType.expense || isSaving(x.category)) continue;
      if (x.date.isBefore(start) || !x.date.isBefore(end)) continue;
      t += x.amount;
    }
    return t;
  }

  /// Total limit across spending categories for the period.
  double totalLimit(BudgetPeriod p) {
    var t = 0.0;
    budgetsFor(p).forEach((k, v) {
      if (!isSaving(k)) t += v;
    });
    return t;
  }

  /// Bars for the chart: weeks (month), months (quarter, year).
  /// [budgetPerBar] is where the dashed budget line sits.
  ({List<SpendBucket> bars, double budgetPerBar}) spendBuckets(
      BudgetPeriod p, DateTime anchor) {
    final start = AppStore.periodStart(p, anchor);
    final limit = totalLimit(p);
    if (p == BudgetPeriod.month) {
      final days = DateTime(start.year, start.month + 1, 0).day;
      final bars = <SpendBucket>[];
      for (var d = 1; d <= days; d += 7) {
        final from = DateTime(start.year, start.month, d);
        final to = DateTime(start.year, start.month, (d + 7 > days + 1) ? days + 1 : d + 7);
        bars.add(SpendBucket('W${bars.length + 1}', _consumed(from, to)));
      }
      return (bars: bars, budgetPerBar: limit * 7 / days);
    }
    final n = p == BudgetPeriod.quarter ? 3 : 12;
    final bars = <SpendBucket>[];
    for (var i = 0; i < n; i++) {
      final from = DateTime(start.year, start.month + i);
      final to = DateTime(start.year, start.month + i + 1);
      bars.add(SpendBucket(_monthNames[from.month - 1], _consumed(from, to)));
    }
    return (bars: bars, budgetPerBar: limit / n);
  }

  /// Plain-language ways to bring spending down, from your own numbers.
  List<Tip> tips(BudgetPeriod p, DateTime anchor) {
    final out = <Tip>[];
    final spent = spentByCategory(p, anchor)
      ..removeWhere((k, _) => isSaving(k));
    final limits = budgetsFor(p)..removeWhere((k, _) => isSaving(k));
    final monthsIn = p == BudgetPeriod.month ? 1 : (p == BudgetPeriod.quarter ? 3 : 12);
    final total = spent.values.fold(0.0, (a, b) => a + b);
    final limit = limits.values.fold(0.0, (a, b) => a + b);

    // 1. Categories over their limit, worst first.
    final over = <MapEntry<String, double>>[];
    limits.forEach((k, v) {
      final s = spent[k] ?? 0;
      if (s > v) over.add(MapEntry(k, s - v));
    });
    over.sort((a, b) => b.value.compareTo(a.value));
    for (final e in over.take(2)) {
      final pct = ((spent[e.key]! / limits[e.key]! - 1) * 100).round();
      out.add(Tip(
        '${e.key} is $pct% over budget',
        'You spent ${money(spent[e.key]!)} against a limit of ${money(limits[e.key]!)}. '
            'Bringing it back to budget would free up ${money(e.value)}.',
        saving: '${money(e.value / monthsIn)} a month',
      ));
    }

    // 2. Big spending with no limit set.
    final unbudgeted = spent.entries
        .where((e) => !limits.containsKey(e.key) && total > 0 && e.value / total > 0.1)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in unbudgeted.take(1)) {
      out.add(Tip(
        '${e.key} has no limit',
        '${money(e.value)} went on ${e.key}, ${(e.value / total * 100).round()}% of your spending. '
            'Set a limit below to keep an eye on it.',
      ));
    }

    // 3. Compared with the period before.
    final prevAnchor = DateTime(anchor.year, anchor.month - monthsIn);
    final prev = _consumed(AppStore.periodStart(p, prevAnchor), AppStore.periodEnd(p, prevAnchor));
    if (prev > 0 && total > prev * 1.15) {
      final pct = ((total / prev - 1) * 100).round();
      out.add(Tip(
        'Spending is up $pct% on the last ${p == BudgetPeriod.month ? 'month' : (p == BudgetPeriod.quarter ? 'quarter' : 'year')}',
        'It was ${money(prev)} before and is ${money(total)} now. Look at the biggest categories first.',
      ));
    }

    // 4. Good news.
    if (limit > 0 && total <= limit) {
      out.add(Tip(
        'You are within budget',
        '${money(limit - total)} of your ${money(limit)} budget is still unspent.',
        good: true,
      ));
    }
    if (limit == 0) {
      out.add(const Tip(
        'Set a few limits to get tips',
        'Tap a category below and give it a limit. Tips are worked out against your limits.',
      ));
    }
    return out;
  }
}
