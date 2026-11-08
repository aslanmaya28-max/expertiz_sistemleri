import 'package:flutter/material.dart';

/// Inter değişken fontu uygulamaya gömülüdür; tüm rakamlar tablo genişliğinde.
abstract final class Yazilar {
  static const raporBaslik = TextStyle(
    fontFamily: 'Inter',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -.8,
  );
  static const raporGovde = TextStyle(
    fontFamily: 'Inter',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const rakamBuyuk = TextStyle(
    fontFamily: 'Inter',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 38,
    fontWeight: FontWeight.w600,
    letterSpacing: -.8,
  );
  static const baslik1 = TextStyle(
    fontFamily: 'Inter',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 25,
    fontWeight: FontWeight.w600,
    letterSpacing: -.4,
  );
  static const baslik2 = TextStyle(
    fontFamily: 'Inter',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 21,
    fontWeight: FontWeight.w600,
    letterSpacing: -.3,
  );
  static const bolumBaslik = TextStyle(
    fontFamily: 'Inter',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );
  static const govde = TextStyle(
    fontFamily: 'Inter',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const govdeKucuk = TextStyle(
    fontFamily: 'Inter',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const etiket = TextStyle(
    fontFamily: 'Inter',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );
  static const kucuk = TextStyle(
    fontFamily: 'Inter',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: .2,
  );
  static const menu = TextStyle(
    fontFamily: 'Inter',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );
  static const buton = TextStyle(
    fontFamily: 'Inter',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static const textTheme = TextTheme(
    displaySmall: rakamBuyuk,
    headlineMedium: baslik1,
    headlineSmall: baslik2,
    titleLarge: bolumBaslik,
    titleMedium: govde,
    titleSmall: etiket,
    bodyLarge: govde,
    bodyMedium: govdeKucuk,
    bodySmall: etiket,
    labelLarge: etiket,
    labelMedium: kucuk,
    labelSmall: menu,
  );
}

class YbYazi extends ThemeExtension<YbYazi> {
  final TextStyle rakamBuyuk,
      baslik1,
      baslik2,
      bolumBaslik,
      govde,
      govdeKucuk,
      etiket,
      kucuk,
      menu,
      buton;
  const YbYazi({
    this.rakamBuyuk = Yazilar.rakamBuyuk,
    this.baslik1 = Yazilar.baslik1,
    this.baslik2 = Yazilar.baslik2,
    this.bolumBaslik = Yazilar.bolumBaslik,
    this.govde = Yazilar.govde,
    this.govdeKucuk = Yazilar.govdeKucuk,
    this.etiket = Yazilar.etiket,
    this.kucuk = Yazilar.kucuk,
    this.menu = Yazilar.menu,
    this.buton = Yazilar.buton,
  });
  @override
  YbYazi copyWith({
    TextStyle? rakamBuyuk,
    TextStyle? baslik1,
    TextStyle? baslik2,
    TextStyle? bolumBaslik,
    TextStyle? govde,
    TextStyle? govdeKucuk,
    TextStyle? etiket,
    TextStyle? kucuk,
    TextStyle? menu,
    TextStyle? buton,
  }) => YbYazi(
    rakamBuyuk: rakamBuyuk ?? this.rakamBuyuk,
    baslik1: baslik1 ?? this.baslik1,
    baslik2: baslik2 ?? this.baslik2,
    bolumBaslik: bolumBaslik ?? this.bolumBaslik,
    govde: govde ?? this.govde,
    govdeKucuk: govdeKucuk ?? this.govdeKucuk,
    etiket: etiket ?? this.etiket,
    kucuk: kucuk ?? this.kucuk,
    menu: menu ?? this.menu,
    buton: buton ?? this.buton,
  );
  @override
  YbYazi lerp(covariant YbYazi? other, double t) => other == null
      ? this
      : YbYazi(
          rakamBuyuk: TextStyle.lerp(rakamBuyuk, other.rakamBuyuk, t)!,
          baslik1: TextStyle.lerp(baslik1, other.baslik1, t)!,
          baslik2: TextStyle.lerp(baslik2, other.baslik2, t)!,
          bolumBaslik: TextStyle.lerp(bolumBaslik, other.bolumBaslik, t)!,
          govde: TextStyle.lerp(govde, other.govde, t)!,
          govdeKucuk: TextStyle.lerp(govdeKucuk, other.govdeKucuk, t)!,
          etiket: TextStyle.lerp(etiket, other.etiket, t)!,
          kucuk: TextStyle.lerp(kucuk, other.kucuk, t)!,
          menu: TextStyle.lerp(menu, other.menu, t)!,
          buton: TextStyle.lerp(buton, other.buton, t)!,
        );
  static YbYazi of(BuildContext context) =>
      Theme.of(context).extension<YbYazi>()!;
}
