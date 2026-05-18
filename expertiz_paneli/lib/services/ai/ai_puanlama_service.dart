import '../../models/expertiz/adim1_arac_satici_model.dart';
import '../../models/expertiz/adim2_dis_ekspertiz_model.dart';
import '../../models/expertiz/adim3_ic_ekspertiz_model.dart';
import '../../models/expertiz/adim4_boya_kaporta_model.dart';
import '../../models/expertiz/adim5_kurumsal_ekspertiz_model.dart';
import '../../models/expertiz/durum_enum.dart';
import '../../models/ai/ai_skor_model.dart';

/// AI Puanlama Servisi
/// Araç ekspertizinde puanlama işlemlerini yönetir
class AIPuanlamaService {
  /// Durum puan ağırlıkları
  static const Map<Durum, double> _durumPuanlari = {
    Durum.mukemmel: 100.0,
    Durum.iyi: 75.0,
    Durum.orta: 50.0,
    Durum.sorunlu: 25.0,
    Durum.kotu: 10.0,
    Durum.agirHasar: 0.0,
  };

  /// Adım 1: Araç ve Satıcı Puanı Hesapla
  static double _hesaplaAdim1Puan(Adim1AracSaticiModel adim1) {
    if (!adim1.isValid) return 0.0;

    double toplamPuan = 0.0;
    int soruSayisi = adim1.durumSorular.length;

    for (final soru in adim1.durumSorular) {
      if (soru.durum != null) {
        toplamPuan += _durumPuanlari[soru.durum!] ?? 0.0;
      }
    }

    // Araç bilgileri puanı (zorunlu alanların dolumu)
    double aracBilgileriPuan = 0.0;
    if (adim1.marka.isNotEmpty) aracBilgileriPuan += 10.0;
    if (adim1.model.isNotEmpty) aracBilgileriPuan += 10.0;
    if (adim1.plaka.isNotEmpty) aracBilgileriPuan += 10.0;
    if (adim1.saseNo.isNotEmpty && adim1.saseNo.length == 17) aracBilgileriPuan += 10.0;
    if (adim1.guncelKm >= 0) aracBilgileriPuan += 10.0;
    if (adim1.ruhsatSahibiAdSoyad.isNotEmpty) aracBilgileriPuan += 10.0;
    if (adim1.iletisimTelefon.isNotEmpty) aracBilgileriPuan += 10.0;

    // Hasar bilgileri puanı (hasar kaydı varsa puan düşür)
    double hasarPuan = 100.0;
    if (adim1.hasarKayitAdet != null && adim1.hasarKayitAdet! > 0) {
      hasarPuan -= (adim1.hasarKayitAdet! * 5.0);
      if (hasarPuan < 0) hasarPuan = 0.0;
    }

    // Ağırlıklı ortalama
    double durumPuan = soruSayisi > 0 ? (toplamPuan / soruSayisi) : 0.0;
    double toplam = (durumPuan * 0.4) + (aracBilgileriPuan * 0.3) + (hasarPuan * 0.3);

    return toplam.clamp(0.0, 100.0);
  }

  /// Adım 2: Dış Ekspertiz Puanı Hesapla
  static double _hesaplaAdim2Puan(Adim2DisEkspertizModel adim2) {
    if (!adim2.isValid) return 0.0;

    double toplamPuan = 0.0;
    int alanSayisi = 14; // Toplam alan sayısı

    // Her alan için puan hesapla
    final alanlar = [
      adim2.onTampon,
      adim2.onFarlar,
      adim2.onCamurluklar,
      adim2.onKaput,
      adim2.arkaTampon,
      adim2.arkaCamurluklar,
      adim2.bagajKapagi,
      adim2.solOnKapi,
      adim2.sagOnKapi,
      adim2.solArkaKapi,
      adim2.sagArkaKapi,
      adim2.tavan,
      adim2.onLastikler,
      adim2.arkaLastikler,
    ];

    for (final alan in alanlar) {
      if (alan != null) {
        // Durum değerini puanla
        double alanPuan = 0.0;
        switch (alan) {
          case 'Mükemmel':
            alanPuan = 100.0;
            break;
          case 'İyi':
            alanPuan = 75.0;
            break;
          case 'Orta':
            alanPuan = 50.0;
            break;
          case 'Kötü':
            alanPuan = 25.0;
            break;
          case 'Ağır Hasar':
            alanPuan = 0.0;
            break;
          default:
            alanPuan = 50.0;
        }
        toplamPuan += alanPuan;
      }
    }

    return (toplamPuan / alanSayisi).clamp(0.0, 100.0);
  }

