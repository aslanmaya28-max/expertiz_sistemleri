import 'kontrol_listesi.dart';

/// Adım 2 – Dış Ekspertiz.
///
/// Tüm maddelerin durumu [durumlar] haritasında (madde anahtarı → durum)
/// tutulur. Maddeler [DisEkspertizListesi]'nden gelir. Eski alan adları
/// (onTampon, onCamurluklar, solOnKapi ...) PDF / AI servisleriyle uyum için
/// getter olarak korunur.
class Adim2DisEkspertizModel {
  final String gorevId;
  final String personelId;

  /// Madde anahtarı → [KontrolDurumu] değeri
  final Map<String, String> durumlar;

  /// Madde anahtarı → personel notu
  Map<String, String>? aciklamalar;

  String? genelNot;
  String? motorNo;

  // Eski uyumluluk (fotoğraflar artık sunucuda; bkz. RaporMedya)
  Map<String, List<String>>? fotografUrl;
  Map<String, String>? fotografYolu;
  List<String> fotografUrlleri;

  final DateTime kayitTarihi;

  Adim2DisEkspertizModel({
    required this.gorevId,
    required this.personelId,
    Map<String, String>? durumlar,
    this.aciklamalar,
    this.genelNot,
    this.motorNo,
    this.fotografUrl,
    this.fotografYolu,
    List<String>? fotografUrlleri,
    // Eski alanlar (eski taslaklar / testler için)
    String? onTampon,
    String? onFarlar,
    String? onCamurluklar,
    String? onKaput,
    String? arkaTampon,
    String? arkaCamurluklar,
    String? bagajKapagi,
    String? solOnKapi,
    String? sagOnKapi,
    String? solArkaKapi,
    String? sagArkaKapi,
    String? tavan,
    String? tavanTente,
    String? onSasi,
    String? arkaSasi,
    String? onLastikler,
    String? arkaLastikler,
  })  : durumlar = {
          ..._legacySeed({
            'onTampon': [onTampon],
            'onFarlar': [onFarlar],
            'solOnCamurluk': [onCamurluklar],
            'sagOnCamurluk': [onCamurluklar],
            'onKaput': [onKaput],
            'arkaTampon': [arkaTampon],
            'solArkaCamurluk': [arkaCamurluklar],
            'sagArkaCamurluk': [arkaCamurluklar],
            'bagajKapagi': [bagajKapagi],
            'solOnKapi': [solOnKapi],
            'sagOnKapi': [sagOnKapi],
            'solArkaKapi': [solArkaKapi],
            'sagArkaKapi': [sagArkaKapi],
            'tavan': [tavan],
            'tavanTente': [tavanTente],
            'onSasi': [onSasi],
            'arkaSasi': [arkaSasi],
            'onSolLastik': [onLastikler],
            'onSagLastik': [onLastikler],
            'arkaSolLastik': [arkaLastikler],
            'arkaSagLastik': [arkaLastikler],
          }),
          ...?durumlar,
        },
        fotografUrlleri = fotografUrlleri ?? [],
        kayitTarihi = DateTime.now();

  static Map<String, String> _legacySeed(Map<String, List<String?>> values) {
    final result = <String, String>{};
    values.forEach((key, list) {
      final value = list.first;
      if (value != null && value.isNotEmpty) result[key] = value;
    });
    return result;
  }

  // ---------------------------------------------------------------------------
  // Eski alan adları (salt okunur)
  // ---------------------------------------------------------------------------
  String? _w(List<String> keys) => KontrolDurumu.enKotu(keys.map((k) => durumlar[k]));

  String? get onTampon => durumlar['onTampon'];
  String? get onFarlar => durumlar['onFarlar'];
  String? get onCamurluklar => _w(['solOnCamurluk', 'sagOnCamurluk']);
  String? get onKaput => durumlar['onKaput'];
  String? get arkaTampon => durumlar['arkaTampon'];
  String? get arkaCamurluklar => _w(['solArkaCamurluk', 'sagArkaCamurluk']);
  String? get bagajKapagi => durumlar['bagajKapagi'];
  String? get solOnKapi => durumlar['solOnKapi'];
  String? get sagOnKapi => durumlar['sagOnKapi'];
  String? get solArkaKapi => durumlar['solArkaKapi'];
  String? get sagArkaKapi => durumlar['sagArkaKapi'];
  String? get onKapi => _w(['solOnKapi', 'sagOnKapi']);
  String? get arkaKapi => _w(['solArkaKapi', 'sagArkaKapi']);
  String? get tavan => durumlar['tavan'];
  String? get tavanTente => durumlar['tavanTente'];
  String? get onSasi => durumlar['onSasi'];
  String? get arkaSasi => durumlar['arkaSasi'];
  String? get onCamurlar => onCamurluklar;
  String? get arkaCamurlar => arkaCamurluklar;
  String? get onLastikler => _w(['onSolLastik', 'onSagLastik']);
  String? get arkaLastikler => _w(['arkaSolLastik', 'arkaSagLastik']);

  // ---------------------------------------------------------------------------
  // Durum
  // ---------------------------------------------------------------------------
  static List<KontrolMaddesi> get maddeler => DisEkspertizListesi.maddeler;

  String? durum(String key) => durumlar[key];
  String not(String key) => aciklamalar?[key] ?? '';

  /// Durumu seçilmemiş maddeler
  List<KontrolMaddesi> get eksikMaddeler => maddeler.where((m) => durumlar[m.key] == null).toList();

  /// Eksiklik (sorunlu/kötü/ağır hasar) işaretlenen maddeler → fotoğraf zorunlu
  List<KontrolMaddesi> get eksiklikliMaddeler =>
      maddeler.where((m) => KontrolDurumu.eksiklikMi(durumlar[m.key])).toList();

