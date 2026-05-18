/// AI Analiz Modeli
/// 
/// Bu model, yapay zeka destekli araç değerleme analizi için
/// gerekli tüm verileri içerir. Müşteri panelindeki oto-analiz
/// merkezi formundan gelen verileri temsil eder.
/// 
/// Özellikler:
/// - Marka, model, paket bilgileri
/// - Yıl, KM, renk bilgileri
/// - Boyalı ve hasarlı parçalar listesi
/// - 21 adet premium donanım seçeneği
library;

/// AI Araç Analiz Girdisi
class AIAnalizModel {
  // Temel Araç Bilgileri
  final String brand;
  final String model;
  final String packageLevel;
  final int year;
  final int km;
  final String color;

  // Parça Bilgileri
  final List<String> paintedParts;
  final List<String> damagedParts;

  // 21 Premium Donanım Seçeneği
  final Map<String, bool> selectedOptions;

  const AIAnalizModel({
    required this.brand,
    required this.model,
    required this.packageLevel,
    required this.year,
    required this.km,
    required this.color,
    required this.paintedParts,
    required this.damagedParts,
    required this.selectedOptions,
  });

  /// Boş bir analiz modeli oluşturur
  factory AIAnalizModel.empty() {
    return AIAnalizModel(
      brand: '',
      model: '',
      packageLevel: '',
      year: DateTime.now().year,
      km: 0,
      color: '',
      paintedParts: [],
      damagedParts: [],
      selectedOptions: {},
    );
  }

  /// JSON'dan model oluşturur
  factory AIAnalizModel.fromJson(Map<String, dynamic> json) {
    return AIAnalizModel(
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      packageLevel: json['packageLevel'] as String? ?? '',
      year: json['year'] as int? ?? DateTime.now().year,
      km: json['km'] as int? ?? 0,
      color: json['color'] as String? ?? '',
      paintedParts: (json['paintedParts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      damagedParts: (json['damagedParts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      selectedOptions: (json['selectedOptions'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, value as bool)) ??
          {},
    );
  }

  /// Modeli JSON'a dönüştürür
  Map<String, dynamic> toJson() {
    return {
      'brand': brand,
      'model': model,
      'packageLevel': packageLevel,
      'year': year,
      'km': km,
      'color': color,
      'paintedParts': paintedParts,
      'damagedParts': damagedParts,
      'selectedOptions': selectedOptions,
    };
  }

  /// Kopyalama yöntemi - belirli alanları güncelleyerek yeni bir model oluşturur
  AIAnalizModel copyWith({
    String? brand,
    String? model,
    String? packageLevel,
    int? year,
    int? km,
    String? color,
    List<String>? paintedParts,
    List<String>? damagedParts,
    Map<String, bool>? selectedOptions,
  }) {
    return AIAnalizModel(
      brand: brand ?? this.brand,
      model: model ?? this.model,
      packageLevel: packageLevel ?? this.packageLevel,
      year: year ?? this.year,
      km: km ?? this.km,
      color: color ?? this.color,
      paintedParts: paintedParts ?? this.paintedParts,
      damagedParts: damagedParts ?? this.damagedParts,
      selectedOptions: selectedOptions ?? this.selectedOptions,
    );
  }

  /// Seçilen donanım sayısını döndürür
  int get selectedEquipmentCount {
    return selectedOptions.values.where((isSelected) => isSelected).length;
  }

  /// Araç bilgilerinin eksiksiz olup olmadığını kontrol eder
  bool get isComplete {
    return brand.isNotEmpty &&
        model.isNotEmpty &&
        packageLevel.isNotEmpty &&
        year > 0 &&
        km >= 0 &&
        color.isNotEmpty;
  }

  /// Spor paket olup olmadığını kontrol eder
  bool get isSportPackage {
    final sportKeywords = [
      'AMG',
      'M',
      'RS',
      'R-Line',
      'ST',
      'GTI',
      'Cupra',
      'M-Sport',
      'S-Line',
      'TFSI',
      'TDI',
      'Quattro',
      'xDrive',
      '4MATIC',
      'AMT',
      'DCT'
    ];
    return sportKeywords.any((keyword) =>
        model.toUpperCase().contains(keyword) ||
        packageLevel.toLowerCase() == 'spor');
  }

  /// Araç kimlik bilgisini döndürür
  String get vehicleIdentity {
    return '$year $brand $model';
  }

  @override
  String toString() {
    return 'AIAnalizModel(brand: $brand, model: $model, packageLevel: $packageLevel, year: $year, km: $km, color: $color, paintedParts: ${paintedParts.length}, damagedParts: ${damagedParts.length}, selectedOptions: $selectedEquipmentCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AIAnalizModel &&
        other.brand == brand &&
        other.model == model &&
        other.packageLevel == packageLevel &&
        other.year == year &&
        other.km == km &&
        other.color == color &&
        _listEquals(other.paintedParts, paintedParts) &&
        _listEquals(other.damagedParts, damagedParts) &&
        _mapEquals(other.selectedOptions, selectedOptions);
  }

  @override
  int get hashCode {
    return brand.hashCode ^
        model.hashCode ^
        packageLevel.hashCode ^
        year.hashCode ^
        km.hashCode ^
        color.hashCode ^
        paintedParts.hashCode ^
        damagedParts.hashCode ^
        selectedOptions.hashCode;
  }

  // Yardımcı metodlar
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _mapEquals(Map<String, bool> a, Map<String, bool> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) return false;
    }
    return true;
  }
}

