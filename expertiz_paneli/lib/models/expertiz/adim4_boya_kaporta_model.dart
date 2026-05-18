/// Hasar kaydı modeli
class HasarKaydi {
  final String id;
  final String konum;
  final String tip;
  final String buyukluk;
  final String? fotografUrl;
  final String? not;

  HasarKaydi({
    required this.id,
    required this.konum,
    required this.tip,
    required this.buyukluk,
    this.fotografUrl,
    this.not,
  });

  /// JSON'dan HasarKaydi nesnesi oluştur
  factory HasarKaydi.fromJson(Map<String, dynamic> json) {
    return HasarKaydi(
      id: json['id'] as String,
      konum: json['konum'] as String,
      tip: json['tip'] as String,
      buyukluk: json['buyukluk'] as String,
      fotografUrl: json['fotografUrl'] as String?,
      not: json['not'] as String?,
    );
  }

  /// HasarKaydi nesnesini JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'konum': konum,
      'tip': tip,
      'buyukluk': buyukluk,
      'fotografUrl': fotografUrl,
      'not': not,
    };
  }

  /// Hasar kaydını kopyalar
  HasarKaydi copyWith({
    String? id,
    String? konum,
    String? tip,
    String? buyukluk,
    String? fotografUrl,
    String? not,
  }) {
    return HasarKaydi(
      id: id ?? this.id,
      konum: konum ?? this.konum,
      tip: tip ?? this.tip,
      buyukluk: buyukluk ?? this.buyukluk,
      fotografUrl: fotografUrl ?? this.fotografUrl,
      not: not ?? this.not,
    );
  }
}

/// Adım 4: Boya / Kaporta Modeli
class Adim4BoyaKaportaModel {
  // Görev ID
  final String gorevId;
  final String personelId;

  // 🎨 BOYA
  String? onKapiBoya;
  String? arkaKapiBoya;
  String? kaputBoya;
  String? tamponBoya;
  String? tavanBoya;
  List<String> boyaliParcalar; // Yeni alan

  // 🔩 KAPORTA
  String? onKapiKaporta;
  String? arkaKapiKaporta;
  String? kaputKaporta;
  String? tamponKaporta;
  List<String> degisenParcalar; // Yeni alan

  // 🚗 ŞASİ VE DİREKLER
  String? onSasi;
  String? arkaSasi;
  String? onDirekler;
  String? arkaDirekler;

  // 🎯 EKSTRA KAPORTA PARÇALARI
  String? podye;
  String? marsbiyel;

  // ⚠️ HASAR KAYITLARI
  List<HasarKaydi> hasarKayitlari;

  // 📝 NOTLAR
  String? genelNot;
  String? aciklama; // Yeni alan
  Map<String, String>? aciklamalar; // Her madde için açıklama
  Map<String, List<String>>? fotografUrl; // Her madde için fotoğraflar
  Map<String, String>? fotografYolu; // Her madde için ilk fotoğraf yolu (thumbnail)
  List<String> fotografUrlleri; // Eski uyumluluk için

  // Kayıt tarihi
  final DateTime kayitTarihi;

  Adim4BoyaKaportaModel({
    required this.gorevId,
    required this.personelId,
    this.onKapiBoya,
    this.arkaKapiBoya,
    this.kaputBoya,
    this.tamponBoya,
    this.tavanBoya,
    List<String>? boyaliParcalar,
    this.onKapiKaporta,
    this.arkaKapiKaporta,
    this.kaputKaporta,
    this.tamponKaporta,
    List<String>? degisenParcalar,
    this.onSasi,
    this.arkaSasi,
    this.onDirekler,
    this.arkaDirekler,
    this.podye,
    this.marsbiyel,
    List<HasarKaydi>? hasarKayitlari,
    this.genelNot,
    this.aciklama,
    this.aciklamalar,
    this.fotografUrl,
    this.fotografYolu,
    List<String>? fotografUrlleri,
  })  : boyaliParcalar = boyaliParcalar ?? [],
        degisenParcalar = degisenParcalar ?? [],
        hasarKayitlari = hasarKayitlari ?? [],
        fotografUrlleri = fotografUrlleri ?? [],
        kayitTarihi = DateTime.now();

