import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/crypto.dart';

void main() {
  test('encrypts and decrypts, and scrambles the stored text', () {
    Crypto.useKeyForTest(List<int>.generate(32, (i) => i));
    const secret = '[{"payee":"Tesco","amount":12.5}]';
    final sealed = Crypto.seal(secret);
    expect(sealed.startsWith('enc1:'), true);
    expect(sealed.contains('Tesco'), false);
    expect(Crypto.open(sealed), secret);
    expect(Crypto.open('plain old data'), 'plain old data'); // older unencrypted data still reads
    Crypto.useKeyForTest(List<int>.generate(32, (i) => 255 - i));
    expect(Crypto.open(sealed), null); // wrong key cannot read it
  });
}
