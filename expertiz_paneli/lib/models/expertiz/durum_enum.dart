/// Durum değerleri için enum
/// Expertiz formlarında kullanılan durum değerlendirmeleri
enum Durum {
  mukemmel,
  iyi,
  orta,
  sorunlu,
  kotu,
  agirHasar;

  /// Enum değerini kullanıcı dostu string'e çevirir
  String get displayName {
    switch (this) {
      case Durum.mukemmel:
        return 'Mükemmel';
      case Durum.iyi:
        return 'İyi';
      case Durum.orta:
        return 'Orta';
      case Durum.sorunlu:
        return 'Sorunlu';
      case Durum.kotu:
        return 'Kötü';
      case Durum.agirHasar:
        return 'Ağır Hasar';
    }
  }

  /// Enum değerinin rengini döndürür
  String get colorValue {
    switch (this) {
      case Durum.mukemmel:
        return '#4CAF50'; // Green
      case Durum.iyi:
        return '#4CAF50'; // Green
      case Durum.orta:
        return '#FF9800'; // Orange
      case Durum.sorunlu:
        return '#FF9800'; // Orange
      case Durum.kotu:
        return '#F44336'; // Red
      case Durum.agirHasar:
        return '#F44336'; // Red
    }
  }

  /// String'den Durum enum'ı oluşturur
  static Durum fromString(String value) {
    switch (value.toLowerCase()) {
      case 'mukemmel':
      case 'mükemmel':
        return Durum.mukemmel;
      case 'iyi':
        return Durum.iyi;
      case 'orta':
        return Durum.orta;
      case 'sorunlu':
        return Durum.sorunlu;
      case 'kotu':
      case 'kötü':
        return Durum.kotu;
      case 'agirhasar':
      case 'ağır hasar':
        return Durum.agirHasar;
      default:
        return Durum.orta;
    }
  }

  /// JSON'a dönüştürür
  String toJson() => name;

  /// JSON'dan oluşturur
  static Durum fromJson(String json) => values.firstWhere(
        (e) => e.name == json,
        orElse: () => Durum.orta,
      );
}
