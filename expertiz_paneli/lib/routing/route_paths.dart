/// ROUTE PATHS - GoRouter Path Tanımlamaları
/// 
/// Tüm uygulama route'ları tek bir yerde tanımlanır
library;

/// Route Paths
class RoutePaths {
  // =====================================================
  // PUBLIC ROUTES
  // =====================================================
  
  /// Splash Screen
  static const String splash = '/';
  
  /// Login Screen
  static const String login = '/login';
  
  /// Register Screen
  static const String register = '/register';
  
  // =====================================================
  // ADMIN ROUTES
  // =====================================================
  
  /// Admin Dashboard
  static const String admin = '/admin';
  
  /// Admin Panel
  static const String adminPanel = '/admin/panel';
  
  /// Admin Finans Dashboard
  static const String adminFinans = '/admin/finans';
  
  /// Admin Personel Yönetimi
  static const String adminPersonel = '/admin/personel';
  
  /// Admin Rapor Yönetimi
  static const String adminRaporlar = '/admin/raporlar';
  
  /// Admin Evidence Timeline
  static const String adminEvidenceTimeline = '/admin/evidence-timeline';
  
  // =====================================================
  // PERSONNEL ROUTES
  // =====================================================
  
  /// Personel Dashboard
  static const String personel = '/personel';
  
  /// Personel Panel
  static const String personelPanel = '/personel/panel';
  
  /// Personel Raporlar
  static const String personelRaporlar = '/personel/raporlar';
  
  /// Personel Yeni Rapor
  static const String personelYeniRapor = '/personel/yeni-rapor';
  
  /// Personel Profil
  static const String personelProfil = '/personel/profil';
  
  // =====================================================
  // CUSTOMER ROUTES
  // =====================================================
  
  /// Customer Dashboard
  static const String musteri = '/musteri';
  
  /// Customer Ana Sayfa
  static const String musteriAnaSayfa = '/musteri/ana-sayfa';
  
  /// Customer Raporlarım
  
  /// Customer Talep Oluştur
  static const String musteriTalepOlustur = '/musteri/talep-olustur';
  
  /// Customer Ödeme Sayfası
  static const String musteriOdeme = '/musteri/odeme';
  
  // =====================================================
  // REPORT ROUTES (Dynamic)
  // =====================================================
  
  
  
  
  // =====================================================
  // OTHER ROUTES
  // =====================================================
  
  /// Ana Sayfa (Genel)
  static const String anaSayfa = '/ana-sayfa';
  
  /// Kategori Seçimi
  static const String kategoriSecimi = '/kategori-secimi';
  
  /// Maps Screen
  static const String maps = '/maps';
  
  /// Ayarlar
  static const String ayarlar = '/ayarlar';
  
  /// Profil
  static const String profil = '/profil';
  
  /// Unauthorized Screen
  static const String unauthorized = '/unauthorized';
  
  /// 404 Not Found
  static const String notFound = '/404';
}

/// Route Path Extension for convenience
extension RoutePathsExtension on RoutePaths {
  /// Check if path is admin route
  static bool isAdminRoute(String path) {
    return path.startsWith('/admin');
  }
  
  /// Check if path is personel route
  static bool isPersonelRoute(String path) {
    return path.startsWith('/personel');
  }
  
  /// Check if path is musteri route
  static bool isMusteriRoute(String path) {
    return path.startsWith('/musteri');
  }
  
  /// Check if path is public route
  static bool isPublicRoute(String path) {
    return path == RoutePaths.splash ||
           path == RoutePaths.login ||
           path == RoutePaths.register;
  }
  
  /// Get default redirect route for role
  static String getDefaultRouteForRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return RoutePaths.admin;
      case 'field_staff':
      case 'personel':
        return RoutePaths.personel;
      case 'customer':
      case 'musteri':
        return RoutePaths.musteri;
      default:
        return RoutePaths.login;
    }
  }
}