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
