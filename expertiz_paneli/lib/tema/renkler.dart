import 'package:flutter/material.dart';

/// Tasarım sistemi bölüm 3; koyu temada marka bandı kullanılmaz.
class YbRenkler extends ThemeExtension<YbRenkler> {
  final Map<String, Color> _values;
  const YbRenkler._(this._values);
  Color get zemin => _values['zemin']!;
  Color get yuzey => _values['yuzey']!;
  Color get yuzeyIkincil => _values['yuzeyIkincil']!;
  Color get metin => _values['metin']!;
  Color get metinIkincil => _values['metinIkincil']!;
  Color get metinGovde => _values['metinGovde']!;
  Color get ikonPasif => _values['ikonPasif']!;
  Color get kenarlik => _values['kenarlik']!;
  Color get ayirici => _values['ayirici']!;
  Color get girdiKenarlik => _values['girdiKenarlik']!;
  Color get birincil => _values['birincil']!;
  Color get birincilUstu => _values['birincilUstu']!;
  Color get birincilMetin => _values['birincilMetin']!;
  Color get birincilYuzey => _values['birincilYuzey']!;
  Color get birincilAcik => _values['birincilAcik']!;
  Color get markaBandi => _values['markaBandi']!;
  Color get markaBandiMetin => _values['markaBandiMetin']!;
  Color get markaBandiVurgu => _values['markaBandiVurgu']!;
  Color get uyari => _values['uyari']!;
  Color get uyariYuzey => _values['uyariYuzey']!;
  Color get uyariKenar => _values['uyariKenar']!;
  Color get tehlike => _values['tehlike']!;
  Color get tehlikeYuzey => _values['tehlikeYuzey']!;
  Color get bilgi => _values['bilgi']!;
  Color get bilgiYuzey => _values['bilgiYuzey']!;
  Color get lokalYuzey => _values['lokalYuzey']!;
  Color get lokalKenar => _values['lokalKenar']!;
  Color get boyaliYuzey => _values['boyaliYuzey']!;
  Color get boyaliKenar => _values['boyaliKenar']!;
  Color get degisenYuzey => _values['degisenYuzey']!;
  Color get degisenMetin => _values['degisenMetin']!;
  Color get cam => _values['cam']!;
  Color get beyaz => _values['beyaz']!;
  // Turuncu vurgu (kullanıcı kararı, 6 Kasım 2026): ana renk yeşil kalır;
  // turuncu yalnız küçük dokunuşlarda (kredi, Yakında, hizmet simgesi, ilan çizgisi).
  Color get vurgu => _values['vurgu']!;
  Color get vurguMetin => _values['vurguMetin']!;
  Color get vurguYuzey => _values['vurguYuzey']!;
  Color get vurguKenar => _values['vurguKenar']!;
  Color get vurguBant => _values['vurguBant']!;
  Color get raporYuzey => _values['raporYuzey']!;
  Color get raporKenar => _values['raporKenar']!;
  Color get raporKoyu => _values['raporKoyu']!;
  static const acik = YbRenkler._({
    'raporYuzey': Color(0xFFF0F7F1),
    'raporKenar': Color(0xFFCEE3D6),
    'raporKoyu': Color(0xFF002C25),
    'vurgu': Color(0xFFE8622C),
    'vurguMetin': Color(0xFFB4461B),
    'vurguYuzey': Color(0xFFFFEDE2),
    'vurguKenar': Color(0xFFF7B48E),
    'vurguBant': Color(0xFFFF9B6A),
    'lokalYuzey': Color(0xFFFDF1E2),
    'lokalKenar': Color(0xFFF2C894),
    'boyaliYuzey': Color(0xFFF2C894),
    'boyaliKenar': Color(0xFFC98A3A),
    'degisenYuzey': Color(0xFFA3580A),
    'degisenMetin': Color(0xFFFFFFFF),
    'cam': Color(0xFFE9EEED),
    'beyaz': Color(0xFFFFFFFF),
    'zemin': Color(0xFFF2F5F4),
    'yuzey': Color(0xFFFFFFFF),
    'yuzeyIkincil': Color(0xFFF2F5F4),
    'metin': Color(0xFF0F1B1A),
    'metinIkincil': Color(0xFF4B5B59),
    'metinGovde': Color(0xFF4B5B59),
    'ikonPasif': Color(0xFF5B6B69),
    'kenarlik': Color(0xFFE3E8E7),
    'ayirici': Color(0xFFE6ECEA),
    'girdiKenarlik': Color(0xFFCFD8D6),
    'birincil': Color(0xFF00876F),
    'birincilUstu': Color(0xFFFFFFFF),
    'birincilMetin': Color(0xFF006B58),
    'birincilYuzey': Color(0xFFD6F5EB),
    'birincilAcik': Color(0xFF6EDCC2),
    'markaBandi': Color(0xFF00574C),
    'markaBandiMetin': Color(0xFFB5E3D8),
    'markaBandiVurgu': Color(0xFF5CEBC6),
    'uyari': Color(0xFF8A4B00),
    'uyariYuzey': Color(0xFFFDF1E2),
    'uyariKenar': Color(0xFFF2C894),
    'tehlike': Color(0xFF9A2A1C),
    'tehlikeYuzey': Color(0xFFFCEDEA),
    'bilgi': Color(0xFF1F4E8C),
    'bilgiYuzey': Color(0xFFE8F0FB),
  });
  static const koyu = YbRenkler._({
    'raporYuzey': Color(0xFF142923),
    'raporKenar': Color(0xFF325448),
    'raporKoyu': Color(0xFF073B2F),
    'vurgu': Color(0xFFFF8A57),
    'vurguMetin': Color(0xFFFFA57D),
    'vurguYuzey': Color(0xFF3B2016),
    'vurguKenar': Color(0xFF8A4326),
    'vurguBant': Color(0xFFFF8A57),
    'lokalYuzey': Color(0xFF241A0B),
    'lokalKenar': Color(0xFF6B4A16),
    'boyaliYuzey': Color(0xFF6B4A16),
    'boyaliKenar': Color(0xFFB8812F),
    'degisenYuzey': Color(0xFFE9A23B),
    'degisenMetin': Color(0xFF04201C),
    'cam': Color(0xFF253230),
    'beyaz': Color(0xFFFFFFFF),
    'zemin': Color(0xFF0D1312),
    'yuzey': Color(0xFF151D1C),
    'yuzeyIkincil': Color(0xFF1C2625),
    'metin': Color(0xFFEAF0EF),
    'metinIkincil': Color(0xFF9DADAA),
    'metinGovde': Color(0xFFB7C4C1),
    'ikonPasif': Color(0xFF9DADAA),
    'kenarlik': Color(0xFF1F2928),
    'ayirici': Color(0xFF222D2C),
    'girdiKenarlik': Color(0xFF2A3735),
    'birincil': Color(0xFF2ED9B8),
    'birincilUstu': Color(0xFF04201C),
    'birincilMetin': Color(0xFF55E3C6),
    'birincilYuzey': Color(0xFF0E3A31),
    'birincilAcik': Color(0xFF1C7F6C),
    'markaBandi': Color(0xFF0D1312),
    'markaBandiMetin': Color(0xFF9DADAA),
    'markaBandiVurgu': Color(0xFF2ED9B8),
    'uyari': Color(0xFFF0B458),
    'uyariYuzey': Color(0xFF241A0B),
    'uyariKenar': Color(0xFF6B4A16),
    'tehlike': Color(0xFFF29A8C),
    'tehlikeYuzey': Color(0xFF2A1613),
    'bilgi': Color(0xFF8FB8F0),
    'bilgiYuzey': Color(0xFF14202F),
  });

  @override
  YbRenkler copyWith({Map<String, Color>? values}) =>
      YbRenkler._({..._values, ...?values});
  @override
  YbRenkler lerp(covariant YbRenkler? other, double t) => other == null
      ? this
      : YbRenkler._({
          for (final key in _values.keys)
            key: Color.lerp(_values[key], other._values[key], t)!,
        });
  static YbRenkler of(BuildContext context) =>
      Theme.of(context).extension<YbRenkler>() ??
      (Theme.of(context).brightness == Brightness.dark ? koyu : acik);
}

extension YbRenkBaglami on BuildContext {
  YbRenkler get renkler => YbRenkler.of(this);
}
