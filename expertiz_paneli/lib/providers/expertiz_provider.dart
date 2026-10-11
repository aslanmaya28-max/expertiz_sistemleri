import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/expertiz/adim1_arac_satici_model.dart';
import '../models/expertiz/adim2_dis_ekspertiz_model.dart';
import '../models/expertiz/adim3_ic_ekspertiz_model.dart';
import '../models/expertiz/adim4_boya_kaporta_model.dart';
import '../models/expertiz/adim5_kurumsal_ekspertiz_model.dart';
import '../models/expertiz/kontrol_listesi.dart';
import '../models/expertiz/rapor_medya.dart';
import '../models/expertiz/tam_rapor_model.dart';
import '../services/yerimebak_expertiz_api_service.dart';

/// Saha ekspertiz akışı state yönetimi.
///
/// Akış: Görevi Başlat → 1 Araç → 2 Dış → 3 İç → 4 Boya/Kaporta →
/// 5 Kurumsal Ekspertiz → Kaydet ve Gönder (admin "Onay Bekleyen").
///
/// - Taslak her değişiklikte (1.5 sn gecikmeyle) merkezi API'ye kaydedilir;
///   personel uygulamayı kapatsa da kaldığı yerden devam eder.
/// - Eksiklik işaretlenen maddeler için fotoğraf zorunludur. Fotoğraflar
///   anında sunucuya yüklenir; admin ve (yayınlandıktan sonra) müşteri görür.
/// - Müşteri kurumsal ekspertiz talep ettiyse firmanın raporu dosyaya
///   eklenmeden gönderilemez.
class ExpertizProvider extends ChangeNotifier {
  ExpertizProvider({YerimebakExpertizApiService? apiService})
      : _api = apiService ?? YerimebakExpertizApiService();

  final YerimebakExpertizApiService _api;

  /// Bölüm anahtarları (sunucudaki `section` alanı)
  static const bolumArac = 'arac';
  static const bolumDis = 'dis';
  static const bolumIc = 'ic';
  static const bolumBoya = 'boya_kaporta';
  static const bolumKurumsal = 'kurumsal';

  // Görev bilgileri
  String? _gorevId;
  String? _personelId;
  String? _personelAdi;
  String? _musteriAdi;
  String? _aracPlakasi;

  int _currentStep = 1;

  Adim1AracSaticiModel? _adim1Model;
  Adim2DisEkspertizModel? _adim2Model;
  Adim3IcEkspertizModel? _adim3Model;
  Adim4BoyaKaportaModel? _adim4Model;
  Adim5KurumsalEkspertizModel? _adim5Model;

  // Sunucu durumu
  List<RaporMedya> _medya = [];
  bool _kurumsalZorunlu = false;
  String _kurumsalFirma = '';
  String _kurumsalPaket = '';
  String? _redNedeni;
  bool _duzenlenebilir = true;
  DateTime? _taslakKayitZamani;
  bool _taslakKaydediliyor = false;
  String? _taslakHatasi;
  Timer? _taslakTimer;
  final Set<String> _yuklenenler = {};

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Getters
  String? get gorevId => _gorevId;
  String? get personelId => _personelId;
  String? get personelAdi => _personelAdi;
  String? get musteriAdi => _musteriAdi;
  String? get aracPlakasi => _aracPlakasi;
  int get currentStep => _currentStep;
  Adim1AracSaticiModel? get adim1Model => _adim1Model;
  Adim2DisEkspertizModel? get adim2Model => _adim2Model;
  Adim3IcEkspertizModel? get adim3Model => _adim3Model;
  Adim4BoyaKaportaModel? get adim4Model => _adim4Model;
  Adim5KurumsalEkspertizModel? get adim5Model => _adim5Model;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<RaporMedya> get medya => List.unmodifiable(_medya);
  bool get kurumsalZorunlu => _kurumsalZorunlu;
  String get kurumsalFirma => _kurumsalFirma;
  String get kurumsalPaket => _kurumsalPaket;
  String? get redNedeni => _redNedeni;
  bool get duzenlenebilir => _duzenlenebilir;
  DateTime? get taslakKayitZamani => _taslakKayitZamani;
  bool get taslakKaydediliyor => _taslakKaydediliyor;
  String? get taslakHatasi => _taslakHatasi;
  YerimebakExpertizApiService get api => _api;