  Adim2DisEkspertizModel withDurum(String key, String? value) {
    final yeni = Map<String, String>.from(durumlar);
    if (value == null) {
      yeni.remove(key);
    } else {
      yeni[key] = value;
    }
    return copyWith(durumlar: yeni);
  }

  Adim2DisEkspertizModel withNot(String key, String value) {
    final yeni = Map<String, String>.from(aciklamalar ?? {});
    if (value.trim().isEmpty) {
      yeni.remove(key);
    } else {
      yeni[key] = value;
    }
    return copyWith(aciklamalar: yeni);
  }

  bool get isValid => eksikMaddeler.isEmpty;

  int get filledFields => maddeler.where((m) => durumlar[m.key] != null).length;
  int get totalFields => maddeler.length;
  double get completionPercentage => totalFields == 0 ? 0 : filledFields / totalFields;

  // ---------------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------------
  factory Adim2DisEkspertizModel.fromJson(Map<String, dynamic> json) {
    final stored = stringMap(json['maddeDurumlari']);
    final common = Adim2DisEkspertizModel(
      gorevId: json['gorevId']?.toString() ?? '',
      personelId: json['personelId']?.toString() ?? '',
      aciklamalar: stringMap(json['aciklamalar']),
      genelNot: json['genelNot'] as String?,
      motorNo: json['motorNo'] as String?,
      fotografUrl: stringListMap(json['fotografUrl']),
      fotografYolu: stringMap(json['fotografYolu']),
      fotografUrlleri: stringList(json['fotografUrlleri']),
    );
    if (stored.isNotEmpty) {
      return common.copyWith(durumlar: stored);
    }
    // Eski taslak: maddeDurumlari yok, eski alan adlarından doldur
    final legacy = Adim2DisEkspertizModel(
      gorevId: common.gorevId,
      personelId: common.personelId,
      onTampon: json['onTampon'] as String?,
      onFarlar: json['onFarlar'] as String?,
      onCamurluklar: json['onCamurluklar'] as String?,
      onKaput: json['onKaput'] as String?,
      arkaTampon: json['arkaTampon'] as String?,
      arkaCamurluklar: json['arkaCamurluklar'] as String?,
      bagajKapagi: json['bagajKapagi'] as String?,
      solOnKapi: json['solOnKapi'] as String?,
      sagOnKapi: json['sagOnKapi'] as String?,
      solArkaKapi: json['solArkaKapi'] as String?,
      sagArkaKapi: json['sagArkaKapi'] as String?,
      tavan: json['tavan'] as String?,
      tavanTente: json['tavanTente'] as String?,
      onSasi: json['onSasi'] as String?,
      arkaSasi: json['arkaSasi'] as String?,
      onLastikler: json['onLastikler'] as String?,
      arkaLastikler: json['arkaLastikler'] as String?,
    );
    return common.copyWith(durumlar: legacy.durumlar);
  }

  Map<String, dynamic> toJson() {
    return {
      'gorevId': gorevId,
      'personelId': personelId,
      'maddeDurumlari': durumlar,
      'kontrolListesi': kontrolListesiJson(
        maddeler,
        durumlar,
        aciklamalar ?? const {},
        KontrolDurumu.etiket,
        KontrolDurumu.eksiklikMi,
      ),
      // Eski alanlar (PDF / AI / eski ekranlar)
      'onTampon': onTampon,
      'onFarlar': onFarlar,
      'onCamurluklar': onCamurluklar,
      'onKaput': onKaput,
      'arkaTampon': arkaTampon,
      'arkaCamurluklar': arkaCamurluklar,
      'bagajKapagi': bagajKapagi,
      'solOnKapi': solOnKapi,
      'sagOnKapi': sagOnKapi,
      'solArkaKapi': solArkaKapi,
      'sagArkaKapi': sagArkaKapi,
      'tavan': tavan,
      'tavanTente': tavanTente,
      'onSasi': onSasi,
      'arkaSasi': arkaSasi,
      'onLastikler': onLastikler,
      'arkaLastikler': arkaLastikler,
      'genelNot': genelNot,
      'motorNo': motorNo,
      'aciklamalar': aciklamalar,
      'fotografUrl': fotografUrl,
      'fotografYolu': fotografYolu,
      'fotografUrlleri': fotografUrlleri,
      'kayitTarihi': kayitTarihi.toIso8601String(),
    };
  }

  Adim2DisEkspertizModel copyWith({
    String? gorevId,
    String? personelId,
    Map<String, String>? durumlar,
    Map<String, String>? aciklamalar,
    String? genelNot,
    String? motorNo,
    Map<String, List<String>>? fotografUrl,
    Map<String, String>? fotografYolu,
    List<String>? fotografUrlleri,
  }) {
    return Adim2DisEkspertizModel(
      gorevId: gorevId ?? this.gorevId,
      personelId: personelId ?? this.personelId,
      durumlar: durumlar ?? this.durumlar,
      aciklamalar: aciklamalar ?? this.aciklamalar,
      genelNot: genelNot ?? this.genelNot,
      motorNo: motorNo ?? this.motorNo,
      fotografUrl: fotografUrl ?? this.fotografUrl,
      fotografYolu: fotografYolu ?? this.fotografYolu,
      fotografUrlleri: fotografUrlleri ?? this.fotografUrlleri,
    );
  }

  @override
  String toString() => 'Adim2DisEkspertizModel(durum: $filledFields/$totalFields)';

  static Adim2DisEkspertizModel empty({String? gorevId, String? personelId}) {
    return Adim2DisEkspertizModel(gorevId: gorevId ?? '', personelId: personelId ?? '');
  }

  bool get isEmpty => durumlar.isEmpty;
}
