import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:yerimebak_sistemleri/admin/admin_shell.dart';
import 'package:yerimebak_sistemleri/admin/modules/piyasa_takibi_module.dart';
import 'package:yerimebak_sistemleri/providers/user_provider.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

http.Response jsonResponse(Object body, [int code = 200]) => http.Response(
      jsonEncode(body),
      code,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

class StaffProvider extends ChangeNotifier implements UserProvider {
  @override
  bool get isAuthenticated => true;
  @override
  bool get isAdmin => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const row1 = {
  'iz': 'a',
  'seri': 'HS',
  'model': 'Luxury',
  'yil': 2024,
  'km': 12000,
  'fiyat': 1500000,
  'beygir': 162,
  'ilan_tarihi': '2026-11-01',
  'il': 'Ankara'
};
const row2 = {
  'iz': 'b',
  'seri': 'HS',
  'model': 'Comfort',
  'yil': 2023,
  'km': 25000,
  'fiyat': 1400000,
  'beygir': 162,
  'ilan_tarihi': '2026-10-30',
  'il': 'İstanbul'
};

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1400, 2400);
    view.devicePixelRatio = 1;
  });
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> mount(WidgetTester tester, MockClient client) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PiyasaTakibiModule(
      apiService: YerimebakExpertizApiService(
          client: client, accessToken: 'admin-test'),
    ))));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'önizleme, satır çıkarma, marka zorunluluğu ve kayıt sonrası yenileme',
      (tester) async {
    final saved = <Map<String, dynamic>>[];
    var gaps = 0;
    final client = MockClient((r) async {
      expect(r.headers['Authorization'], 'Bearer admin-test');
      if (r.url.path.endsWith('/admin/market/gaps')) {
        expect(r.url.queryParameters['limit'], '50');
        gaps++;
        return jsonResponse({
          'modeller': [
            {
              'brand': 'MG',
              'model': 'HS',
              'year': 2024,
              'requests': 7,
              'last_count': 2,
              'takip_ilan': 0
            }
          ]
        });
      }
      if (r.url.path.endsWith('/manual/preview')) {
        expect(jsonDecode(r.body), {'text': 'ilan listesi'});
        return jsonResponse({
          'satirlar': [row1, row2],
          'atlanan': 1,
          'marka': 'MG'
        });
      }
      saved.add(jsonDecode(r.body) as Map<String, dynamic>);
      return jsonResponse({'eklenen': 1, 'tekrar': 0});
    });
    await mount(tester, client);
    expect(find.text('Verisi az olan modeller'), findsOneWidget);
    expect(find.text('MG'), findsOneWidget);
    final gapTable =
        tester.widget<DataTable>(find.byKey(const Key('marketGapsTable')));
    expect(gapTable.rows.single.color, isNotNull);
    await tester.enterText(
        find.byKey(const Key('marketPaste')), 'ilan listesi');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Önizle'));
    await tester.pumpAndSettle();
    expect(find.text('Luxury'), findsOneWidget);
    expect(find.text('Comfort'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('marketBrand')))
            .controller!
            .text,
        'MG');
    await tester.tap(find.byKey(const Key('removeMarketRow-0')));
    await tester.pump();
    expect(find.text('Luxury'), findsNothing);
    await tester.enterText(find.byKey(const Key('marketBrand')), '  ');
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Kaydet'))
            .onPressed,
        isNull);
    await tester.enterText(find.byKey(const Key('marketBrand')), ' MG ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();
    expect(saved, [
      {
        'brand': 'MG',
        'satirlar': [row2]
      }
    ]);
    expect(find.text('1 yeni kayıt, 0 zaten vardı'), findsOneWidget);
    expect(find.text('Comfort'), findsNothing);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('marketPaste')))
            .controller!
            .text,
        isEmpty);
    expect(gaps, 2);
  });

  testWidgets('422 ayrıntısı gösterilir; başarısız önizleme kaydedilemez',
      (tester) async {
    await mount(
        tester,
        MockClient((r) async => r.method == 'GET'
            ? jsonResponse({'modeller': []})
            : jsonResponse({'detail': 'İlan satırı bulunamadı.'}, 422)));
    await tester.enterText(
        find.byKey(const Key('marketPaste')), 'geçersiz liste');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Önizle'));
    await tester.pumpAndSettle();
    expect(find.text('İlan satırı bulunamadı.'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Kaydet'))
            .onPressed,
        isNull);
  });

  testWidgets('liste değişince eski önizleme kaydedilemez', (tester) async {
    await mount(
        tester,
        MockClient((r) async => jsonResponse(r.method == 'GET'
            ? {'modeller': []}
            : {
                'satirlar': [row1],
                'atlanan': 0,
                'marka': 'MG'
              })));
    await tester.enterText(find.byKey(const Key('marketPaste')), 'liste bir');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Önizle'));
    await tester.pumpAndSettle();
    expect(find.text('Luxury'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('marketPaste')), 'liste iki');
    await tester.pump();
    expect(find.text('Luxury'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Kaydet'))
            .onPressed,
        isNull);
  });

  testWidgets('marka bulunamazsa elle girilir; kayıt hatasında liste korunur',
      (tester) async {
    var gets = 0;
    await mount(tester, MockClient((r) async {
      if (r.method == 'GET') {
        gets++;
        return jsonResponse({'modeller': []});
      }
      if (r.url.path.endsWith('/preview')) {
        return jsonResponse({
          'satirlar': [row1],
          'marka': null,
          'atlanan': 0
        });
      }
      return jsonResponse(
          {'detail': 'Kaydetme başarısız, tekrar deneyin.'}, 503);
    }));
    await tester.enterText(find.byKey(const Key('marketPaste')), 'liste');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Önizle'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('marketBrand')))
            .controller!
            .text,
        isEmpty);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Kaydet'))
            .onPressed,
        isNull);
    await tester.enterText(find.byKey(const Key('marketBrand')), 'MG');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Kaydetme başarısız, tekrar deneyin.'), findsOneWidget);
    expect(find.text('Luxury'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('marketPaste')))
            .controller!
            .text,
        'liste');
    expect(gets, 1);
  });

  testWidgets('takip listesi yükleme hatası yeniden denenebilir',
      (tester) async {
    var gets = 0;
    await mount(tester, MockClient((r) async {
      gets++;
      return gets == 1
          ? jsonResponse({'detail': 'Piyasa listesi yüklenemedi.'}, 503)
          : jsonResponse({'modeller': []});
    }));
    expect(find.text('Piyasa listesi yüklenemedi.'), findsOneWidget);
    await tester.tap(find.text('Yenile'));
    await tester.pumpAndSettle();
    expect(find.text('Piyasa listesi yüklenemedi.'), findsNothing);
    expect(find.text('Şu anda verisi az olan model yok.'), findsOneWidget);
    expect(gets, 2);
  });

  testWidgets('dar ekranda tablolar taşmadan kaydırılabilir', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    await mount(
        tester,
        MockClient((r) async => jsonResponse(r.method == 'GET'
            ? {
                'modeller': [
                  {
                    'brand': 'MG',
                    'model': 'HS',
                    'year': 2024,
                    'requests': 7,
                    'last_count': 2,
                    'takip_ilan': 0
                  }
                ]
              }
            : {
                'satirlar': [row1],
                'marka': 'MG',
                'atlanan': 0
              })));
    await tester.enterText(find.byKey(const Key('marketPaste')), 'liste');
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Önizle'));
    await tester.tap(find.widgetWithText(FilledButton, 'Önizle'));
    await tester.pumpAndSettle();
    expect(find.text('Luxury'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('personel admin menüsünü ve Piyasa takibi ekranını göremez',
      (tester) async {
    final provider = StaffProvider();
    await tester.pumpWidget(ChangeNotifierProvider<UserProvider>.value(
      value: provider,
      child: const MaterialApp(home: AdminShell()),
    ));
    await tester.pump();
    expect(find.text('Yetkisiz Erişim'), findsOneWidget);
    expect(find.text('Piyasa takibi'), findsNothing);
    expect(find.byType(PiyasaTakibiModule), findsNothing);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
