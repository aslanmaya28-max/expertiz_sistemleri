import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'api/providers.dart' hide themeModeProvider;
import 'tema/gorunum.dart';
import 'bilesenler/alt_menu.dart';
import 'analiz/analiz_ekranlari.dart';
import 'analiz/ilan_metni.dart';
import 'analiz/paylasim.dart';
import 'bilesenler/ortak.dart';
import 'ekranlar/auth_screen.dart';
import 'ekranlar/home_screen.dart';
import 'ekranlar/profile_screen.dart';
import 'ekranlar/reports_screen.dart';
import 'kredi/kredi_ekrani.dart';
import 'oturum/session_controller.dart';
import 'tema/tema.dart';
import 'api/models.dart';
import 'hizmetler/hizmet_tanitim.dart';
import 'hizmetler/kesfet.dart';
import 'hizmetler/hizmet_api.dart';
import 'hizmetler/talep_ekrani.dart';
import 'hizmetler/odeme_ekrani.dart';
import 'hizmetler/kayit_ekranlari.dart';

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(sessionProvider, (_, _) => refresh.refresh());
  ref.listen(configProvider, (_, _) => refresh.refresh());
  ref.listen(hizmetBolgesiProvider, (_, _) => refresh.refresh());
  ref.listen(versionProvider, (_, _) => refresh.refresh());
  final router = GoRouter(
    refreshListenable: refresh,
    initialLocation: '/',
    redirect: (context, state) {
      final config = ref.read(configProvider),
          version = ref.read(versionProvider),
          session = ref.read(sessionProvider);
      final path = state.uri.path;
      if (config.isLoading ||
          version.isLoading ||
          config.hasError ||
          version.hasError ||
          session.phase == SessionPhase.restoring ||
          session.phase == SessionPhase.failed) {
        return path == '/durum' ? null : '/durum';
      }
      try {
        if (config.requireValue.requiresUpdate(version.requireValue)) {
          return path == '/guncelle' ? null : '/guncelle';
        }
      } on FormatException {
        return path == '/durum' ? null : '/durum';
      }
      final public = ['/giris', '/kayit', '/sifremi-unuttum'].contains(path);
      if (session.phase != SessionPhase.signedIn) {
        return public ? null : '/giris';
      }
      if ((path == '/ekspertiz/talep' ||
              path.startsWith('/ekspertiz/odeme/')) &&
          !ref.read(hizmetBolgesiProvider).isLoading &&
          !ref.read(hizmetBolgesiProvider).hasError &&
          !ref.read(ekspertizAcikProvider)) {
        return '/yerinde-inceleme';
      }
      if (public || path == '/durum' || path == '/guncelle') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/durum', builder: (_, _) => const StatusScreen()),
      GoRoute(path: '/guncelle', builder: (_, _) => const UpdateScreen()),
      GoRoute(
        path: '/giris',
        builder: (_, _) => const AuthScreen(AuthMode.login),
      ),
      GoRoute(
        path: '/kayit',
        builder: (_, _) => const AuthScreen(AuthMode.register),
      ),
      GoRoute(
        path: '/sifremi-unuttum',
        builder: (_, _) => const AuthScreen(AuthMode.forgot),
      ),
      // Analiz adımları alt menüsüz, tam ekran: müşteri akıştan dağılmaz.
      GoRoute(
        path: '/analiz/oku',
        builder: (_, s) {
          final link = s.uri.queryParameters['link'] ?? '';
          return paylasimdanLink(link) == null
              ? const AnalizBaslatEkrani()
              : IlanOkunuyorEkrani(link);
        },
      ),
      GoRoute(path: '/analiz/metin', builder: (_, _) => const MetinEkrani()),
      GoRoute(path: '/analiz/form', builder: (_, _) => const AracFormuEkrani()),
      GoRoute(
        path: '/analiz/bekle',
        builder: (_, _) => const AnalizBeklemeEkrani(),
      ),
      GoRoute(
        path: '/ekspertiz/talep',
        builder: (_, s) =>
            EkspertizTalepEkrani(arac: s.extra is Map ? object(s.extra) : null),
      ),
      GoRoute(
        path: '/ekspertiz/odeme/:id',
        builder: (_, s) => HizmetOdemeEkrani(
          s.pathParameters['id']!,
          checkout: s.extra is Map ? object(s.extra) : null,
        ),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: '/raporlar',
            builder: (_, _) => const ReportsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) => ReportDetailScreen(s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/analiz',
            builder: (_, _) => const AnalizBaslatEkrani(),
          ),
          GoRoute(path: '/kredi', builder: (_, _) => const KrediEkrani()),
          GoRoute(
            path: '/yerinde-inceleme',
            builder: (_, s) => YerindeIncelemeEkrani(
              arac: s.extra is Map ? object(s.extra) : null,
            ),
          ),
          GoRoute(
            path: '/arac-degerleme',
            builder: (_, _) => const AracDegerlemeEkrani(),
          ),
          GoRoute(
            path: '/ornek-rapor',
            builder: (_, _) => const OrnekRaporEkrani(),
          ),
          GoRoute(path: '/fiyatlar', builder: (_, _) => const FiyatlarEkrani()),
          GoRoute(
            path: '/uzaktan-satin-alma',
            builder: (_, _) => const UzaktanSatinAlmaEkrani(),
          ),
          GoRoute(
            path: '/talepler',
            builder: (_, _) => const HizmetKayitlariEkrani(),
          ),
          GoRoute(
            path: '/ekspertiz-raporlari',
            builder: (_, _) => const HizmetKayitlariEkrani(raporlar: true),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    EkspertizRaporEkrani(s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/bildirimler',
            builder: (_, _) => const BildirimEkrani(),
          ),
          GoRoute(
            path: '/profil',
            builder: (_, _) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'duzenle',
                builder: (_, _) => const AccountEditScreen(EditMode.profile),
              ),
              GoRoute(
                path: 'sifre',
                builder: (_, _) => const AccountEditScreen(EditMode.password),
              ),
              GoRoute(
                path: 'sil',
                builder: (_, _) => const AccountEditScreen(EditMode.delete),
              ),
              GoRoute(
                path: 'gecmis',
                builder: (_, _) => const CreditHistoryScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Sayfa bulunamadı')),
      body: PageBody(
        child: TextButton(
          onPressed: () => context.go('/'),
          child: const Text('Ana sayfaya dön'),
        ),
      ),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class YerimeBakApp extends ConsumerWidget {
  const YerimeBakApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'YerimeBak',
    debugShowCheckedModeBanner: false,
    theme: YbTema.acik,
    darkTheme: YbTema.koyu,
    themeMode: ref.watch(themeModeProvider),
    routerConfig: ref.watch(routerProvider),
    builder: (context, child) => UygulamaDinleyicileri(
      yonlendirici: (r) => r.read(routerProvider),
      child: child ?? const SizedBox.shrink(),
    ),
    locale: const Locale('tr', 'TR'),
    supportedLocales: const [Locale('tr', 'TR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
  );
}

class AppShell extends StatelessWidget {
  final Widget child;
  final String path;
  const AppShell({super.key, required this.path, required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: child,
    bottomNavigationBar: AltMenu(
      secili: path.startsWith('/raporlar')
          ? 1
          : path.startsWith('/kredi')
          ? 2
          : (path.startsWith('/profil') ||
                path.startsWith('/talepler') ||
                path.startsWith('/ekspertiz-raporlari') ||
                path.startsWith('/bildirimler'))
          ? 3
          : 0,
      onChanged: (index) =>
          context.go(['/', '/raporlar', '/kredi', '/profil'][index]),
    ),
  );
}

class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider),
        config = ref.watch(configProvider),
        version = ref.watch(versionProvider);
    Object? error = config.error ?? version.error ?? session.error;
    if (error == null && config.hasValue && version.hasValue) {
      try {
        config.requireValue.requiresUpdate(version.requireValue);
      } on FormatException catch (e) {
        error = e.message;
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('YerimeBak')),
      body: PageBody(
        child: error != null
            ? FailureView(error, () {
                ref.invalidate(configProvider);
                ref.invalidate(versionProvider);
                ref.read(sessionProvider).restore();
              })
            : const LoadingView(),
      ),
    );
  }
}

class UpdateScreen extends ConsumerWidget {
  const UpdateScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider).requireValue;
    return Scaffold(
      appBar: AppBar(title: const Text('Güncelleme gerekli')),
      body: PageBody(
        child: Panel('YerimeBak’ı güncelleyin', [
          Text(
            'Devam etmek için en az ${config.minimumVersion} sürümü gerekir.',
          ),
          ActionButton(
            'Mağazada aç',
            config.storeUrl.isEmpty
                ? null
                : () => ref.read(platformProvider).openLink(config.storeUrl),
          ),
          Text('Destek: ${config.supportEmail}'),
        ]),
      ),
    );
  }
}
