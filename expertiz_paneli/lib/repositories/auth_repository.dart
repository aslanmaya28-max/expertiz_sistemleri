/// AUTH REPOSITORY - SUPABASE AUTH + PROFILES
/// 
/// Single Source of Truth for authentication operations
/// Handles Supabase Auth signIn/signOut and profiles table queries
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/central_auth_client.dart';

/// Authentication Result
class AuthResult {
  final bool isSuccess;
  final UserModel? user;
  final String? error;

  const AuthResult({
    required this.isSuccess,
    this.user,
    this.error,
  });

  factory AuthResult.success(UserModel user) {
    return AuthResult(
      isSuccess: true,
      user: user,
    );
  }

  factory AuthResult.failure(String error) {
    return AuthResult(
      isSuccess: false,
      error: error,
    );
  }
}

/// Auth Repository
/// 
/// Tüm authentication işlemlerini yönetir:
/// - Supabase Auth signIn/signOut
/// - Profiles tablosundan kullanıcı verisi çekme
/// - Role-based access control
class AuthRepository {
  final SupabaseClient _supabase;
  final CentralAuthClient _centralAuthClient;
  String? _centralAccessToken;

  AuthRepository({
    required SupabaseClient supabase,
    CentralAuthClient? centralAuthClient,
  })  : _supabase = supabase,
        _centralAuthClient = centralAuthClient ?? CentralAuthClient();

  String? get centralAccessToken => _centralAccessToken;

  /// =====================================================
  // SIGN IN
  // =====================================================

  /// Login with email and password
  /// 
  /// Returns AuthResult with UserModel if successful
  /// Automatically fetches profile from profiles table
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔄 Sign in başlatılıyor: $email');

