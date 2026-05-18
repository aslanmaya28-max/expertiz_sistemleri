/// AI Öneri Modeli
/// AI tarafından üretilen önerileri içerir
class AIOneriModel {
  // Kategori: 'Kritik', 'Önemli', 'Öneri'
  final String kategori;

  // Öneri başlığı
  final String baslik;

  // Öneri açıklaması
  final String aciklama;

  // Önerilen eylem (opsiyonel)
  final String? onerilenEylem;

  // Öncelik (1-10, 1 en kritik)
  final int oncelik;
  final String? onemDerecesi;

  // İlgili adım (1-5)
  final int? ilgiliAdim;

  // İlgili alan (örn: 'onTampon', 'motorDurumu')
  final String? ilgiliAlan;

  // Öneri oluşturulma tarihi
  final DateTime olusturmaZamani;

  AIOneriModel({
    required this.kategori,
    required this.baslik,
    required this.aciklama,
    this.onerilenEylem,
    required this.oncelik,
    this.onemDerecesi,
    this.ilgiliAdim,
    this.ilgiliAlan,
    DateTime? olusturmaZamani,
  }) : olusturmaZamani = olusturmaZamani ?? DateTime.now();

  /// JSON'dan AIOneriModel nesnesi oluştur
  factory AIOneriModel.fromJson(Map<String, dynamic> json) {
    return AIOneriModel(
      kategori: json['kategori'] as String,
      baslik: json['baslik'] as String,
      aciklama: json['aciklama'] as String,
      onerilenEylem: json['onerilenEylem'] as String?,
      oncelik: json['oncelik'] as int,
      onemDerecesi: json['onemDerecesi'] as String?,
      ilgiliAdim: json['ilgiliAdim'] as int?,
      ilgiliAlan: json['ilgiliAlan'] as String?,
      olusturmaZamani: json['olusturmaZamani'] != null
          ? DateTime.parse(json['olusturmaZamani'] as String)
          : DateTime.now(),
    );
  }

  /// AIOneriModel nesnesini JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'kategori': kategori,
      'baslik': baslik,
      'aciklama': aciklama,
      'onerilenEylem': onerilenEylem,
      'oncelik': oncelik,
      'onemDerecesi': onemDerecesi,
      'ilgiliAdim': ilgiliAdim,
      'ilgiliAlan': ilgiliAlan,
      'olusturmaZamani': olusturmaZamani.toIso8601String(),
    };
  }

  /// Modeli kopyalar ve belirtilen alanları günceller
  AIOneriModel copyWith({
    String? kategori,
    String? baslik,
    String? aciklama,
    String? onerilenEylem,
    int? oncelik,
    int? ilgiliAdim,
    String? ilgiliAlan,
    DateTime? olusturmaZamani,
  }) {
    return AIOneriModel(
      kategori: kategori ?? this.kategori,
      baslik: baslik ?? this.baslik,
      aciklama: aciklama ?? this.aciklama,
      onerilenEylem: onerilenEylem ?? this.onerilenEylem,
      oncelik: oncelik ?? this.oncelik,
      ilgiliAdim: ilgiliAdim ?? this.ilgiliAdim,
      ilgiliAlan: ilgiliAlan ?? this.ilgiliAlan,
      olusturmaZamani: olusturmaZamani ?? this.olusturmaZamani,
    );
  }

  /// Kategori rengini döndürür
  String get kategoriRengi {
    switch (kategori) {
      case 'Kritik':
        return '#F44336'; // Red
      case 'Önemli':
        return '#FF9800'; // Orange
      case 'Öneri':
        return '#2196F3'; // Blue
      default:
        return '#9E9E9E'; // Grey
    }
  }

  /// Kategori ikonunu döndürür
  String get kategoriIkonu {
    switch (kategori) {
      case 'Kritik':
        return '🚨';
      case 'Önemli':
        return '⚠️';
      case 'Öneri':
        return '💡';
      default:
        return '📋';
    }
  }

  /// Önerinin kritik olup olmadığını kontrol eder
  bool get isKritik => kategori == 'Kritik';

  /// Önerinin geçerli olup olmadığını kontrol eder
  bool get isValid {
    return kategori.isNotEmpty &&
        baslik.isNotEmpty &&
        aciklama.isNotEmpty &&
        oncelik >= 1 &&
        oncelik <= 10 &&
        (ilgiliAdim == null || (ilgiliAdim! >= 1 && ilgiliAdim! <= 5));
  }

  /// String reprazantasyonu
  @override
  String toString() {
    return 'AIOneriModel(kategori: $kategori, baslik: $baslik, oncelik: $oncelik)';
  }

  /// Kategori listesi
  static List<String> get kategoriler => [
        'Kritik',
        'Önemli',
        'Öneri',
      ];

  /// Boş model oluştur
  static AIOneriModel empty() {
    return AIOneriModel(
      kategori: 'Öneri',
      baslik: '',
      aciklama: '',
      oncelik: 5,
    );
  }
}