  bool yukleniyor(String bolum, String maddeKey) => _yuklenenler.contains('$bolum/$maddeKey');

  List<RaporMedya> fotograflar(String bolum, String maddeKey) => _medya
      .where((m) => m.kategori == RaporMedya.kategoriFoto && m.bolum == bolum && m.maddeKey == maddeKey)
      .toList();

  List<RaporMedya> get kurumsalRaporlar => _medya.where((m) => m.kurumsalRaporMu).toList();

  int get toplamFotograf => _medya.where((m) => m.kategori == RaporMedya.kategoriFoto).length;

  /// Seçili donanımlar (MarketRadarService formatı)
  Map<String, bool> get selectedOptions {
    final model = _adim3Model;
    if (model == null) return {};
    return {
      for (final entry in model.durumlar.entries)
        if (entry.value != KontrolDurumu.yok) entry.key: true,
    };
  }

  // ---------------------------------------------------------------------------
  // Doğrulama
  // ---------------------------------------------------------------------------

  /// Fotoğrafı eksik olan "eksiklikli" maddeler
  List<KontrolMaddesi> eksikFotograflar(int step) {
    switch (step) {
      case 2:
        return (_adim2Model?.eksiklikliMaddeler ?? const <KontrolMaddesi>[])
            .where((m) => fotograflar(bolumDis, m.key).isEmpty)
            .toList();
      case 3:
        return (_adim3Model?.eksiklikliMaddeler ?? const <KontrolMaddesi>[])
            .where((m) => fotograflar(bolumIc, m.key).isEmpty)
            .toList();
      case 4:
        return (_adim4Model?.eksiklikliMaddeler ?? const <KontrolMaddesi>[])
            .where((m) => fotograflar(bolumBoya, m.key).isEmpty)
            .toList();
      default:
        return const [];
    }
  }

  /// Adımdaki eksikler (kullanıcıya gösterilecek mesajlar)
  List<String> adimEksikleri(int step) {
    final eksikler = <String>[];
    switch (step) {
      case 1:
        final m = _adim1Model;
        if (m == null) return ['Araç bilgileri yüklenmedi'];
        if (m.marka.isEmpty) eksikler.add('Marka');
        if (m.model.isEmpty) eksikler.add('Model');
        if (m.plaka.isEmpty) eksikler.add('Plaka');
        if (m.saseNo.isEmpty) eksikler.add('Şase No');
        if (m.ruhsatSahibiAdSoyad.isEmpty) eksikler.add('Ruhsat sahibi');
        if (m.iletisimTelefon.isEmpty) eksikler.add('İletişim telefonu');
        if (!m.durumSorular.every((s) => s.isFilled)) eksikler.add('Satıcı değerlendirme soruları (durum + not)');
        if (m.pazarlikPayiVar && (m.pazarlikMiktari == null || m.pazarlikMiktari! <= 0)) {
          eksikler.add('Pazarlık miktarı');
        }
        break;
      case 2:
        eksikler.addAll((_adim2Model?.eksikMaddeler ?? DisEkspertizListesi.maddeler).map((m) => '${m.label}: durum seçilmedi'));
        break;
      case 3:
        eksikler.addAll((_adim3Model?.eksikMaddeler ?? IcEkspertizListesi.maddeler).map((m) => '${m.label}: durum seçilmedi'));
        break;
      case 4:
        final m = _adim4Model;
        eksikler.addAll(
          (m?.eksikMaddeler ?? [...BoyaKaportaListesi.parcalar, ...BoyaKaportaListesi.yapisal])
              .map((x) => '${x.label}: durum seçilmedi'),
        );
        break;
      case 5:
        final m = _adim5Model;
        if (_kurumsalZorunlu) {
          if (kurumsalRaporlar.isEmpty) eksikler.add('Kurumsal ekspertiz raporu dosyası eklenmedi');
          if ((m?.kurumsalRaporNo ?? '').trim().isEmpty) eksikler.add('Kurumsal rapor numarası');
        }
        if (m?.genelPuan != null && (m!.genelPuan! < 0 || m.genelPuan! > 100)) {
          eksikler.add('Genel puan 0-100 arasında olmalı');
        }
        break;
    }
    eksikler.addAll(eksikFotograflar(step).map((m) => '${m.label}: eksiklik için fotoğraf çekilmedi'));
    return eksikler;
  }

