import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../store.dart';

class MonthBar extends StatelessWidget {
  final AppStore store;
  const MonthBar({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous month',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => store.shiftMonth(-1),
        ),
        SizedBox(
          width: 150,
          child: Text(
            DateFormat('MMMM yyyy').format(store.month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          icon: const Icon(Icons.chevron_right),
          onPressed: store.isCurrentMonth ? null : () => store.shiftMonth(1),
        ),
      ],
    );
  }
}

/// Previous / next control for the Budgets tab's month, quarter or year.
class PeriodBar extends StatelessWidget {
  final AppStore store;
  const PeriodBar({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => store.shiftBudget(-1),
        ),
        SizedBox(
          width: 150,
          child: Text(
            AppStore.periodLabel(store.budgetPeriod, store.budgetAnchor),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Next',
          icon: const Icon(Icons.chevron_right),
          onPressed: store.canBudgetNext ? () => store.shiftBudget(1) : null,
        ),
      ],
    );
  }
}
