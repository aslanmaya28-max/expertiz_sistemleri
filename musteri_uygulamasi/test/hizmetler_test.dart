import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_filex/open_filex.dart';
import 'package:yerimebak/api/api_client.dart';
import 'package:yerimebak/hizmetler/hizmet_api.dart';
import 'package:yerimebak/hizmetler/hizmet_dosyalari.dart';
import 'api_client_test.dart' show MemoryTokens;

void main() {
  test('kapalı sunucu ayarı doğrudan talep göndermeyi de engeller', () async {
    final calls = <String>[];
    final api = ApiClient(
      store: MemoryTokens()..token = 'valid',
      client: MockClient((r) async {
        calls.add(r.url.path);
        return http.Response(jsonEncode({'expertiz_enabled': false}), 200);
      }),
    );
    addTearDown(api.close);
    await expectLater(
      HizmetRepository(api).talep({'firm_id': 'firma'}),
      throwsA(isA<ApiFailure>()),
    );
    expect(calls, ['/api/v1/app/config']);
  });
  test('eksik fiyat özeti ödeme adımına uygun teklif sayılmaz', () async {
    final api = ApiClient(
      store: MemoryTokens()..token = 'valid',
      client: MockClient(
        (r) async => http.Response('{"totals":{"total_tl":"7654"}}', 200),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      HizmetRepository(api).teklif('firma', 'paket'),
      throwsA(isA<ApiFailure>()),
    );
  });
  test('açık ayarda talep aynı kimlikli API ile gönderilir', () async {
    final calls = <http.Request>[];
    final api = ApiClient(
      store: MemoryTokens()..token = 'valid',
      client: MockClient((r) async {
        calls.add(r);
        return http.Response(
          jsonEncode(
            r.url.path.endsWith('/config')
                ? {'expertiz_enabled': true}
                : {
                    'order_id': 'order1',
                    'request_id': 'request1',
                    'provider': 'paytr',
                    'iframe_url': 'https://www.paytr.com/odeme/guvenli/token',
                  },
          ),
          200,
        );
      }),
    );
    addTearDown(api.close);
    final result = await HizmetRepository(
      api,
    ).talep({'firm_id': 'firma', 'contract_accepted': true});
    expect(result['request_id'], 'request1');
    expect(calls.last.headers['authorization'], 'Bearer valid');
    expect(jsonDecode(calls.last.body)['contract_accepted'], true);
  });
  test(
    'ayar kontrolü sırasında hesap değişirse eski talep gönderilmez',
    () async {
      final config = Completer<http.Response>();
      var posts = 0;
      final api = ApiClient(
        store: MemoryTokens()..token = 'valid',
        client: MockClient((r) {
          if (r.method == 'POST') posts++;
          return config.future;
        }),
      );
      addTearDown(api.close);
      final future = HizmetRepository(api).talep({});
      final assertion = expectLater(future, throwsA(isA<ApiFailure>()));
      await Future<void>.delayed(Duration.zero);
      await api.clearSession();
      config.complete(http.Response('{"expertiz_enabled":true}', 200));
      await assertion;
      expect(posts, 0);
    },
  );
  test(
    'bildirim okundu işlemi gerçek expertiz yolu ve seçilen kimliği kullanır',
    () async {
      late http.Request call;
      final api = ApiClient(
        store: MemoryTokens()..token = 'valid',
        client: MockClient((r) async {
          call = r;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(api.close);
      await HizmetRepository(api).okundu(12);
      expect(call.url.path, '/api/v1/expertiz/notifications/read');
      expect(jsonDecode(call.body), {
        'ids': [12],
      });
    },
  );
  test('PayTR dönüş adresinde alan adı, protokol ve yol kesin eşleşir', () {
    expect(
      odemeDonusu('https://www.yerimebak.com.tr/odeme/sonuc?durum=basarili'),
      OdemeDonusu.basarili,
    );
    expect(
      odemeDonusu('https://yerimebak.com.tr/odeme/sonuc?durum=basarisiz'),
      OdemeDonusu.basarisiz,
    );
    for (final value in [
      'https://yerimebak.com.tr.evil.test/odeme/sonuc?durum=basarili',
      'http://yerimebak.com.tr/odeme/sonuc?durum=basarili',
      'https://evil@yerimebak.com.tr/odeme/sonuc?durum=basarili',
      'https://yerimebak.com.tr:444/odeme/sonuc?durum=basarili',
      'https://yerimebak.com.tr/baska?durum=basarili',
    ]) {
      expect(odemeDonusu(value), isNull, reason: value);
    }
  });
  test('imzalı medya sorgusu korunur, harici ve kaçış yolları engellenir', () {
    final base = Uri.parse('https://api.yerimebak.com.tr/api/v1');
    expect(
      guvenliMedyaYolu('/api/v1/expertiz/media/abc?exp=123&sig=test', base),
      '/expertiz/media/abc?exp=123&sig=test',
    );
    expect(
      guvenliMedyaYolu(
        'https://api.yerimebak.com.tr/api/v1/expertiz/media/abc?sig=test',
        base,
      ),
      '/expertiz/media/abc?sig=test',
    );
    for (final value in [
      'https://evil.test/api/v1/expertiz/media/a',
      '//evil.test/expertiz/media/a',
      '/api/v1/expertiz/media/../admin',
      '/api/v1/expertiz/media/%2e%2e',
      '/api/v1/expertiz/media/a?orijinal=1',
    ]) {
      expect(guvenliMedyaYolu(value, base), isNull);
    }
  });
  test('PDF yerine HTML gelirse dosya açılmaz', () async {
    var opened = 0;
    final api = ApiClient(
      store: MemoryTokens()..token = 'valid',
      client: MockClient(
        (r) async => http.Response(
          '<html>hata</html>',
          200,
          headers: {'content-type': 'application/pdf'},
        ),
      ),
    );
    addTearDown(api.close);
    final files = HizmetDosyalari(
      openDocument: (_, _) async {
        opened++;
        return OpenResult(type: ResultType.done, message: '');
      },
    );
    await expectLater(
      files.ac(api, '/expertiz/media/a?sig=s'),
      throwsA(isA<ApiFailure>()),
    );
    expect(opened, 0);
  });
  test(
    'dosya önbelleği hazırlanırken oturum değişirse belge açılmaz',
    () async {
      final temporary = Completer<Directory>();
      var opened = 0;
      final dir = await Directory.systemTemp.createTemp('yb023-');
      addTearDown(() => dir.delete());
      final api = ApiClient(
        store: MemoryTokens()..token = 'valid',
        client: MockClient(
          (r) async => http.Response(
            '%PDF-1.7',
            200,
            headers: {'content-type': 'application/pdf'},
          ),
        ),
      );
      addTearDown(api.close);
      final files = HizmetDosyalari(
        temporaryDirectory: () => temporary.future,
        openDocument: (_, _) async {
          opened++;
          return OpenResult(type: ResultType.done, message: '');
        },
      );
      final future = files.ac(api, '/expertiz/media/a?sig=s');
      final assertion = expectLater(future, throwsA(isA<ApiFailure>()));
      await Future<void>.delayed(Duration.zero);
      await api.clearSession();
      temporary.complete(dir);
      await assertion;
      expect(opened, 0);
      expect(await dir.list().isEmpty, true);
    },
  );
  for (final mime in ['image/webp', 'image/heic']) {
    test('$mime sunucunun geçerli fotoğraf biçimi olarak açılır', () async {
      final bytes = mime == 'image/webp'
          ? <int>[82, 73, 70, 70, 20, 0, 0, 0, 87, 69, 66, 80, 0, 0, 0, 0]
          : <int>[
              0,
              0,
              0,
              24,
              102,
              116,
              121,
              112,
              104,
              101,
              105,
              99,
              0,
              0,
              0,
              0,
            ];
      final root = await Directory.systemTemp.createTemp('yb023-format-');
      addTearDown(() => root.delete());
      final api = ApiClient(
        store: MemoryTokens()..token = 'valid',
        client: MockClient(
          (r) async =>
              http.Response.bytes(bytes, 200, headers: {'content-type': mime}),
        ),
      );
      addTearDown(api.close);
      var opened = false;
      final files = HizmetDosyalari(
        temporaryDirectory: () async => root,
        openDocument: (path, type) async {
          opened = true;
          expect(type, mime);
          expect(await File(path).readAsBytes(), bytes);
          await File(path).delete();
          await File(path).parent.delete();
          return OpenResult(type: ResultType.done, message: '');
        },
      );
      await files.ac(api, '/expertiz/media/a?exp=123&sig=test');
      expect(opened, true);
    });
  }
}
