/// Adım 2: Dış Ekspertiz Modeli
class Adim2DisEkspertizModel {
  // Görev ID
  final String gorevId;
  final String personelId;

  // 🚗 ÖN KISIM
  String? onTampon;
  String? onFarlar;
  String? onCamurluklar;
  String? onKaput;
  String? motorNo; // Yeni alan


  // 🚗 ARKA KISIM
  String? arkaTampon;
  String? arkaCamurluklar;
  String? bagajKapagi;

  // 🚗 YAN KISIMLAR
  String? solOnKapi;
  String? sagOnKapi;
  String? solArkaKapi;
  String? sagArkaKapi;
  
  // 🚗 EK KAPILAR (Adım 2 sayfası için)
  String? onKapi; // Ön kapılar için genel durum
  String? arkaKapi; // Arka kapılar için genel durum

  // 🚗 TAVAN
  String? tavan;
  String? tavanTente; // Tavan tente için

  // 🚘 ŞASİ
  String? onSasi; // Ön şasi
  String? arkaSasi; // Arka şasi

  // 🚗 KAPORTA
  String? onCamurlar; // Ön çamurlar için
  String? arkaCamurlar; // Arka çamurlar için

  //  LASTİKLER
  String? onLastikler;
  String? arkaLastikler;

  // 📝 NOTLAR
  String? genelNot;
  Map<String, String>? aciklamalar; // Her madde için açıklama
  Map<String, List<String>>? fotografUrl; // Her madde için fotoğraflar
  Map<String, String>? fotografYolu; // Her madde için ilk fotoğraf yolu (thumbnail)
  List<String> fotografUrlleri; // Eski uyumluluk için

  // Kayıt tarihi
  final DateTime kayitTarihi;

  Adim2DisEkspertizModel({
    required this.gorevId,
    required this.personelId,
    this.onTampon,
    this.onFarlar,
    this.onCamurluklar,
    this.onKaput,
    this.motorNo,
    this.arkaTampon,
    this.arkaCamurluklar,
    this.bagajKapagi,
    this.solOnKapi,
    this.sagOnKapi,
    this.solArkaKapi,
    this.sagArkaKapi,
    this.onKapi,
    this.arkaKapi,
    this.tavan,
    this.tavanTente,
    this.onSasi,
    this.arkaSasi,
    this.onCamurlar,
    this.arkaCamurlar,
    this.onLastikler,
    this.arkaLastikler,
    this.genelNot,
    this.aciklamalar,
    this.fotografUrl,
    this.fotografYolu,
    List<String>? fotografUrlleri,
  })  : fotografUrlleri = fotografUrlleri ?? [],
        kayitTarihi = DateTime.now();

  /// JSON'dan Adim2DisEkspertizModel nesnesi oluştur
  factory Adim2DisEkspertizModel.fromJson(Map<String, dynamic> json) {
    final aciklamalarMap = json['aciklamalar'] as Map<String, dynamic>?;
    final fotografUrlMap = json['fotografUrl'] as Map<String, dynamic>?;
    final fotografYoluMap = json['fotografYolu'] as Map<String, dynamic>?;
    
    return Adim2DisEkspertizModel(
      gorevId: json['gorevId'] as String,
      personelId: json['personelId'] as String,
      onTampon: json['onTampon'] as String?,
      onFarlar: json['onFarlar'] as String?,
      onCamurluklar: json['onCamurluklar'] as String?,
      onKaput: json['onKaput'] as String?,
      motorNo: json['motorNo'] as String?,
      arkaTampon: json['arkaTampon'] as String?,
      arkaCamurluklar: json['arkaCamurluklar'] as String?,
      bagajKapagi: json['bagajKapagi'] as String?,
      solOnKapi: json['solOnKapi'] as String?,
      sagOnKapi: json['sagOnKapi'] as String?,
      solArkaKapi: json['solArkaKapi'] as String?,
      sagArkaKapi: json['sagArkaKapi'] as String?,
      onKapi: json['onKapi'] as String?,
      arkaKapi: json['arkaKapi'] as String?,
      tavan: json['tavan'] as String?,
      tavanTente: json['tavanTente'] as String?,
      onSasi: json['onSasi'] as String?,
      arkaSasi: json['arkaSasi'] as String?,
      onCamurlar: json['onCamurlar'] as String?,
      arkaCamurlar: json['arkaCamurlar'] as String?,
      onLastikler: json['onLastikler'] as String?,
      arkaLastikler: json['arkaLastikler'] as String?,
      genelNot: json['genelNot'] as String?,
      aciklamalar: aciklamalarMap?.map((key, value) => MapEntry(key, value as String)),
      fotografUrl: fotografUrlMap?.map((key, value) => MapEntry(key, (value as List<dynamic>).map((e) => e as String).toList())),
      fotografYolu: fotografYoluMap?.map((key, value) => MapEntry(key, value as String)),
      fotografUrlleri: (json['fotografUrlleri'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    );
  }

  /// Adim2DisEkspertizModel nesnesini JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'gorevId': gorevId,
      'personelId': personelId,
      'onTampon': onTampon,
      'onFarlar': onFarlar,
      'onCamurluklar': onCamurluklar,
      'onKaput': onKaput,
      'motorNo': motorNo,
      'arkaTampon': arkaTampon,
      'arkaCamurluklar': arkaCamurluklar,
      'bagajKapagi': bagajKapagi,
      'solOnKapi': solOnKapi,
      'sagOnKapi': sagOnKapi,
      'solArkaKapi': solArkaKapi,
      'sagArkaKapi': sagArkaKapi,
      'onKapi': onKapi,
      'arkaKapi': arkaKapi,
      'tavan': tavan,
      'tavanTente': tavanTente,
      'onSasi': onSasi,
      'arkaSasi': arkaSasi,
      'onCamurlar': onCamurlar,
      'arkaCamurlar': arkaCamurlar,
      'onLastikler': onLastikler,
      'arkaLastikler': arkaLastikler,
      'genelNot': genelNot,
      'aciklamalar': aciklamalar,
      'fotografUrl': fotografUrl,
      'fotografYolu': fotografYolu,
      'fotografUrlleri': fotografUrlleri,
      'kayitTarihi': kayitTarihi.toIso8601String(),
    };
  }