      final centralSession = await _centralAuthClient.login(
        email: email,
        password: password,
      );
      _centralAccessToken = centralSession.token;
      CentralAuthTokenStore.accessToken = centralSession.token;
      return AuthResult.success(centralSession.user);

    } on AuthException catch (e) {
      debugPrint('❌ Auth hatası: ${e.message}');
      return AuthResult.failure(e.message);
    } catch (e) {
      debugPrint('❌ Sign in hatası: $e');
      return AuthResult.failure(e.toString());
    }
  }

  /// =====================================================
  // SIGN OUT
  // =====================================================

  /// Logout current user
  Future<void> signOut() async {
    try {
      debugPrint('🔄 Sign out başlatılıyor...');
      _centralAccessToken = null;
      CentralAuthTokenStore.accessToken = null;
      await _supabase.auth.signOut();
      debugPrint('✅ Sign out başarılı');
    } catch (e) {
      debugPrint('❌ Sign out hatası: $e');
      rethrow;
    }
  }

  /// =====================================================
  // GET USER PROFILE
  // =====================================================

  /// Get current authenticated user profile
  /// 
  /// Fetches from profiles table using auth session
  Future<AuthResult> getCurrentUser() async {
    try {
      final centralToken = _centralAccessToken ?? CentralAuthTokenStore.accessToken;
      if (centralToken != null) {
        _centralAccessToken = centralToken;
        try {
          final user = await _centralAuthClient.me(centralToken);
          return AuthResult.success(user);
        } catch (e) {
          // Suresi dolmus / gecersiz oturum: saklanan anahtar silinir, giris ekranina donulur
          _centralAccessToken = null;
          CentralAuthTokenStore.clear();
          return AuthResult.failure('Oturumunuzun süresi doldu, lütfen tekrar giriş yapın');
        }
      }

      // 1. Check if user is logged in
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return AuthResult.failure('Oturum açılmadı');
      }

      // 2. Get profile from profiles table
      final profileResult = await _getUserProfile(currentUser.id);

      if (!profileResult.isSuccess) {
        return AuthResult.failure(profileResult.error!);
      }

      return AuthResult.success(profileResult.user!);
    } catch (e) {
      debugPrint('❌ Get current user hatası: $e');
      return AuthResult.failure(e.toString());
    }
  }

  /// Get user profile from profiles table
  Future<AuthResult> _getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      // Check if profile is active
      if (response['is_active'] == false ||
          response['aktif'] == false ||
          response['aktif_mi'] == false) {
        return AuthResult.failure('Hesap pasif durumda');
      }

      final user = UserModel.fromJson(response);
      return AuthResult.success(user);
    } catch (e) {
      debugPrint('❌ Get user profile hatası: $e');
      return AuthResult.failure('Profil bulunamadı: $e');
    }
  }

  /// =====================================================
  // SESSION MANAGEMENT
  // =====================================================

  /// Check if user is authenticated
  bool isAuthenticated() {
    return _centralAccessToken != null ||
        CentralAuthTokenStore.accessToken != null ||
        _supabase.auth.currentUser != null;
  }

  /// Get current user ID
  String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  /// Get current user email
  String? getCurrentUserEmail() {
    return _supabase.auth.currentUser?.email;
  }

  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final centralSession = await _centralAuthClient.registerCustomer(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      _centralAccessToken = centralSession.token;
      CentralAuthTokenStore.accessToken = centralSession.token;
      return AuthResult.success(centralSession.user);
    } catch (e) {
      debugPrint('Sign up failed: $e');
      return AuthResult.failure(e.toString());
    }
  }

  /// =====================================================
  // ROLE CHECKS
  // =====================================================

  /// Check if current user is admin
  Future<bool> isAdmin() async {
    final result = await getCurrentUser();
    return result.user?.isAdmin ?? false;
  }

  /// Check if current user is field staff
  Future<bool> isFieldStaff() async {
    final result = await getCurrentUser();
    return result.user?.isFieldStaff ?? false;
  }

  /// Check if current user is customer
  Future<bool> isCustomer() async {
    final result = await getCurrentUser();
    return result.user?.isCustomer ?? false;
  }

  /// Check if current user has specific role
  Future<bool> hasRole(UserRole role) async {
    final result = await getCurrentUser();
    return result.user?.role == role;
  }

  /// =====================================================
  // PROFILE UPDATE
  // =====================================================

  /// Update user profile
  Future<AuthResult> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? avatarUrl,
    int? bolgeId,
    int? ilId,
    String? department,
    String? position,
    String? expertise,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (fullName != null) updates['full_name'] = fullName;
      if (phone != null) updates['phone'] = phone;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (bolgeId != null) updates['bolge_id'] = bolgeId;
      if (ilId != null) updates['il_id'] = ilId;
      if (department != null) updates['department'] = department;
      if (position != null) updates['position'] = position;
      if (expertise != null) updates['expertise'] = expertise;

      updates['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId);

      // Fetch updated profile
      final profileResult = await _getUserProfile(userId);

      if (!profileResult.isSuccess) {
        return AuthResult.failure('Profil güncellendi ama alınamadı');
      }

      return AuthResult.success(profileResult.user!);
    } catch (e) {
      debugPrint('❌ Update profile hatası: $e');
      return AuthResult.failure(e.toString());
    }
  }

  /// =====================================================
  // AUTH STATE CHANGES
  // =====================================================

  /// Stream auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  /// =====================================================
  // TOKEN REFRESH & RACE CONDITION PREVENTION
  // =====================================================

  /// Token refresh mutex - Race condition koruması
  bool _isRefreshing = false;
  Completer<void>? _refreshCompleter;

  /// Safely refresh session with mutex lock
  /// 
  /// Aynı anda gelen 401/API çağrılarında:
  /// - Tek bir refresh
  /// - Diğerleri bekler
  /// - Router panic yapmaz
  Future<void> refreshSessionSafely() async {
    // Eğer zaten refresh yapılıyorsa, bitmesini bekle
    if (_isRefreshing) {
      debugPrint('⏳ Token refresh zaten devam ediyor, bekleniyor...');
      return _refreshCompleter?.future;
    }

    // Refresh başlat
    _isRefreshing = true;
    _refreshCompleter = Completer<void>();

    try {
      debugPrint('🔄 Token refresh başlatılıyor...');
      await _supabase.auth.refreshSession();
      debugPrint('✅ Token refresh başarılı');
      _refreshCompleter?.complete();
    } catch (e) {
      debugPrint('❌ Token refresh hatası: $e');
      _refreshCompleter?.completeError(e);
      rethrow;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  /// =====================================================
  // SILENT SESSION CHECK (Background → Resume)
  // =====================================================

  /// Silent session check for app resume
  /// 
  /// Kullanıcı app'i arka plana attı → geri geldi
  /// Session düşmüş olabilir
  /// 
  /// Özellikler:
  /// - UI'ye yansımaz
  /// - Splash'a atmaz
  /// - Gerekirse token refresh
  /// - Session yoksa UserProvider zaten düşer
  Future<void> silentSessionCheck() async {
    try {
      debugPrint('🔕 Silent session check başlatılıyor...');
      
      final session = _supabase.auth.currentSession;
      
      if (session == null) {
        debugPrint('⚠️ Session yok, UserProvider düşürecek');
        // UserProvider auth state change'den haberdar olacak
        return;
      }

      // Session varsa, token'ı refresh et
      debugPrint('✅ Session mevcut, token refresh yapılıyor...');
      await refreshSessionSafely();
      
      debugPrint('✅ Silent session check tamamlandı');
    } catch (e) {
      debugPrint('❌ Silent session check hatası: $e');
      // Hata olsa bile UI'ya yansıtma
    }
  }

  /// =====================================================
  // ATOMIC LOGOUT (TOPLU İMHA)
  // =====================================================

  /// Atomic logout - tüm sistemi durdur
  /// 
  /// Logout → sadece UI değil, tüm sistem durur
  /// - Vision Service
  /// - Ledger Service
  /// - Background Collectors
  /// - Supabase Auth
  Future<void> atomicLogout() async {
    try {
      debugPrint('💀 Atomic logout başlatılıyor...');

      // 1. Tüm servisleri durdur (Future.wait ile paralel)
      debugPrint('🛑 Servisler durduruluyor...');
      await Future.wait([
        // TODO: Servisleri durdur
        // VisionEngineService().stop(),
        // AuditService().flush(),
        // BackgroundCollectors().cancelAll(),
      ]);

      // 2. Supabase Auth logout
      debugPrint('🚪 Supabase auth signOut...');
      _centralAccessToken = null;
      CentralAuthTokenStore.accessToken = null;
      await _supabase.auth.signOut();

      debugPrint('✅ Atomic logout tamamlandı');
    } catch (e) {
      debugPrint('❌ Atomic logout hatası: $e');
      rethrow;
    }
  }
}
