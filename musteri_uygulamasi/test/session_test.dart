import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak/api/api_client.dart';
import 'package:yerimebak/api/models.dart';
import 'package:yerimebak/api/repositories.dart';
import 'package:yerimebak/oturum/session_controller.dart';
import 'api_client_test.dart' show MemoryTokens;

const profile =
    '{"profile":{"id":20,"email":"sentetik@example.test","role":"customer","credits":5,"email_verified":false}}';

void main() {
  test(
    'kayıtlı belirteç /me ve profil ile doğrulanır, e-posta durumu kaybolmaz',
    () async {
      final api = ApiClient(
        store: MemoryTokens('valid'),
        client: MockClient(
          (r) async => http.Response(
            r.url.path.endsWith('/profile') ? profile : '{}',
            200,
          ),
        ),
      );
      final session = SessionController(
        repository: AccountRepository(api),
        api: api,
      );
      await session.restore();
      expect(session.phase, SessionPhase.signedIn);
      expect(session.user!.credits, 5);
      expect(session.user!.emailVerified, false);
    },
  );

  test(
    'ağ hatasında kayıtlı belirteç korunur, açılış tekrar denenebilir',
    () async {
      final store = MemoryTokens('valid');
      final api = ApiClient(
        store: store,
        client: MockClient((r) async => throw http.ClientException('offline')),
      );
      final session = SessionController(
        repository: AccountRepository(api),
        api: api,
      );
      await session.restore();
      expect(session.phase, SessionPhase.failed);
      expect(store.token, 'valid');
    },
  );

  test('belirteç yoksa açılışta ağa çıkılmaz', () async {
    final api = ApiClient(
      store: MemoryTokens(),
      client: MockClient((r) async => fail('Ağ çağrısı yapılmamalı')),
    );
    final session = SessionController(
      repository: AccountRepository(api),
      api: api,
    );
    await session.restore();
    expect(session.phase, SessionPhase.signedOut);
  });

  test('çıkıştan sonra geciken giriş yanıtı oturumu canlandıramaz', () async {
    final store = MemoryTokens();
    final entered = Completer<void>(), release = Completer<void>();
    final api = ApiClient(
      store: store,
      client: MockClient((r) async {
        entered.complete();
        await release.future;
        return http.Response('{"token":"late"}', 200);
      }),
    );
    final session = SessionController(
      repository: AccountRepository(api),
      api: api,
    );
    final login = session.login('test@example.test', 'Musteri123!');
    await entered.future;
    await session.logout();
    release.complete();
    await login;
    expect(session.phase, SessionPhase.signedOut);
    expect(store.token, isNull);
  });

  test('başarılı giriş ve silme belirteci temizler', () async {
    final store = MemoryTokens();
    final api = ApiClient(
      store: store,
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) {
          return http.Response('{"token":"valid"}', 200);
        }
        if (r.url.path.endsWith('/profile')) return http.Response(profile, 200);
        return http.Response('{}', 200);
      }),
    );
    final session = SessionController(
      repository: AccountRepository(api),
      api: api,
    );
    await session.login('test@example.test', 'Musteri123!');
    expect(session.phase, SessionPhase.signedIn);
    await session.deleteAccount('Musteri123!');
    expect(session.user, isNull);
    expect(store.token, isNull);
  });

  test('eski sunucuda config yoksa silme yeteneği kapalıdır', () async {
    final api = ApiClient(
      store: MemoryTokens(),
      client: MockClient((r) async => http.Response('{}', 404)),
    );
    final config = await ConfigRepository(api).load();
    expect(config.available, false);
    expect(config.expertizEnabled, false);
  });

  test('sürüm sayısal ve semantik karşılaştırılır', () {
    final config = AppConfig.fromJson({'min_supported_version': '1.10.0'});
    expect(config.requiresUpdate('1.9.9'), true);
    expect(config.requiresUpdate('1.10.0+20'), false);
    expect(config.requiresUpdate('2.0.0'), false);
    expect(config.requiresUpdate('1.10.0-beta.1'), true);
  });
}
