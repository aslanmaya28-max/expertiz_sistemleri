import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak/api/api_client.dart';
import 'package:yerimebak/api/repositories.dart';
import 'package:yerimebak/oturum/token_store.dart';

class MemoryTokens implements TokenStore {
  String? token;
  MemoryTokens([this.token]);
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

void main() {
  test('eski API token döndürmeden şifre değişikliğini tamamlayabilir', () async {
    final store = MemoryTokens('eski');
    final api = ApiClient(store: store, client: MockClient((_) async {
      return http.Response('{"success":true}', 200);
    }));
    await AccountRepository(api).changePassword('Eski123!', 'Yeni456!');
    expect(store.token, 'eski');
  });
  test('şifre değişikliği yeni tokenı saklar ve sonraki istekte kullanır', () async {
    final store = MemoryTokens('eski');
    final api = ApiClient(store: store, client: MockClient((request) async {
      if (request.url.path.endsWith('/change-password')) {
        expect(request.headers['Authorization'], 'Bearer eski');
        return http.Response('{"success":true,"token":"yeni"}', 200);
      }
      expect(request.headers['Authorization'], 'Bearer yeni');
      return http.Response('{}', 200);
    }));
    await AccountRepository(api).changePassword('Eski123!', 'Yeni456!');
    expect(store.token, 'yeni');
    await api.get('/auth/me');
  });
  test(
    'belirteç okuması beklerken değişen oturum eski profil isteğini göndermez',
    () async {
      final store = PausedReadTokens(1);
      var sent = 0;
      final api = ApiClient(
        store: store,
        client: MockClient((r) async {
          sent++;
          return http.Response('{}', 200);
        }),
      );
      final pending = expectLater(
        api.put('/auth/profile', {'full_name': 'A müşterisi'}),
        throwsA(isA<ApiFailure>()),
      );
      await store.entered.future;
      await api.clearSession();
      await api.saveSession('user-b');
      store.release.complete();
      await pending;
      expect(sent, 0);
      expect(store.token, 'user-b');
    },
  );
  test(
    'yenileme öncesi depo okuması beklerken değişen kuşak eski refresh başlatmaz',
    () async {
      final store = PausedReadTokens(2, capture: true);
      var refreshes = 0;
      final api = ApiClient(
        store: store,
        client: MockClient((r) async {
          if (r.url.path.endsWith('refresh-token')) {
            refreshes++;
            return http.Response('{"token":"late"}', 200);
          }
          return http.Response('{}', 401);
        }),
      );
      final pending = expectLater(
        api.get('/auth/me'),
        throwsA(isA<ApiFailure>()),
      );
      await store.entered.future;
      await api.clearSession();
      await api.saveSession('user-b');
      store.release.complete();
      await pending;
      expect(refreshes, 0);
      expect(store.token, 'user-b');
    },
  );
  test('eski 401 temizliği yeni girişin oturumunu kapatamaz', () async {
    final store = DelayedClearTokens();
    var expired = 0;
    final api =
        ApiClient(
            store: store,
            client: MockClient((r) async => http.Response('{}', 401)),
          )
          ..onUnauthorized = () {
            expired++;
          };
    final request = expectLater(
      api.get('/auth/me'),
      throwsA(isA<ApiFailure>()),
    );
    await store.entered.future;
    final newLogin = api.saveSession('new-session');
    store.release.complete();
    await Future.wait([request, newLogin]);
    expect(store.token, 'new-session');
    expect(expired, 0);
  });

  test('farklı oturum kuşakları aynı refresh geleceğini paylaşmaz', () async {
    final store = MemoryTokens('old');
    final oldEntered = Completer<void>(),
        newEntered = Completer<void>(),
        releaseOld = Completer<void>();
    var refreshes = 0;
    final api = ApiClient(
      store: store,
      client: MockClient((r) async {
        final token = r.headers['authorization'];
        if (r.url.path.endsWith('refresh-token')) {
          refreshes++;
          if (token == 'Bearer old') {
            oldEntered.complete();
            await releaseOld.future;
            return http.Response('{"token":"late"}', 200);
          }
          return http.Response('{"token":"latest"}', 200);
        }
        if (token == 'Bearer new') {
          newEntered.complete();
        }
        return http.Response('{}', token == 'Bearer latest' ? 200 : 401);
      }),
    );
    final old = expectLater(api.get('/one'), throwsA(isA<ApiFailure>()));
    await oldEntered.future;
    await api.saveSession('new');
    final fresh = api.get('/two');
    await newEntered.future;
    await Future<void>.delayed(Duration.zero);
    releaseOld.complete();
    expect(await fresh, {});
    await old;
    expect(store.token, 'latest');
    expect(refreshes, 2);
  });
  test(
    '401 bir kez yenilenir, yeni belirteçle asıl istek tekrar edilir',
    () async {
      final store = MemoryTokens('old');
      final paths = <String>[];
      final api = ApiClient(
        store: store,
        client: MockClient((r) async {
          paths.add(r.url.path);
          if (r.url.path.endsWith('/refresh-token')) {
            expect(r.headers['authorization'], 'Bearer old');
            return http.Response('{"token":"new"}', 200);
          }
          return r.headers['authorization'] == 'Bearer new'
              ? http.Response('{"credits":5}', 200)
              : http.Response('{}', 401);
        }),
      );
      expect(await api.get('/credits/balance'), {'credits': 5});
      expect(store.token, 'new');
      expect(paths, [
        '/api/v1/credits/balance',
        '/api/v1/auth/refresh-token',
        '/api/v1/credits/balance',
      ]);
    },
  );

  test('eşzamanlı 401 yanıtları tek yenileme üretir', () async {
    final store = MemoryTokens('old');
    var refreshes = 0;
    final wait = Completer<void>();
    var initial = 0;
    final api = ApiClient(
      store: store,
      client: MockClient((r) async {
        if (r.url.path.endsWith('refresh-token')) {
          refreshes++;
          await wait.future;
          return http.Response('{"token":"new"}', 200);
        }
        if (r.headers['authorization'] == 'Bearer old') {
          initial++;
          if (initial == 2) wait.complete();
          return http.Response('{}', 401);
        }
        return http.Response('{}', 200);
      }),
    );
    await Future.wait([api.get('/one'), api.get('/two')]);
    expect(refreshes, 1);
  });

  test('yenileme reddinde oturum temizlenir, sonsuz döngü olmaz', () async {
    final store = MemoryTokens('old');
    var calls = 0, expired = 0;
    final api =
        ApiClient(
            store: store,
            client: MockClient((r) async {
              calls++;
              return http.Response('{"detail":"Geçersiz"}', 401);
            }),
          )
          ..onUnauthorized = () {
            expired++;
          };
    await expectLater(
      api.get('/auth/me'),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 401)),
    );
    expect(store.token, isNull);
    expect(calls, 2);
    expect(expired, 1);
  });

  test('giriş 401 yenilenmez ve sunucu detail mesajı korunur', () async {
    var calls = 0;
    final api = ApiClient(
      store: MemoryTokens(),
      client: MockClient((r) async {
        calls++;
        return http.Response(
          jsonEncode({'detail': 'Şifre yanlış.'}),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await expectLater(
      api.post('/auth/login', {}, authenticated: false),
      throwsA(
        isA<ApiFailure>().having((e) => e.message, 'mesaj', 'Şifre yanlış.'),
      ),
    );
    expect(calls, 1);
  });

  test(
    '402 kodu ayrı hata türüdür, 429 ve doğrulama ayrıntıları okunur',
    () async {
      final api = ApiClient(
        store: MemoryTokens(),
        client: MockClient(
          (r) async => http.Response(
            '{"detail":{"message":"Yetersiz kredi","code":"insufficient_credits"}}',
            402,
          ),
        ),
      );
      await expectLater(api.get('/test'), throwsA(isA<InsufficientCredits>()));
      expect(
        ApiFailure.fromResponse(429, '{"detail":"Günlük sınır"}').message,
        'Günlük sınır',
      );
      expect(
        ApiFailure.fromResponse(
          422,
          '{"detail":[{"msg":"Alan eksik"}]}',
        ).message,
        contains('Alan eksik'),
      );
    },
  );

  test('ağ ve zaman aşımı Türkçe hata verir', () async {
    for (final error in [
      http.ClientException('offline'),
      TimeoutException('slow'),
    ]) {
      final api = ApiClient(
        store: MemoryTokens(),
        client: MockClient((r) async => throw error),
      );
      await expectLater(
        api.get('/test'),
        throwsA(isA<ApiFailure>().having((e) => e.status, 'ağ', 0)),
      );
    }
  });

  test('PDF kimlikli indirilir, HTML yanıt dosya olarak açılmaz', () async {
    final api = ApiClient(
      store: MemoryTokens('secret'),
      client: MockClient((r) async {
        expect(r.headers['authorization'], 'Bearer secret');
        return http.Response(
          '%PDF-1.7\n',
          200,
          headers: {'content-type': 'application/pdf'},
        );
      }),
    );
    expect(
      utf8.decode(await api.getPdf('/valuation/reports/id/pdf')),
      startsWith('%PDF-'),
    );
    final wrong = ApiClient(
      store: MemoryTokens(),
      client: MockClient((r) async => http.Response('<html>', 200)),
    );
    await expectLater(wrong.getPdf('/test'), throwsA(isA<ApiFailure>()));
  });

  test('çıkış sırasında tamamlanan refresh belirteci geri yazamaz', () async {
    final store = MemoryTokens('old');
    final entered = Completer<void>(), release = Completer<void>();
    final api = ApiClient(
      store: store,
      client: MockClient((r) async {
        if (r.url.path.endsWith('refresh-token')) {
          entered.complete();
          await release.future;
          return http.Response('{"token":"new"}', 200);
        }
        return http.Response('{}', 401);
      }),
    );
    final pending = expectLater(
      api.get('/auth/me'),
      throwsA(isA<ApiFailure>()),
    );
    await entered.future;
    await api.clearSession();
    release.complete();
    await pending;
    expect(store.token, isNull);
  });
}

class DelayedClearTokens extends MemoryTokens {
  final entered = Completer<void>(), release = Completer<void>();
  DelayedClearTokens() : super('old');
  @override
  Future<void> clear() async {
    entered.complete();
    await release.future;
    await super.clear();
  }
}

class PausedReadTokens extends MemoryTokens {
  final int at;
  final bool capture;
  int reads = 0;
  final entered = Completer<void>(), release = Completer<void>();
  PausedReadTokens(this.at, {this.capture = false}) : super('user-a');
  @override
  Future<String?> read() async {
    final before = token;
    if (++reads == at) {
      entered.complete();
      await release.future;
    }
    return capture ? before : token;
  }
}
