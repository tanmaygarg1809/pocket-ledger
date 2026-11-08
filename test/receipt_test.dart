import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/receipt_scan.dart';

void main() {
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
