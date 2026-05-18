/// AUTH-AWARE SERVICE CONTRACT
/// 
/// Tüm servisler bu kontratı uygulamalıdır.
/// Auth state'e bağlı servisler için tek doğruluk kaynağı.
/// 
/// ALTIN KURAL:
/// Auth state düşerse, sistemde TEK BİR SERVİS, TEK BİR ISOLATE,
/// TEK BİR STREAM, TEK BİR TIMER çalışıyor olamaz.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth-aware service kontratı
/// 
/// Tüm servisler:
/// - Auth-aware
/// - Start/Stop kontrollü
/// - Isolate-based ise kill zorunlu
/// - Heartbeat göndermek zorunlu
abstract class AuthAwareService {
  /// Servis şu an çalışıyor mu?
  bool get isAlive;

  /// Bu servis Isolate kullanıyor mu?
  /// 
  /// Isolate tabanlı servisler stop() içinde mutlaka kill edilmelidir
  bool get isIsolateBased => false;

  /// Servis adı (heartbeat için)
  String get serviceName;

  /// Auth stream'den gelen session ile servisi başlat
  /// 
  /// Bu metod:
  /// - Servisi ayağa kaldırır
  /// - Session'ı kullanarak auth işlemleri yapar
  /// - Token veya Session cache'lemek YASAKTIR
  /// - Heartbeat timer'ı başlatır (60s)
  Future<void> start(Session session);

  /// Tüm kaynakları, stream'leri ve isolate'leri imha et
  /// 
  /// Bu metod:
  /// - Tüm stream'leri cancel eder
  /// - Tüm timer'ları iptal eder
  /// - Isolate varsa kill eder (priority: immediate)
  /// - Logout sonrası byte hareketi kalmaz
  /// - Heartbeat göndermeyi DURDURUR
  Future<void> stop();

  /// Service heartbeat gönder
  /// 
  /// Bu metod:
  /// - Her 60s'de bir çağrılır
  /// - Supabase'e service_heartbeat tablosuna yazar
  /// - Servis hayatta olduğunu bildirir
  /// - start() içinde timer ile çalıştırılır
  /// - stop() içinde timer iptal edilir
  Future<void> sendHeartbeat(SupabaseClient supabase, String userId);
}
