/// FORENSIC THEME
/// 
/// FAZ-1.0 / T0 — Forensic-Grade UI Theme System
/// 
/// ⚖️ PURPOSE:
/// Provides a unified, court-defensible visual language across all panels.
/// Every color, font, and spacing token is designed for forensic clarity.
/// 
/// 🎨 DESIGN PHILOSOPHY:
/// "Evidence must be clear, unambiguous, and visually distinct."
/// 
/// 🔐 COLOR PSYCHOLOGY:
/// - Obsidian Emerald: Verification success, integrity confirmed
/// - Atomic Red: Tampering detected, assumptions present
/// - Neon Cyan: Interactive elements, actions
/// - Forensic Slate: Neutral information, metadata
/// - Deep Space Blue: Backgrounds, containers
/// 
/// 📏 TYPOGRAPHY:
/// - Inter: UI text, human-readable content
/// - JetBrains Mono: Cryptographic hashes, code, technical data
/// 
/// ✨ EFFECTS:
/// - Glow: Used sparingly on verified/active states
/// - Radius: 8dp for cards, 4dp for buttons
/// - Shadows: Subtle elevation for depth
library;

import 'package:flutter/material.dart';

/// Forensic Theme
/// 
/// Single source of truth for all visual tokens
/// Used across Admin, Personnel, and Customer panels
class ForensicTheme {
  // =====================================================
  // COLOR TOKENS
  // =====================================================
  
  /// Deep Space Blue - Primary background color
  /// Provides depth and context without distraction
  static const Color deepSpaceBlue = Color(0xFF0A0E27);
  
  /// Forensic Slate - Secondary background, neutral areas
  /// Used for cards, containers, metadata displays
  static const Color forensicSlate = Color(0xFF1A1F3A);
  
  /// Neon Cyan - Interactive elements, actions, highlights
  /// Used for buttons, links, active states
  static const Color neonCyan = Color(0xFF00F5FF);
  
  /// Obsidian Emerald - Verification success, integrity confirmed
  /// Used when cryptographic hash matches, data is verified
  static const Color obsidianEmerald = Color(0xFF00FF88);
  
  /// Atomic Red - Tampering detected, assumptions, warnings
  /// Used for errors, limitations, uncertainty
  static const Color atomicRed = Color(0xFFFF4444);
  
  /// Warning Amber - For limitation warnings and offline indicators
  /// Used for caution states, cached data notices
  static const Color warningAmber = Color(0xFFFFAA00);
  
  /// White - Primary text, high-contrast labels
  static const Color textWhite = Color(0xFFFFFFFF);
  
  /// Grey 70% - Secondary text, less important information
  static const Color textGrey = Color(0xB3FFFFFF);
  
  /// Grey 40% - Tertiary text, placeholders
  static const Color textDim = Color(0x66FFFFFF);
  
  // =====================================================
  // GRADIENTS
  // =====================================================
  
