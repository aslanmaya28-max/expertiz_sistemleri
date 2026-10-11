import 'durumlu_soru_model.dart';

/// Adım 1: Araç ve Satıcı Bilgileri Modeli
class Adim1AracSaticiModel {
  // Görev ID
  final String gorevId;
  final String personelId;

  // 🚗 Araç Bilgileri (ZORUNLU)
  final String marka;
  final String model;
  final String? yil;
  final String yakitTuru;
  final String plaka;
  final String saseNo;
  final String motorNo; // Yeni alan
  final int guncelKm;
  final DateTime? enSonBakimTarihi;
  final DateTime? sonMuayeneTarihi;
  
  // Paket bilgisi
  final String? paket;

  // ⚠️ Hasar Bilgileri (OPSİYONEL)
  final int? hasarKayitAdet;
  final double? hasarKayitToplamTutar;
  double? get hasarKayitTutar => hasarKayitToplamTutar; // Alias

  // 👤 Ruhsat / Satıcı Bilgileri (ZORUNLU)
  final String ruhsatSahibiAdSoyad;
  final String iletisimTelefon;

  // 🔸 Durum Sekme Mantığı
  final List<DurumluSoru> durumSorular;

  // Pazarlık bilgisi
  final bool pazarlikPayiVar;
  final double? pazarlikMiktari;

  // Genel Not
  final String? genelNot;

  // Fotoğraflar
  final List<String> fotografUrlleri;

  // Kayıt tarihi
  final DateTime kayitTarihi;

  Adim1AracSaticiModel({
    required this.gorevId,
    required this.personelId,
    required this.marka,
    required this.model,
    this.yil,
    required this.yakitTuru,
    required this.plaka,
    required this.saseNo,
    required this.motorNo,
    required this.guncelKm,
    required this.ruhsatSahibiAdSoyad,
    required this.iletisimTelefon,
    this.enSonBakimTarihi,
    this.sonMuayeneTarihi,
    this.paket,
    this.hasarKayitAdet,
    this.hasarKayitToplamTutar,
    this.pazarlikPayiVar = false,
    this.pazarlikMiktari,
    this.genelNot,
    List<DurumluSoru>? durumSorular,
    List<String>? fotografUrlleri,
  })  : durumSorular = durumSorular ?? _defaultDurumSorular(),
        fotografUrlleri = fotografUrlleri ?? [],
        kayitTarihi = DateTime.now();

  /// Varsayılan durum soruları
  static List<DurumluSoru> _defaultDurumSorular() {
    return [
      DurumluSoru(
        soru: 'Satıcı aracı temiz getirdi mi?',
        zorunlu: true,
      ),
      DurumluSoru(
        soru: 'Satıcının araç bilgisi',
        zorunlu: true,
      ),
    ];
  }

