import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/admin/widgets/hizmet_ayarlari.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

YerimebakExpertizApiService _api(http.Client c) =>
    YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', client: c, accessToken: 't');

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1000, 1600);
    view.devicePixelRatio = 1.0;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('hizmet bölgeleri: yalnız değişen iller gider, açarken onay sorulur', (tester) async {
    final gonderilen = <Object?>[];
    final client = MockClient((r) async {
      if (r.method == 'PUT') {
        gonderilen.add(jsonDecode(r.body));
        return _json({'success': true});
      }
      return _json({
        'pilot': 'İstanbul',
        'cities': [
          {'il': 'Adana', 'durum': 'kapali'},
          {'il': 'Ankara', 'durum': 'kapali'},
          {'il': 'İstanbul', 'durum': 'acik'},
        ],
      });
    });
    await tester.pumpWidget(MaterialApp(home: HizmetBolgeleriSayfasi(api: _api(client))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Açık 1 · Test 0 · Kapalı 2'), findsOneWidget);

    Future<void> sec(String il, String etiket) async {
      await tester.tap(find.descendant(of: find.byKey(Key('il-$il')), matching: find.byType(DropdownButton<String>)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(etiket).last);
      await tester.pumpAndSettle();
    }

    await sec('Ankara', 'Test');
    await sec('Adana', 'Açık');
    expect(find.text('Kaydet (2)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('hizmet-bolgeleri-kaydet')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Adana: Bu ildeki herkes talep ve ödeme yapabilir'), findsOneWidget);
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(gonderilen.single, {
      'cities': [
        {'il': 'Adana', 'durum': 'acik'},
        {'il': 'Ankara', 'durum': 'test'},
      ],
    });
    expect(find.text('Kaydet'), findsOneWidget);
  });

  testWidgets('kontrol merkezi penceresi numarayı kaydeder, hatayı gösterir', (tester) async {
    final gonderilen = <Object?>[];
    var hatali = true;
    final client = MockClient((r) async {
      if (r.method == 'PUT') {
        gonderilen.add(jsonDecode(r.body));
        if (hatali) {
          hatali = false;
          return http.Response(jsonEncode({'detail': {'message': 'Telefon geçersiz', 'code': 'telefon_gecersiz'}}), 422,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return _json({'success': true});
      }
      return _json({'telefon': '', 'calisma_saatleri': '', 'tanimli': false});
    });
    bool? sonuc;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => sonuc = await kontrolMerkeziAyariAc(context, _api(client)),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Kontrol merkezi telefonu'), '123');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Telefon geçersiz'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Kontrol merkezi telefonu'), '0850 111 22 33');
    await tester.enterText(find.widgetWithText(TextField, 'Çalışma saatleri'), 'Her gün 08.00–20.00');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(sonuc, isTrue);
    expect(gonderilen.last, {'telefon': '0850 111 22 33', 'calisma_saatleri': 'Her gün 08.00–20.00'});
  });
}
