import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Açılmış araç çizimi (420 × 540 tasarım birimi): ortada üstten görünüş
/// (burun yukarıda), iki yanda yan görünüşler (tekerlekler dışta), üstte ön,
/// altta arka görünüş. Sol taraf görselin solundadır.
class KaportaParca {
  /// Boyanacak parça şekli.
  final Path sekil;

  /// Dokunma alanı; komşularıyla çakışmayan dikdörtgen.
  final Rect isabet;

  /// Durum harfinin yazılacağı nokta.
  final Offset etiket;
  const KaportaParca(this.sekil, this.isabet, this.etiket);
}

abstract final class KaportaGeometri {
  static const genislik = 420.0, yukseklik = 540.0;
  static const _orta = genislik / 2;

  /// Yan görünüşte eşik çizgisinin x konumu (sol); sağ taraf aynalanır.
  static const _esik = 28.0;

  static Path _kutu(double l, double t, double w, double h, double r) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r)),
    );

  static Path _daire(Offset c, double r) =>
      Path()..addOval(Rect.fromCircle(center: c, radius: r));

  // ---- Yan görünüş, yerel koordinat: u eşikten tavana, v boyuna. ----
  static Path get _yanGovde => Path()
    ..moveTo(0, 100)
    ..quadraticBezierTo(0, 72, 24, 72)
    ..lineTo(44, 73)
    ..quadraticBezierTo(52, 74, 52, 84)
    ..lineTo(52, 150)
    ..lineTo(86, 214)
    ..quadraticBezierTo(90, 222, 90, 232)
    ..lineTo(90, 320)
    ..quadraticBezierTo(90, 330, 84, 338)
    ..lineTo(58, 392)
    ..lineTo(56, 448)
    ..quadraticBezierTo(54, 466, 32, 466)
    ..lineTo(12, 466)
    ..quadraticBezierTo(0, 466, 0, 452)
    ..close();

  static Path get _yanCam => Path()
    ..moveTo(55, 164)
    ..lineTo(82, 220)
    ..quadraticBezierTo(84, 224, 84, 230)
    ..lineTo(84, 320)
    ..lineTo(62, 370)
    ..lineTo(55, 370)
    ..close();

  static const _onTeker = Offset(0, 128), _arkaTeker = Offset(0, 412);

  static Path _kemerli(Path p, Offset teker) =>
      Path.combine(PathOperation.difference, p, _daire(teker, 27));

  static Path get _yanOnCamurluk => _kemerli(
    Path()
      ..moveTo(2, 100)
      ..quadraticBezierTo(2, 76, 24, 75)
      ..lineTo(44, 76)
      ..quadraticBezierTo(50, 77, 50, 86)
      ..lineTo(50, 165)
      ..lineTo(2, 165)
      ..close(),
    _onTeker,
  );
  static Path get _yanOnKapi => _kutu(2, 169, 50, 98, 3);
  static Path get _yanArkaKapi => _kutu(2, 271, 50, 94, 3);
  static Path get _yanArkaCamurluk => _kemerli(
    Path()
      ..moveTo(2, 369)
      ..lineTo(54, 369)
      ..lineTo(54, 446)
      ..quadraticBezierTo(52, 463, 32, 463)
      ..lineTo(12, 463)
      ..quadraticBezierTo(2, 463, 2, 452)
      ..close(),
    _arkaTeker,
  );

  static Path get _yanDetay => Path()
    // kapı kolları
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(40, 182, 4, 12),
        const Radius.circular(2),
      ),
    )
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(40, 282, 4, 12),
        const Radius.circular(2),
      ),
    )
    // ayna
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(52, 150, 10, 12),
        const Radius.circular(3),
      ),
    )
    // farlar
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(30, 76, 16, 8),
        const Radius.circular(3),
      ),
    )
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(36, 454, 14, 7),
        const Radius.circular(3),
      ),
    );

  static Float64List _sol() => Matrix4.translationValues(_esik, 0, 0).storage;
  static Float64List _sag() => (Matrix4.translationValues(
    genislik - _esik,
    0,
    0,
  )..multiply(Matrix4.diagonal3Values(-1, 1, 1))).storage;

  static Path _iki(Path yerel) => Path()
    ..addPath(yerel.transform(_sol()), Offset.zero)
    ..addPath(yerel.transform(_sag()), Offset.zero);

  static Rect _yanIsabet(bool sol, double v1, double v2) => sol
      ? Rect.fromLTRB(_esik - 23, v1, _esik + 90, v2)
      : Rect.fromLTRB(genislik - _esik - 90, v1, genislik - _esik + 23, v2);

  static Offset _yanEtiket(bool sol, double u, double v) =>
      Offset(sol ? _esik + u : genislik - _esik - u, v);

  // ---- Üstten görünüş (orta). ----
  static Path get _ustGovde => Path()
    ..moveTo(170, 68)
    ..quadraticBezierTo(210, 62, 250, 68)
    ..cubicTo(272, 72, 278, 90, 278, 120)
    ..lineTo(280, 420)
    ..cubicTo(280, 455, 265, 468, 240, 470)
    ..quadraticBezierTo(210, 474, 180, 470)
    ..cubicTo(155, 468, 140, 455, 140, 420)
    ..lineTo(142, 120)
    ..cubicTo(142, 90, 148, 72, 170, 68)
    ..close();

  static Path get _kaput => Path()
    ..moveTo(175, 74)
    ..quadraticBezierTo(210, 69, 245, 74)
    ..cubicTo(260, 78, 266, 92, 266, 112)
    ..lineTo(264, 166)
    ..quadraticBezierTo(210, 172, 156, 166)
    ..lineTo(154, 112)
    ..cubicTo(154, 92, 160, 78, 175, 74)
    ..close();

  static Path get _onCam => Path()
    ..moveTo(158, 174)
    ..quadraticBezierTo(210, 180, 262, 174)
    ..lineTo(252, 222)
    ..quadraticBezierTo(210, 226, 168, 222)
    ..close();

  static Path get _tavan => Path()
    ..moveTo(168, 228)
    ..quadraticBezierTo(210, 232, 252, 228)
    ..lineTo(254, 330)
    ..quadraticBezierTo(210, 334, 166, 330)
    ..close();

  static Path get _arkaCam => Path()
    ..moveTo(166, 336)
    ..quadraticBezierTo(210, 340, 254, 336)
    ..lineTo(260, 372)
    ..quadraticBezierTo(210, 378, 160, 372)
    ..close();

  static Path get _bagaj => Path()
    ..moveTo(158, 378)
    ..quadraticBezierTo(210, 384, 262, 378)
    ..lineTo(264, 430)
    ..cubicTo(264, 450, 250, 460, 232, 462)
    ..quadraticBezierTo(210, 464, 188, 462)
    ..cubicTo(170, 460, 156, 450, 156, 430)
    ..close();

  static Path get _ustDetay => Path()
    ..addOval(const Rect.fromLTWH(128, 176, 14, 9))
    ..addOval(const Rect.fromLTWH(278, 176, 14, 9));

  // ---- Ön görünüş (üstte; tekerlekler dışta, yani yukarıda). ----
  static Path get _onGovde => Path()
    ..moveTo(140, 14)
    ..quadraticBezierTo(140, 4, 152, 4)
    ..lineTo(268, 4)
    ..quadraticBezierTo(280, 4, 280, 14)
    ..lineTo(278, 40)
    ..quadraticBezierTo(276, 54, 258, 56)
    ..lineTo(162, 56)
    ..quadraticBezierTo(144, 54, 142, 40)
    ..close();

  static Path get _onTampon => Path()
    ..moveTo(141, 30)
    ..lineTo(141, 14)
    ..quadraticBezierTo(141, 5, 152, 5)
    ..lineTo(268, 5)
    ..quadraticBezierTo(279, 5, 279, 14)
    ..lineTo(279, 30)
    ..close();

  static Path get _onDetay => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(150, 36, 32, 9),
        const Radius.circular(4),
      ),
    )
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(238, 36, 32, 9),
        const Radius.circular(4),
      ),
    )
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(186, 34, 48, 14),
        const Radius.circular(4),
      ),
    )
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(180, 14, 60, 9),
        const Radius.circular(4),
      ),
    );

  // ---- Arka görünüş (altta; tekerlekler aşağıda). ----
  static Path get _arkaGovde => Path()
    ..moveTo(162, 484)
    ..lineTo(258, 484)
    ..quadraticBezierTo(276, 486, 278, 500)
    ..lineTo(280, 526)
    ..quadraticBezierTo(280, 536, 268, 536)
    ..lineTo(152, 536)
    ..quadraticBezierTo(140, 536, 140, 526)
    ..lineTo(142, 500)
    ..quadraticBezierTo(144, 486, 162, 484)
    ..close();

  static Path get _arkaTampon => Path()
    ..moveTo(141, 510)
    ..lineTo(279, 510)
    ..lineTo(279, 526)
    ..quadraticBezierTo(279, 535, 268, 535)
    ..lineTo(152, 535)
    ..quadraticBezierTo(141, 535, 141, 526)
    ..close();

  static Path get _arkaDetay => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(150, 492, 30, 9),
        const Radius.circular(4),
      ),
    )
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(240, 492, 30, 9),
        const Radius.circular(4),
      ),
    )
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(192, 494, 36, 8),
        const Radius.circular(2),
      ),
    )
    ..addOval(Rect.fromCircle(center: const Offset(176, 528), radius: 3))
    ..addOval(Rect.fromCircle(center: const Offset(186, 528), radius: 3));

  /// Gövde hatları (boyanmaz, yalnız çizilir).
  static final Path govdeler = Path()
    ..addPath(_iki(_yanGovde), Offset.zero)
    ..addPath(_ustGovde, Offset.zero)
    ..addPath(_onGovde, Offset.zero)
    ..addPath(_arkaGovde, Offset.zero);

  static final Path camlar = Path()
    ..addPath(_iki(_yanCam), Offset.zero)
    ..addPath(_onCam, Offset.zero)
    ..addPath(_arkaCam, Offset.zero);

  static final Path detaylar = Path()
    ..addPath(_iki(_yanDetay), Offset.zero)
    ..addPath(_ustDetay, Offset.zero)
    ..addPath(_onDetay, Offset.zero)
    ..addPath(_arkaDetay, Offset.zero);

  /// Lastikler: yan görünüşte daire, ön/arka görünüşte köşelerde blok.
  static final Path lastikler = Path()
    ..addPath(
      _iki(
        Path()
          ..addPath(_daire(_onTeker, 23), Offset.zero)
          ..addPath(_daire(_arkaTeker, 23), Offset.zero),
      ),
      Offset.zero,
    )
    ..addPath(_kutu(130, 0, 12, 22, 3), Offset.zero)
    ..addPath(_kutu(278, 0, 12, 22, 3), Offset.zero)
    ..addPath(_kutu(130, 518, 12, 22, 3), Offset.zero)
    ..addPath(_kutu(278, 518, 12, 22, 3), Offset.zero);

  static final Path jantlar = _iki(
    Path()
      ..addPath(_daire(_onTeker, 13), Offset.zero)
      ..addPath(_daire(_arkaTeker, 13), Offset.zero),
  );

  static final Map<String, KaportaParca> parcalar = {
    'onTampon': KaportaParca(
      _onTampon,
      const Rect.fromLTRB(124, 0, 296, 62),
      const Offset(_orta, 20),
    ),
    'kaput': KaportaParca(
      _kaput,
      const Rect.fromLTRB(146, 64, 274, 172),
      const Offset(_orta, 120),
    ),
    'tavan': KaportaParca(
      _tavan,
      const Rect.fromLTRB(160, 226, 260, 334),
      const Offset(_orta, 280),
    ),
    'bagajKapagi': KaportaParca(
      _bagaj,
      const Rect.fromLTRB(150, 376, 270, 474),
      const Offset(_orta, 420),
    ),
    'arkaTampon': KaportaParca(
      _arkaTampon,
      const Rect.fromLTRB(124, 476, 296, 540),
      const Offset(_orta, 523),
    ),
    for (final sol in [true, false]) ...{
      '${sol ? 'sol' : 'sag'}OnCamurluk': KaportaParca(
        sol
            ? _yanOnCamurluk.transform(_sol())
            : _yanOnCamurluk.transform(_sag()),
        _yanIsabet(sol, 68, 167),
        _yanEtiket(sol, 38, 140),
      ),
      '${sol ? 'sol' : 'sag'}OnKapi': KaportaParca(
        sol ? _yanOnKapi.transform(_sol()) : _yanOnKapi.transform(_sag()),
        _yanIsabet(sol, 167, 269),
        _yanEtiket(sol, 26, 218),
      ),
      '${sol ? 'sol' : 'sag'}ArkaKapi': KaportaParca(
        sol ? _yanArkaKapi.transform(_sol()) : _yanArkaKapi.transform(_sag()),
        _yanIsabet(sol, 269, 367),
        _yanEtiket(sol, 26, 318),
      ),
      '${sol ? 'sol' : 'sag'}ArkaCamurluk': KaportaParca(
        sol
            ? _yanArkaCamurluk.transform(_sol())
            : _yanArkaCamurluk.transform(_sag()),
        _yanIsabet(sol, 367, 470),
        _yanEtiket(sol, 40, 400),
      ),
    },
  };
}
