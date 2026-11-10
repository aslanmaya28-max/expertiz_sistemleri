import 'dart:math';
import '../api/api_client.dart';
import '../api/models.dart';
import 'arac_formu.dart';

/// Sunucunun ilan çıkarım yanıtı (`/valuation/prefill`, `/valuation/prefill-text`).
class OnDoldurma {
  final Map<String, dynamic> arac;
  final Map<String, String> parcalar;
  final Set<String> dogrulanan;
  final int dogrulananSayisi;
  final String mesaj;
  const OnDoldurma(this.arac, this.parcalar, this.dogrulanan, this.dogrulananSayisi, this.mesaj);

  factory OnDoldurma.fromJson(Json d) {
    final alanlar = object(d['fields']);
    return OnDoldurma(
      object(d['vehicle']),
      {for (final e in object(d['parts']).entries) e.key: text(e.value)},
      {for (final e in alanlar.entries) if (object(e.value)['dogrulandi'] == true) e.key},
      integer(d['verified_count']),
      text(d['message']),
    );
  }

  /// Yeterli mi: marka, model, yıl ve fiyat okunduysa form doğrudan açılabilir.
  bool get yeterli => ['brand', 'model', 'year', 'price'].every((k) => text(arac[k]).isNotEmpty);

  /// Forma aktarır; okunan alanlar "İlandan" etiketi alır.
  AracFormu forma(String link) {
    String y(String k) => text(arac[k]).trim();
    String r(String k) => sadeceRakam(text(arac[k]));
    const eslesme = {
      'brand': 'marka', 'model': 'model', 'package': 'paket', 'year': 'yil', 'km': 'km',
      'price': 'fiyat', 'fuel': 'yakit', 'transmission': 'vites', 'hp': 'hp', 'tramer_amount': 'tramer',
    };
    return AracFormu(
      link: link,
      marka: y('brand'),
      model: y('model'),
      paket: y('package'),
      yil: r('year'),
      km: r('km'),
      fiyat: r('price'),
      yakit: y('fuel'),
      vites: y('transmission'),
      hp: r('hp'),
      tramer: r('tramer_amount'),
      ilandanOkunan: {
        for (final e in eslesme.entries)
          if (dogrulanan.contains(e.key) && text(arac[e.key]).isNotEmpty) e.value,
        if (parcalar.isNotEmpty) 'parcalar',
      },
      parcalar: {
        for (final e in parcalar.entries)
          if (parcaDurumlari.contains(e.value)) e.key: e.value,
      },
    );
  }
}

class Parca {
  final String anahtar, ad;
  const Parca(this.anahtar, this.ad);
}

class KasaSecenegi {
  final String kod, ad;
  const KasaSecenegi(this.kod, this.ad);
}

class AnalizSonucu {
  final String raporId;
  final int? kalanKredi;
  const AnalizSonucu(this.raporId, this.kalanKredi);
}

const baglantiKoptuMesaji =
    'Sunucuyla bağlantı koptu. Raporunuz hazırlanmış olabilir; birkaç dakika sonra Raporlarım bölümünden kontrol edin. '
    'Kredi yalnız rapor üretildiyse düşer.';

/// Yalnız taşıma hataları yeniden denenir: ağ hatası, zaman aşımı ya da kodsuz 502–504.
bool yenidenDenenebilir(Object hata) =>
    hata is ApiFailure &&
    hata is! InsufficientCredits &&
    (hata.status == 0 || (hata.status >= 502 && hata.status <= 504 && hata.code == null));

class AnalizRepository {
  final ApiClient api;
  final Future<void> Function(Duration) bekle;
  AnalizRepository(this.api, {Future<void> Function(Duration)? bekle})
    : bekle = bekle ?? Future.delayed;

  Future<OnDoldurma> linktenOku(String link) async => OnDoldurma.fromJson(
    await api.get('/valuation/prefill?url=${Uri.encodeQueryComponent(link)}'),
  );

  /// Telefonda ilan metni kopyalanamıyor (Sahibinden): ilanın 1–4 ekran görüntüsünden okunur.
  /// Sitedeki "Ekran görüntüsü yükle" ile aynı uç (08.11.2026; uygulama 11.11.2026).
  Future<OnDoldurma> ekrandanOku(List<DosyaParcasi> dosyalar) async =>
      OnDoldurma.fromJson(
        await api.postDosyalar(
          '/valuation/prefill-screenshot',
          dosyalar,
          timeout: const Duration(seconds: 120),
        ),
      );

  Future<OnDoldurma> metindenOku(String metin) async => OnDoldurma.fromJson(
    await api.post('/valuation/prefill-text', {'text': metin}, timeout: const Duration(seconds: 90)),
  );

  Future<List<Parca>> parcalar() async => objects((await api.get('/valuation/parts'))['parts'])
      .map((p) => Parca(text(p['key']), text(p['label'])))
      .where((p) => p.anahtar.isNotEmpty)
      .toList();

  /// Yıl bir kasa geçiş yılıysa iki seçenek; değilse boş liste.
  Future<List<KasaSecenegi>> kasaSecenekleri(String marka, String model, String yil) async {
    final q = 'brand=${Uri.encodeQueryComponent(marka)}&model=${Uri.encodeQueryComponent(model)}'
        '&year=${Uri.encodeQueryComponent(yil)}';
    final d = await api.get('/valuation/generation?$q');
    if (d['gecisYili'] != true) return const [];
    return objects(d['secenekler']).map((s) {
      final bas = text(s['baslangic']), bit = text(s['bitis']);
      final aralik = bas.isEmpty ? '' : ' ($bas–${bit.isEmpty ? 'günümüz' : bit})';
      final ad = text(s['kasa']).isEmpty ? (s['kod'] == 'eski' ? 'Önceki kasa' : 'Yeni kasa') : text(s['kasa']);
      return KasaSecenegi(text(s['kod']), '$ad$aralik');
    }).where((s) => s.kod == 'yeni' || s.kod == 'eski').toList();
  }

  /// Aynı [istekNo] ile tekrar denemek raporu yeniden üretmez, krediyi ikinci kez düşmez.
  Future<AnalizSonucu> analizEt(AracFormu form, String istekNo, {int deneme = 6}) async {
    for (var i = 1; ; i++) {
      try {
        final d = await api.post(
          '/valuation/analyze',
          form.istek(istekNo),
          timeout: const Duration(seconds: 200),
        );
        final id = text(object(d['rapor'])['id']);
        if (id.isEmpty) throw const ApiFailure('Rapor kaydedilemedi. Raporlarım bölümünü kontrol edin.');
        final kredi = object(d['kredi'])['kalan'];
        return AnalizSonucu(id, kredi is num ? kredi.toInt() : null);
      } catch (e) {
        if (!yenidenDenenebilir(e)) rethrow;
        if (i >= deneme) throw const ApiFailure(baglantiKoptuMesaji, code: 'baglanti_koptu');
        await bekle(const Duration(seconds: 4));
      }
    }
  }
}

/// RFC 4122 sürüm 4 istek numarası (sunucu UUID bekler).
String yeniIstekNo([Random? rastgele]) {
  final r = rastgele ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  final s = List.generate(16, h).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}
