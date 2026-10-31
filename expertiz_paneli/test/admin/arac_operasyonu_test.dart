import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/admin/modules/arac_operasyonu.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

http.Response _json(Object body, [int code = 200]) =>
    http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _talep(String bucket) => {
      'id': 'R1',
      'bucket': bucket,
      'status': bucket == 'cancelled' ? 'cancelled' : 'draft',
      'plaka': '34ABC123',
      'region': 'İstanbul / Kadıköy',
      'total_tl': 12000.0,
      'payment_status': 'paid',
      'is_paid': true,
      'assignment': <String, dynamic>{},
    };

void main() {
  testWidgets('admin talepteki ilan baglantisini acar', (tester) async {
    const url = 'https://www.sahibinden.com/ilan/test-1347633467/detay';
    Uri? opened;
    final client = MockClient((_) async => _json({
      'requests': [{..._talep('waiting_assignment'), 'vehicle': {'title': 'Seat Arona', 'listing_url': url}}],
      'counts': {'waiting_assignment': 1},
    }));
    await tester.pumpWidget(MaterialApp(home: AracOperasyonu(
      apiService: YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', client: client, accessToken: 'admin-token'),
      openListing: (uri) async {opened = uri; return true;},
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seat Arona'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İlanı aç'));
    await tester.pumpAndSettle();
    expect(opened.toString(), url);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('calistirilabilir ilan adresi admin butonu olusturmaz', (tester) async {
    final client = MockClient((_) async => _json({
      'requests': [{..._talep('waiting_assignment'), 'vehicle': {'title': 'Seat Arona', 'listing_url': 'javascript:alert(1)'}}],
      'counts': {'waiting_assignment': 1},
    }));
    await tester.pumpWidget(MaterialApp(home: AracOperasyonu(
      apiService: YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', client: client, accessToken: 'admin-token'),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seat Arona'));
    await tester.pumpAndSettle();
    expect(find.text('İlanı aç'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1400, 2600);
    view.devicePixelRatio = 1.0;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('talep gerekce ve iade secimiyle iptal edilir', (tester) async {
    var bucket = 'waiting_assignment';
    http.Request? iptal;
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/cancel')) {
        iptal = request;
        bucket = 'cancelled';
        return _json({'success': true, 'refunded_tl': 12000.0});
      }
      return _json({
        'requests': [_talep(bucket)],
        'counts': {bucket: 1},
      });
    });

    await tester.pumpWidget(MaterialApp(
      home: AracOperasyonu(
        apiService: YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', client: client, accessToken: 'admin-token'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cancel-R1')));
    await tester.pumpAndSettle();

    // Gerekce zorunlu
    await tester.tap(find.byKey(const Key('confirmCancelButton')));
    await tester.pumpAndSettle();
    expect(find.text('İptal nedeni zorunludur'), findsOneWidget);
    expect(iptal, isNull);

    expect(find.byKey(const Key('refundCheckbox')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('cancelReasonField')), 'Musteri vazgecti');
    await tester.tap(find.byKey(const Key('confirmCancelButton')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(iptal, isNotNull);
    expect(iptal!.url.path, '/api/v1/expertiz/admin/requests/R1/cancel');
    final body = jsonDecode(iptal!.body) as Map<String, dynamic>;
    expect(body['reason'], 'Musteri vazgecti');
    expect(body['refund'], isTrue);
    expect(find.textContaining('müşteriye iade edildi'), findsOneWidget);

    // Iptal edilen talepte tekrar iptal butonu olmaz
    await tester.tap(find.textContaining('İptal Edilen').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('cancel-R1')), findsNothing);

    // Periyodik yenileme zamanlayicisini kapat
    await tester.pumpWidget(const SizedBox());
  });
}