  bool adimGecerli(int step) => adimEksikleri(step).isEmpty;

  bool get currentStepValid => adimGecerli(_currentStep);

  bool get allStepsValid => [1, 2, 3, 4, 5].every(adimGecerli);

  double get completionPercentage {
    int filled = 0;
    int total = 0;
    void add(int f, int t) {
      filled += f;
      total += t;
    }

    final a1 = _adim1Model;
    if (a1 != null) add(a1.filledFields, a1.totalFields);
    final a2 = _adim2Model;
    if (a2 != null) add(a2.filledFields, a2.totalFields);
    final a3 = _adim3Model;
    if (a3 != null) add(a3.filledFields, a3.totalFields);
    final a4 = _adim4Model;
    if (a4 != null) add(a4.filledFields, a4.totalFields);
    final a5 = _adim5Model;
    if (a5 != null) add(a5.filledFields, a5.totalFields);
    return total > 0 ? (filled / total).clamp(0.0, 1.0) : 0.0;
  }

  // ---------------------------------------------------------------------------
  // Başlatma ve taslak
  // ---------------------------------------------------------------------------

  Future<void> startGorev({
    required String gorevId,
    required String personelId,
    required String personelAdi,
    required String musteriAdi,
    required String aracPlakasi,
  }) async {
    _gorevId = gorevId;
    _personelId = personelId;
    _personelAdi = personelAdi;
    _musteriAdi = musteriAdi;
    _aracPlakasi = aracPlakasi;
    _errorMessage = null;
    setLoading(true);

    try {
      final response = await _api.getTaskReport(gorevId);
      final task = response['task'] is Map ? Map<String, dynamic>.from(response['task'] as Map) : <String, dynamic>{};
      final vehicle = task['vehicle'] is Map ? Map<String, dynamic>.from(task['vehicle'] as Map) : <String, dynamic>{};
      final corporate = response['corporate'] is Map
          ? Map<String, dynamic>.from(response['corporate'] as Map)
          : <String, dynamic>{};

      _medya = RaporMedya.listFrom(response['media']);
      _kurumsalZorunlu = corporate['required'] == true;
      _kurumsalFirma = corporate['firm_name']?.toString() ?? '';
      _kurumsalPaket = corporate['package_name']?.toString() ?? '';
      _redNedeni = response['rejection_reason']?.toString();
      _duzenlenebilir = response['editable'] != false;
      _taslakKayitZamani = DateTime.tryParse(response['draft_saved_at']?.toString() ?? '');

      final raw = response['tam_rapor'];
      if (raw is Map) {
        final rapor = TamRaporModel.fromJson(Map<String, dynamic>.from(raw));
        _adim1Model = rapor.adim1;
        _adim2Model = rapor.adim2;
        _adim3Model = rapor.adim3;
        _adim4Model = rapor.adim4;
        _adim5Model = rapor.adim5;
      } else {
        _initializeEmptyModels(gorevId, personelId, aracPlakasi, vehicle);
      }
      _adim5Model = _adim5Model!.copyWith(
        kurumsalTalepVar: _kurumsalZorunlu,
        kurumsalFirma: _kurumsalFirma,
        kurumsalPaket: _kurumsalPaket,
      );
      // İlk eksik adımdan devam et
      _currentStep = [1, 2, 3, 4, 5].firstWhere((s) => !adimGecerli(s), orElse: () => 5);
    } catch (e) {
      debugPrint('Görev raporu yüklenemedi: $e');
      _errorMessage = 'Görev yüklenemedi: $e';
    } finally {
      setLoading(false);
    }
  }

  void _initializeEmptyModels(String gorevId, String personelId, String plaka, Map<String, dynamic> vehicle) {
    _currentStep = 1;
    _adim1Model = Adim1AracSaticiModel(
      gorevId: gorevId,
      personelId: personelId,
      marka: vehicle['brand']?.toString() ?? '',
      model: vehicle['model']?.toString() ?? '',
      yil: vehicle['year']?.toString(),
      yakitTuru: 'Benzin',
      plaka: (vehicle['plate']?.toString() ?? '').isNotEmpty ? vehicle['plate'].toString() : plaka,
      saseNo: '',
      guncelKm: vehicle['km'] is num ? (vehicle['km'] as num).toInt() : int.tryParse('${vehicle['km'] ?? ''}') ?? 0,
      ruhsatSahibiAdSoyad: '',
      iletisimTelefon: '',
      motorNo: '',
    );
    _adim2Model = Adim2DisEkspertizModel.empty(gorevId: gorevId, personelId: personelId);
    _adim3Model = Adim3IcEkspertizModel.empty(gorevId: gorevId, personelId: personelId);
    _adim4Model = Adim4BoyaKaportaModel.empty(gorevId: gorevId, personelId: personelId);
    _adim5Model = Adim5KurumsalEkspertizModel.empty(gorevId: gorevId, personelId: personelId);
  }