  /// Modeli kopyalar ve belirtilen alanları günceller
  Adim2DisEkspertizModel copyWith({
    String? gorevId,
    String? personelId,
    String? onTampon,
    String? onFarlar,
    String? onCamurluklar,
    String? onKaput,
    String? motorNo,
    String? arkaTampon,
    String? arkaCamurluklar,
    String? bagajKapagi,
    String? solOnKapi,
    String? sagOnKapi,
    String? solArkaKapi,
    String? sagArkaKapi,
    String? onKapi,
    String? arkaKapi,
    String? tavan,
    String? tavanTente,
    String? onSasi,
    String? arkaSasi,
    String? onCamurlar,
    String? arkaCamurlar,
    String? onLastikler,
    String? arkaLastikler,
    String? genelNot,
    Map<String, String>? aciklamalar,
    Map<String, List<String>>? fotografUrl,
    Map<String, String>? fotografYolu,
    List<String>? fotografUrlleri,
  }) {
    return Adim2DisEkspertizModel(
      gorevId: gorevId ?? this.gorevId,
      personelId: personelId ?? this.personelId,
      onTampon: onTampon ?? this.onTampon,
      onFarlar: onFarlar ?? this.onFarlar,
      onCamurluklar: onCamurluklar ?? this.onCamurluklar,
      onKaput: onKaput ?? this.onKaput,
      motorNo: motorNo ?? this.motorNo,
      arkaTampon: arkaTampon ?? this.arkaTampon,
      arkaCamurluklar: arkaCamurluklar ?? this.arkaCamurluklar,
      bagajKapagi: bagajKapagi ?? this.bagajKapagi,
      solOnKapi: solOnKapi ?? this.solOnKapi,
      sagOnKapi: sagOnKapi ?? this.sagOnKapi,
      solArkaKapi: solArkaKapi ?? this.solArkaKapi,
      sagArkaKapi: sagArkaKapi ?? this.sagArkaKapi,
      onKapi: onKapi ?? this.onKapi,
      arkaKapi: arkaKapi ?? this.arkaKapi,
      tavan: tavan ?? this.tavan,
      tavanTente: tavanTente ?? this.tavanTente,
      onSasi: onSasi ?? this.onSasi,
      arkaSasi: arkaSasi ?? this.arkaSasi,
      onCamurlar: onCamurlar ?? this.onCamurlar,
      arkaCamurlar: arkaCamurlar ?? this.arkaCamurlar,
      onLastikler: onLastikler ?? this.onLastikler,
      arkaLastikler: arkaLastikler ?? this.arkaLastikler,
      genelNot: genelNot ?? this.genelNot,
      aciklamalar: aciklamalar ?? this.aciklamalar,
      fotografUrl: fotografUrl ?? this.fotografUrl,
      fotografYolu: fotografYolu ?? this.fotografYolu,
      fotografUrlleri: fotografUrlleri ?? this.fotografUrlleri,
    );
  }

  /// Tüm durum alanlarının doldurulup doldurulmadığını kontrol eder
  bool get isValid {
    return onTampon != null &&
        onFarlar != null &&
        onCamurluklar != null &&
        onKaput != null &&
        arkaTampon != null &&
        arkaCamurluklar != null &&
        bagajKapagi != null &&
        solOnKapi != null &&
        sagOnKapi != null &&
        solArkaKapi != null &&
        sagArkaKapi != null &&
        tavan != null &&
        onLastikler != null &&
        arkaLastikler != null;
  }

  /// Doldurulmuş alan sayısı
  int get filledFields {
    int count = 0;
    final fields = [
      onTampon, onFarlar, onCamurluklar, onKaput,
      arkaTampon, arkaCamurluklar, bagajKapagi,
      solOnKapi, sagOnKapi, solArkaKapi, sagArkaKapi,
      tavan, onLastikler, arkaLastikler
    ];
    for (final field in fields) {
      if (field != null) count++;
    }
    return count;
  }

  /// Toplam alan sayısı
  int get totalFields => 14;

  /// Dolum yüzdesi
  double get completionPercentage => filledFields / totalFields;

  /// String reprazantasyonu
  @override
  String toString() {
    return 'Adim2DisEkspertizModel(durum: $filledFields/$totalFields)';
  }

  /// Boş model oluştur
  static Adim2DisEkspertizModel empty({String? gorevId, String? personelId}) {
    return Adim2DisEkspertizModel(
      gorevId: gorevId ?? '',
      personelId: personelId ?? '',
    );
  }
  bool get isEmpty => gorevId.isEmpty;
}
