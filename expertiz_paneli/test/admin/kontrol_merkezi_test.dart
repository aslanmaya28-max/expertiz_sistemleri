import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/admin/modules/kontrol_merkezi_module.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _gorev(String id, String saat, String stage, {String satici = '05321112233'}) => {
      'id': id,
      'vehicle': {'title': 'Fiat Egea 2019'},
      'city': 'İstanbul',
      'district': 'Kadıköy',
      'firm_name': 'Örnek Ekspertiz',
      'stage': stage,
      'stage_label': stage,
      'customer': {'name': 'Ayşe Müşteri', 'phone': '05551112233'},
      'randevu': {'tarih_saat': saat, 'adres': 'Moda Cad. No 10', 'satici_adi': 'Ali', 'satici_telefon': satici},
      'assignment': {'personnel_name': 'Saha Bir', 'personnel_phone': ''},
      'son_iletisim': null,
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

  testWidgets('kontrol merkezi: randevu sırası, gecikme uyarısı, arama ve sonuç kaydı', (tester) async {
    final gonderilen = <Map<String, dynamic>>[];
    final acilan = <Uri>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/admin/control-center/tasks')) {
        return _json({
          'ayarlar': {'telefon': '08501112233', 'calisma_saatleri': '08.00–20.00', 'tanimli': true},
          // Sunucu randevu sırasıyla gönderir
          'gorevler': [_gorev('a', '2026-11-10T10:30', 'assigned'), _gorev('b', '2026-11-10T15:00', 'on_the_way', satici: '')],
        });
      }
      if (request.url.path.endsWith('/contact-log') && request.method == 'POST') {
        gonderilen.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _json({'success': true});
      }
      return _json({});
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: KontrolMerkeziModule(
          apiService: YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', client: client, accessToken: 't'),
          telefonAc: (uri) async {
            acilan.add(uri);
            return true;
          },
          simdi: () => DateTime(2026, 11, 10, 10, 0),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('08501112233'), findsOneWidget);
    expect(find.text('10.11.2026 10:30'), findsOneWidget);
    expect(find.text('10.11.2026 15:00'), findsOneWidget);
    // 'a' randevuya 30 dk kala hâlâ 'atandı' → uyarı; 'b' yolda ve 5 saat var → uyarı yok
    expect(find.text('Randevuya 1 saatten az kaldı, personel yola çıkmadı'), findsOneWidget);
    // Numarası olmayan düğmeler pasif (b'nin satıcı telefonu, personel telefonu boş)
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('ara-satici-b'))).onPressed, isNull);
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('ara-personel-a'))).onPressed, isNull);

    await tester.tap(find.byKey(const Key('ara-musteri-a')));
    await tester.pumpAndSettle();
    expect(acilan.single.toString(), 'tel:05551112233');
    expect(find.text('Müşteri araması — sonuç'), findsOneWidget);
    await tester.tap(find.text('Mesaj bırakıldı'));
    await tester.enterText(find.widgetWithText(TextField, 'Not (isteğe bağlı)'), 'Sesli mesaj');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(gonderilen.single, {'hedef': 'musteri', 'sonuc': 'mesaj_birakildi', 'note': 'Sesli mesaj'});
  });

  testWidgets('numara girilmemişse uyarı gösterilir', (tester) async {
    final client = MockClient((request) async => _json({'ayarlar': {'telefon': '', 'tanimli': false}, 'gorevler': []}));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: KontrolMerkeziModule(
          apiService: YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', client: client, accessToken: 't'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kontrol merkezi numarası girilmedi'), findsOneWidget);
    expect(find.text('Açık görev yok.'), findsOneWidget);
  });
}
