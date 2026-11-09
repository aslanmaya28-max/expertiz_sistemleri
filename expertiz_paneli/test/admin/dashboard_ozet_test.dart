import 'dart:convert';
import 'dart:async';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/admin/modules/dashboard_module.dart';
import 'package:yerimebak_sistemleri/models/dashboard_stats.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

Map<String, dynamic> yanit({bool ozet = true}) => {
      if (ozet)
        'ozet': {
          'musteriler': {'bugun': 3, 'son7': 12},
          'degerlemeler': {'bugun': 7, 'son7': 24},
          'kredi_satisi': {
            'son30_tl': 1250,
            'son30_adet': 5,
            'bekleyen_havale': 2,
            'play_son30_adet': 1
          },
          'ekspertiz': {
            'waiting_assignment': 2,
            'in_progress': 4,
            'pending_approval': 0,
            'completed': 8,
            'cancelled': 1,
            'arac_bulunamadi': 0
          },
          'gunluk': [
            {'tarih': '2026-11-09', 'degerleme': 7, 'yeni_musteri': 3}
          ],
        },
      'pending_admin': [],
      'recent_activities': [],
    };

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  testWidgets('eski sunucunun bilinen onay işleri özetsiz de gösterilir', (tester) async {
    final api = YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', accessToken: 'test',
      client: MockClient((_) async => http.Response(jsonEncode({...yanit(ozet:false), 'status_distribution': {'pending_admin': 2}}),200,
        headers:{'content-type':'application/json; charset=utf-8'})));
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:DashboardModule(apiService:api, email:'admin@example.test'))));
    await tester.pumpAndSettle();
    expect(find.text('2 rapor onay bekliyor'),findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('yenilemeler örtüşmez ve sayaç yeni veriye eski değerden ilerler', (tester) async {
    tester.view.physicalSize=const Size(1440,1400);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final replies=<Completer<http.Response>>[];
    final api=YerimebakExpertizApiService(baseUrl:'http://api.test/api/v1',accessToken:'test',client:MockClient((_) {
      final reply=Completer<http.Response>();replies.add(reply);return reply.future;
    }));
    http.Response result(Map<String,dynamic> body)=>http.Response(jsonEncode(body),200,headers:{'content-type':'application/json; charset=utf-8'});
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:DashboardModule(apiService:api,email:'admin@example.test'))));
    await tester.pump();
    await tester.tap(find.byTooltip('Ana sayfayı yenile'));
    await tester.pump();
    expect(replies.length,1);
    replies.first.complete(result(yanit()));
    await tester.pumpAndSettle();
    expect(find.text('3'),findsOneWidget);
    await tester.tap(find.byTooltip('Ana sayfayı yenile'));
    await tester.pump();
    expect(replies.length,2);
    final updated=yanit();(updated['ozet']['musteriler'] as Map)['bugun']=9;
    replies.last.complete(result(updated));
    await tester.pump();await tester.pump();
    expect(find.text('3'),findsOneWidget);
    await tester.pump(const Duration(milliseconds:350));
    final counters=tester.widgetList<Text>(find.byType(Text)).where((t)=>t.style?.fontSize==32).map((t)=>t.data).toList();
    expect(counters, isNot(contains('0')));
    await tester.pumpAndSettle();
    expect(find.text('9'),findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  test('özet alanı eksik sunucuda null; sayısal değerler korunur', () {
    expect(DashboardOzet.fromResponse({}), isNull);
    final ozet = DashboardOzet.fromResponse(yanit())!;
    expect(ozet.musteriler['bugun'], 3);
    expect(ozet.krediSatisi['son30_tl'], 1250);
    expect(ozet.gunluk.single.degerleme, 7);
  });

  for (final brightness in Brightness.values) {
    for (final hasOzet in [true, false]) {
      testWidgets(
          '$brightness özet=$hasOzet: e-posta adı, sayaç ve dikkat listesi',
          (tester) async {
        tester.view.physicalSize = const Size(1440, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = YerimebakExpertizApiService(
            baseUrl: 'http://api.test/api/v1',
            accessToken: 'test',
            client: MockClient((_) async => http.Response(
                jsonEncode(yanit(ozet: hasOzet)), 200,
                headers: {'content-type': 'application/json; charset=utf-8'})));
        final opened = <String>[];
        await tester.pumpWidget(MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
                data: const MediaQueryData(
                    disableAnimations: true, size: Size(1440, 1400)),
                child: Scaffold(
                    body: DashboardModule(
                        apiService: api,
                        displayName: '',
                        email: 'ayse@example.test',
                        onNavigate: (page, filter) =>
                            opened.add('$page:$filter'))))));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.textContaining('ayse'), findsOneWidget);
        expect(find.textContaining('Hoş Geldiniz'), findsNothing);
        if (hasOzet) {
          expect(find.text('1.250 TL'), findsOneWidget);
          expect(find.text('2 talep atama bekliyor'), findsOneWidget);
          expect(find.textContaining('iade kararı'), findsNothing);
          await tester.tap(find.text('2 talep atama bekliyor'));
          expect(opened, ['talepler:waiting_assignment']);
        } else {
          expect(find.text('—'), findsNWidgets(4));
          expect(find.text('Özet verisi henüz sunulmuyor'), findsOneWidget);
          expect(find.text('Ekspertiz özeti henüz sunulmuyor'), findsOneWidget);
          expect(find.text('Henüz ekspertiz talebi yok'), findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
