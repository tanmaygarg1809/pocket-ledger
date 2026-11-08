import 'package:flutter/services.dart';

const _channel = MethodChannel('pocket_ledger/widget');

/// Asks Android to redraw the home-screen widget (e.g. "Spent today").
/// Safe to call anywhere: failures (tests, non-Android) are ignored.
Future<void> refreshWidget() async {
  try {
    await _channel.invokeMethod<void>('refresh');
  } catch (_) {}
}
