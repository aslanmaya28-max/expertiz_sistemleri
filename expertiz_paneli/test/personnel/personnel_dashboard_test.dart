import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/personnel/personnel_dashboard.dart';
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
}
