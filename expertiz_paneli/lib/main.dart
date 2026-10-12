/// MAIN ENTRY POINT - EXPERTIZ SISTEMI
///
/// ⚠️ SINGLE SOURCE OF TRUTH: UserProvider
/// AuthServicePro TAMAMEN KALDIRILDI - AuthRepository + UserProvider kullanılır
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/futuristic_theme.dart';
import 'core/services/service_orchestrator.dart';
import 'core/lifecycle/app_lifecycle_observer.dart';
import 'providers/theme_provider.dart';
import 'providers/clock_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/user_provider.dart';
import 'controllers/app_menu_controller.dart';
import 'services/personel_service.dart';
import 'services/rapor_service.dart';
import 'services/vision_engine_service.dart';
import 'services/shared_preferences_manager.dart';
import 'services/central_auth_client.dart';
import 'repositories/auth_repository.dart';
import 'routing/app_router.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferencesManager.init();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'YOUR_SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
      defaultValue: 'YOUR_SUPABASE_ANON_KEY');

  // Admin ve personel ekranlari merkezi API'yi (YERIMEBAK_API_BASE_URL) kullanir;
  // Supabase yalnizca eski musteri ekranlari icin istege baglidir. Adres verilmezse
  // istemci etkisiz bir adresle olusturulur (ag cagrisi yapmaz) ve Supabase'e dayali
  // eski yedek yollar kapali kalir; uygulama yine de acilir.
  final supabaseConfigured = supabaseUrl != 'YOUR_SUPABASE_URL' &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY' &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;
  await Supabase.initialize(
    url: supabaseConfigured ? supabaseUrl : 'https://supabase-devre-disi.invalid',
    anonKey: supabaseConfigured ? supabaseAnonKey : 'devre-disi',
  );
  if (supabaseConfigured) {
    RaporService.initSupabase(Supabase.instance.client);
  }

  // Onceki oturum (sayfa yenilendiginde / uygulama yeniden acildiginda) geri yuklenir
  await CentralAuthTokenStore.restore();

  final authRepository =
      AuthRepository(supabase: Supabase.instance.client);
  final orchestrator = ServiceOrchestrator();

  orchestrator.registerService(VisionEngineService());
  orchestrator.init(authRepository);

  final lifecycleHandler =
      AppLifecycleHandler(authRepository: authRepository);
  WidgetsBinding.instance.addObserver(lifecycleHandler);

  runApp(const ProviderScope(child: ExpertizSistemiApp()));
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
