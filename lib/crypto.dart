import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypts what the app keeps on the phone (AES-256-GCM). The key is created
/// on first run and held in the Android Keystore through secure storage, so
/// other apps and anyone reading the app's files only see scrambled text.
/// Until [init] runs (for example in unit tests) values are stored as they are.
class Crypto {
  static enc.Key? _key;
  static bool get ready => _key != null;

  static Future<void> init() async {
    try {
      const s = FlutterSecureStorage();
      var k = await s.read(key: 'pl_key_v1');
      if (k == null) {
        final r = Random.secure();
        k = base64Encode(List<int>.generate(32, (_) => r.nextInt(256)));
        await s.write(key: 'pl_key_v1', value: k);
      }
      _key = enc.Key(base64Decode(k));
    } catch (_) {
      _key = null;
    }
  }

  /// For tests: use a fixed key without Android secure storage.
  static void useKeyForTest(List<int> bytes) => _key = enc.Key(Uint8List.fromList(bytes));

  static bool isSealed(String s) => s.startsWith('enc1:');

  static String seal(String plain) {
    final key = _key;
    if (key == null) return plain;
    final iv = enc.IV.fromSecureRandom(12);
    final e = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    return 'enc1:${iv.base64}:${e.encrypt(plain, iv: iv).base64}';
  }

  /// Plain text back, or null if it cannot be read (wrong or missing key).
  static String? open(String s) {
    if (!isSealed(s)) return s;
    final key = _key;
    if (key == null) return null;
    try {
      final parts = s.split(':');
      final e = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      return e.decrypt64(parts[2], iv: enc.IV.fromBase64(parts[1]));
    } catch (_) {
      return null;
    }
  }
}
