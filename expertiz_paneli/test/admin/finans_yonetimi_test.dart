import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/admin/modules/finans_yonetimi.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

/// finance_service.summarize() (backend) çıktısı.
const _ozetJson = r'''{"success": true, "ekspertiz": {"request_count": 1, "ciro_tl": 12000.0, "kdv_tl": 2000.0, "net_tl": 10000.0, "simulated_payment_count": 1, "report_status_counts": {"published": 1}}, "kredi_satislari": {"approved_tl": 1500.0, "approved_count": 2, "pending_tl": 0.0, "pending_count": 0}, "personel": {"share_rate": 0.25, "hakedis_tl": 2500.0, "by_personnel": [{"personnel_id": "7", "personnel_name": "Ayse Yilmaz", "report_count": 1, "hakedis_tl": 2500.0}], "payout_tracking": false}}''';

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
    late Uri istek;
    await tester.pumpWidget(_app(MockClient((request) async {
      istek = request.url;
      return http.Response(_ozetJson, 200, headers: {'content-type': 'application/json; charset=utf-8'});
    })));
    await tester.pumpAndSettle();

    expect(istek.path, '/api/v1/expertiz/admin/finance/summary');
    expect(find.text('12.000,00 TL'), findsWidgets); // kart + detay satırı
    expect(find.text('Ayse Yilmaz'), findsOneWidget);
    expect(find.textContaining('simülasyon'), findsOneWidget);
  });

  testWidgets('API hatasinda tekrar dene ekrani gosterilir', (tester) async {
    await tester.pumpWidget(_app(MockClient((_) async => http.Response('{"detail":"Yetki yok"}', 403))));
    await tester.pumpAndSettle();

    expect(find.text('Finans verileri yüklenemedi'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
  });
}
