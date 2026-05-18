/// USER PROVIDER - SINGLE SOURCE OF TRUTH
/// 
/// Tüm uygulama boyunca kullanıcı verisine erişim için tek kaynak
/// Her yerden `context.read<UserProvider>().currentUser` ile erişilir
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../core/permissions/permission_matrix.dart';
import '../core/services/service_orchestrator.dart';

/// User Provider State
class UserProviderState {
  final UserModel? currentUser;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? dashboardStats;

  const UserProviderState({
    this.currentUser,
    this.isLoading = false,
    this.error,
    this.dashboardStats,
  });

  UserProviderState copyWith({
    UserModel? currentUser,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? dashboardStats,
  }) {
    return UserProviderState(
      currentUser: currentUser ?? this.currentUser,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      dashboardStats: dashboardStats ?? this.dashboardStats,
    );
  }

  bool get isAuthenticated => currentUser != null;
  bool get isAdmin => currentUser?.isAdmin ?? false;
  bool get isFieldStaff => currentUser?.isFieldStaff ?? false;
  bool get isCustomer => currentUser?.isCustomer ?? false;
}

/// User Provider
/// 
/// SINGLE SOURCE OF TRUTH for user data
/// 
/// KULLANIM:
/// ```dart
/// // Kullanıcıya eriş
/// final user = context.read<UserProvider>().currentUser;
/// 
/// // Rol kontrolü
/// if (context.read<UserProvider>().isAdmin) {
///   // Admin yetkileri
/// }
/// 
/// // Login
/// await context.read<UserProvider>().login(email, password);
/// 
/// // Logout
/// await context.read<UserProvider>().logout();
/// ```
class UserProvider extends ChangeNotifier {
  final AuthRepository _authRepository;

  UserProviderState _state = const UserProviderState();
  StreamSubscription<AuthState>? _authSub;

  UserProvider({required AuthRepository authRepository})
      : _authRepository = authRepository {
    _initAuthStateListener();
  }

  // =====================================================
  // GETTERS
  // =====================================================

  /// Current authenticated user
  UserModel? get currentUser => _state.currentUser;

  /// Is user authenticated?
  bool get isAuthenticated => _state.isAuthenticated;

  /// Is loading?
  bool get isLoading => _state.isLoading;

  /// Error message
  String? get error => _state.error;

  // =====================================================
  // ROLE GETTERS - Tek kaynak!!!
  // =====================================================

  /// Is current user admin?
  /// 
  /// ⚠️ NON-NEGOTIABLE: BU METODU KULLANIN - başka yere bakmayın!
  /// Magic string kontrolü YASAKTIR.
  bool get isAdmin => _state.isAdmin;

  /// Is current user field staff?
  /// 
  /// ⚠️ NON-NEGOTIABLE: BU METODU KULLANIN - başka yere bakmayın!
  /// Magic string kontrolü YASAKTIR.
  bool get isFieldStaff => _state.isFieldStaff;

  /// Is current user customer?
  /// 
  /// ⚠️ NON-NEGOTIABLE: BU METODU KULLANIN - başka yere bakmayın!
  /// Magic string kontrolü YASAKTIR.
  bool get isCustomer => _state.isCustomer;

  /// @deprecated Use [isFieldStaff] instead.
  @Deprecated('Use isFieldStaff instead')
  bool get isPersonel => _state.currentUser?.isFieldStaff ?? false;

  /// @deprecated Use [isCustomer] instead.
  @Deprecated('Use isCustomer instead')
  bool get isMusteri => _state.currentUser?.isCustomer ?? false;


  /// Get current user ID
  String? get userId => _state.currentUser?.id;

  /// Get current user email
  String? get email => _state.currentUser?.email;

  /// Get current user full name
  String? get fullName => _state.currentUser?.fullName;

  /// Get current user role
  UserRole? get role => _state.currentUser?.role;

  /// Get current user's region ID (for personel)
  int? get bolgeId => _state.currentUser?.bolgeId;

  /// Get current user's province ID (for personel)
  int? get ilId => _state.currentUser?.ilId;

  /// Get current user's permissions
  List<String> get permissions => _state.currentUser?.permissions ?? [];

