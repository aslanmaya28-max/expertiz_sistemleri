import '../../models/expertiz/adim1_arac_satici_model.dart';
import '../../models/expertiz/adim2_dis_ekspertiz_model.dart';
import '../../models/expertiz/adim3_ic_ekspertiz_model.dart';
import '../../models/expertiz/adim4_boya_kaporta_model.dart';
import '../../models/expertiz/adim5_kurumsal_ekspertiz_model.dart';
import '../../models/expertiz/durum_enum.dart';
import '../../models/ai/ai_oneri_model.dart';

/// AI Oneri Servisi
/// Araç ekspertizinde öneriler üretir
class AIOneriService {
  /// Kritik sorunları tespit et
  static List<String> tespitKritikSorunlar({
    required Adim1AracSaticiModel adim1,
    required Adim2DisEkspertizModel adim2,
    required Adim3IcEkspertizModel adim3,
    required Adim4BoyaKaportaModel adim4,
    required Adim5KurumsalEkspertizModel adim5,
  }) {
    List<String> kritikSorunlar = [];

    // Adım 1: Kritik sorunlar
    if (adim1.hasarKayitAdet != null && adim1.hasarKayitAdet! > 0) {
      kritikSorunlar.add('${adim1.hasarKayitAdet} adet hasar kaydı var');
    }
    if (adim1.hasarKayitToplamTutar != null && adim1.hasarKayitToplamTutar! > 50000) {
      kritikSorunlar.add('Hasar tutarı yüksek: ₺${adim1.hasarKayitToplamTutar}');
    }

    // Adım 2: Kritik sorunlar
    if (adim2.fotografUrl != null) {
      for (final soru in adim2.fotografUrl!.entries) {
        if (soru.value.isEmpty) {
          kritikSorunlar.add('${soru.key} için fotoğraf yok');
        }
      }
    }

    // Adım 3: Kritik sorunlar
    if (adim3.fotografUrl != null) {
      for (final soru in adim3.fotografUrl!.entries) {
        if (soru.value.isEmpty) {
          kritikSorunlar.add('${soru.key} için fotoğraf yok');
        }
      }
    }

    // Adım 4: Kritik sorunlar
    if (adim4.hasarSayisi > 3) {
      kritikSorunlar.add('Çok fazla hasar: ${adim4.hasarSayisi} adet');
    }
    for (final hasar in adim4.hasarKayitlari) {
      if (hasar.buyukluk == 'Çok Büyük') {
        kritikSorunlar.add('Çok büyük hasar: ${hasar.konum} - ${hasar.tip}');
      }
    }

    // Adım 5: Kritik sorunlar
    int eksikDosya = 0;
    if (adim5.ruhsatDosyasiVar != true) eksikDosya++;
    if (adim5.bakimDefteriVar != true) eksikDosya++;
    if (adim5.sigortaPolicesiVar != true) eksikDosya++;
    if (adim5.muayeneBelgesiVar != true) eksikDosya++;

    if (eksikDosya > 2) {
      kritikSorunlar.add('$eksikDosya adet dosya eksik');
    }

    // Adım 1-4'teki ağır hasarlar
    for (final soru in adim1.durumSorular) {
      if (soru.durum == Durum.agirHasar) {
        kritikSorunlar.add('Ağır hasar: ${soru.soru}');
      }
    }

    return kritikSorunlar;
  }

