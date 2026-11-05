import 'package:flutter/material.dart';

/// Önden bakış; araç burnu yukarıda, sol taraf görselin solundadır.
abstract final class KaportaGeometri {
  static const govde = Rect.fromLTWH(60, 20, 280, 500), govdeKose = 85.0;
  static const camlar = [
    Rect.fromLTWH(128, 160, 140, 32),
    Rect.fromLTWH(128, 350, 140, 32),
  ];
  static const parcalar = <String, Rect>{
    'onTampon': Rect.fromLTWH(110, 25, 180, 35),
    'kaput': Rect.fromLTWH(115, 80, 170, 75),
    'solOnCamurluk': Rect.fromLTWH(65, 100, 45, 80),
    'solOnKapi': Rect.fromLTWH(65, 195, 65, 90),
    'solArkaKapi': Rect.fromLTWH(65, 290, 65, 85),
    'solArkaCamurluk': Rect.fromLTWH(70, 390, 45, 65),
    'sagOnCamurluk': Rect.fromLTWH(290, 100, 45, 80),
    'sagOnKapi': Rect.fromLTWH(270, 195, 65, 90),
    'sagArkaKapi': Rect.fromLTWH(270, 290, 65, 85),
    'sagArkaCamurluk': Rect.fromLTWH(285, 390, 45, 65),
    'tavan': Rect.fromLTWH(145, 207, 110, 120),
    'bagajKapagi': Rect.fromLTWH(112, 395, 176, 60),
    'arkaTampon': Rect.fromLTWH(110, 480, 180, 35),
  };
}
