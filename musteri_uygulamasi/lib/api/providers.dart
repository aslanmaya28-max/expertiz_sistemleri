import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../oturum/token_store.dart';
import '../oturum/session_controller.dart';
import 'api_client.dart';
import 'models.dart';
import 'repositories.dart';

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => const SecureTokenStore(),
);
final apiProvider = Provider<ApiClient>((ref) {
  final api = ApiClient(store: ref.watch(tokenStoreProvider));
  ref.onDispose(api.close);
  return api;
});
final platformProvider = Provider<PlatformServices>((ref) => AndroidServices());
final accountRepositoryProvider = Provider(
  (ref) => AccountRepository(ref.watch(apiProvider)),
);
final reportRepositoryProvider = Provider(
  (ref) => ReportRepository(ref.watch(apiProvider)),
);
final sessionProvider = ChangeNotifierProvider<SessionController>((ref) {
  final api = ref.watch(apiProvider);
  final session = SessionController(
    repository: ref.watch(accountRepositoryProvider),
    api: api,
  );
  api.onUnauthorized = session.expire;
  unawaited(Future.microtask(session.restore));
  return session;
});
final configProvider = FutureProvider<AppConfig>(
  (ref) => ConfigRepository(ref.watch(apiProvider)).load(),
);
final versionProvider = FutureProvider<String>(
  (ref) => ref.watch(platformProvider).version(),
);
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final balanceProvider = FutureProvider.autoDispose<int>((ref) {
  final user = ref.watch(sessionProvider.select((s) => s.user?.id));
  if (user == null) return 0;
  return ref.watch(reportRepositoryProvider).balance();
});
final recentReportsProvider = FutureProvider.autoDispose<ReportPage>((ref) {
  final user = ref.watch(sessionProvider.select((s) => s.user?.id));
  if (user == null) return ReportPage.fromJson({});
  return ref.watch(reportRepositoryProvider).page(limit: 5);
});
final reportDetailProvider = FutureProvider.autoDispose
    .family<ReportSnapshot, String>((ref, id) {
      ref.watch(sessionProvider.select((s) => s.user?.id));
      return ref.watch(reportRepositoryProvider).detail(id);
    });
final historyProvider = FutureProvider.autoDispose<List<CreditHistoryEntry>>((
  ref,
) {
  ref.watch(sessionProvider.select((s) => s.user?.id));
  return ref.watch(reportRepositoryProvider).history();
});
