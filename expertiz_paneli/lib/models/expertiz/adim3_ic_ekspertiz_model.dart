/// Adım 3: İç Ekspertiz Modeli
class Adim3IcEkspertizModel {
  // Görev ID
  final String gorevId;
  final String personelId;

  // 🎛️ KOKPİT
  String? direksiyon;
  String? gostergePaneli;
  String? klima;
  String? sesSistemi;

  // 💺 KOLTUKLAR
  String? onKoltuklar;
  String? arkaKoltuklar;
  String? get arkaKoltukler => arkaKoltuklar;
  set arkaKoltukler(String? value) => arkaKoltuklar = value;
  String? koltukDosemesi;

  // 🪟 DÖŞEME
  String? dorseme;
  String? tavanDosemesi;

  // 🪟 PENCERELER
  String? onPencereler;
  String? arkaPencereler;
  String? camlar;

  // 🔌 ELEKTRONİK
  String? merkeziKilit;
  String? camKontrolleri;
  String? aynaKontrolleri;

  // 📝 NOTLAR
  String? genelNot;
  Map<String, String>? aciklamalar; // Her madde için açıklama
  Map<String, List<String>>? fotografUrl; // Her madde için fotoğraflar
  Map<String, String>? fotografYolu; // Her madde için ilk fotoğraf yolu (thumbnail)
  List<String> fotografUrlleri; // Eski uyumluluk için

  // Kayıt tarihi
  final DateTime kayitTarihi;

  Adim3IcEkspertizModel({
    required this.gorevId,
    required this.personelId,
    this.direksiyon,
    this.gostergePaneli,
    this.klima,
    this.sesSistemi,
    this.onKoltuklar,
    this.arkaKoltuklar,
    this.koltukDosemesi,
    this.dorseme,
    this.tavanDosemesi,
    this.onPencereler,
    this.arkaPencereler,
    this.camlar,
    this.merkeziKilit,
    this.camKontrolleri,
    this.aynaKontrolleri,
    this.genelNot,
    this.aciklamalar,
    this.fotografUrl,
    this.fotografYolu,
    List<String>? fotografUrlleri,
  })  : fotografUrlleri = fotografUrlleri ?? [],
        kayitTarihi = DateTime.now();

  /// JSON'dan Adim3IcEkspertizModel nesnesi oluştur
  factory Adim3IcEkspertizModel.fromJson(Map<String, dynamic> json) {
    final aciklamalarMap = json['aciklamalar'] as Map<String, dynamic>?;
    final fotografUrlMap = json['fotografUrl'] as Map<String, dynamic>?;
    final fotografYoluMap = json['fotografYolu'] as Map<String, dynamic>?;
    
    return Adim3IcEkspertizModel(
      gorevId: json['gorevId'] as String,
      personelId: json['personelId'] as String,
      direksiyon: json['direksiyon'] as String?,
      gostergePaneli: json['gostergePaneli'] as String?,
      klima: json['klima'] as String?,
      sesSistemi: json['sesSistemi'] as String?,
      onKoltuklar: json['onKoltuklar'] as String?,
      arkaKoltuklar: json['arkaKoltuklar'] as String?,
      koltukDosemesi: json['koltukDosemesi'] as String?,
      dorseme: json['dorseme'] as String?,
      tavanDosemesi: json['tavanDosemesi'] as String?,
      onPencereler: json['onPencereler'] as String?,
      arkaPencereler: json['arkaPencereler'] as String?,
      camlar: json['camlar'] as String?,
      merkeziKilit: json['merkeziKilit'] as String?,
      camKontrolleri: json['camKontrolleri'] as String?,
      aynaKontrolleri: json['aynaKontrolleri'] as String?,
      genelNot: json['genelNot'] as String?,
      aciklamalar: aciklamalarMap?.map((key, value) => MapEntry(key, value as String)),
      fotografUrl: fotografUrlMap?.map((key, value) => MapEntry(key, (value as List<dynamic>).map((e) => e as String).toList())),
      fotografYolu: fotografYoluMap?.map((key, value) => MapEntry(key, value as String)),
      fotografUrlleri: (json['fotografUrlleri'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    );
  }

  /// Adim3IcEkspertizModel nesnesini JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'gorevId': gorevId,
      'personelId': personelId,
      'direksiyon': direksiyon,
      'gostergePaneli': gostergePaneli,
      'klima': klima,
      'sesSistemi': sesSistemi,
      'onKoltuklar': onKoltuklar,
      'arkaKoltuklar': arkaKoltuklar,
      'koltukDosemesi': koltukDosemesi,
      'dorseme': dorseme,
      'tavanDosemesi': tavanDosemesi,
      'onPencereler': onPencereler,
      'arkaPencereler': arkaPencereler,
      'camlar': camlar,
      'merkeziKilit': merkeziKilit,
      'camKontrolleri': camKontrolleri,
      'aynaKontrolleri': aynaKontrolleri,
      'genelNot': genelNot,
      'aciklamalar': aciklamalar,
      'fotografUrl': fotografUrl,
      'fotografYolu': fotografYolu,
      'fotografUrlleri': fotografUrlleri,
      'kayitTarihi': kayitTarihi.toIso8601String(),
    };
  }

