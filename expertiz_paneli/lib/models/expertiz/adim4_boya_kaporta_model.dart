import 'kontrol_listesi.dart';

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
  final String gorevId;
  final String personelId;

  /// Parça anahtarı → [ParcaDurumu] (orijinal, boyalı, değişen ...)
  final Map<String, String> parcaDurumlari;

  /// Parça anahtarı → boya kalınlığı (mikron, opsiyonel)
  final Map<String, int> mikronlar;

  /// Yapısal eleman anahtarı → [YapisalDurum] (şasi, direkler, podye ...)
  final Map<String, String> yapisalDurumlar;

  /// Ek hasar kayıtları (çizik, göçük, pas ...)
  List<HasarKaydi> hasarKayitlari;

  String? genelNot;
  String? aciklama;

  /// Madde anahtarı → personel notu (parça ve yapısal anahtarlar çakışmaz)
  Map<String, String>? aciklamalar;

  // Eski uyumluluk
  Map<String, List<String>>? fotografUrl;
  Map<String, String>? fotografYolu;
  List<String> fotografUrlleri;

  // Eski veri modeli (parça bazlı kayıt yoksa kullanılır)
  final Map<String, String> _legacy;
  final List<String> _legacyBoyali;
  final List<String> _legacyDegisen;

  final DateTime kayitTarihi;

  static const List<String> _legacyKeys = [
    'onKapiBoya',
    'arkaKapiBoya',
    'kaputBoya',
    'tamponBoya',
    'tavanBoya',
    'onKapiKaporta',
    'arkaKapiKaporta',
    'kaputKaporta',
    'tamponKaporta',
    'onSasi',
    'arkaSasi',
    'onDirekler',
    'arkaDirekler',
    'podye',
    'marsbiyel',
  ];

  Adim4BoyaKaportaModel({
    String? gorevId,
    String? personelId,
    Map<String, String>? parcaDurumlari,
    Map<String, int>? mikronlar,
    Map<String, String>? yapisalDurumlar,
    List<HasarKaydi>? hasarKayitlari,
    this.genelNot,
    this.aciklama,
    this.aciklamalar,
    this.fotografUrl,
    this.fotografYolu,
    List<String>? fotografUrlleri,
    // Eski alanlar
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
  })  : gorevId = gorevId ?? '',
        personelId = personelId ?? '',
        parcaDurumlari = Map<String, String>.from(parcaDurumlari ?? const {}),
        mikronlar = Map<String, int>.from(mikronlar ?? const {}),
        yapisalDurumlar = Map<String, String>.from(yapisalDurumlar ?? const {}),
        hasarKayitlari = hasarKayitlari ?? [],
        fotografUrlleri = fotografUrlleri ?? [],
        _legacyBoyali = boyaliParcalar ?? const [],
        _legacyDegisen = degisenParcalar ?? const [],
        _legacy = _seed([
          onKapiBoya,
          arkaKapiBoya,
          kaputBoya,
          tamponBoya,
          tavanBoya,
          onKapiKaporta,
          arkaKapiKaporta,
          kaputKaporta,
          tamponKaporta,
          onSasi,
          arkaSasi,
          onDirekler,
          arkaDirekler,
          podye,
          marsbiyel,
        ]),
        kayitTarihi = DateTime.now();

  static Map<String, String> _seed(List<String?> values) {
    final result = <String, String>{};
    for (var i = 0; i < _legacyKeys.length; i++) {
      final value = values[i];
      if (value != null && value.isNotEmpty) result[_legacyKeys[i]] = value;
    }
    return result;
  }

  static List<KontrolMaddesi> get parcalar => BoyaKaportaListesi.parcalar;
  static List<KontrolMaddesi> get yapisal => BoyaKaportaListesi.yapisal;

  bool get _parcaBazli => parcaDurumlari.isNotEmpty || yapisalDurumlar.isNotEmpty;

  // ---------------------------------------------------------------------------
  // Eski alan adları (AI puanlama / PDF bu sözlüğü kullanır)
  // ---------------------------------------------------------------------------
  String? _boya(List<String> keys) {
    final values = keys.map((k) => parcaDurumlari[k]).whereType<String>().toList();
    if (values.isEmpty) return null;
    if (values.contains(ParcaDurumu.degisen)) return 'Değişmiş';
    if (values.contains(ParcaDurumu.hasarli)) return 'Hasarlı';
    if (values.contains(ParcaDurumu.boyali) || values.contains(ParcaDurumu.lokalBoyali)) return 'Boyalı';
    return 'Orijinal';
  }

  String? _kaporta(List<String> keys) {
    final values = keys.map((k) => parcaDurumlari[k]).whereType<String>().toList();
    if (values.isEmpty) return null;
    if (values.contains(ParcaDurumu.degisen)) return 'Değişmiş';
    if (values.contains(ParcaDurumu.hasarli)) return 'Hasarlı';
    return 'Orijinal';
  }

  String? _yapisal(String key) {
    switch (yapisalDurumlar[key]) {
      case YapisalDurum.orijinal:
        return 'Orijinal';
      case YapisalDurum.islemli:
        return 'İşlemli';
      case YapisalDurum.hasarli:
        return 'Hasarlı';
      default:
        return null;
    }
  }

  String? _pick(String legacyKey, String? Function() computed) => _parcaBazli ? computed() : _legacy[legacyKey];

  String? get onKapiBoya => _pick('onKapiBoya', () => _boya(['solOnKapi', 'sagOnKapi']));
  String? get arkaKapiBoya => _pick('arkaKapiBoya', () => _boya(['solArkaKapi', 'sagArkaKapi']));
  String? get kaputBoya => _pick('kaputBoya', () => _boya(['kaput']));
  String? get tamponBoya => _pick('tamponBoya', () => _boya(['onTampon', 'arkaTampon']));
  String? get tavanBoya => _pick('tavanBoya', () => _boya(['tavan']));
  String? get onKapiKaporta => _pick('onKapiKaporta', () => _kaporta(['solOnKapi', 'sagOnKapi']));
  String? get arkaKapiKaporta => _pick('arkaKapiKaporta', () => _kaporta(['solArkaKapi', 'sagArkaKapi']));
  String? get kaputKaporta => _pick('kaputKaporta', () => _kaporta(['kaput']));
  String? get tamponKaporta => _pick('tamponKaporta', () => _kaporta(['onTampon', 'arkaTampon']));
  String? get onSasi => _pick('onSasi', () => _yapisal('onSasi'));
  String? get arkaSasi => _pick('arkaSasi', () => _yapisal('arkaSasi'));
  String? get onDirekler => _pick('onDirekler', () => _yapisal('onDirekler'));
  String? get arkaDirekler => _pick('arkaDirekler', () => _yapisal('arkaDirekler'));
  String? get podye => _pick('podye', () => _yapisal('podye'));
  String? get marsbiyel => _pick('marsbiyel', () => _yapisal('marsbiyel'));

  List<String> _labelsWhere(bool Function(String durum) test) => parcalar
      .where((p) => parcaDurumlari[p.key] != null && test(parcaDurumlari[p.key]!))
      .map((p) => p.label)
      .toList();

  /// Boyalı (lokal dahil) parça adları
  List<String> get boyaliParcalar => _parcaBazli
      ? _labelsWhere((d) => d == ParcaDurumu.boyali || d == ParcaDurumu.lokalBoyali)
      : _legacyBoyali;

  /// Değişen parça adları
  List<String> get degisenParcalar => _parcaBazli ? _labelsWhere((d) => d == ParcaDurumu.degisen) : _legacyDegisen;

  // ---------------------------------------------------------------------------
  // Durum
  // ---------------------------------------------------------------------------
  String not(String key) => aciklamalar?[key] ?? '';

  List<KontrolMaddesi> get eksikMaddeler => [
        ...parcalar.where((p) => parcaDurumlari[p.key] == null),
        ...yapisal.where((y) => yapisalDurumlar[y.key] == null),
      ];

  /// Orijinal olmayan parçalar ve işlemli/hasarlı yapısal elemanlar → fotoğraf zorunlu
  List<KontrolMaddesi> get eksiklikliMaddeler => [
        ...parcalar.where((p) => ParcaDurumu.eksiklikMi(parcaDurumlari[p.key])),
        ...yapisal.where((y) => YapisalDurum.eksiklikMi(yapisalDurumlar[y.key])),
        // Ek hasar kayıtları da fotoğraflanmalı (anahtar = kayıt id)
        ...hasarKayitlari.map((h) => KontrolMaddesi(h.id, '${h.konum} (${h.tip})', 'Ek Hasar')),
      ];

  Adim4BoyaKaportaModel withParca(String key, String? durum) {
    final yeni = Map<String, String>.from(parcaDurumlari);
    if (durum == null) {
      yeni.remove(key);
    } else {
      yeni[key] = durum;
    }
    return copyWith(parcaDurumlari: yeni);
  }

  Adim4BoyaKaportaModel withMikron(String key, int? mikron) {
    final yeni = Map<String, int>.from(mikronlar);
    if (mikron == null || mikron <= 0) {
      yeni.remove(key);
    } else {
      yeni[key] = mikron;
    }
    return copyWith(mikronlar: yeni);
  }

  Adim4BoyaKaportaModel withYapisal(String key, String? durum) {
    final yeni = Map<String, String>.from(yapisalDurumlar);
    if (durum == null) {
      yeni.remove(key);
    } else {
      yeni[key] = durum;
    }
    return copyWith(yapisalDurumlar: yeni);
  }

  Adim4BoyaKaportaModel withNot(String key, String value) {
    final yeni = Map<String, String>.from(aciklamalar ?? {});
    if (value.trim().isEmpty) {
      yeni.remove(key);
    } else {
      yeni[key] = value;
    }
    return copyWith(aciklamalar: yeni);
  }

  /// Hasar kaydı ekle
  Adim4BoyaKaportaModel hasarEkle(HasarKaydi hasar) => copyWith(hasarKayitlari: [...hasarKayitlari, hasar]);

  /// Hasar kaydı güncelle
  Adim4BoyaKaportaModel hasarGuncelle(String hasarId, HasarKaydi yeniHasar) =>
      copyWith(hasarKayitlari: hasarKayitlari.map((h) => h.id == hasarId ? yeniHasar : h).toList());

  /// Hasar kaydı sil
  Adim4BoyaKaportaModel hasarSil(String hasarId) =>
      copyWith(hasarKayitlari: hasarKayitlari.where((h) => h.id != hasarId).toList());

  bool get isValid => _parcaBazli ? eksikMaddeler.isEmpty : _legacyKeys.every((k) => _legacy[k] != null);

  int get filledFields => _parcaBazli
      ? parcalar.where((p) => parcaDurumlari[p.key] != null).length +
          yapisal.where((y) => yapisalDurumlar[y.key] != null).length
      : _legacy.length;

  int get totalFields => _parcaBazli || _legacy.isEmpty ? parcalar.length + yapisal.length : _legacyKeys.length;

  double get completionPercentage => totalFields == 0 ? 0 : filledFields / totalFields;

  /// Hasar sayısı: ek hasar kayıtları + hasarlı parça/yapısal eleman
  int get hasarSayisi =>
      hasarKayitlari.length +
      parcaDurumlari.values.where((d) => d == ParcaDurumu.hasarli).length +
      yapisalDurumlar.values.where((d) => d == YapisalDurum.hasarli).length;

  // ---------------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------------
  factory Adim4BoyaKaportaModel.fromJson(Map<String, dynamic> json) {
    final mikron = <String, int>{};
    final rawMikron = json['mikronlar'];
    if (rawMikron is Map) {
      rawMikron.forEach((k, v) {
        final value = v is num ? v.toInt() : int.tryParse('$v');
        if (value != null) mikron['$k'] = value;
      });
    }
    return Adim4BoyaKaportaModel(
      gorevId: json['gorevId']?.toString() ?? '',
      personelId: json['personelId']?.toString() ?? '',
      parcaDurumlari: stringMap(json['parcaDurumlari']),
      mikronlar: mikron,
      yapisalDurumlar: stringMap(json['yapisalDurumlar']),
      hasarKayitlari: (json['hasarKayitlari'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => HasarKaydi.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      genelNot: json['genelNot'] as String?,
      aciklama: json['aciklama'] as String?,
      aciklamalar: stringMap(json['aciklamalar']),
      fotografUrl: stringListMap(json['fotografUrl']),
      fotografYolu: stringMap(json['fotografYolu']),
      fotografUrlleri: stringList(json['fotografUrlleri']),
      // Eski taslaklar
      onKapiBoya: json['onKapiBoya'] as String?,
      arkaKapiBoya: json['arkaKapiBoya'] as String?,
      kaputBoya: json['kaputBoya'] as String?,
      tamponBoya: json['tamponBoya'] as String?,
      tavanBoya: json['tavanBoya'] as String?,
      boyaliParcalar: stringList(json['boyaliParcalar']),
      onKapiKaporta: json['onKapiKaporta'] as String?,
      arkaKapiKaporta: json['arkaKapiKaporta'] as String?,
      kaputKaporta: json['kaputKaporta'] as String?,
      tamponKaporta: json['tamponKaporta'] as String?,
      degisenParcalar: stringList(json['degisenParcalar']),
      onSasi: json['onSasi'] as String?,
      arkaSasi: json['arkaSasi'] as String?,
      onDirekler: json['onDirekler'] as String?,
      arkaDirekler: json['arkaDirekler'] as String?,
      podye: json['podye'] as String?,
      marsbiyel: json['marsbiyel'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final notlar = aciklamalar ?? const <String, String>{};
    return {
      'gorevId': gorevId,
      'personelId': personelId,
      'parcaDurumlari': parcaDurumlari,
      'mikronlar': mikronlar,
      'yapisalDurumlar': yapisalDurumlar,
      'kontrolListesi': [
        ...kontrolListesiJson(parcalar, parcaDurumlari, notlar, ParcaDurumu.etiket, ParcaDurumu.eksiklikMi)
            .map((e) => {...e, 'mikron': mikronlar[e['key']]}),
        ...kontrolListesiJson(yapisal, yapisalDurumlar, notlar, YapisalDurum.etiket, YapisalDurum.eksiklikMi),
      ],
      // Eski alanlar (AI / PDF / merkezi AI worker)
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

  Adim4BoyaKaportaModel copyWith({
    String? gorevId,
    String? personelId,
    Map<String, String>? parcaDurumlari,
    Map<String, int>? mikronlar,
    Map<String, String>? yapisalDurumlar,
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
      parcaDurumlari: parcaDurumlari ?? this.parcaDurumlari,
      mikronlar: mikronlar ?? this.mikronlar,
      yapisalDurumlar: yapisalDurumlar ?? this.yapisalDurumlar,
      hasarKayitlari: hasarKayitlari ?? this.hasarKayitlari,
      genelNot: genelNot ?? this.genelNot,
      aciklama: aciklama ?? this.aciklama,
      aciklamalar: aciklamalar ?? this.aciklamalar,
      fotografUrl: fotografUrl ?? this.fotografUrl,
      fotografYolu: fotografYolu ?? this.fotografYolu,
      fotografUrlleri: fotografUrlleri ?? this.fotografUrlleri,
      boyaliParcalar: _legacyBoyali,
      degisenParcalar: _legacyDegisen,
      onKapiBoya: _legacy['onKapiBoya'],
      arkaKapiBoya: _legacy['arkaKapiBoya'],
      kaputBoya: _legacy['kaputBoya'],
      tamponBoya: _legacy['tamponBoya'],
      tavanBoya: _legacy['tavanBoya'],
      onKapiKaporta: _legacy['onKapiKaporta'],
      arkaKapiKaporta: _legacy['arkaKapiKaporta'],
      kaputKaporta: _legacy['kaputKaporta'],
      tamponKaporta: _legacy['tamponKaporta'],
      onSasi: _legacy['onSasi'],
      arkaSasi: _legacy['arkaSasi'],
      onDirekler: _legacy['onDirekler'],
      arkaDirekler: _legacy['arkaDirekler'],
      podye: _legacy['podye'],
      marsbiyel: _legacy['marsbiyel'],
    );
  }

  @override
  String toString() => 'Adim4BoyaKaportaModel(durum: $filledFields/$totalFields, hasarlar: $hasarSayisi)';

  static Adim4BoyaKaportaModel empty({String? gorevId, String? personelId}) {
    return Adim4BoyaKaportaModel(gorevId: gorevId, personelId: personelId);
  }

  bool get isEmpty => !_parcaBazli && _legacy.isEmpty && hasarKayitlari.isEmpty;

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
