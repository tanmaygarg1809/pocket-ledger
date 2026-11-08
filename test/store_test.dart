import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/models.dart';
import 'package:pocket_ledger/excel_backup.dart';
import 'package:pocket_ledger/store.dart';
import 'package:pocket_ledger/wealth.dart';
import 'package:pocket_ledger/trends.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> fresh() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppStore();
  await s.load();
  return s;
}

Txn tx(String id, double amt, String cat,
        {TxType type = TxType.expense, DateTime? date, int u = 0}) =>
    Txn(
        id: id,
        type: type,
        amount: amt,
        category: cat,
        note: '',
        date: date ?? DateTime.now(),
        updatedAt: u);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('totals, budgets and deletes', () async {
    final s = await fresh();
    await s.upsert(tx('1', 1000, 'Salary', type: TxType.income));
    await s.upsert(tx('2', 40, 'Food'));
    await s.upsert(tx('3', 10, 'Food'));
    expect(s.monthIncome, 1000);
    expect(s.monthExpense, 50);
    await s.setBudget('Food', 100);
    expect(s.budgets['Food'], 100);
    await s.setBudget('Food', null);
    expect(s.budgets.containsKey('Food'), false);
    await s.remove('3');
    expect(s.monthExpense, 40);
    // delete is kept as a tombstone so it can sync
    expect(s.dirtyTxns.any((t) => t.id == '3' && t.deleted), true);
  });

  test('newest edit wins when merging', () async {
    final s = await fresh();
    await s.upsert(tx('a', 10, 'Food'));
    final local = s.all.first;
    final older = tx('a', 99, 'Food', u: local.updatedAt - 1000);
    final newer = tx('a', 55, 'Food', u: local.updatedAt + 1000);
    expect(await s.mergeTxns([older]), 0);
    expect(s.all.first.amount, 10);
    expect(await s.mergeTxns([newer]), 1);
    expect(s.all.first.amount, 55);
  });

  test('recurring items are created once, with stable ids', () async {
    final s = await fresh();
    final now = DateTime(2026, 11, 10);
    await s.upsertRule(const RecurringRule(
        id: 'r1',
        type: TxType.expense,
        amount: 500,
        category: 'Rent & Bills',
        note: 'Rent',
        day: 1,
        startMonth: '2026-09'));
    s.materializeRecurring(now);
    s.materializeRecurring(now); // second run adds nothing
    final ids = s.all.where((t) => t.id.startsWith('rec_r1_')).map((t) => t.id).toList();
    expect(ids.toSet(), {'rec_r1_202609', 'rec_r1_202610', 'rec_r1_202611'});
    expect(ids.length, 3); // no duplicates
  });

  test('safe to spend', () async {
    final s = await fresh();
    expect(s.safeToSpend, isNull);
    await s.setBudget('Food', 3100);
    final now = DateTime.now();
    final daysLeft = DateTime(now.year, now.month + 1, 0).day - now.day + 1;
    await s.upsert(tx('x', 100, 'Food'));
    final r = s.safeToSpend!;
    expect(r.daysLeft, daysLeft);
    expect(r.remainingMonth, 3000);
    expect(r.dailyAllowance, closeTo(3100 / daysLeft, 0.001));
    expect(r.leftToday, closeTo(3100 / daysLeft - 100, 0.001));
  });

  test('backup round trip', () async {
    final a = await fresh();
    await a.upsert(tx('b1', 12, 'Food'));
    await a.setBudget('Food', 200);
    final json = a.backupJson();
    final b = await fresh();
    final msg = await b.restoreBackup(jsonEncode(json));
    expect(msg.startsWith('Restored 1'), true);
    expect(b.budgets['Food'], 200);
    expect(await b.restoreBackup('nonsense'), 'Could not read this file.');
  });

  test('quarterly and yearly budgets are separate from monthly', () async {
    final s = await fresh();
    await s.setBudget('Food', 100);
    await s.setBudget('Food', 280, period: BudgetPeriod.quarter);
    await s.setBudget('Food', 1000, period: BudgetPeriod.year);
    expect(s.budgets['Food'], 100);
    expect(s.budgetsFor(BudgetPeriod.quarter)['Food'], 280);
    expect(s.budgetsFor(BudgetPeriod.year)['Food'], 1000);
    await s.upsert(tx('q1', 60, 'Food'));
    final q = s.budgetProgress(BudgetPeriod.quarter)!;
    expect(q.limit, 280);
    expect(q.spent, 60);
    expect(AppStore.periodLabel(BudgetPeriod.quarter, DateTime(2026, 11)), 'Q4 2026');
    expect(AppStore.periodStart(BudgetPeriod.quarter, DateTime(2026, 11)),
        DateTime(2026, 10));
    await s.setBudget('Food', null, period: BudgetPeriod.quarter);
    expect(s.budgetsFor(BudgetPeriod.quarter).isEmpty, true);
    expect(s.budgets['Food'], 100); // monthly untouched
  });

  test('savings are not spending; refunds net off a category', () async {
    final s = await fresh();
    await s.upsert(tx('i', 3000, 'Salary', type: TxType.income));
    await s.upsert(tx('e', 100, 'Food'));
    await s.upsert(tx('r', -30, 'Food')); // refund
    await s.upsert(tx('s', 500, 'Savings')); // saving category by default
    expect(s.monthExpense, 70);
    expect(s.monthSaving, 500);
    expect(s.monthTrueNet, 2930);
    final y = s.yearTotals(DateTime.now().year);
    expect(y.consumption, 70);
    expect(y.saving, 500);
    expect(y.trueNet, 2930);
  });

  test('ledger, insights and payee memory', () async {
    final s = await fresh();
    await s.setBudget('Food', 10);
    await s.upsert(Txn(
        id: 'a', type: TxType.expense, amount: 250, category: 'Food',
        payee: 'Tesco', note: '', date: DateTime.now()));
    final rows = s.ledger(DateTime.now().year);
    expect(rows.first.category, 'Food');
    expect(rows.first.hasBudget, true);
    expect(rows.first.diff, greaterThan(0));
    expect(s.insights(DateTime.now().year).first.title.contains('Food'), true);
    // learns that Tesco is Food
    expect(s.categoryForPayee('tesco', TxType.expense), 'Food');
    expect(s.payeeSuggestions('tes').first, 'Tesco');
  });

  test('renaming a category moves entries and budgets', () async {
    final s = await fresh();
    await s.setBudget('Food', 100);
    await s.setBudget('Food', 900, period: BudgetPeriod.year);
    await s.upsert(tx('f', 20, 'Food'));
    final food = s.categoryByName('Food');
    expect(await s.saveCategory(food.copyWith(name: 'Eating Out'), oldName: 'Food'), isNull);
    expect(s.all.first.category, 'Eating Out');
    expect(s.budgets['Eating Out'], 100);
    expect(s.budgetsFor(BudgetPeriod.year)['Eating Out'], 900);
    expect(await s.saveCategory(food.copyWith(name: 'groceries')), isNotNull); // clash
  });

  test('sorting Other entries by payee', () async {
    final s = await fresh();
    for (final id in ['p1', 'p2']) {
      await s.upsert(Txn(
          id: id, type: TxType.expense, amount: 5, category: 'Other',
          payee: 'Boots', note: '', date: DateTime.now()));
    }
    expect(s.needsReview.length, 2);
    final n = await s.recategorize(s.needsReview.first, 'Health', allFromPayee: true);
    expect(n, 2);
    expect(s.needsReview, isEmpty);
  });

  test('trends: lower than last month, savings excluded, week days', () async {
    final s = await fresh();
    final n = DateTime.now();
    final lastMonth = DateTime(n.year, n.month - 1, 1);
    await s.upsert(tx('p1', 200, 'Food', date: lastMonth));
    await s.upsert(tx('p2', 900, 'Savings', date: lastMonth)); // saving: ignored
    await s.upsert(tx('c1', 50, 'Food', date: DateTime(n.year, n.month, 1)));
    final t = s.monthTrend(DateTime(n.year, n.month));
    expect(t.before, 200);
    expect(t.now, 50);
    expect(t.pct, closeTo(-75, 0.001));
    expect(s.monthlySpendSeries(DateTime(n.year, n.month)).length, 6);

    final ws = weekStartOf(n);
    final days = s.daySpend(ws);
    expect(days.length, 7);
    expect(weekStartOf(DateTime(2026, 11, 8)), DateTime(2026, 11, 2)); // Sunday -> Monday before
  });

  test('Excel backup round trip', () async {
    final a = await fresh();
    await a.upsert(tx('t1', 12.5, 'Food', date: DateTime(2026, 11, 3, 9, 30)));
    await a.upsert(tx('t2', 2400, 'Salary', type: TxType.income, date: DateTime(2026, 11, 1)));
    await a.setBudget('Food', 300);
    await a.setBudget('Food', 900, period: BudgetPeriod.quarter);
    await a.saveAccount(Account(
        id: 'g1',
        kind: AccountKind.gold,
        name: 'Gold coins',
        weight: 50,
        history: [ValuePoint(DateTime(2026, 1, 1), 3000), ValuePoint(DateTime(2026, 11, 1), 3950)]));
    await a.savePolicy(const Policy(id: 'p1', type: 'Life', provider: 'L&G', cover: 250000, premium: 18));

    final bytes = ExcelBackup.build(a)!;
    final b = await fresh();
    final msg = await ExcelBackup.restore(b, bytes);
    expect(msg.contains('Could not'), false);
    expect(b.all.length, 2);
    final t1 = b.all.firstWhere((t) => t.id == 't1');
    expect(t1.amount, 12.5);
    expect(t1.category, 'Food');
    expect(t1.date, DateTime(2026, 11, 3, 9, 30));
    expect(b.budgets['Food'], 300);
    expect(b.budgetsFor(BudgetPeriod.quarter)['Food'], 900);
    expect(b.wealth.byId('g1')!.value, 3950);
    expect(b.wealth.byId('g1')!.history.length, 2);
    expect(b.wealth.byId('g1')!.weight, 50);
    expect(b.wealth.listedPolicies.single.cover, 250000);
  });
}