  /// Adım 3: İç Ekspertiz Puanı Hesapla
  static double _hesaplaAdim3Puan(Adim3IcEkspertizModel adim3) {
    if (!adim3.isValid) return 0.0;

    double toplamPuan = 0.0;
    int alanSayisi = 16; // Toplam alan sayısı

    // Her alan için puan hesapla
    final alanlar = [
      adim3.direksiyon,
      adim3.gostergePaneli,
      adim3.klima,
      adim3.sesSistemi,
      adim3.onKoltuklar,
      adim3.arkaKoltuklar,
      adim3.koltukDosemesi,
      adim3.dorseme,
      adim3.tavanDosemesi,
      adim3.onPencereler,
      adim3.arkaPencereler,
      adim3.camlar,
      adim3.merkeziKilit,
      adim3.camKontrolleri,
      adim3.aynaKontrolleri,
    ];

    for (final alan in alanlar) {
      if (alan != null) {
        // Durum değerini puanla
        double alanPuan = 0.0;
        switch (alan) {
          case 'Mükemmel':
            alanPuan = 100.0;
            break;
          case 'İyi':
            alanPuan = 75.0;
            break;
          case 'Orta':
            alanPuan = 50.0;
            break;
          case 'Kötü':
            alanPuan = 25.0;
            break;
          case 'Ağır Hasar':
            alanPuan = 0.0;
            break;
          default:
            alanPuan = 50.0;
        }
        toplamPuan += alanPuan;
      }
    }

    return (toplamPuan / alanSayisi).clamp(0.0, 100.0);
  }

  /// Adım 4: Boya/Kaporta Puanı Hesapla
  static double _hesaplaAdim4Puan(Adim4BoyaKaportaModel adim4) {
    if (!adim4.isValid) return 0.0;

    double toplamPuan = 0.0;
    int alanSayisi = 15; // Toplam alan sayısı

    // Boya alanları için puan hesapla
    final boyaAlanlari = [
      adim4.onKapiBoya,
      adim4.arkaKapiBoya,
      adim4.kaputBoya,
      adim4.tamponBoya,
      adim4.tavanBoya,
    ];

    // Kaporta alanları için puan hesapla
    final kaportaAlanlari = [
      adim4.onKapiKaporta,
      adim4.arkaKapiKaporta,
      adim4.kaputKaporta,
      adim4.tamponKaporta,
      adim4.onSasi,
      adim4.arkaSasi,
      adim4.onDirekler,
      adim4.arkaDirekler,
      adim4.podye,
      adim4.marsbiyel,
    ];

    // Boya puanları
    for (final alan in boyaAlanlari) {
      if (alan != null) {
        double alanPuan = 0.0;
        switch (alan) {
          case 'Orijinal':
            alanPuan = 100.0;
            break;
          case 'Boyalı':
            alanPuan = 50.0;
            break;
          case 'Hasarlı':
            alanPuan = 25.0;
            break;
          case 'Değişmiş':
            alanPuan = 10.0;
            break;
          default:
            alanPuan = 50.0;
        }
        toplamPuan += alanPuan;
      }
    }

    // Kaporta puanları
    for (final alan in kaportaAlanlari) {
      if (alan != null) {
        double alanPuan = 0.0;
        switch (alan) {
          case 'Orijinal':
            alanPuan = 100.0;
            break;
          case 'Değişmiş':
            alanPuan = 50.0;
            break;
          case 'Hasarlı':
            alanPuan = 0.0;
            break;
          default:
            alanPuan = 50.0;
        }
        toplamPuan += alanPuan;
      }
    }

    // Hasar kayıtları puanı (hasar sayısına göre puan düşür)
    double hasarPuan = 100.0;
    int hasarSayisi = adim4.hasarSayisi;
    if (hasarSayisi > 0) {
      hasarPuan -= (hasarSayisi * 10.0);
      if (hasarPuan < 0) hasarPuan = 0.0;
    }

    double alanPuan = (toplamPuan / alanSayisi);
    double toplam = (alanPuan * 0.7) + (hasarPuan * 0.3);

    return toplam.clamp(0.0, 100.0);
  }

  /// Adım 5: Kurumsal Ekspertiz Puanı Hesapla (Motor/Mekanik)
  static double _hesaplaAdim5Puan(Adim5KurumsalEkspertizModel adim5) {
    if (!adim5.isValid) return 0.0;

    double toplamPuan = 0.0;
    int alanSayisi = 5; // Toplam alan sayısı

    // Motor ve mekanik alanları için puan hesapla
    final alanlar = [
      adim5.motorDurumu,
      adim5.sanzimanDurumu,
      adim5.frenSistemi,
      adim5.direksiyonSistemi,
      adim5.elektrikSistemi,
    ];

    for (final alan in alanlar) {
      if (alan != null) {
        // Durum değerini puanla
        double alanPuan = 0.0;
        switch (alan) {
          case 'Mükemmel':
            alanPuan = 100.0;
            break;
          case 'İyi':
            alanPuan = 75.0;
            break;
          case 'Orta':
            alanPuan = 50.0;
            break;
          case 'Kötü':
            alanPuan = 25.0;
            break;
          case 'Ağır Hasar':
            alanPuan = 0.0;
            break;
          default:
            alanPuan = 50.0;
        }
        toplamPuan += alanPuan;
      }
    }

    return (toplamPuan / alanSayisi).clamp(0.0, 100.0);
  }

