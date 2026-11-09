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
  testWidgets('dikkat bağlantısı iade bekleyen talepleri ilgili kovada açar', (tester) async {
    final client = MockClient((_) async => _json({
      'requests': [
        {..._talep('in_progress'), 'vehicle': {'title': 'İade bekleyen araç'}, 'durum_kodu': 'vehicle_not_found'},
        {..._talep('in_progress'), 'id': 'R2', 'vehicle': {'title': 'Devam eden araç'}},
      ],
      'counts': {'in_progress': 2},
    }));
    await tester.pumpWidget(MaterialApp(home: AracOperasyonu(
      initialBucket: 'in_progress',
      refundOnly: true,
      apiService: YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', client: client, accessToken: 'admin-token'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('İade bekleyen araç'), findsOneWidget);
    expect(find.text('Devam eden araç'), findsNothing);
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'İade kararı bekleyen')).selected, isTrue);
    await tester.tap(find.widgetWithText(FilterChip, 'İade kararı bekleyen'));
    await tester.pumpAndSettle();
    expect(find.text('Devam eden araç'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

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

    await tester.tap(find.byTooltip('Talep ayrıntısı'));
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

  Future<void> bekle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  YerimebakExpertizApiService api(http.Client c) =>
      YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', client: c, accessToken: 'admin-token');

  testWidgets('arac adreste yok: paket ucreti iadesi gerekceyle yapilir (037)', (tester) async {
    var bucket = 'in_progress';
    http.Request? iade;
    final client = MockClient((r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/not-found-refund')) {
        iade = r;
        bucket = 'cancelled';
        return _json({'success': true, 'refund_tl': 2000.0, 'kept_tl': 5000.0, 'status': 'cancelled'});
      }
      return _json({
        'requests': [
          {
            ..._talep(bucket),
            'durum_kodu': 'vehicle_not_found',
            'vehicle': {'title': 'Skoda Kamiq'},
            'assignment': {'status': 'vehicle_not_found', 'personnel_name': 'Saha Bir'},
          }
        ],
        'counts': {bucket: 1},
      });
    });
    await tester.pumpWidget(MaterialApp(home: AracOperasyonu(apiService: api(client))));
    await bekle(tester);
    await tester.tap(find.textContaining('İşlemdeki').first);
    await bekle(tester);

    expect(find.text('Araç adreste yok'), findsOneWidget);
    expect(find.text('Yeniden Ata'), findsNothing, reason: 'saha kapandı; yönetim kararı bekleniyor');
    await tester.tap(find.byTooltip('Talep ayrıntısı'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('bulunamadi-iade-R1')));
    await tester.tap(find.byKey(const Key('bulunamadi-iade-R1')));
    await bekle(tester);
    await tester.enterText(find.byKey(const Key('bulunamadi-neden')), 'Satıcı aracı satmış');
    await tester.tap(find.byKey(const Key('bulunamadi-iade-onay')));
    await bekle(tester);

    expect(iade!.url.path, '/api/v1/expertiz/admin/requests/R1/not-found-refund');
    expect(jsonDecode(iade!.body), {'reason': 'Satıcı aracı satmış'});
    expect(find.textContaining('2.000 TL paket ücreti iade edildi, 5.000 TL hizmet bedeli kaldı'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('detayda randevu ve kontrol merkezi iletisim gecmisi gorunur (037)', (tester) async {
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/contact-log')) {
        return _json({
          'success': true,
          'kayitlar': [
            {'hedef': 'satici', 'sonuc': 'ulasilamadi', 'actor_name': 'Kontrol Ayşe', 'note': 'Telefon kapalı',
             'created_at': '2026-11-10T09:00:00+03:00'},
          ],
        });
      }
      return _json({
        'requests': [
          {
            ..._talep('waiting_assignment'),
            'vehicle': {'title': 'Skoda Kamiq'},
            'randevu': {
              'tarih_saat': '2026-11-10T14:30:00+03:00',
              'adres': 'Kadıköy Moda Cd. No 5',
              'satici_adi': 'Mehmet Satıcı',
              'satici_telefon': '05321112233',
            },
          }
        ],
        'counts': {'waiting_assignment': 1},
      });
    });
    await tester.pumpWidget(MaterialApp(home: AracOperasyonu(apiService: api(client))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Randevu: '), findsOneWidget);
    await tester.tap(find.text('Skoda Kamiq'));
    await tester.pumpAndSettle();
    expect(find.text('Kadıköy Moda Cd. No 5'), findsOneWidget);
    expect(find.text('Mehmet Satıcı'), findsOneWidget);
    expect(find.text('05321112233'), findsOneWidget);
    expect(find.byKey(const Key('iletisim-gecmisi')), findsOneWidget);
    expect(find.text('Satıcı · Ulaşılamadı'), findsOneWidget);
    expect(find.textContaining('Telefon kapalı'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('atama penceresi talep firmasini ve personel firmasini gosterir, firma hatasini aciklar (037)',
      (tester) async {
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/candidates')) {
        return _json({
          'success': true,
          'firm_id': 'otorapor',
          'recommended_id': 'P1',
          'candidates': [
            {'id': 'P1', 'full_name': 'Firma Personeli', 'city': 'İstanbul', 'district': 'Kadıköy', 'region': 'Marmara',
             'match': 'same_district', 'assignable': true, 'open_task_count': 0, 'firm_id': 'otorapor', 'firm_name': 'Otorapor'},
            {'id': 'P2', 'full_name': 'Koordinatör', 'city': 'İstanbul', 'district': 'Şişli', 'region': 'Marmara',
             'match': 'same_city', 'assignable': true, 'open_task_count': 1, 'firm_id': '', 'firm_name': ''},
          ],
        });
      }
      if (r.method == 'POST' && r.url.path.endsWith('/assign')) {
        return _json({'detail': {'message': 'Firma uyuşmuyor', 'code': 'firma_uyusmuyor'}}, 409);
      }
      return _json({
        'requests': [
          {..._talep('waiting_assignment'), 'vehicle': {'title': 'Skoda Kamiq'}, 'firm_name': 'Otorapor'}
        ],
        'counts': {'waiting_assignment': 1},
      });
    });
    await tester.pumpWidget(MaterialApp(home: AracOperasyonu(apiService: api(client))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Talep ayrıntısı'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Personel Ata'));
    await tester.tap(find.text('Personel Ata'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('atama-firma-basligi')), findsOneWidget);
    expect(find.textContaining('Talep firması: Otorapor'), findsOneWidget);
    expect(find.textContaining('• Otorapor'), findsOneWidget);
    expect(find.textContaining('YerimeBak (firmasız)'), findsOneWidget);
    await tester.tap(find.text('Personele Gönder'));
    await tester.pumpAndSettle();
    expect(find.textContaining('başka bir firmaya bağlı'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
