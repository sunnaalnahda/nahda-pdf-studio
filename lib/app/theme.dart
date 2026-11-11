import 'package:flutter/material.dart';

abstract final class NahdaTheme {
  static const ink = Color(0xFF16263D);
  static const navy = Color(0xFF11243A);
  static const gold = Color(0xFFCB9A57);
  static const blue = Color(0xFF2B547C);
  static const canvas = Color(0xFFF2F5F9);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.light,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: null,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
