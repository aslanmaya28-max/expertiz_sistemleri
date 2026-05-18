/// MAIN ENTRY POINT - EXPERTIZ SISTEMI
///
/// ⚠️ SINGLE SOURCE OF TRUTH: UserProvider
/// AuthServicePro TAMAMEN KALDIRILDI - AuthRepository + UserProvider kullanılır
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart' as sharing;

import 'core/theme/futuristic_theme.dart';
import 'core/services/service_orchestrator.dart';
import 'core/lifecycle/app_lifecycle_observer.dart';
import 'providers/theme_provider.dart';
import 'services/shared_listing_intake_service.dart';

import 'providers/clock_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/user_provider.dart';
import 'controllers/app_menu_controller.dart';
import 'services/personel_service.dart';
import 'services/rapor_service.dart';
import 'services/vision_engine_service.dart';
import 'services/shared_preferences_manager.dart';
import 'repositories/auth_repository.dart';
import 'admin/admin_dashboard.dart';
import 'personnel/personnel_dashboard.dart';
import 'customer/customer_dashboard.dart';
import 'screens/login_screen.dart';
import 'widgets/auth_wrapper.dart';
import 'routing/app_router.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferencesManager.init();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'YOUR_SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
      defaultValue: 'YOUR_SUPABASE_ANON_KEY');

  // 🔒 DÜZELTİLDİ (B13): Placeholder credentials ile crash önlendi.
  if (supabaseUrl == 'YOUR_SUPABASE_URL' ||
      supabaseAnonKey == 'YOUR_SUPABASE_ANON_KEY') {
    debugPrint('''
    ============================================================
    KRITIK UYARI: Supabase credentials placeholder!
    Uygulama baslatilamiyor.
    Calistirmak icin:
      flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
    ============================================================
    ''');
    // 🔒 Placeholder ile crash verme, dummy credentials ile devam etme
    // Gerçek deployment'ta --dart-define zorunludur.
    runApp(const ProviderScope(child: _ConfigErrorApp()));
    return;
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  RaporService.initSupabase(Supabase.instance.client);

  final authRepository =
      AuthRepository(supabase: Supabase.instance.client);
  final orchestrator = ServiceOrchestrator();

  orchestrator.registerService(VisionEngineService());
  orchestrator.init(authRepository);

  final lifecycleHandler =
      AppLifecycleHandler(authRepository: authRepository);
  WidgetsBinding.instance.addObserver(lifecycleHandler);

  // Mobil paylasim intent listener'ini baslat
  _initShareListener(authRepository);

  runApp(const ProviderScope(child: ExpertizSistemiApp()));

}

/// Mobil paylasim intent'lerini dinler ve ilan analiz kuyruguna yonlendirir.
void _initShareListener(AuthRepository authRepository) {
  // Platform tarafindan paylasilan metinleri dinle
  sharing.ReceiveSharingIntent.instance.getMediaStream().listen((List<sharing.SharedMediaFile> value) {
    _handleSharedContent(value, authRepository);
  }, onError: (Object error) {
    debugPrint('Share listener hatasi: $error');
  });

  // Uygulama kapaliyken gelen paylasimlari da isle
  sharing.ReceiveSharingIntent.instance.getInitialMedia().then((List<sharing.SharedMediaFile> value) {
    _handleSharedContent(value, authRepository);
  });
}

/// Paylasilan medya dosyalarindan URL cikarir ve analiz kuyruguna ekler.
void _handleSharedContent(List<sharing.SharedMediaFile> files, AuthRepository authRepository) async {
  for (final file in files) {
    final text = file.content;
    if (text != null && text.isNotEmpty && (text.startsWith('http://') || text.startsWith('https://'))) {
      debugPrint('Paylasilan URL yakalandi: $text');

      // Kullanici auth token'ini al
      String? token;
      try {
        final session = authRepository.currentSession;
        token = session?.accessToken;
      } catch (e) {
        debugPrint('Auth token alinamadi (muhtemelen giris yapilmamis): $e');
      }


      if (token != null) {
        await SharedListingIntakeService.submitSharedUrl(
          rawText: text,
          authToken: token,
        );
        debugPrint('URL analiz kuyruguna eklendi: $text');
      } else {
        debugPrint('Kullanici giris yapmamis, paylasim atlandi: $text');
      }
    }
  }
}

/// 🔒 DÜZELTİLDİ (B13): Config hatası durumunda gösterilecek basit uygulama

class _ConfigErrorApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'YerimeBak - Config Hatası',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Supabase Yapılandırması Eksik',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Lütfen --dart-define ile SUPABASE_URL ve SUPABASE_ANON_KEY parametrelerini sağlayın.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ExpertizSistemiApp extends StatelessWidget {

  const ExpertizSistemiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository =
        AuthRepository(supabase: Supabase.instance.client);

    return legacy_provider.MultiProvider(
      providers: [
        legacy_provider.ChangeNotifierProvider(
            create: (_) => ThemeProvider()),
        legacy_provider.ChangeNotifierProvider(
            create: (_) => ClockProvider()),
        legacy_provider.ChangeNotifierProvider(
            create: (_) => AppMenuController()),
        legacy_provider.ChangeNotifierProvider(
            create: (_) => PersonelService()),
        legacy_provider.ChangeNotifierProvider(
            create: (_) => AdminProvider()..init()),
        // SINGLE SOURCE OF TRUTH - UserProvider
        legacy_provider.ChangeNotifierProvider(
            create: (_) => UserProvider(authRepository: authRepository)),
      ],
      child: legacy_provider.Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          // 🔒 DÜZELTİLDİ (B11): GoRouter bağlandı — MaterialApp.router() kullanılıyor.
          // Artık kullanıcılar URL'ye /admin_dashboard yazarak direkt admin paneline erişemez.
          // GoRouter route lockdown ile tüm route'lar korunur.
          return MaterialApp.router(
            title: 'YerimeBak Sistemleri',
            debugShowCheckedModeBanner: false,
            theme: FuturisticTheme.theme,
            darkTheme: FuturisticTheme.theme,
            themeMode: themeProvider.themeMode,
            routerConfig: createRouter(context),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('tr', 'TR'),
              Locale('en', 'US'),
            ],
          );
        },
      ),

    );
  }
}