  /// Öneriler üret
  static List<AIOneriModel> uretOneriler({
    required Adim1AracSaticiModel adim1,
    required Adim2DisEkspertizModel adim2,
    required Adim3IcEkspertizModel adim3,
    required Adim4BoyaKaportaModel adim4,
    required Adim5KurumsalEkspertizModel adim5,
    required double genelPuan,
  }) {
    List<AIOneriModel> oneriler = [];

    // Kritik öneriler
    if (adim1.hasarKayitAdet != null && adim1.hasarKayitAdet! > 0) {
      oneriler.add(AIOneriModel(
        kategori: 'Kritik',
        baslik: 'Hasar Kaydı Var',
        aciklama: 'Araçta ${adim1.hasarKayitAdet} adet hasar kaydı bulunuyor.',
        onerilenEylem: 'Hasar detaylarını kontrol edin',
        oncelik: 1,
        ilgiliAdim: 1,
        ilgiliAlan: 'hasarKayitAdet',
      ));
    }

    if (adim4.hasarSayisi > 3) {
      oneriler.add(AIOneriModel(
        kategori: 'Kritik',
        baslik: 'Çok Fazla Hasar',
        aciklama: 'Araçta ${adim4.hasarSayisi} adet hasar bulunuyor.',
        onerilenEylem: 'Detaylı hasar analizi yapın',
        oncelik: 1,
        ilgiliAdim: 4,
        ilgiliAlan: 'hasarKayitlari',
      ));
    }

    // Önemli öneriler
    for (final soru in adim1.durumSorular) {
      if (soru.durum == Durum.kotu || soru.durum == Durum.sorunlu) {
        oneriler.add(AIOneriModel(
          kategori: 'Önemli',
          baslik: 'Düşük Puanlı Alan',
          aciklama: '${soru.soru} alanı düşük puan aldı.',
          onerilenEylem: 'Bu alanı detaylı inceleyin',
          oncelik: 3,
          ilgiliAdim: 1,
          ilgiliAlan: soru.soru,
        ));
      }
    }

    for (final hasar in adim4.hasarKayitlari) {
      if (hasar.buyukluk == 'Büyük' || hasar.buyukluk == 'Çok Büyük') {
        oneriler.add(AIOneriModel(
          kategori: 'Önemli',
          baslik: 'Büyük Hasar Tespiti',
          aciklama: '${hasar.konum} alanında ${hasar.buyukluk} boyutunda hasar var.',
          onerilenEylem: 'Profesyonel onarım önerilir',
          oncelik: 2,
          ilgiliAdim: 4,
          ilgiliAlan: hasar.konum,
        ));
      }
    }

    // Bakım önerileri
    if (adim5.motorDurumu == 'Kötü' || adim5.motorDurumu == 'Ağır Hasar') {
      oneriler.add(AIOneriModel(
        kategori: 'Önemli',
        baslik: 'Motor Sorunu',
        aciklama: 'Motor durumunda sorun tespit edildi.',
        onerilenEylem: 'Motor servisi kontrolü önerilir',
        oncelik: 2,
        ilgiliAdim: 5,
        ilgiliAlan: 'motorDurumu',
      ));
    }

    if (adim5.sanzimanDurumu == 'Kötü' || adim5.sanzimanDurumu == 'Ağır Hasar') {
      oneriler.add(AIOneriModel(
        kategori: 'Önemli',
        baslik: 'Şanziman Sorunu',
        aciklama: 'Şanziman durumunda sorun tespit edildi.',
        onerilenEylem: 'Şanziman servisi kontrolü önerilir',
        oncelik: 2,
        ilgiliAdim: 5,
        ilgiliAlan: 'sanzimanDurumu',
      ));
    }

    // Fiyatlandırma önerileri
    if (adim4.hasarSayisi > 0) {
      double hasarTutari = 0.0;
      for (final hasar in adim4.hasarKayitlari) {
        // Hasar tipine göre tahmini tutar
        switch (hasar.tip) {
          case 'Çizik':
            hasarTutari += 500.0;
            break;
          case 'Çökme':
            hasarTutari += 200.0;
            break;
          case 'Göçük':
            hasarTutari += 150.0;
            break;
          case 'Boyasızlık':
            hasarTutari += 100.0;
            break;
          case 'Deformasyon':
            hasarTutari += 250.0;
            break;
          case 'Paslanma':
            hasarTutari += 800.0;
            break;
        }
      }

      if (hasarTutari > 0) {
        oneriler.add(AIOneriModel(
          kategori: 'Öneri',
          baslik: 'Hasar Onarım Tahmini',
          aciklama: 'Hasar onarımı için tahmini tutar: ₺${hasarTutari.toStringAsFixed(0)}',
          onerilenEylem: 'Profesyonel teklif alın',
          oncelik: 5,
          ilgiliAdim: 4,
          ilgiliAlan: 'hasarKayitlari',
        ));
      }
    }

    // Dosya eksikliği önerileri
    int eksikDosya = 0;
    if (adim5.ruhsatDosyasiVar != true) eksikDosya++;
    if (adim5.bakimDefteriVar != true) eksikDosya++;
    if (adim5.sigortaPolicesiVar != true) eksikDosya++;
    if (adim5.muayeneBelgesiVar != true) eksikDosya++;

    if (eksikDosya > 0) {
      oneriler.add(AIOneriModel(
        kategori: 'Önemli',
        baslik: 'Eksik Dosyalar',
        aciklama: '$eksikDosya adet dosya eksik.',
        onerilenEylem: 'Eksik dosyaları tamamlayın',
        oncelik: 3,
        ilgiliAdim: 5,
        ilgiliAlan: 'dosyaKontrolu',
      ));
    }

    // Periyodik bakım önerileri
    if (adim1.guncelKm > 100000) {
      oneriler.add(AIOneriModel(
        kategori: 'Öneri',
        baslik: 'Yüksek Kilometre',
        aciklama: 'Araç kilometresi yüksek (${adim1.guncelKm} km). Periyodik bakım önerilir.',
        onerilenEylem: 'Bakım takvimi oluşturun',
        oncelik: 5,
        ilgiliAdim: 1,
        ilgiliAlan: 'guncelKm',
      ));
    }

    // Genel önerileri
    if (genelPuan < 70) {
      oneriler.add(AIOneriModel(
        kategori: 'Öneri',
        baslik: 'Genel Puan Düşük',
        aciklama: 'Araç genel puanı düşük ($genelPuan). Detaylı inceleme önerilir.',
        onerilenEylem: 'Uzman görüşü alın',
        oncelik: 5,
        ilgiliAdim: 0,
      ));
    }

    return oneriler;
  }

