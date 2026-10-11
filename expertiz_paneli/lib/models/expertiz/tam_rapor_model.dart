import 'adim1_arac_satici_model.dart';
import 'adim2_dis_ekspertiz_model.dart';
import 'adim3_ic_ekspertiz_model.dart';
import 'adim4_boya_kaporta_model.dart';
import 'adim5_kurumsal_ekspertiz_model.dart';
import '../ai/ai_analiz_sonucu_model.dart';

/// Tam Expertiz Rapor Modeli
/// Tüm 5 adımı birleştiren tam rapor modeli
class TamRaporModel {
  // Görev Bilgileri
  final String gorevId;
  final String personelId;
  final DateTime baslangicZamani;
  final DateTime? bitisZamani;

  // Adım 1: Araç & Satıcı
  final Adim1AracSaticiModel adim1;

  // Adım 2: Dış Ekspertiz
  final Adim2DisEkspertizModel adim2;

  // Adım 3: İç Ekspertiz
  final Adim3IcEkspertizModel adim3;

  // Adım 4: Boya / Kaporta
  final Adim4BoyaKaportaModel adim4;

  // Adım 5: Kurumsal Ekspertiz
  final Adim5KurumsalEkspertizModel adim5;

  // Genel
  final String? genelNot;
  final String? oneriler;
  final double? genelPuan;
  final String durum; // 'Onay Bekliyor', 'Tamamlandı', 'Reddedildi'

  // AI Analiz Sonucu
  final AIAnalizSonucu? aiAnalizSonucu;

  TamRaporModel({
    required this.gorevId,
    required this.personelId,
    required this.adim1,
    required this.adim2,
    required this.adim3,
    required this.adim4,
    required this.adim5,
    this.genelNot,
    this.oneriler,
    this.genelPuan,
    this.durum = 'Onay Bekliyor',
    this.aiAnalizSonucu,
    DateTime? baslangicZamani,
    this.bitisZamani,
  })  : baslangicZamani = baslangicZamani ?? DateTime.now();

  /// JSON'dan TamRaporModel nesnesi oluştur
  factory TamRaporModel.fromJson(Map<String, dynamic> json) {
    final model = TamRaporModel(
      gorevId: json['gorevId']?.toString() ?? '',
      personelId: json['personelId']?.toString() ?? '',
      adim1: Adim1AracSaticiModel.fromJson(json['adim1'] as Map<String, dynamic>),
      adim2: Adim2DisEkspertizModel.fromJson(json['adim2'] as Map<String, dynamic>),
      adim3: Adim3IcEkspertizModel.fromJson(json['adim3'] as Map<String, dynamic>),
      adim4: Adim4BoyaKaportaModel.fromJson(json['adim4'] as Map<String, dynamic>),
      adim5: Adim5KurumsalEkspertizModel.fromJson(json['adim5'] as Map<String, dynamic>),
      genelNot: json['genelNot'] as String?,
      oneriler: json['oneriler'] as String?,
      genelPuan: (json['genelPuan'] as num?)?.toDouble(),
      durum: json['durum'] as String? ?? 'Onay Bekliyor',
      aiAnalizSonucu: json['aiAnalizSonucu'] != null
          ? AIAnalizSonucu.fromJson(json['aiAnalizSonucu'] as Map<String, dynamic>)
          : null,
    );
    
    // baslangicZamani ve bitisZamani JSON'dan okunur
    return model.copyWith(
      baslangicZamani: json['baslangicZamani'] != null
          ? DateTime.tryParse(json['baslangicZamani'].toString()) ?? DateTime.now()
          : DateTime.now(),
      bitisZamani: json['bitisZamani'] != null
          ? DateTime.tryParse(json['bitisZamani'].toString())
          : null,
    );
  }