  // =====================================================
  // PERMISSION METHODS (RBAC)
  // =====================================================

  /// Check if user has specific permission
  /// 
  /// KULLANIM:
  /// ```dart
  /// if (context.read<UserProvider>().can(PermissionMatrix.reportApprove)) {
  ///   // Rapor onaylama işlemi
  /// }
  /// ```
  bool can(String permission) {
    final userPermissions = _state.currentUser?.permissions ?? [];
    return PermissionMatrix.hasPermission(userPermissions, permission);
  }

  /// Check if user has any of the specified permissions
  /// 
  /// KULLANIM:
  /// ```dart
  /// if (context.read<UserProvider>().canAny([
  ///   PermissionMatrix.reportApprove,
  ///   PermissionMatrix.reportReject,
  /// ])) {
  ///   // İşlem yapabilir
  /// }
  /// ```
  bool canAny(List<String> requiredPermissions) {
    final userPermissions = _state.currentUser?.permissions ?? [];
    return PermissionMatrix.hasAnyPermission(userPermissions, requiredPermissions);
  }

  /// Check if user has all of the specified permissions
  /// 
  /// KULLANIM:
  /// ```dart
  /// if (context.read<UserProvider>().canAll([
  ///   PermissionMatrix.userCreate,
  ///   PermissionMatrix.userDelete,
  /// ])) {
  ///   // Tüm işlemleri yapabilir
  /// }
  /// ```
  bool canAll(List<String> requiredPermissions) {
    final userPermissions = _state.currentUser?.permissions ?? [];
    return PermissionMatrix.hasAllPermissions(userPermissions, requiredPermissions);
  }

  // =====================================================
  // ACTIONS
  // =====================================================

  /// Initialize auth state listener
  /// 
  /// ⚠️ SINGLE SOURCE OF TRUTH: Supabase Auth Session
  /// 
  /// KURAL: Flutter UI'daki user state, Supabase session'ının yansımasıdır,
  /// alternatifi değildir.
  /// 
  /// - currentUser asla manuel set edilmez
  /// - Tüm user state → session'dan türetilir
  /// - Login/logout event değil, stream update'tir
  void _initAuthStateListener() {
    // Listen to auth state changes (SYSTEM'S NERVOUS SYSTEM)
    _authSub = _authRepository.authStateChanges.listen((authState) {
      _handleSessionChange(authState.session);
    });

    // Try to load current user on init
    loadCurrentUser();
  }

  /// Handle session change
  /// 
  /// Session'dan user state'i türet
  void _handleSessionChange(dynamic session) {
    if (session == null) {
      // Session yok → user düşür
      debugPrint('🚪 Session yok → unauthenticated');
      _setUnauthenticated();
    } else {
      // Session var → user profilini çek
      debugPrint('✅ Session var → profil çekiliyor...');
      _syncUserFromSession(session);
    }
  }

  /// Set unauthenticated state
  void _setUnauthenticated() {
    _updateState(
      state: _state.copyWith(currentUser: null),
      isLoading: false,
    );
  }

  /// Sync user from session
  Future<void> _syncUserFromSession(dynamic session) async {
    try {
      // Session'dan user ID al
      final userId = session.user?.id;
      if (userId == null) {
        _setUnauthenticated();
        return;
      }

      // Profil verisini çek
      final result = await _authRepository.getCurrentUser();

      if (result.isSuccess && result.user != null) {
        _updateState(
          state: _state.copyWith(currentUser: result.user),
          isLoading: false,
        );
        debugPrint('✅ User sync\'landı: ${result.user!.fullName}');
      } else {
        // Profil çekilemedi → logout
        _setUnauthenticated();
        debugPrint('⚠️ Profil çekilemedi → unauthenticated');
      }
    } catch (e) {
      debugPrint('❌ Session sync hatası: $e');
      _setUnauthenticated();
    }
  }

