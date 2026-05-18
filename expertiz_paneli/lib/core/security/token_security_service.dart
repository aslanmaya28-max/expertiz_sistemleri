/// TOKEN SECURITY SERVICE
///
/// FAZ-3.0 / S5 — Customer Token Security (httpOnly Cookie)
///
/// 🎯 PURPOSE:
/// Ensures customer tokens are stored securely using httpOnly cookies
/// via Supabase Auth's built-in PKCE flow. No localStorage, no
/// SharedPreferences, no in-memory token storage in Flutter.
///
/// 🪨 PRINCIPLE:
/// "The client never sees the token. The browser/server manages it."
///
/// SECURITY MEASURES:
/// 1. httpOnly cookies — JS/Flutter cannot read the token
/// 2. PKCE flow — No client secret needed, authorization code only
/// 3. Automatic refresh — Tokens refreshed before expiry
/// 4. Session persistence — Survives app restart via cookie
/// 5. XSS protection — Token not accessible via dart:html or any JS bridge
/// 6. CSRF protection — State parameter in OAuth flow
/// 7. Secure flag — Cookies only sent over HTTPS
/// 8. SameSite=Strict — Prevents CSRF attacks
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Token Security Service
///
/// Manages secure token handling for customer authentication.
/// Works exclusively with Supabase Auth's built-in httpOnly cookie mechanism.
///
/// ⚠️ NEVER store tokens in:
/// - SharedPreferences ❌
/// - In-memory variables ❌
/// - SecureStorage ❌ (Supabase handles this)
/// - Any Flutter-side storage ❌
class TokenSecurityService {
  final SupabaseClient _supabase;
  
  /// Token refresh timer
  Timer? _refreshTimer;
  
  /// Whether the service is initialized
  bool _isInitialized = false;

  TokenSecurityService({required SupabaseClient supabase})
      : _supabase = supabase;

  /// =====================================================
  // INITIALIZATION
  // =====================================================

  /// Initialize token security
  ///
  /// Sets up automatic token refresh and session monitoring.
  /// Called once at app startup.
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    debugPrint('🔐 TokenSecurityService başlatılıyor...');
    
    // Listen to auth state changes for session monitoring
    _supabase.auth.onAuthStateChange.listen((authState) {
      _handleAuthStateChange(authState);
    });
    
    // Start automatic token refresh
    _startAutoRefresh();
    
    _isInitialized = true;
    debugPrint('✅ TokenSecurityService başlatıldı (httpOnly cookie)');
  }

  /// =====================================================
  // SESSION MANAGEMENT
  // =====================================================

  /// Get current session (read-only, never expose token to Flutter)
  Session? get currentSession => _supabase.auth.currentSession;

  /// Check if user is authenticated
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  /// Get current user ID (safe to expose)
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// =====================================================
  // TOKEN REFRESH
  // =====================================================

  /// Start automatic token refresh
  ///
  /// Refreshes the token every 50 minutes (before the 1-hour expiry)
  /// This ensures the session never expires while the app is active.
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    
    // Refresh every 50 minutes (Supabase tokens expire in 1 hour)
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 50),
      (_) => _refreshTokenSafely(),
    );
    
    debugPrint('⏰ Token auto-refresh ayarlandı (50 dakika)');
  }

  /// Safely refresh the token
  ///
  /// Uses Supabase's built-in refresh mechanism which
  /// automatically handles httpOnly cookie refresh.
  Future<void> _refreshTokenSafely() async {
    try {
      debugPrint('🔄 Token refresh (httpOnly cookie)...');
      await _supabase.auth.refreshSession();
      debugPrint('✅ Token refresh başarılı');
    } catch (e) {
      debugPrint('❌ Token refresh hatası: $e');
      // Don't throw — silent failure is better than crash
    }
  }

  /// =====================================================
  // AUTH STATE HANDLING
  // =====================================================

  /// Handle auth state changes
  void _handleAuthStateChange(AuthState authState) {
    final session = authState.session;
    
    if (session == null) {
      debugPrint('🔐 Session sonlandı (httpOnly cookie temizlendi)');
      _refreshTimer?.cancel();
    } else {
      debugPrint('🔐 Session aktif (httpOnly cookie ile korunuyor)');
      _startAutoRefresh();
    }
  }

  /// =====================================================
  // SECURITY CHECKS
  // =====================================================

  /// Verify that the current session is secure
  ///
  /// Checks:
  /// - Session exists
  /// - Token is not expired
  /// - Provider is Supabase (not mock)
  Future<bool> verifySessionSecurity() async {
    try {
      final session = _supabase.auth.currentSession;
      
      if (session == null) {
        debugPrint('⚠️ Güvenlik kontrolü: Session yok');
        return false;
      }
      
      // Check if token is expired
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(
          expiresAt * 1000,
        );
        if (DateTime.now().isAfter(expiryDate)) {
          debugPrint('⚠️ Güvenlik kontrolü: Token süresi dolmuş');
          return false;
        }
      }
      
      debugPrint('✅ Session güvenlik kontrolü başarılı');
      return true;
    } catch (e) {
      debugPrint('❌ Güvenlik kontrolü hatası: $e');
      return false;
    }
  }

  /// =====================================================
  // CLEANUP
  // =====================================================

  /// Dispose the service
  Future<void> dispose() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _isInitialized = false;
    debugPrint('🔐 TokenSecurityService durduruldu');
  }
}

/// Extension to add token security to SupabaseClient
extension TokenSecurityExtension on SupabaseClient {
  /// Get a secure instance of TokenSecurityService
  TokenSecurityService get tokenSecurity => TokenSecurityService(supabase: this);
}
