import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/admin/modules/fiyatlandirma_module.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

http.Response _json(Object body, [int code = 200]) =>
    http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _pricing(double fee) => {
      'success': true,
      'service_fee_tl': fee,
      'vat_rate': 0.2,
      'vehicle_inflation': null,
      'firms': [
        {
          'id': 'otorapor',
          'name': 'Otorapor',
          'active': true,
          'verified': false,
          'source_url': 'https://otorapor.com/paketler',
          'packages': [
            {'id': 'otorapor--gold-paket', 'name': 'Gold Paket', 'price': 9000, 'features': ['Motor'], 'active': true},
          ],
        },
      ],
    };

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1200, 2400);
    view.devicePixelRatio = 1.0;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('admin hizmet bedelini ve enflasyonu degistirir, paket ekler', (tester) async {
    var fee = 6000.0;
    final bodies = <String, Map<String, dynamic>>{};
    final client = MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'GET' && path.endsWith('/expertiz/admin/pricing')) return _json(_pricing(fee));
      bodies['${request.method} $path'] = jsonDecode(request.body) as Map<String, dynamic>;
      if (path.endsWith('/admin/pricing/settings')) {
        fee = (bodies['${request.method} $path']!['service_fee_tl'] as num?)?.toDouble() ?? fee;
        return _json({'success': true});
      }
      if (path.endsWith('/admin/firms/otorapor/packages')) return _json({'success': true, 'package': {}});
      return _json({'detail': 'Not Found'}, 404);
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FiyatlandirmaModule(
          apiService: YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', client: client, accessToken: 'a'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Otorapor'), findsOneWidget);
    expect(find.text('9.000 TL'), findsOneWidget);
    expect(find.textContaining('Müşteriye 1 firma gösteriliyor'), findsOneWidget);
    expect(find.textContaining('Henüz girilmedi'), findsOneWidget);

    // Hizmet bedeli
    await tester.enterText(find.byKey(const Key('serviceFeeField')), '7500');
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet').first);
    await tester.pumpAndSettle();
    expect(bodies['PUT /api/v1/expertiz/admin/pricing/settings'], {'service_fee_tl': 7500.0});
    expect(find.text('Hizmet bedeli güncellendi'), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(const Key('serviceFeeField')));
    expect(field.controller!.text, '7500');

    // Enflasyon
    await tester.enterText(find.byKey(const Key('inflationField')), '2,5');
    await tester.pump();
    expect(find.textContaining('Yıllık karşılığı ≈ %34.5'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet').last);
    await tester.pumpAndSettle();
    expect(bodies['PUT /api/v1/expertiz/admin/pricing/settings']!['vehicle_inflation_monthly_pct'], 2.5);

    // Paket ekle
    await tester.tap(find.text('Paket ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Paket adı'), 'Full Paket');
    await tester.enterText(find.widgetWithText(TextField, 'Fiyat (TL)'), '13000');
    await tester.enterText(find.widgetWithText(TextField, 'Kapsam (virgülle ayırın)'), 'Motor, Kaporta');
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet').last);
    await tester.pumpAndSettle();
    expect(bodies['POST /api/v1/expertiz/admin/firms/otorapor/packages'],
        {'name': 'Full Paket', 'price': 13000.0, 'features': ['Motor', 'Kaporta']});
    await tester.pump(const Duration(seconds: 1));
  });
}
