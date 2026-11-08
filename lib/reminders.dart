import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'store.dart';

/// Local (on-phone) reminders before recurring bills and on payday.
class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _plugin.initialize(settings);
    _ready = true;
  }

  /// Asks Android for permission to show notifications (Android 13+).
  static Future<bool> askPermission() async {
    await init();
    final a = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return (await a?.requestNotificationsPermission()) ?? false;
  }

  /// Rebuilds every upcoming reminder from the current recurring bills.
  static Future<void> reschedule(AppStore store) async {
    try {
      await init();
      await _plugin.cancelAll();
      if (!store.remindOn) return;
      final now = DateTime.now();
      final money = store.money;
      var id = 1;
      final df = DateFormat('EEE d MMM');
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'bills',
          'Bill reminders',
          channelDescription: 'Reminders before bills are due and on payday',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );

      Future<void> at(DateTime when, String title, String body) async {
        if (!when.isAfter(now) || id > 60) return;
        await _plugin.zonedSchedule(
          id++,
          title,
          body,
          tz.TZDateTime.from(when, tz.UTC),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }

      for (final r in store.rules.where((r) => r.active && r.type.name == 'expense')) {
        final digits = r.startMonth.replaceAll(RegExp(r'[^0-9]'), '');
        final start = digits.length >= 6 ? int.tryParse(digits.substring(0, 6)) ?? 0 : 0;
        for (var i = 0; i < 3; i++) {
          final m = DateTime(now.year, now.month + i);
          if (m.year * 100 + m.month < start) continue;
          final due = DateTime(m.year, m.month, r.day);
          final remindAt = DateTime(due.year, due.month, due.day - store.remindDays, 9);
          final label = r.note.isNotEmpty ? r.note : r.category;
          await at(remindAt, 'Bill due: $label',
              '${money(r.amount)} due ${store.remindDays == 0 ? 'today' : df.format(due)}');
        }
      }

      final (next, _) = store.nextPay;
      if (next != null) {
        await at(DateTime(next.year, next.month, next.day, 9), 'Payday',
            'Your pay is due today. Check it has arrived.');
      }
    } catch (_) {
      // Reminders are a convenience: never break the app over them.
    }
  }
}
