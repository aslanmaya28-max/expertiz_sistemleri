import 'ai_skor_model.dart';
import 'ai_oneri_model.dart';
import 'ai_rapor_ozeti_model.dart';

/// AI Analiz Sonucu Modeli
/// Tam bir AI analiz sonucunu içerir (skorlar, öneriler, özet)
class AIAnalizSonucu {
  // Görev ID
  final String gorevId;

  // Analiz zamanı
  final DateTime analizZamani;

  // AI skorları
  final AISkorModel skorlar;

  // AI önerileri
  final List<AIOneriModel> oneriler;

  // AI rapor özeti
  final AIRaporOzetiModel raporOzeti;

  // Kritik sorunlar listesi
  final List<String> kritikSorunlar;

  // Fotoğraf analizi sonuçları
  final Map<String, dynamic> fotografAnalizi;

  // Finansal projeksiyonlar (AIEngine'den gelen veriler)
  final Map<String, dynamic> finansalProjeksiyonlar;

  // Analiz tamamlanıp tamamlanmadığı
  final bool tamamlandiMi;

  // Hata mesajı (varsa)
  final String? hataMesaji;

  AIAnalizSonucu({
    required this.gorevId,
    required this.skorlar,
    required this.oneriler,
    required this.raporOzeti,
    List<String>? kritikSorunlar,
    Map<String, dynamic>? fotografAnalizi,
    Map<String, dynamic>? finansalProjeksiyonlar,
    this.tamamlandiMi = true,
    this.hataMesaji,
    DateTime? analizZamani,
  })  : kritikSorunlar = kritikSorunlar ?? [],
        fotografAnalizi = fotografAnalizi ?? {},
        finansalProjeksiyonlar = finansalProjeksiyonlar ?? {},
        analizZamani = analizZamani ?? DateTime.now();

  /// JSON'dan AIAnalizSonucu nesnesi oluştur
  factory AIAnalizSonucu.fromJson(Map<String, dynamic> json) {
    return AIAnalizSonucu(
      gorevId: json['gorevId'] as String,
      analizZamani: json['analizZamani'] != null
          ? DateTime.parse(json['analizZamani'] as String)
          : DateTime.now(),
      skorlar: AISkorModel.fromJson(json['skorlar'] as Map<String, dynamic>),
      oneriler: (json['oneriler'] as List<dynamic>?)
              ?.map((e) => AIOneriModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      raporOzeti: AIRaporOzetiModel.fromJson(
          json['raporOzeti'] as Map<String, dynamic>),
      kritikSorunlar: (json['kritikSorunlar'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      fotografAnalizi: json['fotografAnalizi'] as Map<String, dynamic>? ?? {},
      finansalProjeksiyonlar: json['finansalProjeksiyonlar'] as Map<String, dynamic>? ?? {},
      tamamlandiMi: json['tamamlandiMi'] as bool? ?? true,
      hataMesaji: json['hataMesaji'] as String?,
    );
  }

  /// AIAnalizSonucu nesnesini JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'gorevId': gorevId,
      'analizZamani': analizZamani.toIso8601String(),
      'skorlar': skorlar.toJson(),
      'oneriler': oneriler.map((e) => e.toJson()).toList(),
      'raporOzeti': raporOzeti.toJson(),
      'kritikSorunlar': kritikSorunlar,
      'fotografAnalizi': fotografAnalizi,
      'finansalProjeksiyonlar': finansalProjeksiyonlar,
      'tamamlandiMi': tamamlandiMi,
      'hataMesaji': hataMesaji,
    };
  }

  /// Modeli kopyalar ve belirtilen alanları günceller
  AIAnalizSonucu copyWith({
    String? gorevId,
    DateTime? analizZamani,
    AISkorModel? skorlar,
    List<AIOneriModel>? oneriler,
    AIRaporOzetiModel? raporOzeti,
    List<String>? kritikSorunlar,
    Map<String, dynamic>? fotografAnalizi,
    Map<String, dynamic>? finansalProjeksiyonlar,
    bool? tamamlandiMi,
    String? hataMesaji,
  }) {
    return AIAnalizSonucu(
      gorevId: gorevId ?? this.gorevId,
      analizZamani: analizZamani ?? this.analizZamani,
      skorlar: skorlar ?? this.skorlar,
      oneriler: oneriler ?? this.oneriler,
      raporOzeti: raporOzeti ?? this.raporOzeti,
      kritikSorunlar: kritikSorunlar ?? this.kritikSorunlar,
      fotografAnalizi: fotografAnalizi ?? this.fotografAnalizi,
      finansalProjeksiyonlar: finansalProjeksiyonlar ?? this.finansalProjeksiyonlar,
      tamamlandiMi: tamamlandiMi ?? this.tamamlandiMi,
      hataMesaji: hataMesaji ?? this.hataMesaji,
    );
  }

  /// Kritik önerileri filtrele
  List<AIOneriModel> get kritikOneriler =>
      oneriler.where((o) => o.kategori == 'Kritik').toList();

  /// Önemli önerileri filtrele
  List<AIOneriModel> get onemliOneriler =>
      oneriler.where((o) => o.kategori == 'Önemli').toList();

  /// Normal önerileri filtrele
  List<AIOneriModel> get normalOneriler =>
      oneriler.where((o) => o.kategori == 'Öneri').toList();

  /// Toplam kritik sorun sayısı
  int get kritikSorunSayisi => kritikSorunlar.length;

  /// Analizin tamamlanıp tamamlanmadığını kontrol eder
  bool get isTamamlandi => tamamlandiMi;

  /// Analizin hata verip vermediğini kontrol eder
  bool get hasHata => hataMesaji != null && hataMesaji!.isNotEmpty;

  /// Genel puan değerlendirmesi
  String get genelPuanDegerlendirmesi => skorlar.puanDegerlendirmesi;

  /// Genel puan rengi
  String get genelPuanRengi => skorlar.puanRengi;

  /// String reprazantasyonu
  @override
  String toString() {
    return 'AIAnalizSonucu(gorev: $gorevId, tamamlandi: $tamamlandiMi, genelPuan: ${skorlar.genelPuan})';
  }

  /// Boş model oluştur
  static AIAnalizSonucu empty({required String gorevId}) {
    return AIAnalizSonucu(
      gorevId: gorevId,
      skorlar: AISkorModel.empty(),
      oneriler: [],
      raporOzeti: AIRaporOzetiModel.empty(),
      kritikSorunlar: [],
      fotografAnalizi: {},
      finansalProjeksiyonlar: {},
      tamamlandiMi: false,
    );
  }
}
