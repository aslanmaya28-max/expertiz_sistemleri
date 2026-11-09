import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'olculer.dart';
import 'renkler.dart';
import 'yazi.dart';

abstract final class YbTema {
  // Masaüstü yönetim aracı: düğme yazısı 14/600, köşe 10 (mobil 16/12 yerine)
  static const _panelButon =
      TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600);
  static const _panelKose = 10.0;

  static ThemeData get acik => _build(Brightness.light, YbRenkler.acik);
  static ThemeData get koyu => _build(Brightness.dark, YbRenkler.koyu);
  static ThemeData _build(Brightness brightness, YbRenkler r) {
    final scheme = ColorScheme.fromSeed(
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
      visualDensity: VisualDensity.compact,
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(LucideIcons.arrowLeft),
        closeButtonIconBuilder: (_) => const Icon(LucideIcons.x),
      ),
      iconTheme: IconThemeData(size: Olcu.ikonInce, color: r.ikonPasif),
      extensions: [r, YbYazi(govde: Yazilar.govde.copyWith(fontSize: 14))],
      textTheme: Yazilar.textTheme
          .copyWith(
              bodyLarge: Yazilar.govde.copyWith(fontSize: 14),
              titleMedium: Yazilar.govde.copyWith(fontSize: 14))
          .apply(
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
      snackBarTheme: SnackBarThemeData(
          backgroundColor: r.yuzeyIkincil,
          contentTextStyle: Yazilar.govdeKucuk.copyWith(color: r.metin),
          behavior: SnackBarBehavior.floating),
      dividerTheme: DividerThemeData(color: r.ayirici, thickness: Olcu.kenar),
      inputDecorationTheme: InputDecorationTheme(
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: r.birincil, width: Olcu.odakKenar),
        ),
        labelStyle: Yazilar.etiket.copyWith(color: r.metinIkincil),
        contentPadding: const EdgeInsets.all(Olcu.s12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(Olcu.dokunma, PanelOlcu.buton),
          textStyle: _panelButon,
          visualDensity: VisualDensity.standard,
          padding: const EdgeInsets.symmetric(horizontal: Olcu.s16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_panelKose),
          ),
        ),
      ),
      // Eski ekranlardaki ElevatedButton'lar da ana buton gibi görünür (hap/iri yazı yok)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(Olcu.dokunma, PanelOlcu.buton),
          backgroundColor: r.birincil,
          foregroundColor: r.birincilUstu,
          disabledBackgroundColor: r.yuzeyIkincil,
          disabledForegroundColor: r.metinIkincil,
          elevation: 0,
          textStyle: _panelButon,
          visualDensity: VisualDensity.standard,
          padding: const EdgeInsets.symmetric(horizontal: Olcu.s16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_panelKose),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: r.birincil,
        foregroundColor: r.birincilUstu,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Olcu.butonKose)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: r.metinIkincil,
          hoverColor: r.yuzeyIkincil,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Olcu.s8 + 2)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: r.yuzey,
        selectedColor: r.birincilYuzey,
        checkmarkColor: r.birincilMetin,
        side: BorderSide(color: r.girdiKenarlik),
        labelStyle: Yazilar.etiket.copyWith(color: r.metin),
        secondaryLabelStyle: Yazilar.etiket.copyWith(color: r.birincilMetin),
        padding: const EdgeInsets.symmetric(horizontal: Olcu.s8, vertical: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Olcu.s8)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: r.birincilMetin,
        unselectedLabelColor: r.metinIkincil,
        indicatorColor: r.birincil,
        dividerColor: r.ayirici,
        labelStyle: Yazilar.etiket.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: Yazilar.etiket,
        overlayColor: WidgetStatePropertyAll(r.yuzeyIkincil),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: r.yuzey,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: Yazilar.bolumBaslik.copyWith(fontSize: 18, color: r.metin),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Olcu.kartKose),
            side: BorderSide(color: r.kenarlik)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: r.yuzey,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        textStyle: Yazilar.govdeKucuk.copyWith(color: r.metin),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Olcu.butonKose),
            side: BorderSide(color: r.kenarlik)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
            color: r.metin, borderRadius: BorderRadius.circular(Olcu.s8)),
        textStyle: Yazilar.kucuk.copyWith(color: r.zemin),
        waitDuration: const Duration(milliseconds: 400),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: Yazilar.kucuk.copyWith(
            color: r.metinIkincil, fontWeight: FontWeight.w600),
        dataTextStyle: Yazilar.govdeKucuk.copyWith(color: r.metin),
        dividerThickness: Olcu.kenar,
        headingRowColor: WidgetStatePropertyAll(r.yuzey),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? r.birincilUstu : r.metinIkincil),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? r.birincil : r.yuzeyIkincil),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? r.birincil : r.girdiKenarlik),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? r.birincil : Colors.transparent),
        checkColor: WidgetStatePropertyAll(r.birincilUstu),
        side: BorderSide(color: r.girdiKenarlik, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
          color: r.birincil, linearTrackColor: r.yuzeyIkincil),
      listTileTheme: ListTileThemeData(
        iconColor: r.metinIkincil,
        textColor: r.metin,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Olcu.butonKose)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(Olcu.dokunma, PanelOlcu.buton),
          foregroundColor: r.metin,
          side: BorderSide(color: r.girdiKenarlik),
          textStyle: _panelButon,
          visualDensity: VisualDensity.standard,
          padding: const EdgeInsets.symmetric(horizontal: Olcu.s16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_panelKose),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: r.birincilMetin,
          minimumSize: const Size(Olcu.dokunma, PanelOlcu.buton),
          textStyle: _panelButon.copyWith(fontWeight: FontWeight.w500),
          visualDensity: VisualDensity.standard,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_panelKose)),
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
