import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/wealth.dart';

void main() {
  Account acct(String id, AccountKind k, List<ValuePoint> h, {bool include = true}) =>
      Account(id: id, kind: k, name: id, history: h, include: include, updatedAt: 1);

  test('net worth, debts and history', () {
    final w = Wealth()
      ..upsertAccount(acct('bank', AccountKind.bank, [
        ValuePoint(DateTime(2026, 1, 1), 1000),
        ValuePoint(DateTime(2026, 6, 1), 1500),
      ]))
      ..upsertAccount(acct('loan', AccountKind.loan, [
        ValuePoint(DateTime(2026, 1, 1), 400),
        ValuePoint(DateTime(2026, 6, 1), 300),
      ]))
      ..upsertAccount(acct('hidden', AccountKind.gold,
          [ValuePoint(DateTime(2026, 1, 1), 999)], include: false));
    expect(w.assets, 1500);
    expect(w.debts, 300);
    expect(w.netWorth, 1200);
    expect(w.netWorthAt(DateTime(2026, 2, 1)), 600); // 1000 - 400
    expect(w.netWorthAt(DateTime(2025, 12, 1)), 0); // nothing yet
    final change = w.changeByGroup(DateTime(2026, 2, 1));
    expect(change['Cash & bank'], 500);
    expect(change['Debts paid down'], 100);
    expect(change.containsKey('Gold & valuables'), false);
  });

  test('series has one point per month and ends at net worth', () {
    final w = Wealth()
      ..upsertAccount(acct('bank', AccountKind.bank, [
        ValuePoint(DateTime(2026, 1, 10), 100),
        ValuePoint(DateTime(2026, 3, 10), 300),
      ]));
    final s = w.series(4, now: DateTime(2026, 4, 15));
    expect(s.length, 4);
    expect(s.map((p) => p.value).toList(), [100, 100, 300, 300]); // end Jan, end Feb, end Mar, now
  });

  test('same-day reading replaces, merge keeps newest, tombstones win', () {
    var h = Wealth.withReading([], DateTime(2026, 5, 1, 9), 10);
    h = Wealth.withReading(h, DateTime(2026, 5, 1, 18), 12);
    expect(h.length, 1);
    expect(h.single.value, 12);

    final a = Wealth()..upsertAccount(acct('x', AccountKind.cash, h));
    final b = Wealth()
      ..upsertAccount(acct('x', AccountKind.cash, h).copyWith(deleted: true, updatedAt: 5));
    expect(a.merge(b.toJson()), true);
    expect(a.listed, isEmpty);
    // an older copy does not bring it back
    expect(a.merge(Wealth().toJson()..['accounts'] = [acct('x', AccountKind.cash, h).toJson()]), false);
    expect(a.listed, isEmpty);
  });

  test('policies are not counted unless they have a cash value', () {
    final w = Wealth()
      ..upsertPolicy(const Policy(id: 'p1', type: 'Life', provider: 'L&G', cover: 250000, premium: 18))
      ..upsertPolicy(const Policy(id: 'p2', type: 'Home', provider: 'Aviva', cover: 500000, premium: 31.4, cashValue: 2000));
    expect(w.totalCover, 750000);
    expect(w.netWorth, 2000);
    expect(w.monthlyPremiums, closeTo(49.4, 0.001));
  });

  test('JSON round trip', () {
    final w = Wealth()
      ..upsertAccount(Account(
          id: 'g',
          kind: AccountKind.gold,
          name: 'Coins',
          weight: 50,
          history: [ValuePoint(DateTime(2026, 1, 1), 3000)],
          updatedAt: 9))
      ..upsertPolicy(Policy(id: 'p', type: 'Car', provider: 'X', renewal: DateTime(2027, 3, 2), updatedAt: 3));
    final w2 = Wealth()..loadJson(w.toJson());
    expect(w2.byId('g')!.weight, 50);
    expect(w2.byId('g')!.value, 3000);
    expect(w2.listedPolicies.single.renewal, DateTime(2027, 3, 2));
  });

  test('family: per person and joint, group total', () {
    final w = Wealth()
      ..upsertMember(const Member(id: 'wife', name: 'Asha', updatedAt: 1))
      ..upsertAccount(Account(
          id: 'a1', kind: AccountKind.bank, name: 'Mine', owner: 'me',
          history: [ValuePoint(DateTime(2026, 1, 1), 1000)], updatedAt: 1))
      ..upsertAccount(Account(
          id: 'a2', kind: AccountKind.savings, name: 'Hers', owner: 'wife',
          history: [ValuePoint(DateTime(2026, 1, 1), 2000)], updatedAt: 1))
      ..upsertAccount(Account(
          id: 'a3', kind: AccountKind.loan, name: 'Mortgage', owner: Wealth.joint,
          history: [ValuePoint(DateTime(2026, 1, 1), 500)], updatedAt: 1));
    expect(w.people.map((m) => m.name).toList(), ['Me', 'Asha']);
    expect(w.hasFamily, true);
    expect(w.netWorthOf('me'), 1000);
    expect(w.netWorthOf('wife'), 2000);
    expect(w.netWorthOf(Wealth.joint), -500);
    expect(w.netWorthOf(null), 2500);
    expect(w.ownerName('wife'), 'Asha');
    expect(w.series(2, now: DateTime(2026, 2, 1), owner: 'wife').last.value, 2000);
    expect(w.allocation(owner: 'wife').keys.toList(), ['Cash & bank']);
    final w2 = Wealth()..loadJson(w.toJson());
    expect(w2.people.length, 2);
    expect(w2.byId('a2')!.owner, 'wife');
  });
}
