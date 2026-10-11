/// PersonelService - Admin personel ve bölge yönetimi
///
/// ⚠️ SINGLE SOURCE OF TRUTH: Merkezi API (FastAPI) → PostgreSQL `users`
/// - Personel ekleme / düzenleme / pasife alma / aktif etme / sistemden çıkarma
/// - İl ve 7 coğrafi bölge bazlı kapsama raporu
///
/// Önceki sürüm API hatalarında personeli sadece yerel listeye ekleyip
/// "başarılı" gibi davranıyordu; kayıtlar uygulama kapanınca kayboluyordu.
/// Artık her hata çağırana iletilir ve UI kullanıcıya gösterir.
library;

import 'package:flutter/foundation.dart';
import '../core/mappers/location_mapper.dart';
import '../models/personel_model.dart';
import '../ui/viewmodels/personel_viewmodel.dart';
import 'yerimebak_expertiz_api_service.dart';

class PersonelService extends ChangeNotifier {
  // Singleton pattern
  static final PersonelService _instance = PersonelService._internal();
  factory PersonelService() => _instance;
  PersonelService._internal();

  /// Testler için API istemcisini değiştirmeye izin verir.
  @visibleForTesting
  set apiServiceForTesting(YerimebakExpertizApiService service) => _apiService = service;

  final List<PersonelModel> _personeller = [];
  final LocationMapper _locationMapper = LocationMapper();
  YerimebakExpertizApiService _apiService = YerimebakExpertizApiService();
  Map<String, dynamic>? _coverage;
  bool _isLoading = false;
  String? _lastError;

  List<PersonelModel> get personeller => List.unmodifiable(_personeller);
  int get personelCount => _personeller.length;
  Map<String, dynamic>? get coverage => _coverage;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  List<PersonelModel> get aktifPersoneller => _personeller.where((p) => p.aktif).toList();

