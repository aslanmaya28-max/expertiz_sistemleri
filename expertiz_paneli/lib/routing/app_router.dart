/// APP ROUTER - GoRouter Configuration
/// 
/// Tüm uygulama routing konfigürasyonu
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/ana_sayfa.dart';
import '../admin/admin_shell.dart';
import '../admin/modules/finans_yonetimi.dart';
import '../personnel/personnel_dashboard.dart';
import '../customer/customer_dashboard.dart';
import '../customer/create_request_screen.dart';
import '../customer/report_upload_screen.dart';
import '../screens/rapor_detay_sayfasi.dart';
import '../screens/kategori_secimi.dart';
import '../screens/maps_screen.dart';
import '../screens/error_screen.dart';
import 'route_paths.dart';

/// Create GoRouter
/// 
/// ⚠️ ROUTE LOCKDOWN: Router İLK GÜVENLİK DUVARI
/// 
/// Bu router:
/// - Yetkisiz kullanıcıların admin UI'ye erişimini ENGELLER
/// - Auth state değişikliklerine otomatik tepki verir
/// - Circular redirect'i önler
/// - Loading state'i sırasında redirect yapmaz
/// 
/// Kullanımı:
/// ```dart
/// MaterialApp.router(
///   routerConfig: createRouter(context),
/// )
/// ```
GoRouter createRouter(BuildContext context) {
  // Get UserProvider for reactive routing
  final userProvider = Provider.of<UserProvider>(context, listen: false);
  
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: RoutePaths.splash,
    
    // ===================================================
    // ⚡ REACTIVE ROUTER - Auth state değişikliklerine anında tepki
    // ===================================================
    refreshListenable: userProvider,
    
    // ===================================================
    // 🔒 ROUTE LOCKDOWN - GLOBAL REDIRECT GUARD
    // ===================================================
    /// ⚠️ NON-NEGOTIABLE: Bu mantık birebir uygulanmalı
    /// 
    /// KORUMALAR:
    /// 1. Circular redirect koruması
    /// 2. Loading state koruması
    /// 3. Admin area role guard
    redirect: (context, state) {
      // SINGLE SOURCE OF TRUTH: UserProvider
      final userProvider = context.read<UserProvider>();
      final user = userProvider.currentUser;
      final bool isLoading = userProvider.isLoading;
      final bool isAdminPage = state.matchedLocation.startsWith('/admin');
      final String currentLocation = state.matchedLocation;

      // 🛡️ 0. CIRCULAR REDIRECT KORUMASI (KRİTİK!)
      // Eğer kullanıcı zaten /unauthorized'da, tekrar redirect etme
      // Bu, sonsuz redirect döngüsünü önler
      if (currentLocation == RoutePaths.unauthorized) {
        debugPrint('🛡️ Circular redirect koruması: /unauthorized route\'unda kalınıyor');
        return null;
      }

      // 🛡️ 1. LOADING STATE KORUMASI (KRİTİK!)
      // Auth henüz Supabase'den gelmemiş olabilir.
      // Loading sırasında HİÇBİR redirect yapma.
      // Splash/boş ekran korunur.
      if (isLoading) {
        debugPrint('⏳ Auth loading: $currentLocation korunuyor');
        return null;
      }

      // 🛡️ 2. ADMIN AREA ROLE GUARD (KRİTİK!)
      // Admin UI'ye sadece admin kullanıcılar girebilir
      // Admin olmayan kullanıcı ASLA admin panelini GÖREMEZ
      if (isAdminPage) {
        if (user == null) {
          debugPrint('🚫 Admin area koruması: Kullanıcı giriş yapmamış -> /unauthorized');
          return RoutePaths.unauthorized;
        }
        
        if (user.role != UserRole.admin) {
          final userRole = user.role.toString();
          debugPrint('🚫 Admin area koruması: Yetkisiz rol ($userRole) -> /unauthorized');
          return RoutePaths.unauthorized;
        }
        
        debugPrint('✅ Admin area erişimi izni verildi: ${user.fullName}');
      }

      // 🟢 3. YOL AÇIK
      debugPrint('✅ Route güvenliği OK: $currentLocation');
      return null;
    },
    
    // ===================================================
    // ROUTES
    // ===================================================
    routes: [
      // =================================================
      // PUBLIC ROUTES
      // =================================================
      
      GoRoute(
        path: RoutePaths.splash,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: SplashScreen(),
        ),
      ),
      
      GoRoute(
        path: RoutePaths.login,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: LoginScreen(),
        ),
      ),
      
      GoRoute(
        path: RoutePaths.register,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: RegisterScreen(),
        ),
      ),
      
      // =================================================
      // ADMIN ROUTES
      // =================================================
      
      GoRoute(
        path: RoutePaths.admin,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: AdminShell(),
        ),
        routes: [
          GoRoute(
            path: 'panel',
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: AdminShell(),
            ),
          ),
          GoRoute(
            path: 'finans',
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: const Scaffold(body: SafeArea(child: FinansYonetimi())),
            ),
          ),
          GoRoute(
            path: 'personel',
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: PersonelManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'raporlar',
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: AdminRaporlarScreen(),
            ),
          ),
        ],
      ),
      
      // =================================================
      // PERSONNEL ROUTES
      // =================================================
      
      GoRoute(
        path: RoutePaths.personel,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: PersonnelDashboard(),
        ),
        routes: [
          GoRoute(
            path: 'panel',
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: PersonnelDashboard(),
            ),
          ),
          GoRoute(
            path: 'raporlar',
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: PersonelRaporlarScreen(),
            ),
          ),
      GoRoute(
        path: 'yeni-rapor',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: KategoriSecimiSayfasi(),
        ),
      ),
          GoRoute(
            path: 'profil',
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: PersonelProfilScreen(),
            ),
          ),
        ],
      ),
      
      // =================================================
      // CUSTOMER ROUTES
      // =================================================
      
      GoRoute(
        path: RoutePaths.musteri,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: CustomerDashboard(),
        ),
        routes: [
          GoRoute(
            path: 'ana-sayfa',
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: CustomerDashboard(),
            ),
          ),
          GoRoute(
            path: 'raporlarim',
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: ReportUploadScreen(),
            ),
          ),
          GoRoute(
            path: 'talep-olustur',
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: CreateRequestScreen(),
            ),
          ),
          // Payment route - placeholder for future implementation
          // GoRoute(
          //   path: 'odeme',
          //   pageBuilder: (context, state) {
          //     TODO: Implement payment screen in customer module
          //   },
          // ),
        ],
      ),
      
      // =================================================
      // REPORT ROUTES (Dynamic)
      // =================================================
      
      GoRoute(
        path: '/rapor/:reportId',
        pageBuilder: (context, state) {
          // Raporu Supabase'den yükle
          // TODO: Implement report loading from Supabase
          
          final reportId = state.pathParameters['reportId'] ?? '';
          
          return MaterialPage(
            key: state.pageKey,
            child: RaporDetaySayfasi(
              reportId: reportId,
              rapor: null, // Will be loaded from Supabase
            ),
          );
        },
        routes: [
          GoRoute(
            path: 'duzenle',
            pageBuilder: (context, state) {
              final reportId = state.pathParameters['reportId'] ?? '';
              return MaterialPage(
                key: state.pageKey,
                child: RaporDuzenleScreen(reportId: reportId),
              );
            },
          ),
          GoRoute(
            path: 'onay',
            pageBuilder: (context, state) {
              final reportId = state.pathParameters['reportId'] ?? '';
              return MaterialPage(
                key: state.pageKey,
                child: RaporOnayScreen(reportId: reportId),
              );
            },
          ),
        ],
      ),
      
      // =================================================
      // OTHER ROUTES
      // =================================================
      
      GoRoute(
        path: RoutePaths.anaSayfa,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: AnaSayfa(),
        ),
      ),
      
      GoRoute(
        path: RoutePaths.kategoriSecimi,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: KategoriSecimiSayfasi(),
        ),
      ),
      
      GoRoute(
        path: RoutePaths.maps,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: MapsScreen(),
        ),
      ),
      
      GoRoute(
        path: RoutePaths.unauthorized,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: UnauthorizedScreen(),
        ),
      ),
    ],
    
    // ===================================================
    // ERROR PAGE - Neon Temalı ErrorScreen
    // ===================================================
    errorPageBuilder: (context, state) {
      return MaterialPage(
        key: state.pageKey,
        child: ErrorScreen(
          error: state.error?.toString() ?? 'Bilinmeyen bir hata oluştu',
          details: state.error.toString(),
        ),
      );
    },
  );
}

