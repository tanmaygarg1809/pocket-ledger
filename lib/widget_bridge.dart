import 'package:flutter/services.dart';

const _channel = MethodChannel('pocket_ledger/widget');

/// Asks Android to redraw the home-screen widget (e.g. "Spent today").
/// Safe to call anywhere: failures (tests, non-Android) are ignored.
Future<void> refreshWidget() async {
  try {
    await _channel.invokeMethod<void>('refresh');
  } catch (_) {}
}

/// The category picked by a widget button, if the popup was opened by one.
Future<String?> widgetInitialCategory() async {
  try {
    return await _channel.invokeMethod<String>('initialCategory');
  } catch (_) {
    return null;
  }
}
