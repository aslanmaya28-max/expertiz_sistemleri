import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/personnel/personnel_dashboard.dart';
import 'package:yerimebak_sistemleri/tema/tema.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

http.Response _json(Object body, [int code = 200]) =>
    http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _task(String id, String bucket, String stage, List<String> actions, {String? reason}) => {
      'id': id,
      'status': {'active': 'draft', 'pending': 'pending_admin', 'rejected': 'rejected', 'approved': 'published'}[bucket],
      'personnel_bucket': bucket,
      'city': 'İzmir',
      'district': 'Karşıyaka',
      'corporate_required': true,
      'firm_name': 'Otorapor',
      'package_name': 'Gold Paket',
      'rejection_reason': reason,
      'next_actions': actions,
      'vehicle': {'plate': '35 KSK $id', 'title': 'Fiat Egea $id'},
      'customer': {'name': 'Ayşe Müşteri', 'phone': '0555'},
      'assignment': {'status': stage, 'assigned_at': '2026-10-12T10:00:00Z'},
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

  testWidgets('personel gorev durumunu degistirir, saha adimi atar, bolumleri gorur', (tester) async {
    var onDuty = true;
    var stage = 'accepted';
    var unread = 2;
    final calls = <String>[];
    final client = MockClient((request) async {
      final path = request.url.path;
      calls.add('${request.method} $path');
      if (path.endsWith('/expertiz/personnel/me')) {
        return _json({'personnel': {'full_name': 'Kemal Saha', 'city': 'İzmir', 'district': 'Karşıyaka', 'on_duty': onDuty}});
      }
      if (path.endsWith('/expertiz/personnel/me/duty')) {
        onDuty = (jsonDecode(request.body) as Map)['on_duty'] as bool;
        return _json({'personnel': {'full_name': 'Kemal Saha', 'on_duty': onDuty}});
      }
      if (path.endsWith('/expertiz/personnel/tasks')) {
        final actions = stage == 'accepted' ? ['depart', 'arrive', 'corporate', 'start'] : ['arrive', 'corporate', 'start'];
        return _json({
          'tasks': [
            _task('1', 'active', stage, actions),
            _task('2', 'pending', 'submitted', []),
            _task('3', 'rejected', 'submitted', ['start'], reason: 'Motor fotoğrafı eksik'),
            _task('4', 'approved', 'submitted', []),
          ],
        });
      }
      if (path.endsWith('/tasks/1/depart')) {
        stage = 'on_the_way';
        return _json({'success': true});
      }
      if (path.endsWith('/expertiz/notifications')) {
        return _json({
          'unread': unread,
          'notifications': [
            {'id': 9, 'kind': 'report_rejected', 'title': 'Raporunuz düzeltme için geri gönderildi', 'body': 'Motor fotoğrafı eksik', 'created_at': '2026-10-12T11:00:00Z', 'read': false},
            {'id': 8, 'kind': 'task_assigned', 'title': 'Yeni görev atandı', 'body': '35 KSK 1', 'created_at': '2026-10-12T10:00:00Z', 'read': false},
          ],
        });
      }
      if (path.endsWith('/expertiz/notifications/read')) {
        unread = 0;
        return _json({'success': true, 'updated': 2});
      }
      return _json({'detail': 'Not Found'}, 404);
    });

    await tester.pumpWidget(MaterialApp(
      home: PersonnelDashboard(
        refreshInterval: const Duration(hours: 1),
        apiService: YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', client: client, accessToken: 'p'),
      ),
    ));
    await tester.pumpAndSettle();

    // Bolumler
    expect(find.text('Aktif (1)'), findsOneWidget);
    expect(find.text('Beklemede (1)'), findsOneWidget);
    expect(find.text('Reddedildi (1)'), findsOneWidget);
    expect(find.text('Tamamlanan (1)'), findsOneWidget);
    expect(find.textContaining('Görev için AKTİF'), findsOneWidget);
    expect(find.text('İzmir / Karşıyaka'), findsWidgets);

    // Saha adimi: harekete gectim
    expect(find.text('Harekete Geçtim'), findsOneWidget);
    await tester.tap(find.byKey(const Key('action-1-depart')));
    await tester.pumpAndSettle();
    expect(calls, contains('POST /api/v1/expertiz/personnel/tasks/1/depart'));
    expect(find.text('Harekete geçti'), findsOneWidget);
    expect(find.text('Araç Başındayım'), findsOneWidget);

    // Gorev icin pasif
    await tester.tap(find.byKey(const Key('dutySwitch')));
    await tester.pumpAndSettle();
    expect(calls, contains('PUT /api/v1/expertiz/personnel/me/duty'));
    expect(find.textContaining('Görev için PASİF'), findsOneWidget);

    // Reddedilen rapor: neden ve duzeltme dugmesi
    await tester.tap(find.text('Reddedildi (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Admin notu: Motor fotoğrafı eksik'), findsOneWidget);
    expect(find.text('Düzeltmeye Başla'), findsOneWidget);

    await tester.tap(find.text('Beklemede (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Admin kontrolünde'), findsOneWidget);

    await tester.tap(find.text('Tamamlanan (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Onaylandı'), findsOneWidget);

    // Bildirimler: acinca okundu yapilir
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notificationsButton')));
    await tester.pumpAndSettle();
    expect(calls, contains('POST /api/v1/expertiz/notifications/read'));
    expect(find.text('Raporunuz düzeltme için geri gönderildi'), findsOneWidget);
    expect(find.text('Yeni görev atandı'), findsOneWidget);
  });

  testWidgets('saha yalniz kontrol merkezine baglanir; arac adreste yok yalniz uygun asamada ve not zorunlu (037)',
      (tester) async {
    final gonderilen = <String, Object?>{};
    final acilan = <Uri>[];
    var telefon = '0850 111 22 33';
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/expertiz/personnel/me')) {
        return _json({'personnel': {'full_name': 'Kemal Saha', 'on_duty': true}});
      }
      if (path.endsWith('/expertiz/personnel/tasks')) {
        return _json({
          'kontrol_merkezi': {'telefon': telefon, 'calisma_saatleri': 'Her gün 08.00–20.00', 'tanimli': telefon.isNotEmpty},
          'tasks': [
            _task('A', 'active', 'accepted', ['depart']),
            {
              ..._task('B', 'active', 'at_vehicle', ['corporate', 'start']),
              'customer': {'name': 'Ayşe M.'},
              'randevu': {'tarih_saat': '2026-11-10T14:30:00+03:00', 'adres': 'Bostanlı Mah. 1. Sok. No 3', 'satici_adi': 'Mehmet Bey'},
            },
          ],
        });
      }
      if (path.endsWith('/expertiz/notifications')) return _json({'unread': 0, 'notifications': []});
      if (request.method == 'POST') {
        gonderilen[path] = jsonDecode(request.body);
        return _json({'success': true});
      }
      return _json({'detail': 'Not Found'}, 404);
    });
    final api = YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', client: client, accessToken: 'p');
    await tester.pumpWidget(MaterialApp(
      home: PersonnelDashboard(
        refreshInterval: const Duration(hours: 1),
        apiService: api,
        baglantiAc: (uri) async {
          acilan.add(uri);
          return true;
        },
      ),
    ));
    await tester.pumpAndSettle();

    // Müşteri/satıcı numarası yok; randevu ve satıcı adı var
    expect(find.textContaining('0555'), findsNothing);
    expect(find.text('Satıcı: Mehmet Bey'), findsOneWidget);
    expect(find.textContaining('Randevu: '), findsOneWidget);
    await tester.tap(find.byKey(const Key('harita-B')));
    await tester.pumpAndSettle();
    expect(acilan.last.host, 'www.google.com');
    expect(acilan.last.queryParameters['query'], contains('Bostanlı Mah.'));

    // Kontrol merkezini ara
    await tester.tap(find.byKey(const Key('kontrol-ara-B')));
    await tester.pumpAndSettle();
    expect(acilan.last.toString(), 'tel:08501112233');

    // Kontrol merkezine not: hazır seçenek
    await tester.tap(find.byKey(const Key('kontrol-not-B')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gecikeceğim'));
    await tester.tap(find.byKey(const Key('kontrol-not-gonder')));
    await tester.pumpAndSettle();
    expect(gonderilen['/api/v1/expertiz/personnel/tasks/B/control-note'], {'note': 'Gecikeceğim'});

    // Araç adreste yok: kabul aşamasında yok, araç başında var
    expect(find.byKey(const Key('bulunamadi-A')), findsNothing);
    await tester.tap(find.byKey(const Key('bulunamadi-B')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Satıcıyı aradınız mı? Bu işlem görevi kapatır.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('bulunamadi-gonder'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('bulunamadi-onay')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bulunamadi-notu')), 'Yok');
    await tester.tap(find.byKey(const Key('bulunamadi-gonder')));
    await tester.pumpAndSettle();
    expect(find.text('En az 10 karakterle ne olduğunu yazın'), findsOneWidget);
    expect(gonderilen.keys.where((k) => k.endsWith('/not-found')), isEmpty);
    await tester.enterText(find.byKey(const Key('bulunamadi-notu')), 'Satıcı aracı başka şehre götürmüş');
    await tester.tap(find.byKey(const Key('bulunamadi-gonder')));
    await tester.pumpAndSettle();
    expect(gonderilen['/api/v1/expertiz/personnel/tasks/B/not-found'], {'note': 'Satıcı aracı başka şehre götürmüş'});

    // Numara tanımlı değilse düğme pasif ve uyarı görünür
    telefon = '';
    await tester.tap(find.byTooltip('Yenile'));
    await tester.pumpAndSettle();
    expect(find.text('Kontrol merkezi numarası henüz girilmedi'), findsWidgets);
    expect(tester.widget<FilledButton>(find.byKey(const Key('kontrol-ara-A'))).onPressed, isNull);
  });

  for (final koyu in [false, true]) {
    testWidgets('saha mobil alt menüsü ve arama alanı ${koyu ? "koyu" : "açık"} temada korunur', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      final acilan = <Uri>[];
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/personnel/me')) {
          return _json({'personnel': {'full_name': 'Kemal Saha', 'on_duty': true}});
        }
        if (request.url.path.endsWith('/personnel/tasks')) {
          return _json({
            'kontrol_merkezi': {'telefon': '0850 111 22 33'},
            'tasks': [_task('mobil', 'active', 'accepted', ['depart'])],
          });
        }
        return _json({'unread': 0, 'notifications': []});
      });
      await tester.pumpWidget(MaterialApp(
        theme: koyu ? YbTema.koyu : YbTema.acik,
        home: PersonnelDashboard(
          refreshInterval: const Duration(hours: 1),
          apiService: YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', client: client, accessToken: 'p'),
          baglantiAc: (uri) async { acilan.add(uri); return true; },
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      final ara = find.byKey(const Key('kontrol-ara-mobil'));
      await tester.ensureVisible(ara);
      expect(tester.getSize(ara).height, greaterThanOrEqualTo(44));
      await tester.tap(ara);
      await tester.pumpAndSettle();
      expect(acilan.single.toString(), 'tel:08501112233');
      await tester.tap(find.text('Beklemede (0)'));
      await tester.pumpAndSettle();
      expect(find.text('Admin kontrolünde rapor yok'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

}
