import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/admin/modules/piyasa_verisi_module.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

// Merkezi API'den alınmış gerçek cevap örnekleri.
Map<String, dynamic> _status(String arabam) => {
      'arabam': {'status': arabam, 'pid': arabam == 'running' ? 10423 : null, 'last_activity': '12.10.2026 19:43:28', 'source': 'arabam'},
      'borusan': {'status': 'idle', 'pid': null, 'last_activity': '-', 'source': 'borusan'},
      'active_workers': arabam == 'running' ? 1 : 0,
      'total_workers': 2,
    };
const _stats = {
  'total_listings': 13,
  'analyzed_listings': 13,
  'avg_ai_score': 0.0,
  'buy_opportunities': 0,
  'avg_price': 1217308,
  'by_source': {'borusan': 3, 'arabam': 10},
  'daily_new_listings': 13,
};
const _coverage = {
  'success': true,
  'total_rows': 2,
  'healthy': 0,
  'underfilled': 1,
  'filled_imbalanced': 1,
  'stale': 0,
  'coverage': [
    {'brand': 'Renault', 'model': 'Clio', 'priority': 1, 'year_bucket': '2017-2021', 'active_count': 0, 'target_count': 10, 'missing_count': 10, 'coverage_status': 'underfilled'},
    {'brand': 'Fiat', 'model': 'Egea', 'priority': 1, 'year_bucket': '2017-2021', 'active_count': 10, 'target_count': 10, 'missing_count': 0, 'coverage_status': 'filled_imbalanced'},
  ],
};

http.Response _json(Object body, [int code = 200]) =>
    http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1200, 2600);
    view.devicePixelRatio = 1.0;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('kaziyici baslat/durdur ve piyasa ozeti', (tester) async {
    var arabam = 'idle';
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      expect(request.headers['Authorization'], 'Bearer admin-token');
      final path = request.url.path;
      if (path.endsWith('/scrapers/status')) return _json(_status(arabam));
      if (path.endsWith('/scrapers/start/arabam')) {
        arabam = 'running';
        return _json({'status': 'started', 'message': 'Arabam başlatıldı (PID: 10423)', 'source': 'arabam'});
      }
      if (path.endsWith('/scrapers/stop/arabam')) {
        arabam = 'idle';
        return _json({'status': 'stopped', 'message': 'Arabam durduruldu', 'source': 'arabam'});
      }
      if (path.endsWith('/vitrin/stats')) return _json(_stats);
      if (path.endsWith('/market-coverage/summary')) return _json(_coverage);
      return _json({'detail': 'Not Found'}, 404);
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PiyasaVerisiModule(
          refreshInterval: const Duration(hours: 1),
          apiService: YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', client: client, accessToken: 'admin-token'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Kazıyıcılar (0/2 çalışıyor)'), findsOneWidget);
    expect(find.text('Arabam.com'), findsWidgets);
    expect(find.text('Borusan Next'), findsWidgets);
    expect(find.text('13'), findsWidgets);
    expect(find.text('1.217.308 TL'), findsOneWidget);
    expect(find.text('Renault Clio (2017-2021)'), findsOneWidget);
    expect(find.text('Eksik: 1'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Başlat').first);
    await tester.pumpAndSettle();
    expect(calls, contains('POST /api/v1/scrapers/start/arabam'));
    expect(find.text('Arabam başlatıldı (PID: 10423)'), findsOneWidget);
    expect(find.text('Kazıyıcılar (1/2 çalışıyor)'), findsOneWidget);
    expect(find.text('Çalışıyor'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Durdur'));
    await tester.pumpAndSettle();
    expect(calls, contains('POST /api/v1/scrapers/stop/arabam'));
    expect(find.text('Kazıyıcılar (0/2 çalışıyor)'), findsOneWidget);
  });

  testWidgets('vitrin toplu islemleri merkezi API ye gider', (tester) async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      final path = request.url.path;
      if (path.endsWith('/scrapers/status')) return _json(_status('idle'));
      if (path.endsWith('/vitrin/stats')) return _json(_stats);
      if (path.endsWith('/market-coverage/summary')) return _json(_coverage);
      if (path.endsWith('/vitrin/admin/reanalyze')) return _json({'success': true, 'analyzed': 12, 'total': 13});
      if (path.endsWith('/vitrin/admin/activate-hidden')) return _json({'success': true, 'activated': 4});
      return _json({'detail': 'Not Found'}, 404);
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PiyasaVerisiModule(
          refreshInterval: const Duration(hours: 1),
          apiService: YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', client: client, accessToken: 'admin-token'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('vitrinReanalyzeButton')));
    await tester.pumpAndSettle();
    expect(calls, contains('POST /api/v1/vitrin/admin/reanalyze'));
    expect(find.text('12/13 ilanın analizi yenilendi'), findsOneWidget);

    await tester.tap(find.byKey(const Key('vitrinActivateButton')));
    await tester.pumpAndSettle();
    expect(calls, contains('POST /api/v1/vitrin/admin/activate-hidden'));
    expect(find.text('4 gizli ilan tekrar vitrine alındı'), findsOneWidget);
  });

  testWidgets('yetkisiz kullanici icin hata ve tekrar dene', (tester) async {
    final client = MockClient((_) async => _json({'detail': 'Admin yetkisi gerekli'}, 403));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PiyasaVerisiModule(
          refreshInterval: const Duration(hours: 1),
          apiService: YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', client: client, accessToken: 't'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Piyasa verisi yüklenemedi'), findsOneWidget);
    expect(find.textContaining('Admin yetkisi gerekli'), findsOneWidget);
  });
}