/// 21 Premium Donanım Seçeneği
class PremiumDonanimOptions {
  static const Map<String, String> allOptions = {
    // Güvenlik
    'ABS': 'Anti-lock Braking System',
    'ESP': 'Elektronik Stabilite Programı',
    'Airbag': 'Hava Yastığı Sistemi',
    'Traction Control': 'Çekiş Kontrolü',

    // Konfor
    'Climate Control': 'Otomatik İklim Kontrolü',
    'Cruise Control': 'Hız Sabitleyici',
    'Parking Sensors': 'Park Sensörleri',
    'Rear Camera': 'Arka Kamera',
    'Navigation': 'Navigasyon Sistemi',

    // Multimedya
    'Bluetooth': 'Bluetooth Bağlantısı',
    'USB': 'USB Bağlantısı',
    'Apple CarPlay': 'Apple CarPlay',
    'Android Auto': 'Android Auto',

    // Görünüm
    'Sunroof': 'Panoramik Tavan',
    'Alloy Wheels': 'Alüminyum Jantlar',
    'LED Lights': 'LED Farlar',
    'Xenon Lights': 'Xenon Farlar',

    // Koltuk
    'Leather Seats': 'Deri Koltuklar',
    'Heated Seats': 'Isıtmalı Koltuklar',
    'Electric Seats': 'Elektrikli Koltuklar',
    'Memory Seats': 'Hafızalı Koltuklar',
  };

  /// Kategori bazlı donanım grupları
  static const Map<String, List<String>> categorizedOptions = {
    'Güvenlik': [
      'ABS',
      'ESP',
      'Airbag',
      'Traction Control',
    ],
    'Konfor': [
      'Climate Control',
      'Cruise Control',
      'Parking Sensors',
      'Rear Camera',
      'Navigation',
    ],
    'Multimedya': [
      'Bluetooth',
      'USB',
      'Apple CarPlay',
      'Android Auto',
    ],
    'Görünüm': [
      'Sunroof',
      'Alloy Wheels',
      'LED Lights',
      'Xenon Lights',
    ],
    'Koltuk': [
      'Leather Seats',
      'Heated Seats',
      'Electric Seats',
      'Memory Seats',
    ],
  };

  /// Tüm donanım isimlerini döndürür
  static List<String> get allOptionNames => allOptions.keys.toList();

  /// Kategori bazlı donanım isimlerini döndürür
  static Map<String, List<String>> get categorizedOptionNames => categorizedOptions;
}