  TamRaporModel? _buildRapor({String durum = 'Taslak', DateTime? bitis}) {
    if (_gorevId == null || _personelId == null) return null;
    return TamRaporModel(
      gorevId: _gorevId!,
      personelId: _personelId!,
      adim1: _adim1Model ?? Adim1AracSaticiModel.empty(gorevId: _gorevId, personelId: _personelId),
      adim2: _adim2Model ?? Adim2DisEkspertizModel.empty(gorevId: _gorevId, personelId: _personelId),
      adim3: _adim3Model ?? Adim3IcEkspertizModel.empty(gorevId: _gorevId, personelId: _personelId),
      adim4: _adim4Model ?? Adim4BoyaKaportaModel.empty(gorevId: _gorevId, personelId: _personelId),
      adim5: _adim5Model ?? Adim5KurumsalEkspertizModel.empty(gorevId: _gorevId, personelId: _personelId),
      durum: durum,
      bitisZamani: bitis,
    );
  }

  void _scheduleDraft() {
    if (!_duzenlenebilir) return;
    _taslakTimer?.cancel();
    _taslakTimer = Timer(const Duration(milliseconds: 1500), taslagiKaydet);
  }

  /// Taslağı hemen sunucuya kaydeder.
  Future<void> taslagiKaydet() async {
    _taslakTimer?.cancel();
    final rapor = _buildRapor();
    if (rapor == null || !_duzenlenebilir) return;
    _taslakKaydediliyor = true;
    notifyListeners();
    try {
      final response = await _api.saveTaskDraft(rapor.gorevId, rapor.toJson());
      _taslakKayitZamani = DateTime.tryParse(response['draft_saved_at']?.toString() ?? '') ?? DateTime.now();
      _taslakHatasi = null;
    } catch (e) {
      _taslakHatasi = 'Taslak kaydedilemedi: $e';
      debugPrint(_taslakHatasi);
    } finally {
      _taslakKaydediliyor = false;
      notifyListeners();
    }
  }

  void updateAdim1(Adim1AracSaticiModel model) {
    _adim1Model = model;
    _scheduleDraft();
    notifyListeners();
  }

  void updateAdim2(Adim2DisEkspertizModel model) {
    _adim2Model = model;
    _scheduleDraft();
    notifyListeners();
  }

  void updateAdim3(Adim3IcEkspertizModel model) {
    _adim3Model = model;
    _scheduleDraft();
    notifyListeners();
  }

  void updateAdim4(Adim4BoyaKaportaModel model) {
    _adim4Model = model;
    _scheduleDraft();
    notifyListeners();
  }

