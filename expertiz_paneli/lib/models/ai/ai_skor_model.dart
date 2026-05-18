/// AI Skor Modeli
/// Araç ekspertizinde hesaplanan tüm puanları içerir
class AISkorModel {
  // Araç durumu puanı (Adım 1-4'ten hesaplanır)
  final double aracDurumuPuan;

  // Motor/mekanik puanı (Adım 5'ten hesaplanır)
  final double motorMekanikPuan;

  // Hasar puanı (Adım 4'ten hesaplanır)
  final double hasarPuan;

  // Genel puan (tüm puanların ağırlıklı ortalaması)
  final double genelPuan;

  // Detaylı puanlar (her adım için ayrı puanlar)
  final Map<String, double> detayliPuanlar;

  // Puan hesaplama tarihi
  final DateTime hesaplamaZamani;
  final String puanDegerlendirmesi;
  final String puanRengi;

  AISkorModel({
    required this.aracDurumuPuan,
    required this.motorMekanikPuan,
    required this.hasarPuan,
    required this.genelPuan,
    required this.detayliPuanlar,
    this.puanDegerlendirmesi = 'Belirtilmedi',
    this.puanRengi = 'Gray',
    DateTime? hesaplamaZamani,
  }) : hesaplamaZamani = hesaplamaZamani ?? DateTime.now();

  /// JSON'dan AISkorModel nesnesi oluştur
  factory AISkorModel.fromJson(Map<String, dynamic> json) {
    final detayliPuanlarMap = json['detayliPuanlar'] as Map<String, dynamic>?;

    return AISkorModel(
      aracDurumuPuan: (json['aracDurumuPuan'] as num).toDouble(),
      motorMekanikPuan: (json['motorMekanikPuan'] as num).toDouble(),
      hasarPuan: (json['hasarPuan'] as num).toDouble(),
      genelPuan: (json['genelPuan'] as num).toDouble(),
      detayliPuanlar: detayliPuanlarMap?.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ) ?? {},
      hesaplamaZamani: json['hesaplamaZamani'] != null
          ? DateTime.parse(json['hesaplamaZamani'] as String)
          : DateTime.now(),
      puanDegerlendirmesi: json['puanDegerlendirmesi'] ?? 'Belirtilmedi',
      puanRengi: json['puanRengi'] ?? 'Gray',
    );
  }

  /// AISkorModel nesnesini JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'aracDurumuPuan': aracDurumuPuan,
      'motorMekanikPuan': motorMekanikPuan,
      'hasarPuan': hasarPuan,
      'genelPuan': genelPuan,
      'detayliPuanlar': detayliPuanlar,
      'hesaplamaZamani': hesaplamaZamani.toIso8601String(),
      'puanDegerlendirmesi': puanDegerlendirmesi,
      'puanRengi': puanRengi,
    };
  }

  /// Modeli kopyalar ve belirtilen alanları günceller
  AISkorModel copyWith({
    double? aracDurumuPuan,
    double? motorMekanikPuan,
    double? hasarPuan,
    double? genelPuan,
    Map<String, double>? detayliPuanlar,
    String? puanDegerlendirmesi,
    String? puanRengi,
    DateTime? hesaplamaZamani,
  }) {
    return AISkorModel(
      aracDurumuPuan: aracDurumuPuan ?? this.aracDurumuPuan,
      motorMekanikPuan: motorMekanikPuan ?? this.motorMekanikPuan,
      hasarPuan: hasarPuan ?? this.hasarPuan,
      genelPuan: genelPuan ?? this.genelPuan,
      detayliPuanlar: detayliPuanlar ?? this.detayliPuanlar,
      puanDegerlendirmesi: puanDegerlendirmesi ?? this.puanDegerlendirmesi,
      puanRengi: puanRengi ?? this.puanRengi,
      hesaplamaZamani: hesaplamaZamani ?? this.hesaplamaZamani,
    );
  }



  /// Puanın geçerli olup olmadığını kontrol eder
  bool get isValid {
    return aracDurumuPuan >= 0 &&
        aracDurumuPuan <= 100 &&
        motorMekanikPuan >= 0 &&
        motorMekanikPuan <= 100 &&
        hasarPuan >= 0 &&
        hasarPuan <= 100 &&
        genelPuan >= 0 &&
        genelPuan <= 100;
  }

  /// String reprazantasyonu
  @override
  String toString() {
    return 'AISkorModel(genel: $genelPuan, arac: $aracDurumuPuan, motor: $motorMekanikPuan, hasar: $hasarPuan)';
  }

  /// Boş model oluştur
  static AISkorModel empty() {
    return AISkorModel(
      aracDurumuPuan: 0,
      motorMekanikPuan: 0,
      hasarPuan: 0,
      genelPuan: 0,
      detayliPuanlar: {},
    );
  }
}