  /// API yanıtındaki personeli modele çevirir (il/bölge ID'leri dahil).
  PersonelModel fromApi(Map<String, dynamic> json) {
    final model = PersonelModel.fromMap(json);
    final apiIlId = json['il_id'] is int ? json['il_id'] as int : int.tryParse('${json['il_id'] ?? ''}');
    final ilId = (apiIlId != null && apiIlId > 0) ? apiIlId : _locationMapper.getIlId(model.il ?? '');
    final apiBolgeId = json['region_id'] is int ? json['region_id'] as int : int.tryParse('${json['region_id'] ?? ''}');
    final bolgeId = (apiBolgeId != null && apiBolgeId > 0) ? apiBolgeId : _locationMapper.getBolgeIdFromIlId(ilId);
    final doneTasks = json['completed_task_count'] is int
        ? json['completed_task_count'] as int
        : int.tryParse('${json['completed_task_count'] ?? 0}') ?? 0;
    final expertise = json['expertise']?.toString() ?? '';
    return model.copyWith(
      ilId: ilId,
      bolgeId: bolgeId,
      bolge: json['region']?.toString() ?? _locationMapper.getBolgeAdi(bolgeId),
      unvan: model.unvan.isNotEmpty ? model.unvan : (expertise.isNotEmpty ? expertise : 'Saha Personeli'),
      tamamlananGorevSayisi: doneTasks,
      kayitTarihi: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  /// Personelin üzerindeki açık (atanmış, raporlanmamış) görev sayısı.
  final Map<String, int> _openTaskCounts = {};
  int acikGorevSayisi(String personelId) => _openTaskCounts[personelId] ?? 0;

  /// Personelleri merkezi API'den yükler. Hata olursa [lastError] dolar.
  Future<void> loadPersoneller() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.getPersonnel();
      final data = response['personnel'];
      final rows = data is List ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
      _openTaskCounts
        ..clear()
        ..addEntries(rows.map((row) => MapEntry(
              row['id']?.toString() ?? '',
              row['open_task_count'] is int ? row['open_task_count'] as int : int.tryParse('${row['open_task_count'] ?? 0}') ?? 0,
            )));
      _personeller
        ..clear()
        ..addAll(rows.map(fromApi));
      _lastError = null;
    } catch (e) {
      _lastError = 'Personel listesi yüklenemedi: $e';
      debugPrint('❌ $_lastError');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCoverage() async {
    try {
      _coverage = await _apiService.getPersonnelCoverage();
      notifyListeners();
    } catch (e) {
      _lastError = 'Kapsama raporu yüklenemedi: $e';
      debugPrint('❌ $_lastError');
      notifyListeners();
    }
  }

  /// Personel ve kapsama verisini birlikte yeniler.
  Future<void> refreshAll() async {
    await loadPersoneller();
    await loadCoverage();
  }

  Map<String, dynamic> _toApiPayload(PersonelModel personel, {bool includePassword = false}) {
    final city = (personel.il != null && personel.il!.isNotEmpty) ? personel.il! : _locationMapper.getIlAdi(personel.ilId);
    return {
      'full_name': personel.tamAd.trim(),
      'email': personel.email?.trim(),
      'phone': personel.telefon?.trim() ?? '',
      'city': city,
      'district': personel.ilce ?? '',
      'expertise': personel.uzmanlikAlani ?? personel.unvan,
      if (includePassword) 'temporary_password': personel.sifre,
    };
  }

  void _upsertLocal(PersonelModel personel) {
    final index = _personeller.indexWhere((p) => p.id == personel.id);
    if (index != -1) {
      _personeller[index] = personel;
    } else {
      _personeller.add(personel);
    }
  }

  /// Yeni personel ekler. Başarısız olursa hata fırlatır (UI gösterir).
  Future<PersonelModel> addPersonel(PersonelModel personel) async {
    if ((personel.email ?? '').isEmpty || (personel.sifre ?? '').isEmpty) {
      throw ArgumentError('E-posta ve geçici şifre zorunludur');
    }
    final response = await _apiService.createPersonnel(_toApiPayload(personel, includePassword: true));
    final apiPersonel = response['personnel'];
    if (apiPersonel is! Map) {
      throw StateError('Sunucu personel bilgisini döndürmedi');
    }
    final created = fromApi(Map<String, dynamic>.from(apiPersonel));
    _upsertLocal(created);
    notifyListeners();
    await loadCoverage();
    return created;
  }

  /// Personel bilgilerini günceller (ad, telefon, il/ilçe, uzmanlık).
  Future<PersonelModel> updatePersonel(PersonelModel updatedPersonel) async {
    final payload = _toApiPayload(updatedPersonel)..remove('email');
    final response = await _apiService.updatePersonnel(updatedPersonel.id, payload);
    final apiPersonel = response['personnel'];
    final updated = apiPersonel is Map ? fromApi(Map<String, dynamic>.from(apiPersonel)) : updatedPersonel;
    _upsertLocal(updated);
    notifyListeners();
    await loadCoverage();
    return updated;
  }

  /// Personeli sistemden çıkarır. Açık görevleri otomatik olarak admin
  /// kuyruğuna geri döner. Geri dönen görev sayısını verir.
  Future<int> deletePersonel(String personelId, {String? reason}) async {
    final response = await _apiService.removePersonnel(personelId, reason: reason);
    _personeller.removeWhere((p) => p.id == personelId);
    _openTaskCounts.remove(personelId);
    notifyListeners();
    await loadCoverage();
    return _releasedCount(response);
  }

  /// Personeli pasife alır. Açık görevleri backend tarafından admin
  /// kuyruğuna geri düşürülür; geri dönen görev sayısını verir.
  Future<int> deactivatePersonel(String personelId, String reason) async {
    final response = await _apiService.deactivatePersonnel(personelId, reason);
    final apiPersonel = response['personnel'];
    final index = _personeller.indexWhere((p) => p.id == personelId);
    if (apiPersonel is Map) {
      _upsertLocal(fromApi(Map<String, dynamic>.from(apiPersonel)));
    } else if (index != -1) {
      _personeller[index] = _personeller[index].copyWith(aktif: false);
    }
    _openTaskCounts[personelId] = 0;
    notifyListeners();
    await loadCoverage();
    final released = _releasedCount(response);
    debugPrint('👤 Personel pasife alındı: $personelId | $released görev admin kuyruğuna döndü');
    return released;
  }

  Future<void> activatePersonel(String personelId) async {
    final response = await _apiService.activatePersonnel(personelId);
    final apiPersonel = response['personnel'];
    final index = _personeller.indexWhere((p) => p.id == personelId);
    if (apiPersonel is Map) {
      _upsertLocal(fromApi(Map<String, dynamic>.from(apiPersonel)));
    } else if (index != -1) {
      _personeller[index] = _personeller[index].copyWith(aktif: true);
    }
    notifyListeners();
    await loadCoverage();
  }

  Future<void> resetPersonelPassword(String personelId, String temporaryPassword) async {
    await _apiService.resetPersonnelPassword(personelId, temporaryPassword);
  }

  int _releasedCount(Map<String, dynamic> response) {
    final value = response['released_task_count'];
    if (value is int) return value;
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  /// Get filtered personnel
  Future<List<PersonelModel>> getFilteredPersoneller() async {
    return List.from(_personeller);
  }

  /// Get ViewModels
  Future<List<PersonelViewModel>> getPersonelViewModels() async {
    final filteredPersoneller = await getFilteredPersoneller();
    return filteredPersoneller.map((p) => PersonelViewModel.fromModel(p, _locationMapper)).toList();
  }

  /// Submit TamRapor to cloud (sync with admin dashboard)
  Future<void> submitTamRapor(dynamic tamRapor) async {
    final personelId = tamRapor.personelId;
    final personelIndex = _personeller.indexWhere((p) => p.id == personelId);
    if (personelIndex != -1) {
      final personel = _personeller[personelIndex];
      _personeller[personelIndex] = personel.copyWith(
        tamamlananGorevSayisi: (personel.tamamlananGorevSayisi ?? 0) + 1,
      );
    }
    notifyListeners();
    debugPrint('✅ TamRapor başarıyla kaydedildi: ${tamRapor.gorevId}');
  }
}
