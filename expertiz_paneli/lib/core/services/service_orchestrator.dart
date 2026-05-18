/// GLOBAL SERVICE ORCHESTRATOR
/// 
/// Auth state'e bağlı tüm servislerin tek noktadan yönetimi.
/// 
/// Kurallar:
/// - Singleton olacak
/// - AuthRepository tek noktadan dinlenecek
/// - Servisler yalnızca buradan start/stop alacak
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../repositories/auth_repository.dart';
import 'auth_aware_service.dart';

/// Global Service Orchestrator
/// 
/// Tüm auth-aware servislerin merkezi yönetim noktası.
/// Auth state değiştiğinde tüm servisleri koordine eder.
class ServiceOrchestrator {
  // Singleton pattern
  static final ServiceOrchestrator _instance =
      ServiceOrchestrator._internal();
  factory ServiceOrchestrator() => _instance;
  ServiceOrchestrator._internal();

  /// Kayıtlı tüm servisler
  final List<AuthAwareService> _services = [];

  /// Auth state change subscription
  StreamSubscription<AuthState>? _authSub;

  /// Transition lock - race condition önleme
  bool _transitioning = false;

  /// Servis kaydet
  /// 
  /// Aynı servis tekrar kaydedilmez
  void registerService(AuthAwareService service) {
    if (!_services.contains(service)) {
      debugPrint('🔧 Servis kaydedildi: ${service.runtimeType}');
      _services.add(service);
    } else {
      debugPrint('⚠️ Servis zaten kayıtlı: ${service.runtimeType}');
    }
  }

  /// Orchestrator'ı başlat
  /// 
  /// AuthRepository'nin auth state change stream'ini dinlemeye başlar
  /// Session varsa servisleri boot eder
  void init(AuthRepository authRepository) {
    debugPrint('🚀 ServiceOrchestrator başlatılıyor...');

    // Önceki subscription'ı temizle
    _authSub?.cancel();

    // Auth state change dinle
    _authSub = authRepository.authStateChanges.listen((state) async {
      final session = state.session;

      if (session == null) {
        // Session yok → tüm servisleri durdur
        debugPrint('🛑 Session yok → tüm servisler durduruluyor...');
        await _shutdownAll();
      } else {
        // Session var → servisleri başlat
        debugPrint('✅ Session var → servisler başlatılıyor...');
        await _bootAll(session);
      }
    });

    debugPrint('✅ ServiceOrchestrator hazır (${_services.length} servis)');
  }

  /// Tüm servisleri başlat
  /// 
  /// Session varsa servisleri ayağa kaldırır
  /// Transition lock ile race condition önlenir
  Future<void> _bootAll(Session session) async {
    if (_transitioning) {
      debugPrint('⏳ Boot zaten devam ediyor, atlanıyor...');
      return;
    }

    _transitioning = true;

    try {
      debugPrint('🟢 Servisler boot ediliyor...');

      for (final service in _services) {
        if (!service.isAlive) {
          try {
            debugPrint('▶️ ${service.runtimeType} başlatılıyor...');
            await service.start(session);
            debugPrint('✅ ${service.runtimeType} başlatıldı');
          } catch (e) {
            debugPrint('❌ ${service.runtimeType} başlatılamadı: $e');
            // Diğer servisleri etkilememek için continue
            continue;
          }
        } else {
          debugPrint('ℹ️ ${service.runtimeType} zaten çalışıyor');
        }
      }

      debugPrint('✅ Tüm servisler boot edildi');
    } finally {
      _transitioning = false;
    }
  }

  /// Tüm servisleri durdur
  /// 
  /// Session yoksa servisleri tamamen durdurur
  /// Transition lock ile race condition önlenir
  /// Isolate tabanlı servisler kill edilir
  Future<void> _shutdownAll() async {
    if (_transitioning) {
      debugPrint('⏳ Shutdown zaten devam ediyor, atlanıyor...');
      return;
    }

    _transitioning = true;

    try {
      debugPrint('🔴 Servisler durduruluyor...');

      // Tüm çalışan servisleri paralel olarak durdur
      final shutdownTasks = _services
          .where((s) => s.isAlive)
          .map((service) async {
        try {
          debugPrint('⏹️ ${service.runtimeType} durduruluyor...');
          await service.stop();
          debugPrint('✅ ${service.runtimeType} durduruldu');
        } catch (e) {
          debugPrint('❌ ${service.runtimeType} durdurulamadı: $e');
        }
      });

      await Future.wait(shutdownTasks);

      debugPrint('✅ Tüm servisler durduruldu');
    } finally {
      _transitioning = false;
    }
  }

  /// Orchestrator'ı temizle
  /// 
  /// Auth subscription'ı iptal eder
  /// Tüm servisleri durdurur
  void dispose() {
    debugPrint('💀 ServiceOrchestrator dispose ediliyor...');

    _authSub?.cancel();
    _authSub = null;

    _shutdownAll();

    debugPrint('✅ ServiceOrchestrator disposed');
  }

  /// Kayıtlı servis sayısı
  int get serviceCount => _services.length;

  /// Çalışan servis sayısı
  int get aliveServiceCount => _services.where((s) => s.isAlive).length;
}