import 'package:flutter/material.dart';

abstract final class Hareket {
  static const kisa = Duration(milliseconds: 180);
  static const fiyat = Duration(milliseconds: 300);
  static const nabiz = Duration(milliseconds: 900);
  static const analizGolgeleri = [
    BoxShadow(
      color: Color.fromRGBO(16, 24, 40, .06),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: Color.fromRGBO(16, 24, 40, .07),
      offset: Offset(0, 12),
      blurRadius: 32,
    ),
  ];
}
