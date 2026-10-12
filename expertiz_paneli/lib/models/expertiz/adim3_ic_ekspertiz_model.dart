import 'kontrol_listesi.dart';

/// Adım 3 – İç Ekspertiz.
///
/// Maddeler [IcEkspertizListesi]'nden gelir; durumlar [durumlar] haritasında
/// tutulur. Eski alan adları (direksiyon, klima ...) getter olarak korunur.
class Adim3IcEkspertizModel {
  final String gorevId;
  final String personelId;

  /// Madde anahtarı → [KontrolDurumu] değeri
  final Map<String, String> durumlar;

  /// Madde anahtarı → personel notu
  Map<String, String>? aciklamalar;

  String? genelNot;

  // Eski uyumluluk
  Map<String, List<String>>? fotografUrl;
  Map<String, String>? fotografYolu;
  List<String> fotografUrlleri;

  final DateTime kayitTarihi;

  static const List<String> _legacyKeys = [
    'direksiyon',
    'gostergePaneli',
    'klima',
    'sesSistemi',
    'onKoltuklar',
    'arkaKoltuklar',
    'koltukDosemesi',
    'dorseme',
    'tavanDosemesi',
    'onPencereler',
    'arkaPencereler',
    'camlar',
    'merkeziKilit',
    'camKontrolleri',
    'aynaKontrolleri',
  ];

  Adim3IcEkspertizModel({
    String? gorevId,
    String? personelId,
    Map<String, String>? durumlar,
    this.aciklamalar,
    this.genelNot,
    this.fotografUrl,
    this.fotografYolu,
    List<String>? fotografUrlleri,
    // Eski alanlar
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
  })  : gorevId = gorevId ?? '',
        personelId = personelId ?? '',
        durumlar = {
          ..._seed([
            direksiyon,
            gostergePaneli,
            klima,
            sesSistemi,
            onKoltuklar,
            arkaKoltuklar,
            koltukDosemesi,
            dorseme,
            tavanDosemesi,
            onPencereler,
            arkaPencereler,
            camlar,
            merkeziKilit,
            camKontrolleri,
            aynaKontrolleri,
          ]),
          ...?durumlar,
        },
        fotografUrlleri = fotografUrlleri ?? [],
        kayitTarihi = DateTime.now();

  static Map<String, String> _seed(List<String?> values) {
    final result = <String, String>{};
    for (var i = 0; i < _legacyKeys.length; i++) {
      final value = values[i];
      if (value != null && value.isNotEmpty) result[_legacyKeys[i]] = value;
    }
    return result;
  }

  // Eski alan adları (salt okunur)
  String? get direksiyon => durumlar['direksiyon'];
  String? get gostergePaneli => durumlar['gostergePaneli'];
  String? get klima => durumlar['klima'];
  String? get sesSistemi => durumlar['sesSistemi'];
  String? get onKoltuklar => durumlar['onKoltuklar'];
  String? get arkaKoltuklar => durumlar['arkaKoltuklar'];
  String? get arkaKoltukler => arkaKoltuklar;
  String? get koltukDosemesi => durumlar['koltukDosemesi'];
  String? get dorseme => durumlar['dorseme'];
  String? get tavanDosemesi => durumlar['tavanDosemesi'];
  String? get onPencereler => durumlar['onPencereler'];
  String? get arkaPencereler => durumlar['arkaPencereler'];
  String? get camlar => durumlar['camlar'];
  String? get merkeziKilit => durumlar['merkeziKilit'];
  String? get camKontrolleri => durumlar['camKontrolleri'];
  String? get aynaKontrolleri => durumlar['aynaKontrolleri'];

  static List<KontrolMaddesi> get maddeler => IcEkspertizListesi.maddeler;

  String? durum(String key) => durumlar[key];
  String not(String key) => aciklamalar?[key] ?? '';

  List<KontrolMaddesi> get eksikMaddeler => maddeler.where((m) => durumlar[m.key] == null).toList();

  List<KontrolMaddesi> get eksiklikliMaddeler =>
      maddeler.where((m) => KontrolDurumu.eksiklikMi(durumlar[m.key])).toList();

  Adim3IcEkspertizModel withDurum(String key, String? value) {
    final yeni = Map<String, String>.from(durumlar);
    if (value == null) {
      yeni.remove(key);
    } else {
      yeni[key] = value;
    }
    return copyWith(durumlar: yeni);
  }

  Adim3IcEkspertizModel withNot(String key, String value) {
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

  factory Adim3IcEkspertizModel.fromJson(Map<String, dynamic> json) {
    final stored = stringMap(json['maddeDurumlari']);
    final legacy = <String, String>{};
    if (stored.isEmpty) {
      for (final key in _legacyKeys) {
        final value = json[key];
        if (value is String && value.isNotEmpty) legacy[key] = value;
      }
    }
    return Adim3IcEkspertizModel(
      gorevId: json['gorevId']?.toString() ?? '',
      personelId: json['personelId']?.toString() ?? '',
      durumlar: stored.isNotEmpty ? stored : legacy,
      aciklamalar: stringMap(json['aciklamalar']),
      genelNot: json['genelNot'] as String?,
      fotografUrl: stringListMap(json['fotografUrl']),
      fotografYolu: stringMap(json['fotografYolu']),
      fotografUrlleri: stringList(json['fotografUrlleri']),
    );
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
      for (final key in _legacyKeys) key: durumlar[key],
      'genelNot': genelNot,
      'aciklamalar': aciklamalar,
      'fotografUrl': fotografUrl,
      'fotografYolu': fotografYolu,
      'fotografUrlleri': fotografUrlleri,
      'kayitTarihi': kayitTarihi.toIso8601String(),
    };
  }

  Adim3IcEkspertizModel copyWith({
    String? gorevId,
    String? personelId,
    Map<String, String>? durumlar,
    Map<String, String>? aciklamalar,
    String? genelNot,
    Map<String, List<String>>? fotografUrl,
    Map<String, String>? fotografYolu,
    List<String>? fotografUrlleri,
  }) {
    return Adim3IcEkspertizModel(
      gorevId: gorevId ?? this.gorevId,
      personelId: personelId ?? this.personelId,
      durumlar: durumlar ?? this.durumlar,
      aciklamalar: aciklamalar ?? this.aciklamalar,
      genelNot: genelNot ?? this.genelNot,
      fotografUrl: fotografUrl ?? this.fotografUrl,
      fotografYolu: fotografYolu ?? this.fotografYolu,
      fotografUrlleri: fotografUrlleri ?? this.fotografUrlleri,
    );
  }

  @override
  String toString() => 'Adim3IcEkspertizModel(durum: $filledFields/$totalFields)';

  static Adim3IcEkspertizModel empty({String? gorevId, String? personelId}) {
    return Adim3IcEkspertizModel(gorevId: gorevId, personelId: personelId);
  }

  bool get isEmpty => durumlar.isEmpty;
}
