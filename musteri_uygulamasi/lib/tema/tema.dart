import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'olculer.dart';
import 'renkler.dart';
import 'yazi.dart';

abstract final class YbTema {
  static ThemeData get acik => _build(Brightness.light, YbRenkler.acik);
  static ThemeData get koyu => _build(Brightness.dark, YbRenkler.koyu);
  static ThemeData _build(Brightness brightness, YbRenkler r) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: r.birincil,
          brightness: brightness,
        ).copyWith(
          primary: r.birincil,
          onPrimary: r.birincilUstu,
          primaryContainer: r.birincilYuzey,
          onPrimaryContainer: r.birincilMetin,
          secondary: r.birincil,
          onSecondary: r.birincilUstu,
          secondaryContainer: r.birincilYuzey,
          onSecondaryContainer: r.birincilMetin,
          tertiary: r.bilgi,
          onTertiary: r.yuzey,
          tertiaryContainer: r.bilgiYuzey,
          onTertiaryContainer: r.bilgi,
          surface: r.yuzey,
          onSurface: r.metin,
          onSurfaceVariant: r.metinIkincil,
          surfaceTint: r.yuzey,
          surfaceContainer: r.yuzeyIkincil,
          surfaceContainerLow: r.yuzey,
          surfaceContainerHigh: r.yuzeyIkincil,
          outline: r.girdiKenarlik,
          outlineVariant: r.ayirici,
          error: r.tehlike,
          onError: r.tehlikeYuzey,
          errorContainer: r.tehlikeYuzey,
          onErrorContainer: r.tehlike,
        );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Olcu.butonKose),
      borderSide: BorderSide(color: r.girdiKenarlik, width: Olcu.kenar),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: r.zemin,
      fontFamily: 'Inter',
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(LucideIcons.arrowLeft),
        closeButtonIconBuilder: (_) => const Icon(LucideIcons.x),
      ),
      iconTheme: IconThemeData(size: Olcu.ikonInce, color: r.ikonPasif),
      extensions: [r, const YbYazi()],
      textTheme: Yazilar.textTheme.apply(
        bodyColor: r.metin,
        displayColor: r.metin,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: r.yuzey,
        foregroundColor: r.metin,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: Yazilar.baslik1.copyWith(color: r.metin),
      ),
      cardTheme: CardThemeData(
        color: r.yuzey,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Olcu.kartKose),
        ),
      ),
      dividerTheme: DividerThemeData(color: r.ayirici, thickness: Olcu.kenar),
      inputDecorationTheme: InputDecorationTheme(
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: r.birincil, width: Olcu.odakKenar),
        ),
        labelStyle: Yazilar.etiket.copyWith(color: r.metinIkincil),
        contentPadding: const EdgeInsets.all(Olcu.s16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(Olcu.dokunma, Olcu.anaButon),
          textStyle: Yazilar.buton,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Olcu.butonKose),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(Olcu.dokunma, Olcu.ikincilButon),
          foregroundColor: r.metin,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Olcu.butonKose),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: r.birincilMetin,
          minimumSize: const Size(Olcu.dokunma, Olcu.dokunma),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: Olcu.altMenu,
        backgroundColor: r.yuzey,
        indicatorColor: r.birincilYuzey,
        labelTextStyle: WidgetStatePropertyAll(
          Yazilar.menu.copyWith(color: r.metin),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? r.birincil : r.ikonPasif,
            size: Olcu.ikon,
          ),
        ),
      ),
    );
  }
}
