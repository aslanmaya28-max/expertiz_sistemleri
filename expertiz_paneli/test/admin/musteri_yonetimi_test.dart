import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/admin/modules/musteri_yonetimi_module.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

final _musteri = {
  'id': 1,
  'email': 'm1@x.com',
  'full_name': 'Ali Veli',
  'phone': '',
  'credits': 3,
  'tier': 'free',
  'is_active': true,
  'created_at': '2026-10-01 10:00:00',
  'request_count': 2,
  'total_spent_tl': 24000.0,
};

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

Widget _app(http.Client client) => MaterialApp(
      home: Scaffold(
        body: MusteriYonetimiModule(
          apiService: YerimebakExpertizApiService(
            baseUrl: 'http://api.test/api/v1',
            client: client,
            accessToken: 'admin-token',
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    // Alt sayfadaki talep listesinin ekrana sığması için uzun bir görünüm.
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  for (final fail in [false, true]) {
    testWidgets('kredi formu neden ister, sonucu yeniler; hata=$fail', (tester) async {
      var balance = 3;
      Map<String, dynamic>? sent;
      await tester.pumpWidget(_app(MockClient((request) async {
        if (request.method == 'POST') {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          if (fail) return http.Response('{"detail":"Bakiye eksiye düşemez"}', 400);
          balance = 13;
          return _json({'success': true});
        }
        if (request.url.path.endsWith('/1')) {
          return _json({'customer': {..._musteri, 'credits': balance}, 'requests': [],
            'credit_movements': balance == 13 ? [{'credits_used': -10, 'description': 'Telafi', 'created_at': '2026-11-01'}] : []});
        }
        return _json({'customers': [_musteri], 'active': 1});
      })));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ali Veli'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kredi yükle / düş'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Miktar (+ yükle / - düş)'), '10');
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();
      expect(sent, isNull);
      expect(find.text('Neden zorunludur'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Neden (zorunlu)'), 'Telafi');
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();
      expect(sent, {'amount': 10, 'reason': 'Telafi'});
      if (fail) {
        expect(find.textContaining('Bakiye eksiye'), findsOneWidget);
      } else {
        expect(find.text('free • 13 kredi'), findsOneWidget);
        expect(find.text('Telafi'), findsOneWidget);
        expect(find.text('+10 kredi'), findsOneWidget);
      }
    });
  }

  testWidgets('seviye sınırları API üzerinden gösterilir ve seçim kaydedilir', (tester) async {
    var tier = 'free';
    Map<String, dynamic>? sent;
    await tester.pumpWidget(_app(MockClient((request) async {
      if (request.method == 'POST') {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        tier = 'pro';
        return _json({'success': true});
      }
      if (request.url.path.endsWith('/1')) {
        return _json({'customer': {..._musteri, 'tier': tier}, 'requests': [],
          'tier_limits': {'free': {'max_analyses_per_day': 5},
            'pro': {'max_analyses_per_day': 201}}});
      }
      return _json({'customers': [_musteri], 'active': 1});
    })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ali Veli'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seviye (galerici paketi)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pro • günlük 201 analiz').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();
    expect(sent, {'tier': 'pro'});
    expect(find.text('pro • 3 kredi'), findsOneWidget);
  });

  testWidgets('musteri listesi, arama ve detay gosterilir', (tester) async {
    final istekler = <Uri>[];
    await tester.pumpWidget(_app(MockClient((request) async {
      istekler.add(request.url);
      if (request.url.path.endsWith('/admin/customers/1')) {
        return _json({
          'success': true,
          'customer': _musteri,
          'requests': [
            {'plate': '34 AB 1', 'package_name': 'Standart', 'total_tl': 12000, 'report_status': 'published',
             'created_at': '2026-10-11T10:00:00+00:00'},
          ],
        });
      }
      return _json({'success': true, 'customers': [_musteri], 'total': 1, 'active': 1});
    })));
    await tester.pumpAndSettle();

    expect(find.text('Ali Veli'), findsOneWidget);
    expect(find.textContaining('24.000,00 TL'), findsOneWidget);
    expect(find.text('1 müşteri • 1 aktif'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ali');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(istekler.last.queryParameters['search'], 'ali');

    await tester.tap(find.text('Ali Veli'));
    await tester.pumpAndSettle();
    expect(istekler.last.path, '/api/v1/expertiz/admin/customers/1');
    expect(find.text('34 AB 1 • Standart'), findsOneWidget);
    expect(find.textContaining('Yayınlandı'), findsOneWidget);
    expect(find.text('Pasife Al'), findsOneWidget);
  });

  testWidgets('pasife alma neden ister ve API cagirir', (tester) async {
    Map<String, dynamic>? gonderilen;
    await tester.pumpWidget(_app(MockClient((request) async {
      if (request.method == 'POST') {
        gonderilen = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({'success': true, 'customer': {..._musteri, 'is_active': false}});
      }
      if (request.url.path.endsWith('/admin/customers/1')) {
        return _json({'success': true, 'customer': _musteri, 'requests': []});
      }
      return _json({'success': true, 'customers': [_musteri], 'total': 1, 'active': 1});
    })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ali Veli'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pasife Al'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Neden (zorunlu)'), 'Sahte hesap');
    await tester.tap(find.widgetWithText(FilledButton, 'Pasife Al'));
    await tester.pumpAndSettle();

    expect(gonderilen, {'active': false, 'reason': 'Sahte hesap'});
    expect(find.text('Müşteri durumu güncellendi'), findsOneWidget);
  });
}