/// Placeholder screens (gerekirse gerçek ekranlarla değiştirin)
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Yükleniyor...'),
          ],
        ),
      ),
    );
  }
}

class PersonelManagementScreen extends StatelessWidget {
  const PersonelManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Personel Yönetimi')),
      body: Center(child: Text('Personel Yönetimi - Coming Soon')),
    );
  }
}

class AdminRaporlarScreen extends StatelessWidget {
  const AdminRaporlarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rapor Yönetimi')),
      body: Center(child: Text('Rapor Yönetimi - Coming Soon')),
    );
  }
}

class PersonelRaporlarScreen extends StatelessWidget {
  const PersonelRaporlarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Raporlarım')),
      body: Center(child: Text('Raporlarım - Coming Soon')),
    );
  }
}

class PersonelProfilScreen extends StatelessWidget {
  const PersonelProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profilim')),
      body: Center(child: Text('Profilim - Coming Soon')),
    );
  }
}

class RaporDuzenleScreen extends StatelessWidget {
  final String reportId;
  
  const RaporDuzenleScreen({super.key, required this.reportId});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rapor Düzenle')),
      body: Center(child: Text('Rapor Düzenle: $reportId')),
    );
  }
}

class RaporOnayScreen extends StatelessWidget {
  final String reportId;
  
  const RaporOnayScreen({super.key, required this.reportId});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rapor Onay')),
      body: Center(child: Text('Rapor Onay: $reportId')),
    );
  }
}

/// Unauthorized Screen - Neon Temalı
class UnauthorizedScreen extends StatelessWidget {
  const UnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0E27), // Neon dark blue
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Neon Icon
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.lock_outline,
                size: 80,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 30),
            
            // Neon Text
            Text(
              'YETKİSİZ ERİŞİM',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.red.withValues(alpha: 0.8),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Bu sayfaya erişim yetkiniz yok.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
            ),
            SizedBox(height: 40),
            
            // Back Button - Neon style
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade700],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => context.go(RoutePaths.login),
                icon: Icon(Icons.arrow_back),
                label: Text('Giriş Sayfasına Dön'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 404 Not Found Screen
class NotFoundScreen extends StatelessWidget {
  final Exception? error;
  
  const NotFoundScreen({super.key, this.error});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0E27),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.orange,
            ),
            SizedBox(height: 20),
            Text(
              '404',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Sayfa Bulunamadı',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => context.go(RoutePaths.splash),
              child: Text('Ana Sayfaya Dön'),
            ),
          ],
        ),
      ),
    );
  }
}