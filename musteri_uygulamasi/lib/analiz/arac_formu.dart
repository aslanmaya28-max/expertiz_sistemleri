import 'arac_katalogu.dart';

/// Web'deki `lib/aracFormu.ts` ile aynı kurallar. Uygulama rapor rakamı hesaplamaz;
/// burada yalnız form girdisi düzenlenir ve sunucunun da yaptığı sınır kontrolü kredi düşmeden önce gösterilir.

final List<String> markalar = aracKatalogu.keys.toList()..sort(_trKarsilastir);

int _trKarsilastir(String a, String b) => sadelestir(a).compareTo(sadelestir(b));

/// Türkçe ve aksanlı harfleri sadeleştirir (Ş→s, İ/ı→i, ë→e ...); arama ve eşleme için.
String sadelestir(String metin) {
  const harita = {
    'İ': 'i', 'I': 'i', 'ı': 'i', 'Ş': 's', 'ş': 's', 'Ğ': 'g', 'ğ': 'g',
    'Ü': 'u', 'ü': 'u', 'Ö': 'o', 'ö': 'o', 'Ç': 'c', 'ç': 'c', 'Â': 'a',
    'â': 'a', 'Ë': 'e', 'ë': 'e', 'É': 'e', 'é': 'e', 'Š': 's', 'š': 's',
    'Č': 'c', 'č': 'c', 'Ž': 'z', 'ž': 'z', 'Á': 'a', 'á': 'a', 'Ó': 'o',
    'ó': 'o', 'Í': 'i', 'í': 'i', 'Ú': 'u', 'ú': 'u',
  };
  final b = StringBuffer();
  for (final r in metin.runes) {
    final c = String.fromCharCode(r);
    b.write(harita[c] ?? c.toLowerCase());
  }
  return b
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9#]+'), ' ')
      .trim();
}

/// Önce başı (ya da bir kelimesinin başı) eşleşenler, sonra içinde geçenler.
List<String> katalogAra(List<String> secenekler, String sorgu, {int sinir = 50}) {
  final s = sadelestir(sorgu);
  if (s.isEmpty) return secenekler.take(sinir).toList();
  final bas = <String>[], ic = <String>[];
  for (final secenek in secenekler) {
    final d = sadelestir(secenek);
    if (d.startsWith(s) || d.split(' ').any((k) => k.startsWith(s))) {
      bas.add(secenek);
    } else if (d.replaceAll(' ', '').contains(s.replaceAll(' ', ''))) {
      ic.add(secenek);
    }
  }
  return [...bas, ...ic].take(sinir).toList();
}

/// Markanın katalogdaki modelleri ("mercedes", "Škoda" gibi yazımlar da bulunur).
List<String> modelleri(String marka) {
  final s = sadelestir(marka);
  if (s.isEmpty) return const [];
  for (final m in markalar) {
    final d = sadelestir(m);
    if (d == s || d.replaceAll(' ', '') == s.replaceAll(' ', '')) {
      return aracKatalogu[m]!;
    }
  }
  return const [];
}

/// Yalnız rakamlar ("24.000 km" → "24000"); baştaki sıfırlar atılır.
String sadeceRakam(String metin, {int enFazlaHane = 12}) {
  final r = metin.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+(?=\d)'), '');
  return r.length > enFazlaHane ? r.substring(0, enFazlaHane) : r;
}

/// "24000" → "24.000" (yalnız gösterim).
String binlikNokta(String rakamlar) =>
    rakamlar.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

/// Gönderimden önce kısa kontrol; sunucu aynı sınırları kredi düşmeden denetler.
String? formHatasi({required String yil, required String km, required String fiyat, int? buYil}) {
  final yilSiniri = (buYil ?? DateTime.now().year) + 1;
  final y = int.tryParse(yil) ?? 0;
  if (yil.isEmpty || y < 1980 || y > yilSiniri) {
    return 'Model yılı 1980 ile $yilSiniri arasında olmalı.';
  }
  if ((int.tryParse(km) ?? 0) > 2000000) return 'Kilometre en fazla 2.000.000 olabilir.';
  final f = int.tryParse(fiyat) ?? 0;
  if (fiyat.isEmpty || f < 10000 || f > 200000000) {
    return 'İlan fiyatı 10.000 TL ile 200.000.000 TL arasında olmalı.';
  }
  return null;
}

/// Kaporta durumları; anahtarlar sunucunun `/valuation/parts` yanıtıyla aynıdır.
const parcaDurumlari = ['orijinal', 'lokal_boyali', 'boyali', 'degisen'];
const parcaDurumAdlari = {
  'orijinal': 'Orijinal',
  'lokal_boyali': 'Lokal boyalı',
  'boyali': 'Boyalı',
  'degisen': 'Değişen',
};

/// Formun değerleri. Rakam alanlarında yalnız rakamlar tutulur (binlik nokta gösterimdedir).
class AracFormu {
  String link, marka, model, paket, yil, km, fiyat, yakit, vites, hp, tramer;
  /// Sunucudan gelen ön doldurma kaynakları: alan → "ilandan" gibi etiket gösterimi için.
  final Set<String> ilandanOkunan;
  final Map<String, String> parcalar;
  String? kasa;

  AracFormu({
    this.link = '',
    this.marka = '',
    this.model = '',
    this.paket = '',
    this.yil = '',
    this.km = '',
    this.fiyat = '',
    this.yakit = '',
    this.vites = '',
    this.hp = '',
    this.tramer = '',
    Set<String>? ilandanOkunan,
    Map<String, String>? parcalar,
    this.kasa,
  }) : ilandanOkunan = ilandanOkunan ?? <String>{},
       parcalar = parcalar ?? <String, String>{};

  String? get hata {
    final h = formHatasi(yil: yil, km: km, fiyat: fiyat);
    if (h != null) return h;
    final g = int.tryParse(hp);
    if (hp.isNotEmpty && (g == null || g < 40 || g > 800)) {
      return 'Motor gücü 40 ile 800 hp arasında olmalı ya da boş kalmalı.';
    }
    if (marka.trim().isEmpty || model.trim().isEmpty) return 'Marka ve modeli girin.';
    return null;
  }

  /// Sunucunun `ValuationRequest` gövdesi. [istekNo] aynı kalırsa sunucu krediyi ikinci kez düşmez.
  Map<String, Object?> istek(String istekNo) {
    int? sayi(String v) => v.isEmpty ? null : int.tryParse(v);
    String? yazi(String v) => v.trim().isEmpty ? null : v.trim();
    final govde = <String, Object?>{
      'request_id': istekNo,
      'listing_url': yazi(link),
      'brand': yazi(marka),
      'model': yazi(model),
      'package': yazi(paket),
      'hp': sayi(hp),
      'year': sayi(yil),
      'km': sayi(km),
      'listed_price': sayi(fiyat),
      'fuel': yazi(yakit),
      'transmission': yazi(vites),
      'parts': {
        for (final e in parcalar.entries)
          if (e.value != 'orijinal') e.key: e.value,
      },
      'tramer_amount': sayi(tramer) ?? 0,
      'kasa': kasa,
    };
    govde.removeWhere((_, v) => v == null);
    return govde;
  }
}
