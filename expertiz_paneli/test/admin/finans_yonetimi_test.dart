import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/admin/modules/finans_yonetimi.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

/// finance_service.summarize() (backend) çıktısı.
const _ozetJson = r'''{"success": true, "ekspertiz": {"request_count": 1, "ciro_tl": 12000.0, "kdv_tl": 2000.0, "net_tl": 10000.0, "simulated_payment_count": 1, "report_status_counts": {"published": 1}}, "kredi_satislari": {"approved_tl": 1500.0, "approved_count": 2, "pending_tl": 0.0, "pending_count": 0}, "personel": {"share_rate": 0.25, "hakedis_tl": 2500.0, "by_personnel": [{"personnel_id": "7", "personnel_name": "Ayse Yilmaz", "report_count": 1, "hakedis_tl": 2500.0}], "payout_tracking": false}}''';

const _siparisJson = r'''{"success": true, "orders": [{"id": "CRX1", "status": "approved", "package_name": "3 Analiz", "credits": 3, "amount_tl": 100.0, "user_email": "a@b.com", "created_at": "2026-10-01T10:00:00"}]}''';

http.Response _json(String body) =>
    http.Response(body, 200, headers: {'content-type': 'application/json; charset=utf-8'});

Widget _app(http.Client client) => MaterialApp(
      home: Scaffold(
        body: FinansYonetimi(
          apiService: YerimebakExpertizApiService(
            baseUrl: 'http://api.test/api/v1',
            client: client,
            accessToken: 'admin-token',
          ),
        ),
      ),
    );

void main() {
  testWidgets('finans ozeti merkezi API verisiyle gosterilir', (tester) async {
    final istekler = <String>[];
    await tester.pumpWidget(_app(MockClient((request) async {
      istekler.add(request.url.path);
      return _json(request.url.path.endsWith('/payments/admin/orders') ? _siparisJson : _ozetJson);
    })));
    await tester.pumpAndSettle();

    expect(istekler, containsAll(['/api/v1/expertiz/admin/finance/summary', '/api/v1/payments/admin/orders']));
    expect(find.text('12.000,00 TL'), findsWidgets); // kart + detay satırı
    expect(find.text('Ayse Yilmaz'), findsOneWidget);
    expect(find.textContaining('simülasyon'), findsOneWidget);
  });

  testWidgets('kredi paketi iadesi gerekce ile gonderilir', (tester) async {
    http.Request? iade;
    await tester.pumpWidget(_app(MockClient((request) async {
      if (request.method == 'POST') {
        iade = request;
        return _json('{"success": true}');
      }
      return _json(request.url.path.endsWith('/payments/admin/orders') ? _siparisJson : _ozetJson);
    })));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(const Key('refund-CRX1')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('refund-CRX1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('refundReasonField')), 'Musteri talebi');
    await tester.tap(find.byKey(const Key('confirmRefundButton')));
    await tester.pumpAndSettle();

    expect(iade, isNotNull);
    expect(iade!.url.path, '/api/v1/payments/admin/orders/CRX1/refund');
    expect(iade!.body, contains('Musteri talebi'));
  });

  testWidgets('API hatasinda tekrar dene ekrani gosterilir', (tester) async {
    await tester.pumpWidget(_app(MockClient((_) async => http.Response('{"detail":"Yetki yok"}', 403))));
    await tester.pumpAndSettle();

    expect(find.text('Finans verileri yüklenemedi'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
  });
}
