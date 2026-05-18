import 'package:flutter/material.dart';

class FuturisticTheme {
  static const bgPrimary = Color(0xFF060912);
  static const bgSecondary = Color(0xFF11172A);
  static const neon = Color(0xFF00E5FF);
  
  // Login Screen Theme Colors
  static const loginBgStart = Color(0xFF0A101C);
  static const loginBgEnd = Color(0xFF0D1B2A);
  static const accentCyan = Color(0xFF00F0FF);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF94A3B8);
  static const inputBackground = Color(0xFF0F172A);

  static ThemeData theme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgPrimary,
    useMaterial3: true,
    fontFamily: 'Inter',
    
    colorScheme: const ColorScheme.dark(
      primary: neon,
      surface: bgSecondary,
      surfaceContainer: bgSecondary,
      onPrimary: bgPrimary,
      onSurface: Colors.white,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),

    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white70),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ),
    
    // TextField Theme for Login
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputBackground.withValues(alpha: 0.6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentCyan, width: 1.5),
      ),
      hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
      prefixIconColor: textSecondary,
      suffixIconColor: textSecondary,
    ),
    
    // Checkbox Theme
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accentCyan;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.black),
      side: const BorderSide(color: Colors.white54, width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    
    // TextButton Theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: textSecondary,
        textStyle: const TextStyle(fontSize: 13),
        padding: EdgeInsets.zero,
      ),
    ),
  );
}
