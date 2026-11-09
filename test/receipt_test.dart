import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/models.dart';
import 'package:pocket_ledger/receipt_scan.dart';

void main() {
  itemTests();
  packTests();
  test('reads merchant, date and total from receipt text', () {
    const text = 'TESCO EXPRESS\n12 High Street\n05/11/2026 18:42\nMilk 1.45\nBread 1.10\nSUBTOTAL 2.55\nTOTAL 2.55\nCARD 2.55';
    final r = parseReceiptText(text);
    expect(r.total, 2.55);
    expect(r.date, DateTime(2026, 11, 5));
    expect(r.merchant, 'Tesco Express');
  });

  test('falls back to the largest amount and named months', () {
    final r = parseReceiptText('Costa Coffee\n3 Nov 2026\nLatte 3.40\nCake 3.10');
    expect(r.total, 3.40);
    expect(r.date, DateTime(2026, 11, 3));
  });
}

void itemTests() {
  test('reads item lines and skips totals', () {
    final items = parseReceiptItems('TESCO\nMilk 2L 1.45\n2 x Bread 2.20\nSUBTOTAL 3.65\nTOTAL 3.65\nCARD 3.65');
    expect(items.length, 2);
    expect(items.first.$1, 'Milk 2l');
    expect(items.first.$2, 1.45);
  });
}

void packTests() {
  test('pack sizes and unit prices', () {
    expect(guessPack('Basmati Rice 5kg'), (5.0, 'kg'));
    expect(guessPack('Milk 500ml')!.$2, 'ml');
    final p = PricePoint(id: '1', item: 'Rice 500g', price: 1.5, shop: 'A', date: DateTime(2026), qty: 500, unit: 'g');
    expect(p.perBase, closeTo(3.0, 0.001));
    expect(p.per100, closeTo(0.3, 0.001));
    expect(PricePoint(id: '2', item: 'Rice 1kg', price: 2.5, shop: 'B', date: DateTime(2026), qty: 1, unit: 'kg').key, p.key);
  });
}
