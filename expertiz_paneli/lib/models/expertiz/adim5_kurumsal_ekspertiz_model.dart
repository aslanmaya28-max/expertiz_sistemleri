/// Adım 5: Kurumsal Ekspertiz Modeli
class Adim5KurumsalEkspertizModel {
  // Görev ID
  final String gorevId;
  final String personelId;

  // 📁 DOSYA KONTROLÜ
  bool? ruhsatDosyasiVar;
  bool? bakimDefteriVar;
  bool? sigortaPolicesiVar;
  bool? muayeneBelgesiVar;

  // FOTOĞRAFLAR
  List<String> ruhsatFotograflari;
  List<String> bakimDefteriFotograflari;
  List<String> sigortaFotograflari;
  List<String> muayeneFotograflari;

  // ⚙️ MOTOR VE MEKANİK
  String? motorDurumu;
  String? sanzimanDurumu;
  String? frenSistemi;
  String? direksiyonSistemi;
  String? elektrikSistemi;

  // 🔋 ELEKTRİKLİ ARAÇLAR İÇİN
  String? yakitTipi; // Adım 1'den gelecek
  double? bataryaSagligi; // SoH %
  String? tahminiMenzil; // km
  String? sarjPortuKondisyonu;
  String? yazilimSurumu;

  // 🎯 OPSİYON/DONANIM (MarketRadarService ile uyumlu)
  List<String> ekstraOpsiyonlar;

  //  DEĞERLENDİRME
  double? genelPuan;
  String? ozetNot;
  String? oneriler;

  // 📝 NOTLAR
  String? genelNot;
  List<String> fotografUrlleri;

  // Kayıt tarihi
  final DateTime kayitTarihi;

  Adim5KurumsalEkspertizModel({
    required this.gorevId,
    required this.personelId,
    this.ruhsatDosyasiVar,
    this.bakimDefteriVar,
    this.sigortaPolicesiVar,
    this.muayeneBelgesiVar,
    List<String>? ruhsatFotograflari,
    List<String>? bakimDefteriFotograflari,
    List<String>? sigortaFotograflari,
    List<String>? muayeneFotograflari,
    this.motorDurumu,
    this.sanzimanDurumu,
    this.frenSistemi,
    this.direksiyonSistemi,
    this.elektrikSistemi,
    this.yakitTipi,
    this.bataryaSagligi,
    this.tahminiMenzil,
    this.sarjPortuKondisyonu,
    this.yazilimSurumu,
    List<String>? ekstraOpsiyonlar,
    this.genelPuan,
    this.ozetNot,
    this.oneriler,
    this.genelNot,
    List<String>? fotografUrlleri,
  })  : ruhsatFotograflari = ruhsatFotograflari ?? [],
        bakimDefteriFotograflari = bakimDefteriFotograflari ?? [],
        sigortaFotograflari = sigortaFotograflari ?? [],
        muayeneFotograflari = muayeneFotograflari ?? [],
        ekstraOpsiyonlar = ekstraOpsiyonlar ?? [],
        fotografUrlleri = fotografUrlleri ?? [],
        kayitTarihi = DateTime.now();