  /// TamRaporModel nesnesini JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'gorevId': gorevId,
      'personelId': personelId,
      'adim1': adim1.toJson(),
      'adim2': adim2.toJson(),
      'adim3': adim3.toJson(),
      'adim4': adim4.toJson(),
      'adim5': adim5.toJson(),
      'baslangicZamani': baslangicZamani.toIso8601String(),
      'bitisZamani': bitisZamani?.toIso8601String(),
      'genelNot': genelNot,
      'oneriler': oneriler,
      'genelPuan': genelPuan,
      'durum': durum,
      'aiAnalizSonucu': aiAnalizSonucu?.toJson(),
    };
  }

  /// Modeli kopyalar ve belirtilen alanları günceller
  TamRaporModel copyWith({
    String? gorevId,
    String? personelId,
    Adim1AracSaticiModel? adim1,
    Adim2DisEkspertizModel? adim2,
    Adim3IcEkspertizModel? adim3,
    Adim4BoyaKaportaModel? adim4,
    Adim5KurumsalEkspertizModel? adim5,
    String? genelNot,
    String? oneriler,
    double? genelPuan,
    String? durum,
    AIAnalizSonucu? aiAnalizSonucu,
    DateTime? baslangicZamani,
    DateTime? bitisZamani,
  }) {
    return TamRaporModel(
      gorevId: gorevId ?? this.gorevId,
      personelId: personelId ?? this.personelId,
      adim1: adim1 ?? this.adim1,
      adim2: adim2 ?? this.adim2,
      adim3: adim3 ?? this.adim3,
      adim4: adim4 ?? this.adim4,
      adim5: adim5 ?? this.adim5,
      genelNot: genelNot ?? this.genelNot,
      oneriler: oneriler ?? this.oneriler,
      genelPuan: genelPuan ?? this.genelPuan,
      durum: durum ?? this.durum,
      aiAnalizSonucu: aiAnalizSonucu ?? this.aiAnalizSonucu,
      baslangicZamani: baslangicZamani ?? this.baslangicZamani,
      bitisZamani: bitisZamani ?? this.bitisZamani,
    );
  }

  /// Tüm adımların geçerli olup olmadığını kontrol eder
  bool get isValid {
    return adim1.isValid &&
        adim2.isValid &&
        adim3.isValid &&
        adim4.isValid &&
        adim5.isValid;
  }

  /// Doldurulmuş toplam alan sayısı
  int get totalFilledFields {
    return adim1.filledFields +
        adim2.filledFields +
        adim3.filledFields +
        adim4.filledFields +
        adim5.filledFields;
  }

  /// Toplam alan sayısı
  int get totalFields {
    return adim1.totalFields +
        adim2.totalFields +
        adim3.totalFields +
        adim4.totalFields +
        adim5.totalFields;
  }

  /// Toplam dolum yüzdesi
  double get completionPercentage => totalFilledFields / totalFields;

  /// Araç tam adını döndürür
  String get aracTamAdi => adim1.aracTamAdi;

  /// Araç plakasını döndürür
  String get aracPlakasi => adim1.plaka;

  /// Araç kilometresini döndürür
  int get aracKm => adim1.guncelKm;

  /// Ruhsat sahibini döndürür
  String get ruhsatSahibi => adim1.ruhsatSahibiAdSoyad;

  /// Durum rengini döndürür
  String get durumRengi {
    switch (durum) {
      case 'Onay Bekliyor':
        return '#FF9800'; // Orange
      case 'Tamamlandı':
        return '#4CAF50'; // Green
      case 'Reddedildi':
        return '#F44336'; // Red
      default:
        return '#9E9E9E'; // Grey
    }
  }

  /// Durum ikonunu döndürür
  String get durumIkonu {
    switch (durum) {
      case 'Onay Bekliyor':
        return '⏳';
      case 'Tamamlandı':
        return '✅';
      case 'Reddedildi':
        return '❌';
      default:
        return '📋';
    }
  }

  /// Geçen süreyi döndürür
  Duration? get gecenSure {
    if (bitisZamani == null) return null;
    return bitisZamani!.difference(baslangicZamani);
  }

  /// Geçen süreyi formatlı döndürür
  String get gecenSureFormatli {
    final sure = gecenSure;
    if (sure == null) return 'Devam ediyor';
    
    if (sure.inHours > 24) {
      final gun = sure.inDays;
      return '$gun gün';
    } else if (sure.inHours > 0) {
      final saat = sure.inHours;
      final dakika = sure.inMinutes.remainder(60);
      return '$saat saat $dakika dk';
    } else {
      final dakika = sure.inMinutes;
      return '$dakika dakika';
    }
  }

  /// Tüm fotoğraf URL'lerini döndürür
  List<String> get tumFotograflar {
    return [
      ...adim1.fotografUrlleri,
      ...adim2.fotografUrlleri,
      ...adim3.fotografUrlleri,
      ...adim4.fotografUrlleri,
      ...adim5.fotografUrlleri,
      ...adim5.ruhsatFotograflari,
      ...adim5.bakimDefteriFotograflari,
      ...adim5.sigortaFotograflari,
      ...adim5.muayeneFotograflari,
    ];
  }

  /// Toplam fotoğraf sayısı
  int get toplamFotografSayisi => tumFotograflar.length;

  /// Hasar sayısı
  int get hasarSayisi => adim4.hasarSayisi;

  /// AI analizi tamamlandı mı?
  bool get aiAnalizTamamlandi => aiAnalizSonucu != null && aiAnalizSonucu!.isTamamlandi;

  /// AI genel puanı
  double? get aiGenelPuan => aiAnalizSonucu?.skorlar.genelPuan;

  /// AI puan değerlendirmesi
  String? get aiPuanDegerlendirmesi => aiAnalizSonucu?.skorlar.puanDegerlendirmesi;

  // Yeni Getters
  bool get isEmpty => gorevId.isEmpty;
  
  // Paket bilgisi (Adım 5 veya varsayılan)
  String get paket => 'Standart Paket'; 

  // AI Analiz Getters
  double? get aiGuncelPiyasaDegeri => aiAnalizSonucu?.raporOzeti.tahminiDeger;
  
  double? get ai12AylikDegerTahmini => aiAnalizSonucu?.raporOzeti.degerProjeksiyonu1Yil;
  
  double? get aiKarMarji {
     if(aiGuncelPiyasaDegeri == null || aiGuncelPiyasaDegeri == 0) return 0.0;
     final proj = ai12AylikDegerTahmini ?? 0.0;
     return ((proj - aiGuncelPiyasaDegeri!) / aiGuncelPiyasaDegeri!) * 100;
  }

  /// String reprazantasyonu
  @override
  String toString() {
    return 'TamRaporModel(gorev: $gorevId, arac: $aracTamAdi, durum: $durum)';
  }

  /// Boş model oluştur
  static TamRaporModel empty({
    required String gorevId,
    required String personelId,
  }) {
    return TamRaporModel(
      gorevId: gorevId,
      personelId: personelId,
      adim1: Adim1AracSaticiModel.empty(),
      adim2: Adim2DisEkspertizModel.empty(),
      adim3: Adim3IcEkspertizModel.empty(),
      adim4: Adim4BoyaKaportaModel.empty(),
      adim5: Adim5KurumsalEkspertizModel.empty(),
    );
  }

  /// Durum listesi
  static List<String> get durumler => [
        'Onay Bekliyor',
        'Tamamlandı',
        'Reddedildi',
      ];
}
