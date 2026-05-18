import 'package:flutter/material.dart';

/// AI Rapor Özeti Modeli
/// AI tarafından üretilen rapor özetini içerir
class AIRaporOzetiModel {
  // Genel sonuc: 'Mükemmel', 'Çok İyi', 'İyi', 'Orta', 'Yeterli', 'Yetersiz'
  final String genelSonuc;

  // Anahtar bulgular
  final List<String> anahtarBulgular;

  // Özet açıklama
  final String ozetAciklama;

  // Onay/Red önerisi
  final String onayRedOnerisi;

  // Tahmini piyasa değeri
  final double tahminiDeger;

  // Değer kaybı yüzdesi
  final double degerKaybiYuzde;

  // 1 yıllık değer projeksiyonu
  final double degerProjeksiyonu1Yil;

  // 6 aylık getiri projeksiyonu
  final double altiAylikGetiri;

  // Özet oluşturulma tarihi
  final DateTime olusturmaZamani;

  AIRaporOzetiModel({
    required this.genelSonuc,
    required this.anahtarBulgular,
    required this.ozetAciklama,
    required this.onayRedOnerisi,
    required this.tahminiDeger,
    required this.degerKaybiYuzde,
    required this.degerProjeksiyonu1Yil,
    required this.altiAylikGetiri,
    DateTime? olusturmaZamani,
  }) : olusturmaZamani = olusturmaZamani ?? DateTime.now();

  /// JSON'dan AIRaporOzetiModel nesnesi oluştur
  factory AIRaporOzetiModel.fromJson(Map<String, dynamic> json) {
    return AIRaporOzetiModel(
      genelSonuc: json['genelSonuc'] as String,
      anahtarBulgular: (json['anahtarBulgular'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      ozetAciklama: json['ozetAciklama'] as String,
      onayRedOnerisi: json['onayRedOnerisi'] as String,
      tahminiDeger: (json['tahminiDeger'] as num?)?.toDouble() ?? 0.0,
      degerKaybiYuzde: (json['degerKaybiYuzde'] as num?)?.toDouble() ?? 0.0,
      degerProjeksiyonu1Yil: (json['degerProjeksiyonu1Yil'] as num?)?.toDouble() ?? 0.0,
      altiAylikGetiri: (json['altiAylikGetiri'] as num?)?.toDouble() ?? 0.0,
      olusturmaZamani: json['olusturmaZamani'] != null
          ? DateTime.parse(json['olusturmaZamani'] as String)
          : DateTime.now(),
    );
  }

  /// AIRaporOzetiModel nesnesini JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'genelSonuc': genelSonuc,
      'anahtarBulgular': anahtarBulgular,
      'ozetAciklama': ozetAciklama,
      'onayRedOnerisi': onayRedOnerisi,
      'tahminiDeger': tahminiDeger,
      'degerKaybiYuzde': degerKaybiYuzde,
      'degerProjeksiyonu1Yil': degerProjeksiyonu1Yil,
      'altiAylikGetiri': altiAylikGetiri,
      'olusturmaZamani': olusturmaZamani.toIso8601String(),
    };
  }

  /// Modeli kopyalar ve belirtilen alanları günceller
  AIRaporOzetiModel copyWith({
    String? genelSonuc,
    List<String>? anahtarBulgular,
    String? ozetAciklama,
    String? onayRedOnerisi,
    double? tahminiDeger,
    double? degerKaybiYuzde,
    double? degerProjeksiyonu1Yil,
    double? altiAylikGetiri,
    DateTime? olusturmaZamani,
  }) {
    return AIRaporOzetiModel(
      genelSonuc: genelSonuc ?? this.genelSonuc,
      anahtarBulgular: anahtarBulgular ?? this.anahtarBulgular,
      ozetAciklama: ozetAciklama ?? this.ozetAciklama,
      onayRedOnerisi: onayRedOnerisi ?? this.onayRedOnerisi,
      tahminiDeger: tahminiDeger ?? this.tahminiDeger,
      degerKaybiYuzde: degerKaybiYuzde ?? this.degerKaybiYuzde,
      degerProjeksiyonu1Yil: degerProjeksiyonu1Yil ?? this.degerProjeksiyonu1Yil,
      altiAylikGetiri: altiAylikGetiri ?? this.altiAylikGetiri,
      olusturmaZamani: olusturmaZamani ?? this.olusturmaZamani,
    );
  }

  /// Sonuc rengini döndürür
  Color get sonucRengi {
    switch (genelSonuc) {
      case 'Mükemmel':
        return const Color(0xFF4CAF50); // Green
      case 'Çok İyi':
        return const Color(0xFF8BC34A); // Light Green
      case 'İyi':
        return const Color(0xFFFFC107); // Amber
      case 'Orta':
        return const Color(0xFFFF9800); // Orange
      case 'Yeterli':
        return const Color(0xFFFF5722); // Deep Orange
      case 'Yetersiz':
        return const Color(0xFFF44336); // Red
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  /// Sonuc ikonunu döndürür
  IconData get sonucIkonu {
    switch (genelSonuc) {
      case 'Mükemmel':
      case 'Çok İyi':
      case 'İyi':
        return Icons.check_circle;
      case 'Orta':
      case 'Yeterli':
        return Icons.warning;
      case 'Yetersiz':
        return Icons.cancel;
      default:
        return Icons.description;
    }
  }

  /// Tahmini değeri formatlı string olarak döndürür
  String get tahminiDegerFormatli => _formatDeger(tahminiDeger);

  /// Değer kaybını formatlı string olarak döndürür
  String get degerKaybiFormatli => degerKaybiYuzde > 0
      ? '%${degerKaybiYuzde.toStringAsFixed(1)}'
      : '-';

  /// Değer projeksiyonunu formatlı string olarak döndürür
  String get degerProjeksiyonuFormatli => _formatDeger(degerProjeksiyonu1Yil);

  /// Değer formatlama
  String _formatDeger(double deger) {
    if (deger <= 0) return '-';
    return '₺${deger.toStringAsFixed(0)}';
  }

  /// Anahtar bulgu sayısı
  int get anahtarBulguSayisi => anahtarBulgular.length;

  /// Özetin geçerli olup olmadığını kontrol eder
  bool get isValid {
    return genelSonuc.isNotEmpty &&
        ozetAciklama.isNotEmpty &&
        onayRedOnerisi.isNotEmpty;
  }

  /// Onay önerisi mi?
  bool get isOnay => onayRedOnerisi.contains('Onay');

  /// Red önerisi mi?
  bool get isRed => onayRedOnerisi.contains('Red');

  /// Dikkat önerisi mi?
  bool get isDikkat => onayRedOnerisi.contains('Dikkat');

  /// String reprazantasyonu
  @override
  String toString() {
    return 'AIRaporOzetiModel(genelSonuc: $genelSonuc, bulgular: $anahtarBulguSayisi, deger: $tahminiDegerFormatli)';
  }

  /// Genel sonuç listesi
  static List<String> get genelSonuclar => [
        'Mükemmel',
        'Çok İyi',
        'İyi',
        'Orta',
        'Yeterli',
        'Yetersiz',
      ];

  /// Boş model oluştur
  static AIRaporOzetiModel empty() {
    return AIRaporOzetiModel(
      genelSonuc: 'Orta',
      anahtarBulgular: [],
      ozetAciklama: '',
      onayRedOnerisi: 'Dikkat',
      tahminiDeger: 0.0,
      degerKaybiYuzde: 0.0,
      degerProjeksiyonu1Yil: 0.0,
      altiAylikGetiri: 0.0,
    );
  }
}