  /// Onay/Red önerisi üret
  static String uretOnayRedOnerisi({
    required double genelPuan,
    required int hasarSayisi,
    required List<String> kritikSorunlar,
  }) {
    // Kritik sorun varsa → Red
    if (kritikSorunlar.isNotEmpty) {
      return 'Red - Kritik sorunlar tespit edildi: ${kritikSorunlar.join(', ')}';
    }

    // Çok fazla hasar varsa → Red
    if (hasarSayisi > 3) {
      return 'Red - Çok fazla hasar ($hasarSayisi adet)';
    }

    // Genel puan düşükse → Dikkat
    if (genelPuan < 60) {
      return 'Dikkat - Genel puan düşük ($genelPuan). Detaylı inceleme önerilir.';
    }

    // Genel puan orta ise → Dikkat
    if (genelPuan < 80) {
      return 'Dikkat - Bazı alanlarda iyileştirme önerilir.';
    }

    // Genel puan yüksekse → Onay
    return 'Onay - Araç genel durumu iyi.';
  }

  /// Değer kaybı hesapla
  static double hesaplaDegerKaybi({
    required Adim4BoyaKaportaModel adim4,
    required double piyasaFiyati,
  }) {
    double hasarTutari = 0.0;

    for (final hasar in adim4.hasarKayitlari) {
      // Hasar tipine göre değer kaybı
      switch (hasar.tip) {
        case 'Çizik':
          hasarTutari += 300.0;
          break;
        case 'Çökme':
          hasarTutari += 150.0;
          break;
        case 'Göçük':
          hasarTutari += 120.0;
          break;
        case 'Boyasızlık':
          hasarTutari += 800.0;
          break;
        case 'Deformasyon':
          hasarTutari += 200.0;
          break;
        case 'Paslanma':
          hasarTutari += 500.0;
          break;
      }
    }

    // Değer kaybı = hasar tutarı / piyasa fiyatı * 100
    double degerKaybi = 0.0;
    if (piyasaFiyati > 0) {
      degerKaybi = (hasarTutari / piyasaFiyati) * 100;
    }

    return degerKaybi.clamp(0.0, 100.0);
  }

  /// 1 yıllık enflasyon korumalı değer projeksiyonu hesapla
  static double hesaplaDegerProjeksiyonu({
    required double mevcutDeger,
    required double enflasyonOrani,
    required int yilSayisi,
  }) {
    // Gelecek değer = mevcut değer * (1 - enflasyon oranı)^yıl sayısı
    double enflasyonFaktoru = 1.0 - (enflasyonOrani / 100.0);
    double gelecekDeger = mevcutDeger * pow(enflasyonFaktoru, yilSayisi);

    return gelecekDeger;
  }

  /// Üs alma fonksiyonu
  static double pow(double base, int exponent) {
    double result = 1.0;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