  /// Modeli kopyalar ve belirtilen alanları günceller
  Adim3IcEkspertizModel copyWith({
    String? gorevId,
    String? personelId,
    String? direksiyon,
    String? gostergePaneli,
    String? klima,
    String? sesSistemi,
    String? onKoltuklar,
    String? arkaKoltuklar,
    String? koltukDosemesi,
    String? dorseme,
    String? tavanDosemesi,
    String? onPencereler,
    String? arkaPencereler,
    String? camlar,
    String? merkeziKilit,
    String? camKontrolleri,
    String? aynaKontrolleri,
    String? genelNot,
    Map<String, String>? aciklamalar,
    Map<String, List<String>>? fotografUrl,
    Map<String, String>? fotografYolu,
    List<String>? fotografUrlleri,
  }) {
    return Adim3IcEkspertizModel(
      gorevId: gorevId ?? this.gorevId,
      personelId: personelId ?? this.personelId,
      direksiyon: direksiyon ?? this.direksiyon,
      gostergePaneli: gostergePaneli ?? this.gostergePaneli,
      klima: klima ?? this.klima,
      sesSistemi: sesSistemi ?? this.sesSistemi,
      onKoltuklar: onKoltuklar ?? this.onKoltuklar,
      arkaKoltuklar: arkaKoltuklar ?? this.arkaKoltuklar,
      koltukDosemesi: koltukDosemesi ?? this.koltukDosemesi,
      dorseme: dorseme ?? this.dorseme,
      tavanDosemesi: tavanDosemesi ?? this.tavanDosemesi,
      onPencereler: onPencereler ?? this.onPencereler,
      arkaPencereler: arkaPencereler ?? this.arkaPencereler,
      camlar: camlar ?? this.camlar,
      merkeziKilit: merkeziKilit ?? this.merkeziKilit,
      camKontrolleri: camKontrolleri ?? this.camKontrolleri,
      aynaKontrolleri: aynaKontrolleri ?? this.aynaKontrolleri,
      genelNot: genelNot ?? this.genelNot,
      aciklamalar: aciklamalar ?? this.aciklamalar,
      fotografUrl: fotografUrl ?? this.fotografUrl,
      fotografYolu: fotografYolu ?? this.fotografYolu,
      fotografUrlleri: fotografUrlleri ?? this.fotografUrlleri,
    );
  }

  /// Tüm durum alanlarının doldurulup doldurulmadığını kontrol eder
  bool get isValid {
    return direksiyon != null &&
        gostergePaneli != null &&
        klima != null &&
        sesSistemi != null &&
        onKoltuklar != null &&
        arkaKoltuklar != null &&
        koltukDosemesi != null &&
        dorseme != null &&
        tavanDosemesi != null &&
        onPencereler != null &&
        arkaPencereler != null &&
        camlar != null &&
        merkeziKilit != null &&
        camKontrolleri != null &&
        aynaKontrolleri != null;
  }

  /// Doldurulmuş alan sayısı
  int get filledFields {
    int count = 0;
    final fields = [
      direksiyon, gostergePaneli, klima, sesSistemi,
      onKoltuklar, arkaKoltuklar, koltukDosemesi,
      dorseme, tavanDosemesi,
      onPencereler, arkaPencereler, camlar,
      merkeziKilit, camKontrolleri, aynaKontrolleri
    ];
    for (final field in fields) {
      if (field != null) count++;
    }
    return count;
  }

  /// Toplam alan sayısı
  int get totalFields => 16;

  /// Dolum yüzdesi
  double get completionPercentage => filledFields / totalFields;

  /// String reprazantasyonu
  @override
  String toString() {
    return 'Adim3IcEkspertizModel(durum: $filledFields/$totalFields)';
  }

  /// Boş model oluştur
  static Adim3IcEkspertizModel empty({String? gorevId, String? personelId}) {
    return Adim3IcEkspertizModel(
      gorevId: gorevId ?? '',
      personelId: personelId ?? '',
      direksiyon: null,
      gostergePaneli: null,
      klima: null,
      sesSistemi: null,
      onKoltuklar: null,
      arkaKoltuklar: null,
      koltukDosemesi: null,
      dorseme: null,
      tavanDosemesi: null,
      onPencereler: null,
      arkaPencereler: null,
      camlar: null,
      merkeziKilit: null,
      camKontrolleri: null,
      aynaKontrolleri: null,
      genelNot: null,
      aciklamalar: null,
      fotografUrl: null,
      fotografYolu: null,
      fotografUrlleri: null,
    );
  }

  /// Modelin boş olup olmadığını kontrol eder
  bool get isEmpty => gorevId.isEmpty || personelId.isEmpty;
}
