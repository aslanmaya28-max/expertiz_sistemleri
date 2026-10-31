import 'package:flutter/material.dart';

/// Inspection forms use one readable daylight palette, independently of the shell.
class SahaRaporuTemasi {
  static const primary = Color(0xFF1565C0);
  static const text = Color(0xFF172033);
  static const muted = Color(0xFF475569);
  static const success = Color(0xFF2E7D32);

  static final data = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF4F6FA),
    colorScheme: ColorScheme.fromSeed(seedColor: primary).copyWith(
        primary: primary,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: text,
        onSurfaceVariant: muted,
        error: const Color(0xFFB91C1C)),
    disabledColor: muted,
    cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: muted),
      hintStyle: const TextStyle(color: muted),
      helperStyle: const TextStyle(color: muted, fontSize: 12),
      helperMaxLines: 3,
      errorMaxLines: 3,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF64748B))),
      disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF94A3B8))),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: primary,
            disabledForegroundColor: muted,
            disabledBackgroundColor: const Color(0xFFE2E8F0),
            minimumSize: const Size(44, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            minimumSize: const Size(44, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: primary, minimumSize: const Size(44, 44))),
    dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
  );
}
