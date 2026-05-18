/// APP LIFECYCLE OBSERVER
/// 
/// Background → Resume sonrası sessiz ama kesin doğrulama yapar
/// 
/// Kullanıcı:
/// - App'i arka plana attı
/// - 5-30 dk sonra geri geldi
/// - Session düşmüş olabilir
/// 
/// Bu observer:
/// - Resume anında auth kontrolü yapar
/// - UI'ye yansımaz
/// - Splash'a atmaz
/// - Gerekirse token refresh
library;

import 'package:flutter/widgets.dart';
import '../../repositories/auth_repository.dart';

/// App Lifecycle Handler
/// 
/// App'in yaşam döngüsünü dinler ve resume anında session check yapar
class AppLifecycleHandler extends WidgetsBindingObserver {
  final AuthRepository authRepository;

  AppLifecycleHandler({required this.authRepository});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed → silent session check başlatılıyor...');
      _onResume();
    }
  }

  /// Resume anında silent session check
  Future<void> _onResume() async {
    try {
      await authRepository.silentSessionCheck();
    } catch (e) {
      debugPrint('❌ Resume session check hatası: $e');
      // Hata olsa bile UI'ya yansıtma
    }
  }
}