  /// JSON'dan Adim4BoyaKaportaModel nesnesi oluştur
  factory Adim4BoyaKaportaModel.fromJson(Map<String, dynamic> json) {
    final aciklamalarMap = json['aciklamalar'] as Map<String, dynamic>?;
    final fotografUrlMap = json['fotografUrl'] as Map<String, dynamic>?;
    final fotografYoluMap = json['fotografYolu'] as Map<String, dynamic>?;
    
    return Adim4BoyaKaportaModel(
      gorevId: json['gorevId'] as String,
      personelId: json['personelId'] as String,
      onKapiBoya: json['onKapiBoya'] as String?,
      arkaKapiBoya: json['arkaKapiBoya'] as String?,
      kaputBoya: json['kaputBoya'] as String?,
      tamponBoya: json['tamponBoya'] as String?,
      tavanBoya: json['tavanBoya'] as String?,
      boyaliParcalar: (json['boyaliParcalar'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      onKapiKaporta: json['onKapiKaporta'] as String?,
      arkaKapiKaporta: json['arkaKapiKaporta'] as String?,
      kaputKaporta: json['kaputKaporta'] as String?,
      tamponKaporta: json['tamponKaporta'] as String?,
      degisenParcalar: (json['degisenParcalar'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      onSasi: json['onSasi'] as String?,
      arkaSasi: json['arkaSasi'] as String?,
      onDirekler: json['onDirekler'] as String?,
      arkaDirekler: json['arkaDirekler'] as String?,
      podye: json['podye'] as String?,
      marsbiyel: json['marsbiyel'] as String?,
      hasarKayitlari: (json['hasarKayitlari'] as List<dynamic>?)
              ?.map((e) => HasarKaydi.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      genelNot: json['genelNot'] as String?,
      aciklama: json['aciklama'] as String?,
      aciklamalar: aciklamalarMap?.map((key, value) => MapEntry(key, value as String)),
      fotografUrl: fotografUrlMap?.map((key, value) => MapEntry(key, (value as List<dynamic>).map((e) => e as String).toList())),
      fotografYolu: fotografYoluMap?.map((key, value) => MapEntry(key, value as String)),
      fotografUrlleri: (json['fotografUrlleri'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    );
  }

  /// Adim4BoyaKaportaModel nesnesini JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'gorevId': gorevId,
      'personelId': personelId,
      'onKapiBoya': onKapiBoya,
      'arkaKapiBoya': arkaKapiBoya,
      'kaputBoya': kaputBoya,
      'tamponBoya': tamponBoya,
      'tavanBoya': tavanBoya,
      'boyaliParcalar': boyaliParcalar,
      'onKapiKaporta': onKapiKaporta,
      'arkaKapiKaporta': arkaKapiKaporta,
      'kaputKaporta': kaputKaporta,
      'tamponKaporta': tamponKaporta,
      'degisenParcalar': degisenParcalar,
      'onSasi': onSasi,
      'arkaSasi': arkaSasi,
      'onDirekler': onDirekler,
      'arkaDirekler': arkaDirekler,
      'podye': podye,
      'marsbiyel': marsbiyel,
      'hasarKayitlari': hasarKayitlari.map((e) => e.toJson()).toList(),
      'genelNot': genelNot,
      'aciklama': aciklama,
      'aciklamalar': aciklamalar,
      'fotografUrl': fotografUrl,
      'fotografYolu': fotografYolu,
      'fotografUrlleri': fotografUrlleri,
      'kayitTarihi': kayitTarihi.toIso8601String(),
    };
  }

  /// Modeli kopyalar ve belirtilen alanları günceller
  Adim4BoyaKaportaModel copyWith({
    String? gorevId,
    String? personelId,
    String? onKapiBoya,
    String? arkaKapiBoya,
    String? kaputBoya,
    String? tamponBoya,
    String? tavanBoya,
    List<String>? boyaliParcalar,
    String? onKapiKaporta,
    String? arkaKapiKaporta,
    String? kaputKaporta,
    String? tamponKaporta,
    List<String>? degisenParcalar,
    String? onSasi,
    String? arkaSasi,
    String? onDirekler,
    String? arkaDirekler,
    String? podye,
    String? marsbiyel,
    List<HasarKaydi>? hasarKayitlari,
    String? genelNot,
    String? aciklama,
    Map<String, String>? aciklamalar,
    Map<String, List<String>>? fotografUrl,
    Map<String, String>? fotografYolu,
    List<String>? fotografUrlleri,
  }) {
    return Adim4BoyaKaportaModel(
      gorevId: gorevId ?? this.gorevId,
      personelId: personelId ?? this.personelId,
      onKapiBoya: onKapiBoya ?? this.onKapiBoya,
      arkaKapiBoya: arkaKapiBoya ?? this.arkaKapiBoya,
      kaputBoya: kaputBoya ?? this.kaputBoya,
      tamponBoya: tamponBoya ?? this.tamponBoya,
      tavanBoya: tavanBoya ?? this.tavanBoya,
      boyaliParcalar: boyaliParcalar ?? this.boyaliParcalar,
      onKapiKaporta: onKapiKaporta ?? this.onKapiKaporta,
      arkaKapiKaporta: arkaKapiKaporta ?? this.arkaKapiKaporta,
      kaputKaporta: kaputKaporta ?? this.kaputKaporta,
      tamponKaporta: tamponKaporta ?? this.tamponKaporta,
      degisenParcalar: degisenParcalar ?? this.degisenParcalar,
      onSasi: onSasi ?? this.onSasi,
      arkaSasi: arkaSasi ?? this.arkaSasi,
      onDirekler: onDirekler ?? this.onDirekler,
      arkaDirekler: arkaDirekler ?? this.arkaDirekler,
      podye: podye ?? this.podye,
      marsbiyel: marsbiyel ?? this.marsbiyel,
      hasarKayitlari: hasarKayitlari ?? this.hasarKayitlari,
      genelNot: genelNot ?? this.genelNot,
      aciklama: aciklama ?? this.aciklama,
      aciklamalar: aciklamalar ?? this.aciklamalar,
      fotografUrl: fotografUrl ?? this.fotografUrl,
      fotografYolu: fotografYolu ?? this.fotografYolu,
      fotografUrlleri: fotografUrlleri ?? this.fotografUrlleri,
    );
  }

  /// Hasar kaydı ekle
  Adim4BoyaKaportaModel hasarEkle(HasarKaydi hasar) {
    return copyWith(
      hasarKayitlari: [...hasarKayitlari, hasar],
    );
  }

  /// Hasar kaydı güncelle
  Adim4BoyaKaportaModel hasarGuncelle(String hasarId, HasarKaydi yeniHasar) {
    final yeniListe = hasarKayitlari.map((h) {
      if (h.id == hasarId) {
        return yeniHasar;
      }
      return h;
    }).toList();
    return copyWith(hasarKayitlari: yeniListe);
  }

  /// Hasar kaydı sil
  Adim4BoyaKaportaModel hasarSil(String hasarId) {
    return copyWith(
      hasarKayitlari: hasarKayitlari.where((h) => h.id != hasarId).toList(),
    );
  }

  /// Tüm durum alanlarının doldurulup doldurulmadığını kontrol eder
  bool get isValid {
    return onKapiBoya != null &&
        arkaKapiBoya != null &&
        kaputBoya != null &&
        tamponBoya != null &&
        tavanBoya != null &&
        onKapiKaporta != null &&
        arkaKapiKaporta != null &&
        kaputKaporta != null &&
        tamponKaporta != null &&
        onSasi != null &&
        arkaSasi != null &&
        onDirekler != null &&
        arkaDirekler != null &&
        podye != null &&
        marsbiyel != null;
  }

  /// Doldurulmuş alan sayısı
  int get filledFields {
    int count = 0;
    final fields = [
      onKapiBoya, arkaKapiBoya, kaputBoya, tamponBoya, tavanBoya,
      onKapiKaporta, arkaKapiKaporta, kaputKaporta, tamponKaporta,
      onSasi, arkaSasi, onDirekler, arkaDirekler, podye, marsbiyel
    ];
    for (final field in fields) {
      if (field != null) count++;
    }
    return count;
  }

  /// Toplam alan sayısı
  int get totalFields => 15;

  /// Dolum yüzdesi
  double get completionPercentage => filledFields / totalFields;

  /// Hasar sayısı
  int get hasarSayisi => hasarKayitlari.length;

  /// String reprazantasyonu
  @override
  String toString() {
    return 'Adim4BoyaKaportaModel(durum: $filledFields/$totalFields, hasarlar: $hasarSayisi)';
  }

  /// Boş model oluştur
  static Adim4BoyaKaportaModel empty({String? gorevId, String? personelId}) {
    return Adim4BoyaKaportaModel(
      gorevId: gorevId ?? '',
      personelId: personelId ?? '',
      onKapiBoya: null,
      arkaKapiBoya: null,
      kaputBoya: null,
      tamponBoya: null,
      tavanBoya: null,
      onKapiKaporta: null,
      arkaKapiKaporta: null,
      kaputKaporta: null,
      tamponKaporta: null,
      onSasi: null,
      arkaSasi: null,
      onDirekler: null,
      arkaDirekler: null,
      podye: null,
      marsbiyel: null,
      hasarKayitlari: null,
      genelNot: null,
      aciklama: null,
      aciklamalar: null,
      fotografUrl: null,
      fotografYolu: null,
      fotografUrlleri: null,
    );
  }

  /// Modelin boş olup olmadığını kontrol eder
  bool get isEmpty => gorevId.isEmpty || personelId.isEmpty;

  /// Hasar tipleri
  static List<String> get hasarTipleri => [
        'Çizik',
        'Çökme',
        'Göçük',
        'Boyasızlık',
        'Deformasyon',
        'Paslanma',
        'Diğer',
      ];

  /// Hasar büyüklükleri
  static List<String> get hasarBuyuklukleri => [
        'Küçük',
        'Orta',
        'Büyük',
        'Çok Büyük',
      ];
}