  /// JSON'dan Adim1AracSaticiModel nesnesi oluştur
  factory Adim1AracSaticiModel.fromJson(Map<String, dynamic> json) {
    return Adim1AracSaticiModel(
      gorevId: json['gorevId']?.toString() ?? '',
      personelId: json['personelId']?.toString() ?? '',
      marka: json['marka']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      yakitTuru: json['yakitTuru']?.toString() ?? '',
      yil: json['yil']?.toString(),
      plaka: json['plaka']?.toString() ?? '',
      saseNo: json['saseNo']?.toString() ?? '',
      motorNo: json['motorNo'] as String? ?? '', // Geriye dönük uyumluluk
      guncelKm: (json['guncelKm'] as num?)?.toInt() ?? 0,
      enSonBakimTarihi: json['enSonBakimTarihi'] != null
          ? DateTime.tryParse(json['enSonBakimTarihi'].toString())
          : null,
      sonMuayeneTarihi: json['sonMuayeneTarihi'] != null
          ? DateTime.tryParse(json['sonMuayeneTarihi'].toString())
          : null,
      paket: json['paket'] as String?,
      hasarKayitAdet: (json['hasarKayitAdet'] as num?)?.toInt(),
      hasarKayitToplamTutar: (json['hasarKayitToplamTutar'] as num?)?.toDouble(),
      ruhsatSahibiAdSoyad: json['ruhsatSahibiAdSoyad']?.toString() ?? '',
      iletisimTelefon: json['iletisimTelefon']?.toString() ?? '',
      pazarlikPayiVar: json['pazarlikPayiVar'] as bool? ?? false,
      pazarlikMiktari: (json['pazarlikMiktari'] as num?)?.toDouble(),
      genelNot: json['genelNot'] as String?,
      durumSorular: (json['durumSorular'] as List<dynamic>?)
              ?.map((e) => DurumluSoru.fromJson(e as Map<String, dynamic>))
              .toList() ??
          _defaultDurumSorular(),
      fotografUrlleri: (json['fotografUrlleri'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  /// Adim1AracSaticiModel nesnesini JSON'a çevir
  Map<String, dynamic> toJson() {
    return toMap();
  }

  Map<String, dynamic> toMap() {
    return {
      'gorevId': gorevId,
      'personelId': personelId,
      'marka': marka,
      'model': model,
      'yil': yil,
      'yakitTuru': yakitTuru,
      'plaka': plaka,
      'saseNo': saseNo,
      'motorNo': motorNo,
      'guncelKm': guncelKm,
      'enSonBakimTarihi': enSonBakimTarihi?.toIso8601String(),
      'sonMuayeneTarihi': sonMuayeneTarihi?.toIso8601String(),
      'paket': paket,
      'hasarKayitAdet': hasarKayitAdet,
      'hasarKayitToplamTutar': hasarKayitToplamTutar,
      'ruhsatSahibiAdSoyad': ruhsatSahibiAdSoyad,
      'iletisimTelefon': iletisimTelefon,
      'pazarlikPayiVar': pazarlikPayiVar,
      'pazarlikMiktari': pazarlikMiktari,
      'genelNot': genelNot,
      'durumSorular': durumSorular.map((e) => e.toJson()).toList(),
      'fotografUrlleri': fotografUrlleri,
      'kayitTarihi': kayitTarihi.toIso8601String(),
    };
  }

  factory Adim1AracSaticiModel.fromMap(Map<String, dynamic> map) {
    return Adim1AracSaticiModel.fromJson(map);
  }

  /// Modeli kopyalar ve belirtilen alanları günceller
  Adim1AracSaticiModel copyWith({
    String? gorevId,
    String? personelId,
    String? marka,
    String? model,
    String? yakitTuru,
    String? plaka,
    String? saseNo,
    String? motorNo,
    int? guncelKm,
    DateTime? enSonBakimTarihi,
    DateTime? sonMuayeneTarihi,
    String? paket,
    int? hasarKayitAdet,
    double? hasarKayitToplamTutar,
    String? ruhsatSahibiAdSoyad,
    String? iletisimTelefon,
    bool? pazarlikPayiVar,
    double? pazarlikMiktari,
    String? genelNot,
    List<DurumluSoru>? durumSorular,
    List<String>? fotografUrlleri,
  }) {
    return Adim1AracSaticiModel(
      gorevId: gorevId ?? this.gorevId,
      personelId: personelId ?? this.personelId,
      marka: marka ?? this.marka,
      model: model ?? this.model,
      yakitTuru: yakitTuru ?? this.yakitTuru,
      plaka: plaka ?? this.plaka,
      saseNo: saseNo ?? this.saseNo,
      motorNo: motorNo ?? this.motorNo,
      guncelKm: guncelKm ?? this.guncelKm,
      enSonBakimTarihi: enSonBakimTarihi ?? this.enSonBakimTarihi,
      sonMuayeneTarihi: sonMuayeneTarihi ?? this.sonMuayeneTarihi,
      paket: paket ?? this.paket,
      hasarKayitAdet: hasarKayitAdet ?? this.hasarKayitAdet,
      hasarKayitToplamTutar: hasarKayitToplamTutar ?? this.hasarKayitToplamTutar,
      ruhsatSahibiAdSoyad: ruhsatSahibiAdSoyad ?? this.ruhsatSahibiAdSoyad,
      iletisimTelefon: iletisimTelefon ?? this.iletisimTelefon,
      pazarlikPayiVar: pazarlikPayiVar ?? this.pazarlikPayiVar,
      pazarlikMiktari: pazarlikMiktari ?? this.pazarlikMiktari,
      genelNot: genelNot ?? this.genelNot,
      durumSorular: durumSorular ?? this.durumSorular,
      fotografUrlleri: fotografUrlleri ?? this.fotografUrlleri,
    );
  }

  /// Zorunlu alanların doldurulup doldurulmadığını kontrol eder
  bool get isValid {
    return marka.isNotEmpty &&
        model.isNotEmpty &&
        yakitTuru.isNotEmpty &&
        plaka.isNotEmpty &&
        saseNo.isNotEmpty &&
        guncelKm >= 0 &&
        ruhsatSahibiAdSoyad.isNotEmpty &&
        iletisimTelefon.isNotEmpty &&
        durumSorular.every((soru) => soru.isFilled) &&
        (!pazarlikPayiVar || (pazarlikMiktari != null && pazarlikMiktari! > 0));
  }

  /// Araç tam adını döndürür
  String get aracTamAdi => '$marka $model';

  /// String reprazantasyonu
  @override
  String toString() {
    return 'Adim1AracSaticiModel(arac: $aracTamAdi, plaka: $plaka, km: $guncelKm)';
  }

  /// Doldurulmuş alan sayısı
  int get filledFields {
    int count = 0;
    final fields = [
      marka.isNotEmpty ? 1 : 0,
      model.isNotEmpty ? 1 : 0,
      yakitTuru.isNotEmpty ? 1 : 0,
      plaka.isNotEmpty ? 1 : 0,
      saseNo.isNotEmpty ? 1 : 0,
      motorNo.isNotEmpty ? 1 : 0,
      guncelKm >= 0 ? 1 : 0,
      ruhsatSahibiAdSoyad.isNotEmpty ? 1 : 0,
      iletisimTelefon.isNotEmpty ? 1 : 0,
    ];
    for (final field in fields) {
      if (field == 1) count++;
    }
    return count;
  }

  /// Toplam alan sayısı
  int get totalFields => 10;

  /// Dolum yüzdesi
  double get completionPercentage => filledFields / totalFields;

  /// Yakıt türleri listesi
  static List<String> get yakitTurleri => [
        'Benzin',
        'Dizel',
        'LPG',
        'Benzin + LPG',
        'Elektrik',
        'Hibrit',
      ];

  /// Boş model oluştur
  static Adim1AracSaticiModel empty({String? gorevId, String? personelId}) {
    return Adim1AracSaticiModel(
      gorevId: gorevId ?? '',
      personelId: personelId ?? '',
      marka: '',
      model: '',
      yakitTuru: 'Benzin',
      plaka: '',
      saseNo: '',
      motorNo: '',
      guncelKm: 0,
      ruhsatSahibiAdSoyad: '',
      iletisimTelefon: '',
    );
  }
  bool get isEmpty => marka.isEmpty && model.isEmpty && saseNo.isEmpty;
}
