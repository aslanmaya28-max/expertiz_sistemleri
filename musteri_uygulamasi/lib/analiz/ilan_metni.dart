import 'dart:convert';

/// İlan linki ve sayfa metniyle ilgili saf işlevler (ağ ve arayüz yok; test edilebilir).

/// Paylaşılan metinden ("Bu ilana bak: https://...") ilk web adresini çıkarır.
Uri? paylasimdanLink(String metin) {
  final m = RegExp(r'https?://[^\s<>"\x27]+', caseSensitive: false).firstMatch(metin);
  if (m == null) return null;
  var adres = m.group(0)!;
  // Cümle sonundaki noktalama linke dahil değildir.
  adres = adres.replaceFirst(RegExp(r'[.,;:!?)\]}»”]+$'), '');
  final uri = Uri.tryParse(adres);
  if (uri == null || !uri.hasAuthority || uri.userInfo.isNotEmpty) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return uri;
}

bool sahibindenMi(Uri uri) {
  final h = uri.host.toLowerCase();
  return h == 'sahibinden.com' || h.endsWith('.sahibinden.com');
}

enum SayfaDurumu { yukleniyor, ilanHazir, dogrulamaGerekli }

/// Türkçe küçük harf; uzunluk korunur (Dart'ın toLowerCase'i "İ"yi iki karakterli "i̇" yapar).
String _kucuk(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

/// Görünmeyen WebView'deki sayfanın durumu: ilan bilgileri geldi mi, doğrulama sayfası mı?
SayfaDurumu sayfaDurumu(String metin) {
  final k = _kucuk(metin);
  const dogrulama = [
    'robot değilim', 'güvenlik doğrulaması', 'güvenlik kontrolü', 'captcha',
    'just a moment', 'verify you are human', 'access denied', 'erişiminiz engellendi',
    'olağan dışı trafik', 'olağandışı trafik',
  ];
  // Liste ve arama sayfalarında da "marka", "model", "km" geçer; ilan sayfasını ilan numarası/tarihi ayırır.
  final ilanIsareti = RegExp(r'ilan (no|numarası)\s*:?\s*\d{5,}').hasMatch(k) ||
      (k.contains('ilan tarihi') && (k.contains('ilan no') || k.contains('ilan bilgileri')));
  if (ilanIsareti && metin.length > 400) return SayfaDurumu.ilanHazir;
  if (dogrulama.any(k.contains)) return SayfaDurumu.dogrulamaGerekli;
  return SayfaDurumu.yukleniyor;
}

/// WebView `runJavaScriptReturningResult` Android'de metni JSON dizesi olarak döndürür ("\"...\"").
String jsSonucunuCoz(Object? sonuc) {
  if (sonuc is! String) return '';
  final s = sonuc.trim();
  if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
    try {
      final v = jsonDecode(s);
      if (v is String) return v;
    } on FormatException {
      return '';
    }
  }
  return s == 'null' ? '' : s;
}

/// Sayfa metnini sunucunun `prefill-text` sınırına (8000) indirir. İlan bilgisi bloğu öne alınır;
/// boya-değişen, tramer ve hasar satırları sınırın dışında kalsa da eklenir (ilanın en değerli kısmı).
String ilanMetniniKirp(String metin, {int sinir = 8000}) {
  final satirlar = <String>[];
  for (final ham in metin.split(RegExp(r'\r?\n'))) {
    final s = ham.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty || (satirlar.isNotEmpty && satirlar.last == s)) continue;
    satirlar.add(s);
  }
  final tumu = satirlar.join('\n');
  if (tumu.length <= sinir) return tumu;

  final kucuk = _kucuk(tumu);
  const capalar = ['ilan bilgileri', 'ilan no', 'ilan tarihi', 'marka', 'fiyat'];
  var bas = -1;
  for (final c in capalar) {
    final i = kucuk.indexOf(c);
    if (i >= 0 && (bas < 0 || i < bas)) bas = i;
  }
  // Başlık ve fiyat çoğu sayfada ilan bilgilerinin hemen üstündedir.
  final baslangic = bas < 0 ? 0 : (bas - 600).clamp(0, tumu.length);

  final hasarSatirlari = satirlar
      .where((s) => RegExp(r'boya|değişen|degisen|tramer|hasar|orijinal', caseSensitive: false).hasMatch(s))
      .toList();
  final ek = hasarSatirlari.join('\n');
  final yer = (sinir - ek.length - 1).clamp(sinir ~/ 2, sinir);
  var govde = tumu.substring(baslangic);
  if (govde.length > yer) govde = govde.substring(0, yer);
  final eksikler = hasarSatirlari.where((s) => !govde.contains(s)).join('\n');
  final sonuc = eksikler.isEmpty ? govde : '$govde\n$eksikler';
  return sonuc.length <= sinir ? sonuc : sonuc.substring(0, sinir);
}
