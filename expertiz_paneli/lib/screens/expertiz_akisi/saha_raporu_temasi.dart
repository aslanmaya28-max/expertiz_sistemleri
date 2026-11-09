import 'package:flutter/material.dart';
import '../../tema/renkler.dart';
import '../../tema/tema.dart';

/// Saha formu gün ışığında okunabilir açık paleti ve mobil dokunma alanını korur.
/// Renk, yazı ve bileşen temelleri yönetim paneliyle aynı kaynaktan gelir.
abstract final class SahaRaporuTemasi {
  static ThemeData get data {
    final base = YbTema.acik;
    final r = YbRenkler.acik;
    return base.copyWith(
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: r.yuzey,
        labelStyle: TextStyle(color: r.metinIkincil),
        hintStyle: TextStyle(color: r.metinIkincil),
        helperStyle: TextStyle(color: r.metinIkincil, fontSize: 12),
        helperMaxLines: 3,
        errorMaxLines: 3,
        contentPadding: const EdgeInsets.all(14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 48),
          foregroundColor: r.birincilUstu,
          backgroundColor: r.birincil,
          disabledForegroundColor: r.metinIkincil,
          disabledBackgroundColor: r.yuzeyIkincil,
          padding: const EdgeInsets.all(12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 48),
          foregroundColor: r.birincilMetin,
          padding: const EdgeInsets.all(12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: r.birincilMetin,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: r.yuzey,
        surfaceTintColor: r.yuzey,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: r.yuzey,
        surfaceTintColor: r.yuzey,
      ),
    );
  }
}
