import 'package:flutter/material.dart';

/// Light, fresh colours: teal for the app, coral for actions, gold and green as accents.
class AppTheme {
  static const teal = Color(0xFF0A8A7C);
  static const coral = Color(0xFFFF6B5E);
  static const gold = Color(0xFFF5B83D);
  static const green = Color(0xFF2EAD6B);
  static const ink = Color(0xFF1B2B2A);

  static ThemeData light() {
    final base = ColorScheme.fromSeed(seedColor: teal, brightness: Brightness.light);
    final cs = base.copyWith(
      primary: teal,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD6F3EE),
      onPrimaryContainer: const Color(0xFF0B3B35),
      secondary: coral,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFFF0E4),
      onSecondaryContainer: const Color(0xFF5A3410),
      tertiary: gold,
      surface: Colors.white,
      onSurface: ink,
    );
    return _build(cs, Colors.white);
  }

  static ThemeData dark() {
    final cs = ColorScheme.fromSeed(seedColor: teal, brightness: Brightness.dark);
    return _build(cs, cs.surface);
  }

  static ThemeData _build(ColorScheme cs, Color bg) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: bg,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        indicatorColor: cs.primaryContainer,
        elevation: 3,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.secondary,
        foregroundColor: cs.onSecondary,
      ),
    );
  }

  static ThemeMode mode(String s) =>
      s == 'dark' ? ThemeMode.dark : (s == 'system' ? ThemeMode.system : ThemeMode.light);
}