  /// JSON'dan Adim5KurumsalEkspertizModel nesnesi oluştur
  factory Adim5KurumsalEkspertizModel.fromJson(Map<String, dynamic> json) {
    return Adim5KurumsalEkspertizModel(
      gorevId: json['gorevId'] as String,
      personelId: json['personelId'] as String,
      ruhsatDosyasiVar: json['ruhsatDosyasiVar'] as bool?,
      bakimDefteriVar: json['bakimDefteriVar'] as bool?,
      sigortaPolicesiVar: json['sigortaPolicesiVar'] as bool?,
      muayeneBelgesiVar: json['muayeneBelgesiVar'] as bool?,
      ruhsatFotograflari: (json['ruhsatFotograflari'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      bakimDefteriFotograflari: (json['bakimDefteriFotograflari'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      sigortaFotograflari: (json['sigortaFotograflari'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      muayeneFotograflari: (json['muayeneFotograflari'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      motorDurumu: json['motorDurumu'] as String?,
      sanzimanDurumu: json['sanzimanDurumu'] as String?,
      frenSistemi: json['frenSistemi'] as String?,
      direksiyonSistemi: json['direksiyonSistemi'] as String?,
      elektrikSistemi: json['elektrikSistemi'] as String?,
      yakitTipi: json['yakitTipi'] as String?,
      bataryaSagligi: json['bataryaSagligi'] as double?,
      tahminiMenzil: json['tahminiMenzil'] as String?,
      sarjPortuKondisyonu: json['sarjPortuKondisyonu'] as String?,
      yazilimSurumu: json['yazilimSurumu'] as String?,
      ekstraOpsiyonlar: (json['ekstraOpsiyonlar'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      genelPuan: json['genelPuan'] as double?,
      ozetNot: json['ozetNot'] as String?,
      oneriler: json['oneriler'] as String?,
      genelNot: json['genelNot'] as String?,
      fotografUrlleri: (json['fotografUrlleri'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    );
  }

  /// Adim5KurumsalEkspertizModel nesnesini JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'gorevId': gorevId,
      'personelId': personelId,
      'ruhsatDosyasiVar': ruhsatDosyasiVar,
      'bakimDefteriVar': bakimDefteriVar,
      'sigortaPolicesiVar': sigortaPolicesiVar,
      'muayeneBelgesiVar': muayeneBelgesiVar,
      'ruhsatFotograflari': ruhsatFotograflari,
      'bakimDefteriFotograflari': bakimDefteriFotograflari,
      'sigortaFotograflari': sigortaFotograflari,
      'muayeneFotograflari': muayeneFotograflari,
      'motorDurumu': motorDurumu,
      'sanzimanDurumu': sanzimanDurumu,
      'frenSistemi': frenSistemi,
      'direksiyonSistemi': direksiyonSistemi,
      'elektrikSistemi': elektrikSistemi,
      'yakitTipi': yakitTipi,
      'bataryaSagligi': bataryaSagligi,
      'tahminiMenzil': tahminiMenzil,
      'sarjPortuKondisyonu': sarjPortuKondisyonu,
      'yazilimSurumu': yazilimSurumu,
      'ekstraOpsiyonlar': ekstraOpsiyonlar,
      'genelPuan': genelPuan,
      'ozetNot': ozetNot,
      'oneriler': oneriler,
      'genelNot': genelNot,
      'fotografUrlleri': fotografUrlleri,
      'kayitTarihi': kayitTarihi.toIso8601String(),
    };
  }

  /// Modeli kopyalar ve belirtilen alanları günceller
  Adim5KurumsalEkspertizModel copyWith({
    String? gorevId,
    String? personelId,
    bool? ruhsatDosyasiVar,
    bool? bakimDefteriVar,
    bool? sigortaPolicesiVar,
    bool? muayeneBelgesiVar,
    List<String>? ruhsatFotograflari,
    List<String>? bakimDefteriFotograflari,
    List<String>? sigortaFotograflari,
    List<String>? muayeneFotograflari,
    String? motorDurumu,
    String? sanzimanDurumu,
    String? frenSistemi,
    String? direksiyonSistemi,
    String? elektrikSistemi,
    String? yakitTipi,
    double? bataryaSagligi,
    String? tahminiMenzil,
    String? sarjPortuKondisyonu,
    String? yazilimSurumu,
    List<String>? ekstraOpsiyonlar,
    double? genelPuan,
    String? ozetNot,
    String? oneriler,
    String? genelNot,
    List<String>? fotografUrlleri,
  }) {
    return Adim5KurumsalEkspertizModel(
      gorevId: gorevId ?? this.gorevId,
      personelId: personelId ?? this.personelId,
      ruhsatDosyasiVar: ruhsatDosyasiVar ?? this.ruhsatDosyasiVar,
      bakimDefteriVar: bakimDefteriVar ?? this.bakimDefteriVar,
      sigortaPolicesiVar: sigortaPolicesiVar ?? this.sigortaPolicesiVar,
      muayeneBelgesiVar: muayeneBelgesiVar ?? this.muayeneBelgesiVar,
      ruhsatFotograflari: ruhsatFotograflari ?? this.ruhsatFotograflari,
      bakimDefteriFotograflari: bakimDefteriFotograflari ?? this.bakimDefteriFotograflari,
      sigortaFotograflari: sigortaFotograflari ?? this.sigortaFotograflari,
      muayeneFotograflari: muayeneFotograflari ?? this.muayeneFotograflari,
      motorDurumu: motorDurumu ?? this.motorDurumu,
      sanzimanDurumu: sanzimanDurumu ?? this.sanzimanDurumu,
      frenSistemi: frenSistemi ?? this.frenSistemi,
      direksiyonSistemi: direksiyonSistemi ?? this.direksiyonSistemi,
      elektrikSistemi: elektrikSistemi ?? this.elektrikSistemi,
      yakitTipi: yakitTipi ?? this.yakitTipi,
      bataryaSagligi: bataryaSagligi ?? this.bataryaSagligi,
      tahminiMenzil: tahminiMenzil ?? this.tahminiMenzil,
      sarjPortuKondisyonu: sarjPortuKondisyonu ?? this.sarjPortuKondisyonu,
      yazilimSurumu: yazilimSurumu ?? this.yazilimSurumu,
      ekstraOpsiyonlar: ekstraOpsiyonlar ?? this.ekstraOpsiyonlar,
      genelPuan: genelPuan ?? this.genelPuan,
      ozetNot: ozetNot ?? this.ozetNot,
      oneriler: oneriler ?? this.oneriler,
      genelNot: genelNot ?? this.genelNot,
      fotografUrlleri: fotografUrlleri ?? this.fotografUrlleri,
    );
  }

  /// Tüm durum alanlarının doldurulup doldurulmadığını kontrol eder
  bool get isValid {
    return motorDurumu != null &&
        sanzimanDurumu != null &&
        frenSistemi != null &&
        direksiyonSistemi != null &&
        elektrikSistemi != null &&
        genelPuan != null &&
        genelPuan! >= 0 &&
        genelPuan! <= 100;
  }

  /// Doldurulmuş alan sayısı
  int get filledFields {
    int count = 0;
    final fields = [
      motorDurumu, sanzimanDurumu, frenSistemi,
      direksiyonSistemi, elektrikSistemi
    ];
    for (final field in fields) {
      if (field != null) count++;
    }
    return count;
  }

  /// Toplam alan sayısı
  int get totalFields => 5;

  /// Dolum yüzdesi
  double get completionPercentage => filledFields / totalFields;

  /// Dosya kontrolü sayısı
  int get dosyaSayisi {
    int count = 0;
    final dosyalar = [
      ruhsatDosyasiVar, bakimDefteriVar,
      sigortaPolicesiVar, muayeneBelgesiVar
    ];
    for (final dosya in dosyalar) {
      if (dosya != null) count++;
    }
    return count;
  }

  /// Toplam dosya sayısı
  int get totalDosyaSayisi => 4;

  /// Genel puan değerlendirmesi
  String get puanDegerlendirmesi {
    if (genelPuan == null) return 'Belirtilmedi';
    if (genelPuan! >= 90) return 'Mükemmel';
    if (genelPuan! >= 80) return 'Çok İyi';
    if (genelPuan! >= 70) return 'İyi';
    if (genelPuan! >= 60) return 'Orta';
    if (genelPuan! >= 50) return 'Yeterli';
    return 'Yetersiz';
  }

  /// String reprazantasyonu
  @override
  String toString() {
    return 'Adim5KurumsalEkspertizModel(puan: $genelPuan, dosyalar: $dosyaSayisi/$totalDosyaSayisi)';
  }

  /// Boş model oluştur
  static Adim5KurumsalEkspertizModel empty({String? gorevId, String? personelId}) {
    return Adim5KurumsalEkspertizModel(
      gorevId: gorevId ?? '',
      personelId: personelId ?? '',
      ruhsatDosyasiVar: null,
      bakimDefteriVar: null,
      sigortaPolicesiVar: null,
      muayeneBelgesiVar: null,
      ruhsatFotograflari: null,
      bakimDefteriFotograflari: null,
      sigortaFotograflari: null,
      muayeneFotograflari: null,
      motorDurumu: null,
      sanzimanDurumu: null,
      frenSistemi: null,
      direksiyonSistemi: null,
      elektrikSistemi: null,
      yakitTipi: null,
      bataryaSagligi: null,
      tahminiMenzil: null,
      sarjPortuKondisyonu: null,
      yazilimSurumu: null,
      ekstraOpsiyonlar: null,
      genelPuan: null,
      ozetNot: null,
      oneriler: null,
      genelNot: null,
      fotografUrlleri: null,
    );
  }

  /// Modelin boş olup olmadığını kontrol eder
  bool get isEmpty => gorevId.isEmpty || personelId.isEmpty;
}