  /// Load current user from session
  Future<void> loadCurrentUser() async {
    if (!_authRepository.isAuthenticated()) {
      _updateState(state: _state.copyWith(currentUser: null));
      return;
    }

    _updateState(isLoading: true);

    try {
      final result = await _authRepository.getCurrentUser();

      if (result.isSuccess && result.user != null) {
        _updateState(
          state: _state.copyWith(currentUser: result.user),
          isLoading: false,
        );
      } else {
        _updateState(
          state: _state.copyWith(currentUser: null),
          isLoading: false,
          error: result.error,
        );
      }
    } catch (e) {
      _updateState(
        state: _state.copyWith(currentUser: null),
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Login with email and password
  /// 
  /// Returns true if successful
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _updateState(isLoading: true, error: null);

    try {
      debugPrint('🔄 Login başlatılıyor: $email');

      final result = await _authRepository.signIn(
        email: email,
        password: password,
      );

      if (result.isSuccess && result.user != null) {
        _updateState(
          state: _state.copyWith(currentUser: result.user),
          isLoading: false,
        );

        debugPrint('✅ Login başarılı: ${result.user!.fullName}');
        return true;
      } else {
        _updateState(
          isLoading: false,
          error: result.error ?? 'Login başarısız',
        );

        debugPrint('❌ Login başarısız: ${result.error}');
        return false;
      }
    } catch (e) {
      _updateState(
        isLoading: false,
        error: e.toString(),
      );

      debugPrint('❌ Login hatası: $e');
      return false;
    }
  }

  Future<bool> registerCustomer({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    _updateState(isLoading: true, error: null);

    try {
      final result = await _authRepository.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );

      if (result.isSuccess && result.user != null) {
        _updateState(
          state: _state.copyWith(currentUser: result.user),
          isLoading: false,
        );
        return true;
      }

      _updateState(
        isLoading: false,
        error: result.error ?? 'Kayit basarisiz',
      );
      return false;
    } catch (e) {
      _updateState(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Logout current user
  /// 
  /// ⚠️ ATOMIC LOGOUT: Sistem olayı, UI olayı değil
  /// 
  /// Logout → sadece UI değil, tüm sistem durur
  Future<void> logout() async {
    try {
      debugPrint('💀 Atomic logout başlatılıyor...');

      // Atomic logout - tüm sistemi durdur
      await _authRepository.atomicLogout();

      // UserProvider state auth stream'den güncellenecek
      // Manuel update YAPMIYORUZ!

      debugPrint('✅ Atomic logout tamamlandı');
    } catch (e) {
      debugPrint('❌ Logout hatası: $e');
      rethrow;
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
    int? bolgeId,
    int? ilId,
    String? department,
    String? position,
    String? expertise,
  }) async {
    if (_state.currentUser == null) {
      _updateState(error: 'Oturum açılmadı');
      return false;
    }

    _updateState(isLoading: true);

    try {
      final result = await _authRepository.updateProfile(
        userId: _state.currentUser!.id,
        fullName: fullName,
        phone: phone,
        avatarUrl: avatarUrl,
        bolgeId: bolgeId,
        ilId: ilId,
        department: department,
        position: position,
        expertise: expertise,
      );

      if (result.isSuccess && result.user != null) {
        _updateState(
          state: _state.copyWith(currentUser: result.user),
          isLoading: false,
        );

        debugPrint('✅ Profil güncellendi');
        return true;
      } else {
        _updateState(
          isLoading: false,
          error: result.error ?? 'Profil güncelleme başarısız',
        );

        debugPrint('❌ Profil güncelleme başarısız: ${result.error}');
        return false;
      }
    } catch (e) {
      _updateState(
        isLoading: false,
        error: e.toString(),
      );

      debugPrint('❌ Profil güncelleme hatası: $e');
      return false;
    }
  }

  /// Check if user has specific role
  bool hasRole(UserRole role) {
    return _state.currentUser?.role == role;
  }

  /// Clear error
  void clearError() {
    _updateState(error: null);
  }

  // =====================================================
  // DASHBOARD TRUTH LAYER (FAZ-0.6)
  // =====================================================

  /// Dashboard metrikleri getter
  Map<String, dynamic>? get dashboardStats => _state.dashboardStats;

  /// Admin dashboard metriklerini RPC'den çek
  /// 
  /// ⚠️ SINGLE SOURCE OF TRUTH: Supabase RPC
  /// Dashboard numbers must NEVER be calculated in Flutter.
  /// 
  /// 🛡️ EVIDENCE-GRADE: Tüm metrikler veritabanından gelir
  /// 🛡️ FLOOD PROTECTION: 10 request/dakika limiti
  /// 🛡️ AUDIT LOG: Her fetch auditlenir
  Future<void> fetchDashboardMetrics() async {
    // Only for authenticated admins
    if (!isAuthenticated || !isAdmin) {
      debugPrint('⚠️ Dashboard metrikleri sadece admin için');
      return;
    }

    try {
      debugPrint('📊 Dashboard metrikleri RPC\'den çekiliyor (evidence-grade)...');

      final supabase = Supabase.instance.client;
      
      // Service orchestrator'dan beklenen servis sayısı
      final orchestrator = ServiceOrchestrator();
      final expectedServices = orchestrator.serviceCount;

      final response = await supabase.rpc(
        'get_admin_dashboard_stats',
        params: {
          'p_user_id': userId,
          'p_expected_services': expectedServices > 0 ? expectedServices : 3,
        },
      );

      if (response != null) {
        final stats = Map<String, dynamic>.from(response);

        // NOT: Service orchestrator servis sayıları RPC'den geliyor
        // Flutter'da HESAPLAMA YAPMIYORUZ

        _updateState(
          state: _state.copyWith(dashboardStats: stats),
        );

        debugPrint('✅ Dashboard metrikleri güncellendi (audit_id: ${stats['audit_id']})');
      }
    } catch (e) {
      debugPrint('❌ Dashboard metrikleri hatası: $e');
      // Flood protection hatası olabilir
      if (e.toString().contains('Too many dashboard requests')) {
        debugPrint('⚠️ Dashboard flood protection aktif - lütfen bekleyin');
      }
      // Hatayı state'e koyma, sadece logla
    }
  }

  /// System pulse dinle
  /// 
  /// Realtime streams are triggers only, never data sources.
  /// Dashboard update trigger geldiğinde metrikleri yeniden çek.
  RealtimeChannel? _systemPulseSubscription;

  Future<void> listenToSystemPulse() async {
    // Only for authenticated admins
    if (!isAuthenticated || !isAdmin) {
      debugPrint('⚠️ System pulse sadece admin için');
      return;
    }

    // Önceki subscription'ı temizle
    await _systemPulseSubscription?.unsubscribe();
    _systemPulseSubscription = null;

    try {
      debugPrint('🔄 System pulse dinleniyor...');

      final supabase = Supabase.instance.client;

      // reports tablosunu dinle (trigger)
      _systemPulseSubscription = supabase
          .channel('dashboard_pulse')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reports',
            callback: (payload) {
              debugPrint('📡 Dashboard update trigger alındı');
              // Trigger → metrikleri yeniden çek
              fetchDashboardMetrics();
            },
          )
          .subscribe();

      debugPrint('✅ System pulse dinleniyor');
    } catch (e) {
      debugPrint('❌ System pulse hatası: $e');
    }
  }

  /// System pulse dinlemeyi durdur
  Future<void> stopListeningToSystemPulse() async {
    await _systemPulseSubscription?.unsubscribe();
    _systemPulseSubscription = null;
    debugPrint('⏹️ System pulse durduruldu');
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    // System pulse subscription'ı temizle
    stopListeningToSystemPulse();
    _authSub?.cancel();
    super.dispose();
  }

  // =====================================================
  // PRIVATE METHODS
  // =====================================================

  void _updateState({
    UserProviderState? state,
    bool? isLoading,
    String? error,
  }) {
    if (state != null) {
      _state = state;
    } else {
      _state = _state.copyWith(
        isLoading: isLoading,
        error: error,
      );
    }
    notifyListeners();
  }

  @override
  String toString() {
    return 'UserProvider(currentUser: ${_state.currentUser?.fullName}, isAuthenticated: $isAuthenticated)';
  }
}

/// Convenience extension for UserProvider
extension UserProviderExtension on UserProvider {
  /// Get display name
  String get displayName => _state.currentUser?.displayName ?? 'Misafir';

  /// Get initials for avatar
  String get initials => _state.currentUser?.initials ?? 'M';
}
