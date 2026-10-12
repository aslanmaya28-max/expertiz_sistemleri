import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak_sistemleri/models/expertiz/tam_rapor_model.dart';
import 'package:yerimebak_sistemleri/models/expertiz/adim1_arac_satici_model.dart';
import 'package:yerimebak_sistemleri/models/expertiz/adim2_dis_ekspertiz_model.dart';
import 'package:yerimebak_sistemleri/models/expertiz/adim3_ic_ekspertiz_model.dart';
import 'package:yerimebak_sistemleri/models/expertiz/adim4_boya_kaporta_model.dart';
import 'package:yerimebak_sistemleri/models/expertiz/adim5_kurumsal_ekspertiz_model.dart';
import 'dart:convert';
import 'package:yerimebak_sistemleri/services/rapor_service.dart';

/// inspection_to_ai_analiz() (backend) çıktısından alınmış örnek.
const _merkeziAiJson = r'''{"gorevId": "r-1", "analizZamani": "2026-10-12T19:12:11.797575", "skorlar": {"aracDurumuPuan": 100.0, "motorMekanikPuan": 75.0, "hasarPuan": 100.0, "genelPuan": 91.2, "detayliPuanlar": {"toplamDegerKaybiYuzde": 0.0, "guvenSkoru": 75.0, "boyaliParca": 0.0, "degisenParca": 0.0, "yapisalIslem": 0.0}, "hesaplamaZamani": "2026-10-12T19:12:11.797550", "puanDegerlendirmesi": "Mükemmel Durum", "puanRengi": "Green"}, "oneriler": [{"kategori": "Öneri", "baslik": "Mekanik test önerilir", "aciklama": "Raporda motor/şanzıman değerlendirmesi bulunmuyor; mekanik puan nötr kabul edildi", "onerilenEylem": "Kurumsal ekspertizde motor, şanzıman ve OBD testi yaptırın", "oncelik": 5, "onemDerecesi": "Orta", "ilgiliAdim": 5, "ilgiliAlan": "mekanik", "olusturmaZamani": "2026-10-12T19:12:11.797550", "hedef": "herkes"}, {"kategori": "Öneri", "baslik": "Fiyat uygun", "aciklama": "İlan fiyatı ekspertiz sonucuyla uyumlu", "onerilenEylem": "Belgeler (ruhsat, tramer, bakım) teyit edilerek alım değerlendirilebilir", "oncelik": 7, "onemDerecesi": "Düşük", "ilgiliAdim": null, "ilgiliAlan": null, "olusturmaZamani": "2026-10-12T19:12:11.797550", "hedef": "herkes"}], "raporOzeti": {"genelSonuc": "Mükemmel", "anahtarBulgular": ["Temiz piyasa değeri: 1.000.000 TL", "Değer kaybettiren bulgu tespit edilmedi", "Ekspertiz düzeltmeli değer: 1.000.000 TL", "İlan fiyatı: 1.000.000 TL (İlan fiyatı ekspertiz sonucuyla uyumlu)"], "ozetAciklama": "Ekspertizde kaporta işlemi tespit edilmedi; bulguların toplam değer kaybı %0,0. Temiz piyasa değeri 1.000.000 TL üzerinden bulgular düşülerek aracın değeri 1.000.000 TL olarak belirlendi (adil aralık 940.000 TL – 1.060.000 TL). İlan fiyatı 1.000.000 TL (%+0,0): İlan fiyatı ekspertiz sonucuyla uyumlu.", "onayRedOnerisi": "Alınabilir — fiyat ekspertiz sonucuyla uyumlu", "tahminiDeger": 1000000.0, "degerKaybiYuzde": 0.0, "degerProjeksiyonu1Yil": 0.0, "altiAylikGetiri": 0.0, "olusturmaZamani": "2026-10-12T19:12:11.797550"}, "kritikSorunlar": [], "fotografAnalizi": {}, "finansalProjeksiyonlar": {"ai_piyasa_degeri": 1000000.0, "ai_deger": 1000000.0, "ai_onerilen_alim_fiyati": 970000.0, "ai_adil_fiyat_min": 940000.0, "ai_adil_fiyat_max": 1060000.0, "ai_deger_kaybi": 0.0, "ai_deger_kaybi_tutar": 0.0, "ilan_fiyati": 1000000.0}, "tamamlandiMi": true, "hataMesaji": null, "ekspertizDegerleme": {"modelVersiyonu": "ekspertiz-degerleme-2026.10", "degerlemeYapildi": true, "toplamDegerKaybiYuzde": 0, "kategoriKayiplari": {}, "hasarSeviyesi": "NONE", "agirHasar": false, "boyaliParcaSayisi": 0, "degisenParcaSayisi": 0, "yapisalIslemSayisi": 0, "aracYasi": 2, "yasKmKatsayisi": 1.0, "kayipTavaniUygulandi": false, "doldurulanBolumler": [], "skorlar": {"aracDurumuPuan": 100.0, "motorMekanikPuan": 75.0, "hasarPuan": 100.0, "genelPuan": 91.2, "mekanikVeriVar": false}, "ilanFiyati": 1000000, "piyasaDegeri": 1000000, "temizPiyasaDegeri": 1000000, "piyasaYontemi": "Hasarsız (boyasız/değişensiz) emsal ilanların medyanı", "piyasaDuzeltmeleri": [], "toplamDegerKaybiTutar": 0, "aiDegeri": 1000000, "adilFiyatAraligi": {"min": 940000, "max": 1060000}, "onerilenAlimFiyati": 970000, "guvenSkoru": 75, "eskiPiyasaVerisi": false, "fiyatYorumu": {"karar": "MAKUL", "aciklama": "İlan fiyatı ekspertiz sonucuyla uyumlu", "farkYuzde": 0.0, "farkTutar": 0}, "kalemler": [], "ozet": "Ekspertizde kaporta işlemi tespit edilmedi; bulguların toplam değer kaybı %0,0. Temiz piyasa değeri 1.000.000 TL üzerinden bulgular düşülerek aracın değeri 1.000.000 TL olarak belirlendi (adil aralık 940.000 TL – 1.060.000 TL). İlan fiyatı 1.000.000 TL (%+0,0): İlan fiyatı ekspertiz sonucuyla uyumlu."}, "arac": {"marka": "Fiat", "model": "Egea", "yil": 2020, "km": 50000}}''';

