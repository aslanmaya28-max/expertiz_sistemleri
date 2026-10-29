import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/admin/modules/ai_merkezi.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

void main() {
  testWidgets('AI merkezi merkezi rapor API hatasını gösterir ve tekrar dener', (tester) async {
    var calls = 0;
    final api = YerimebakExpertizApiService(
      accessToken: 'test-token',
      client: MockClient((request) async {
        calls++;
        expect(request.url.path, '/api/v1/expertiz/admin/reports');
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response('{"detail":"Server error"}', 500);
      }),
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AIMerkezi(api: api))));
    await tester.pumpAndSettle();
    expect(find.text('Raporlar yüklenemedi'), findsOneWidget);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('AI merkezi rapor listesini merkezi API üzerinden yükler', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = YerimebakExpertizApiService(
      accessToken: 'test-token',
      client: MockClient((request) async => http.Response('{"reports":[]}', 200)),
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AIMerkezi(api: api))));
    await tester.pumpAndSettle();
    expect(find.text('Sistem Geneli İstatistikler'), findsOneWidget);
    expect(find.text('Raporlar yüklenemedi'), findsNothing);
  });
}