  /// Verified gradient - Success state glow
  static const LinearGradient verifiedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1A00FF88), // Obsidian Emerald with 10% opacity
      Color(0x0D00FF88), // Obsidian Emerald with 5% opacity
    ],
  );
  
  /// Error gradient - Failure state glow
  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1AFF4444), // Atomic Red with 10% opacity
      Color(0x0DFF4444), // Atomic Red with 5% opacity
    ],
  );
  
  /// Neutral gradient - Default card background
  static const LinearGradient neutralGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x331A1F3A), // Forensic Slate with 20% opacity
      Color(0x1A1A1F3A), // Forensic Slate with 10% opacity
    ],
  );
  
  // =====================================================
  // TYPOGRAPHY
  // =====================================================
  
  /// Inter font family - UI text, human-readable content
  static const String fontFamilyInter = 'Inter';
  
  /// JetBrains Mono font family - Cryptographic hashes, code
  static const String fontFamilyJetBrains = 'JetBrainsMono';
  
  /// Headline style - Page titles, section headers
  static const TextStyle headline = TextStyle(
    fontFamily: fontFamilyInter,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textWhite,
    letterSpacing: 1.5,
  );
  
  /// Title style - Card titles, important labels
  static const TextStyle title = TextStyle(
    fontFamily: fontFamilyInter,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textWhite,
    letterSpacing: 0.5,
  );
  
  /// Body style - Primary content text
  static const TextStyle body = TextStyle(
    fontFamily: fontFamilyInter,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textGrey,
    height: 1.5,
  );
  
  /// Caption style - Secondary information, metadata
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamilyInter,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textDim,
    height: 1.4,
  );
  
  /// Monospace style - Cryptographic hashes, technical data
  static const TextStyle monospace = TextStyle(
    fontFamily: fontFamilyJetBrains,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: neonCyan,
    letterSpacing: 0.5,
  );
  
  /// Button text style
  static const TextStyle buttonText = TextStyle(
    fontFamily: fontFamilyInter,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: deepSpaceBlue,
    letterSpacing: 0.5,
  );
  
  // =====================================================
  // SPACING
  // =====================================================
  
  static const double spaceXxs = 4.0;   // Extra extra small
  static const double spaceXs = 8.0;    // Extra small
  static const double spaceSm = 12.0;   // Small
  static const double spaceMd = 16.0;   // Medium
  static const double spaceLg = 24.0;   // Large
  static const double spaceXl = 32.0;   // Extra large
  
  // =====================================================
  // RADIUS
  // =====================================================
  
  /// Card radius - Primary container radius
  static const double radiusCard = 8.0;
  
  /// Button radius - Interactive element radius
  static const double radiusButton = 4.0;
  
  /// Input radius - Text field radius
  static const double radiusInput = 4.0;
  
  // =====================================================
  // EFFECTS
  // =====================================================
  
  /// Verified glow effect - Used when hash matches
  static const BoxShadow glowVerified = BoxShadow(
    color: Color(0x4000FF88), // Obsidian Emerald with 25% opacity
    blurRadius: 16,
    spreadRadius: 0,
    offset: Offset(0, 4),
  );
  
  /// Error glow effect - Used when hash mismatches
  static const BoxShadow glowError = BoxShadow(
    color: Color(0x40FF4444), // Atomic Red with 25% opacity
    blurRadius: 16,
    spreadRadius: 0,
    offset: Offset(0, 4),
  );
  
  /// Neon glow effect - Used for interactive elements
  static const BoxShadow glowNeon = BoxShadow(
    color: Color(0x4000F5FF), // Neon Cyan with 25% opacity
    blurRadius: 12,
    spreadRadius: 0,
    offset: Offset(0, 2),
  );
  
  /// Subtle shadow - Default elevation
  static const BoxShadow shadowSubtle = BoxShadow(
    color: Color(0x20000000), // Black with 12.5% opacity
    blurRadius: 8,
    spreadRadius: 0,
    offset: Offset(0, 2),
  );
  
  // =====================================================
  // ANIMATION DURATIONS
  // =====================================================
  
  /// Fast animation - Micro-interactions
  static const Duration animFast = Duration(milliseconds: 150);
  
  /// Medium animation - Expand/collapse cards
  static const Duration animMedium = Duration(milliseconds: 300);
  
  /// Slow animation - Laser scan effect
  static const Duration animSlow = Duration(milliseconds: 450);
  
  /// Extra slow animation - Page transitions
  static const Duration animExtraSlow = Duration(milliseconds: 600);
  
  // =====================================================
  // BREAKPOINTS
  // =====================================================
  
  /// Mobile breakpoint - Below this width, use mobile layout
  static const double breakpointMobile = 600.0;
  
  /// Tablet breakpoint - Below this width, use tablet layout
  static const double breakpointTablet = 900.0;
  
  /// Desktop breakpoint - Above this width, use desktop layout
  static const double breakpointDesktop = 1200.0;
  
  // =====================================================
  // THEME DATA
  // =====================================================
  
  /// Get Material Theme Data
  /// 
  /// Forensic UX Note: This theme is designed for dark mode only.
  /// Light mode is not recommended for forensic applications
  /// as it reduces the visual impact of verification states.
  static ThemeData get themeData {
    return ThemeData(
      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        secondary: obsidianEmerald,
        error: atomicRed,
        surface: forensicSlate,
        onPrimary: deepSpaceBlue,
        onSecondary: deepSpaceBlue,
        onError: textWhite,
        onSurface: textWhite,
      ),
      
      // Scaffold background
      scaffoldBackgroundColor: deepSpaceBlue,
      
      // App bar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: forensicSlate,
        foregroundColor: textWhite,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: title,
      ),
      
      // Card theme
      cardTheme: const CardThemeData(
        color: forensicSlate,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusCard)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      
      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonCyan,
          foregroundColor: deepSpaceBlue,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: spaceMd,
            vertical: spaceSm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: buttonText,
        ),
      ),
      
      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: neonCyan,
          side: const BorderSide(color: neonCyan, width: 1),
          padding: const EdgeInsets.symmetric(
            horizontal: spaceMd,
            vertical: spaceSm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: buttonText,
        ),
      ),
      
      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: neonCyan,
          padding: const EdgeInsets.symmetric(
            horizontal: spaceSm,
            vertical: spaceXs,
          ),
          textStyle: buttonText,
        ),
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: neonCyan,
        size: 24,
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: forensicSlate,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: textDim, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: textDim, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: neonCyan, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: atomicRed, width: 2),
        ),
        labelStyle: caption,
        hintStyle: caption,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: spaceMd,
        ),
      ),
      
      // Text theme
      textTheme: const TextTheme(
        displayLarge: headline,
        displayMedium: title,
        bodyLarge: body,
        bodyMedium: body,
        bodySmall: caption,
        labelLarge: buttonText,
        labelMedium: body,
        labelSmall: caption,
      ),
    );
  }
  
  // =====================================================
  // GRADIENT MIXINS
  // =====================================================
  
  /// Get verified decoration
  static BoxDecoration getVerifiedDecoration({bool isGlowing = false}) {
    return BoxDecoration(
      gradient: verifiedGradient,
      borderRadius: BorderRadius.circular(radiusCard),
      border: Border.all(
        color: obsidianEmerald,
        width: 2,
      ),
      boxShadow: isGlowing ? [glowVerified] : null,
    );
  }
  
  /// Get error decoration
  static BoxDecoration getErrorDecoration({bool isGlowing = false}) {
    return BoxDecoration(
      gradient: errorGradient,
      borderRadius: BorderRadius.circular(radiusCard),
      border: Border.all(
        color: atomicRed,
        width: 2,
      ),
      boxShadow: isGlowing ? [glowError] : null,
    );
  }
  
  /// Get neutral decoration
  static BoxDecoration getNeutralDecoration() {
    return BoxDecoration(
      gradient: neutralGradient,
      borderRadius: BorderRadius.circular(radiusCard),
      border: Border.all(
        color: textDim,
        width: 1,
      ),
    );
  }
}