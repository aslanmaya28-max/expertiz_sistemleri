/// PersonelService - Enterprise Grade Authority Layer
///
/// ⚠️ SINGLE SOURCE OF TRUTH: Supabase DB
/// SharedPreferences KULLANILMAZ - sadece API üzerinden çalışır
/// AuthServicePro KULLANILMAZ - UserProvider üzerinden yetkilendirme yapılır
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/mappers/location_mapper.dart';
import '../models/personel_model.dart';
import '../ui/viewmodels/personel_viewmodel.dart';
import 'yerimebak_expertiz_api_service.dart';
import 'task_reassignment_service.dart';

class PersonelService extends ChangeNotifier {
  // Singleton pattern
  static final PersonelService _instance = PersonelService._internal();
  factory PersonelService() => _instance;
  PersonelService._internal();

  // Internal storage
  final List<PersonelModel> _personeller = [];
  final LocationMapper _locationMapper = LocationMapper();
  final YerimebakExpertizApiService _apiService = YerimebakExpertizApiService();
  final Map<int, int> _ilSayaclari = {};
  Map<String, dynamic>? _coverage;

  // Getters
  List<PersonelModel> get personeller => List.unmodifiable(_personeller);
  int get personelCount => _personeller.length;
  Map<String, dynamic>? get coverage => _coverage;

  /// Load personnel from Supabase
  Future<void> loadPersoneller() async {
    try {
      if (await _loadPersonellerFromApi()) {
        return;
      }
      // API başarısız olursa Supabase'den yükle
      await _loadPersonellerFromSupabase();
    } catch (e) {
      debugPrint('❌ Personel yükleme hatası: $e');
    }
  }

  Future<void> _loadPersonellerFromSupabase() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('profiles')
          .select()
          .eq('role', 'field_staff')
          .order('created_at', ascending: false);

      final loaded = (response as List)
          .map((json) => PersonelModel.fromMap(json as Map<String, dynamic>))
          .toList();

      _personeller
        ..clear()
        ..addAll(loaded);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Supabase personel yükleme hatası: $e');
    }
  }

  Future<bool> _loadPersonellerFromApi() async {
    try {
      final response = await _apiService.getPersonnel();
      final data = response['personnel'];
      if (data is! List) return false;

      final loaded = data
          .whereType<Map<String, dynamic>>()
          .map(PersonelModel.fromMap)
          .toList();
      _personeller
        ..clear()
        ..addAll(loaded);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Personel API yukleme fallback: $e');
      return false;
    }
  }

  Future<void> loadCoverage() async {
    try {
      _coverage = await _apiService.getPersonnelCoverage();
      notifyListeners();
    } catch (e) {
      debugPrint('Personel coverage yukleme hatasi: $e');
    }
  }

  Map<String, dynamic> _toApiPayload(PersonelModel personel, {bool includePassword = false}) {
    return {
      'full_name': personel.tamAd,
      'email': personel.email,
      'phone': personel.telefon,
      'city': personel.il ?? _locationMapper.getIlAdi(personel.ilId),
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
      _ilSayaclari[personel.ilId] = (_ilSayaclari[personel.ilId] ?? 0) + 1;
    }
  }

  /// Add or update personnel
  Future<void> addPersonel(PersonelModel personel) async {
    try {
      try {
        if (personel.email?.isNotEmpty == true && personel.sifre?.isNotEmpty == true) {
          final response = await _apiService.createPersonnel(
            _toApiPayload(personel, includePassword: true),
          );
          final apiPersonel = response['personnel'];
          if (apiPersonel is Map<String, dynamic>) {
            _upsertLocal(PersonelModel.fromMap(apiPersonel));
          } else {
            _upsertLocal(personel);
          }
        } else {
          _upsertLocal(personel);
        }
      } catch (e) {
        debugPrint('Personel API ekleme fallback: $e');
        _upsertLocal(personel);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Personel ekleme hatası: $e');
      rethrow;
    }
  }

  /// Update personnel
  Future<void> updatePersonel(PersonelModel updatedPersonel) async {
    try {
      try {
        await _apiService.updatePersonnel(
          updatedPersonel.id,
          _toApiPayload(updatedPersonel),
        );
      } catch (e) {
        debugPrint('Personel API guncelleme fallback: $e');
      }
      _upsertLocal(updatedPersonel);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Personel güncelleme hatası: $e');
      rethrow;
    }
  }

  /// Delete personnel
  Future<void> deletePersonel(String personelId) async {
    try {
      _personeller.removeWhere((p) => p.id == personelId);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Personel silme hatası: $e');
      rethrow;
    }
  }

  Future<ReassignmentResult> deactivatePersonel(
    String personelId,
    String reason, {
    String? triggeredByUserId,
  }) async {
    final personel = _personeller.firstWhere((p) => p.id == personelId);
    final personelName = personel.tamAd;

    // 1. Deactivate via API
    await _apiService.deactivatePersonnel(personelId, reason);

    // 2. Reassign all open tasks automatically
    final reassignmentService = TaskReassignmentService(
      supabase: Supabase.instance.client,
    );

    final reassignmentResult = await reassignmentService.reassignOpenTasks(
      deactivatedPersonelId: personelId,
      deactivatedPersonelName: personelName,
      reason: reason,
      triggeredByUserId: triggeredByUserId,
    );

    // 3. Update local state
    _upsertLocal(personel.copyWith(aktif: false));
    await loadCoverage();
    notifyListeners();

    debugPrint(
      '👤 Personel pasife alındı: $personelName | '
      '${reassignmentResult.totalReassigned} görev yeniden atandı, '
      '${reassignmentResult.totalFailed} başarısız',
    );

    return reassignmentResult;
  }

  Future<void> activatePersonel(String personelId) async {
    final personel = _personeller.firstWhere((p) => p.id == personelId);
    await _apiService.activatePersonnel(personelId);
    _upsertLocal(personel.copyWith(aktif: true));
    await loadCoverage();
    notifyListeners();
  }

  Future<void> resetPersonelPassword(String personelId, String temporaryPassword) async {
    await _apiService.resetPersonnelPassword(personelId, temporaryPassword);
  }

  /// Get filtered personnel
  Future<List<PersonelModel>> getFilteredPersoneller() async {
    // UserProvider üzerinden yetkilendirme yapılır
    // Bu metod UI tarafında context.read<UserProvider>() ile kullanılır
    return List.from(_personeller);
  }

  /// Get ViewModels
  Future<List<PersonelViewModel>> getPersonelViewModels() async {
    final filteredPersoneller = await getFilteredPersoneller();
    return filteredPersoneller.map((p) => PersonelViewModel.fromModel(p, _locationMapper)).toList();
  }

  /// Submit TamRapor to cloud (sync with admin dashboard)
  Future<void> submitTamRapor(dynamic tamRapor) async {
    try {
      // In production, this would send to a backend API
      final personelId = tamRapor.personelId;
      final personelIndex = _personeller.indexWhere((p) => p.id == personelId);
      if (personelIndex != -1) {
        final personel = _personeller[personelIndex];
        final updatedPersonel = personel.copyWith(
          tamamlananGorevSayisi: (personel.tamamlananGorevSayisi ?? 0) + 1,
        );
        _personeller[personelIndex] = updatedPersonel;
      }
      
      notifyListeners();
      debugPrint('✅ TamRapor başarıyla kaydedildi: ${tamRapor.gorevId}');
    } catch (e) {
      debugPrint('❌ TamRapor kaydetme hatası: $e');
      rethrow;
    }
  }
}