TamRaporModel _rapor() => TamRaporModel(
  gorevId: 'test-001',
  personelId: 'personel-001',
  adim1: Adim1AracSaticiModel(
    gorevId: 'test-001',
    personelId: 'personel-001',
    marka: 'Renault',
    model: 'Megane',
    yakitTuru: 'Dizel',
    plaka: '34 ABC 123',
    saseNo: 'TESTSASE001',
    motorNo: 'TESTMOTOR001',
    guncelKm: 85000,
    hasarKayitAdet: 0,
    hasarKayitToplamTutar: 0,
    ruhsatSahibiAdSoyad: 'Test Kullanici',
    iletisimTelefon: '05000000000',
    paket: 'Standart',
  ),
  adim2: Adim2DisEkspertizModel.empty(
    gorevId: 'test-001',
    personelId: 'personel-001',
  ),
  adim3: Adim3IcEkspertizModel.empty(
    gorevId: 'test-001',
    personelId: 'personel-001',
  ),
  adim4: Adim4BoyaKaportaModel(
    gorevId: 'test-001',
    personelId: 'personel-001',
    boyaliParcalar: ['Sag On Kaporta'],
    degisenParcalar: [],
    hasarKayitlari: [],
  ),
  adim5: Adim5KurumsalEkspertizModel.empty(
    gorevId: 'test-001',
    personelId: 'personel-001',
  ),
  durum: 'AnalizEdiliyor',
  baslangicZamani: DateTime.now(),
  bitisZamani: null,
  genelNot: '',
  oneriler: '',
  genelPuan: 0,
);

void main() {
  test('merkezi AI sonucu data.ai_analiz_sonucu alanindan rapora eklenir', () {
    final row = {
      'id': 'report-42',
      'data': {
        'tam_rapor': _rapor().toJson(),
        'ai_analiz_sonucu': jsonDecode(_merkeziAiJson),
      },
      'ai_analiz_detay': null,
    };

    final rapor = RaporService.tamRaporFromRow(row);

    expect(rapor, isNotNull);
    expect(rapor!.gorevId, 'report-42');
    expect(rapor.aiAnalizSonucu, isNotNull);
    expect(rapor.aiAnalizSonucu!.tamamlandiMi, isTrue);
    expect(rapor.aiAnalizSonucu!.skorlar.genelPuan, greaterThan(0));
  });

  test('data icinde yoksa ai_analiz_detay kolonu kullanilir', () {
    final row = {
      'id': 'report-43',
      'data': {'tam_rapor': _rapor().toJson()},
      'ai_analiz_detay': jsonDecode(_merkeziAiJson),
    };

    expect(RaporService.tamRaporFromRow(row)?.aiAnalizSonucu, isNotNull);
  });

  test('AI sonucu olmayan rapor AI sonucusuz doner, tam_rapor yoksa null', () {
    expect(
      RaporService.tamRaporFromRow({
        'id': 'r',
        'data': {'tam_rapor': _rapor().toJson()},
      })?.aiAnalizSonucu,
      isNull,
    );
    expect(RaporService.tamRaporFromRow({'id': 'r', 'data': {}}), isNull);
  });
}