  /// Hasar Puanı Hesapla (Adım 4'ten)
  static double _hesaplaHasarPuan(Adim4BoyaKaportaModel adim4) {
    int hasarSayisi = adim4.hasarSayisi;

    if (hasarSayisi == 0) return 100.0;
    if (hasarSayisi == 1) return 90.0;
    if (hasarSayisi == 2) return 75.0;
    if (hasarSayisi == 3) return 50.0;
    if (hasarSayisi >= 4) return 25.0;

    return 0.0;
  }

  /// Araç Durumu Puanı Hesapla (Adım 1-4'ten)
  static double hesaplaAracDurumuPuan({
    required Adim1AracSaticiModel adim1,
    required Adim2DisEkspertizModel adim2,
    required Adim3IcEkspertizModel adim3,
    required Adim4BoyaKaportaModel adim4,
  }) {
    double adim1Puan = _hesaplaAdim1Puan(adim1);
    double adim2Puan = _hesaplaAdim2Puan(adim2);
    double adim3Puan = _hesaplaAdim3Puan(adim3);
    double adim4Puan = _hesaplaAdim4Puan(adim4);

    // Ağırlıklı ortalama
    double toplam = (adim1Puan * 0.25) +
        (adim2Puan * 0.25) +
        (adim3Puan * 0.25) +
        (adim4Puan * 0.25);

    return toplam.clamp(0.0, 100.0);
  }

  /// Motor/Mekanik Puanı Hesapla (Adım 5'ten)
  static double hesaplaMotorMekanikPuan(Adim5KurumsalEkspertizModel adim5) {
    return _hesaplaAdim5Puan(adim5);
  }

  /// Genel Puan Hesapla (Tüm adımlardan)
  static AISkorModel hesaplaGenelPuan({
    required Adim1AracSaticiModel adim1,
    required Adim2DisEkspertizModel adim2,
    required Adim3IcEkspertizModel adim3,
    required Adim4BoyaKaportaModel adim4,
    required Adim5KurumsalEkspertizModel adim5,
  }) {
    // Araç durumu puanı
    double aracDurumuPuan = hesaplaAracDurumuPuan(
      adim1: adim1,
      adim2: adim2,
      adim3: adim3,
      adim4: adim4,
    );

    // Motor/mekanik puanı
    double motorMekanikPuan = hesaplaMotorMekanikPuan(adim5);

    // Hasar puanı
    double hasarPuan = _hesaplaHasarPuan(adim4);

    // Genel puan (ağırlıklı ortalama)
    // Araç durumu: %40, Motor/mekanik: %30, Hasar: %30
    double genelPuan = (aracDurumuPuan * 0.40) +
        (motorMekanikPuan * 0.30) +
        (hasarPuan * 0.30);

    // Detaylı puanlar
    Map<String, double> detayliPuanlar = {
      'adim1': _hesaplaAdim1Puan(adim1),
      'adim2': _hesaplaAdim2Puan(adim2),
      'adim3': _hesaplaAdim3Puan(adim3),
      'adim4': _hesaplaAdim4Puan(adim4),
      'adim5': _hesaplaAdim5Puan(adim5),
      'aracDurumu': aracDurumuPuan,
      'motorMekanik': motorMekanikPuan,
      'hasar': hasarPuan,
    };

    return AISkorModel(
      aracDurumuPuan: aracDurumuPuan,
      motorMekanikPuan: motorMekanikPuan,
      hasarPuan: hasarPuan,
      genelPuan: genelPuan,
      detayliPuanlar: detayliPuanlar,
    );
  }

  /// Puan değerlendirmesi döndür
  static String getPuanDegerlendirmesi(double puan) {
    if (puan >= 90) return 'Mükemmel';
    if (puan >= 80) return 'Çok İyi';
    if (puan >= 70) return 'İyi';
    if (puan >= 60) return 'Orta';
    if (puan >= 50) return 'Yeterli';
    return 'Yetersiz';
  }

  /// Puan rengi döndür
  static String getPuanRengi(double puan) {
    if (puan >= 90) return '#4CAF50'; // Green
    if (puan >= 80) return '#8BC34A'; // Light Green
    if (puan >= 70) return '#FFC107'; // Amber
    if (puan >= 60) return '#FF9800'; // Orange
    if (puan >= 50) return '#FF5722'; // Deep Orange
    return '#F44336'; // Red
  }
}