  void updateAdim5(Adim5KurumsalEkspertizModel model) {
    _adim5Model = model;
    _scheduleDraft();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Fotoğraf ve dosyalar
  // ---------------------------------------------------------------------------

  /// Bir madde için fotoğraf yükler (sunucuya). Hata olursa fırlatır.
  Future<RaporMedya> fotografYukle({
    required String bolum,
    required String maddeKey,
    required String maddeEtiket,
    required List<int> bytes,
    required String dosyaAdi,
    String? not,
  }) async {
    final key = '$bolum/$maddeKey';
    _yuklenenler.add(key);
    notifyListeners();
    try {
      final response = await _api.uploadTaskMedia(
        _gorevId!,
        bytes: bytes,
        fileName: dosyaAdi,
        category: RaporMedya.kategoriFoto,
        section: bolum,
        itemKey: maddeKey,
        itemLabel: maddeEtiket,
        note: not,
      );
      final medya = RaporMedya.fromJson(Map<String, dynamic>.from(response['media'] as Map));
      _medya = [..._medya, medya];
      return medya;
    } finally {
      _yuklenenler.remove(key);
      notifyListeners();
    }
  }

  /// Kurumsal ekspertiz firmasının raporunu (PDF veya fotoğraf) ekler.
  Future<RaporMedya> kurumsalRaporYukle({required List<int> bytes, required String dosyaAdi, String? not}) async {
    const key = '$bolumKurumsal/rapor';
    _yuklenenler.add(key);
    notifyListeners();
    try {
      final response = await _api.uploadTaskMedia(
        _gorevId!,
        bytes: bytes,
        fileName: dosyaAdi,
        category: RaporMedya.kategoriKurumsal,
        section: bolumKurumsal,
        itemKey: 'rapor',
        itemLabel: 'Kurumsal Ekspertiz Raporu',
        note: not,
      );
      final medya = RaporMedya.fromJson(Map<String, dynamic>.from(response['media'] as Map));
      _medya = [..._medya, medya];
      return medya;
    } finally {
      _yuklenenler.remove(key);
      notifyListeners();
    }
  }

  Future<void> medyaSil(RaporMedya medya) async {
    await _api.deleteTaskMedia(_gorevId!, medya.id);
    _medya = _medya.where((m) => m.id != medya.id).toList();
    notifyListeners();
  }

  String medyaUrl(RaporMedya medya) => _api.resolveUrl(medya.url);

  // ---------------------------------------------------------------------------
  // Navigasyon
  // ---------------------------------------------------------------------------

  void nextStep() {
    if (_currentStep < 5) {
      _currentStep++;
      _scheduleDraft();
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep > 1) {
      _currentStep--;
      notifyListeners();
    }
  }

  void goToStep(int step) {
    if (step >= 1 && step <= 5) {
      _currentStep = step;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Kaydet ve Gönder
  // ---------------------------------------------------------------------------

  /// Raporu admin onayına gönderir. Eksik varsa false döner ve
  /// [errorMessage] doldurulur (ekran içeriği kaybolmaz).
  Future<bool> completeGorev() async {
    final eksikAdim = [1, 2, 3, 4, 5].where((s) => !adimGecerli(s)).toList();
    if (eksikAdim.isNotEmpty) {
      setSubmitError('Eksik adımlar var: ${eksikAdim.map((s) => stepTitles[s - 1]).join(', ')}');
      return false;
    }
    final rapor = _buildRapor(durum: 'Onay Bekliyor', bitis: DateTime.now());
    if (rapor == null) return false;

    _taslakTimer?.cancel();
    _isSubmitting = true;
    _submitError = null;
    notifyListeners();
    try {
      await _api.submitTaskReport(rapor.gorevId, rapor.toJson());
      _duzenlenebilir = false;
      return true;
    } catch (e) {
      setSubmitError('Rapor gönderilemedi: $e');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Gönderim hatası (ekranı kapatmadan gösterilir)
  String? _submitError;
  String? get submitError => _submitError;

  void setSubmitError(String? message) {
    _submitError = message;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Tam rapor modeli (tüm adımlar geçerliyse)
  TamRaporModel? get tamRaporModel => allStepsValid ? _buildRapor(durum: 'Onay Bekliyor') : null;

  /// Tam rapor oluştur (Adım5Sayfasi için)
  TamRaporModel? tamRaporOlustur() => tamRaporModel;

  /// Tam raporu güncelle
  Future<void> updateTamRapor(TamRaporModel rapor) async {
    _adim1Model = rapor.adim1;
    _adim2Model = rapor.adim2;
    _adim3Model = rapor.adim3;
    _adim4Model = rapor.adim4;
    _adim5Model = rapor.adim5;
    _scheduleDraft();
    notifyListeners();
  }

  void reset() {
    _taslakTimer?.cancel();
    _gorevId = null;
    _personelId = null;
    _personelAdi = null;
    _musteriAdi = null;
    _aracPlakasi = null;
    _currentStep = 1;
    _adim1Model = null;
    _adim2Model = null;
    _adim3Model = null;
    _adim4Model = null;
    _adim5Model = null;
    _medya = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _taslakTimer?.cancel();
    super.dispose();
  }

  static List<String> get stepTitles => [
        'Araç & Satıcı',
        'Dış Ekspertiz',
        'İç Ekspertiz',
        'Boya / Kaporta',
        'Kurumsal Ekspertiz',
      ];

  static List<String> get stepIcons => ['🚗', '🔍', '💺', '🎨', '🏢'];
}
