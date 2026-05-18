import 'durum_enum.dart';

/// Durum seçimi olan soru modeli
/// Expertiz formlarında kullanılan yeniden kullanılabilir soru yapısı
class DurumluSoru {
  final String soru;
  final Durum? durum;
  final String? not;
  final bool zorunlu;
  final bool notAl;
  final String? fotoYolu;

  DurumluSoru({
    required this.soru,
    this.durum,
    this.not,
    this.zorunlu = false,
    this.notAl = true,
    this.fotoYolu,
  });

  /// Soruyu kopyalar ve belirtilen alanları günceller
  DurumluSoru copyWith({
    String? soru,
    Durum? durum,
    String? not,
    bool? zorunlu,
    bool? notAl,
    String? fotoYolu,
  }) {
    return DurumluSoru(
      soru: soru ?? this.soru,
      durum: durum ?? this.durum,
      not: not ?? this.not,
      zorunlu: zorunlu ?? this.zorunlu,
      notAl: notAl ?? this.notAl,
      fotoYolu: fotoYolu ?? this.fotoYolu,
    );
  }

  /// JSON'dan DurumluSoru nesnesi oluştur
  factory DurumluSoru.fromJson(Map<String, dynamic> json) {
    return DurumluSoru(
      soru: json['soru'] as String,
      durum: json['durum'] != null ? Durum.fromJson(json['durum'] as String) : null,
      not: json['not'] as String?,
      zorunlu: json['zorunlu'] as bool? ?? false,
      notAl: json['notAl'] as bool? ?? true,
      fotoYolu: json['fotoYolu'] as String?,
    );
  }

  /// DurumluSoru nesnesini JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'soru': soru,
      'durum': durum?.toJson(),
      'not': not,
      'zorunlu': zorunlu,
      'notAl': notAl,
      'fotoYolu': fotoYolu,
    };
  }

  /// Sorunun doldurulup doldurulmadığını kontrol eder
  bool get isFilled => durum != null && (!zorunlu || (not != null && not!.isNotEmpty));

  @override
  String toString() {
    return 'DurumluSoru(soru: $soru, durum: $durum, not: $not, fotoYolu: $fotoYolu)';
  }
}
