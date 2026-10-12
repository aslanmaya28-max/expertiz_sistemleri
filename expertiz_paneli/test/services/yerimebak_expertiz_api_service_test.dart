import 'dart:convert';

import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/services/central_auth_client.dart';

void main() {
  tearDown(() {
    CentralAuthTokenStore.accessToken = null;
  });

  test('uses central auth token when explicit token is not provided', () async {
    CentralAuthTokenStore.accessToken = 'central-token';
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer central-token');
      return http.Response(jsonEncode({'success': true}), 200);
    });

    final service = YerimebakExpertizApiService(client: client);
    final result = await service.publishReport('report-central');

    expect(result['success'], isTrue);
  });

  test('publishReport posts to central admin publish endpoint with bearer token', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'http://localhost:8000/api/v1/expertiz/admin/reports/report-1/publish',
      );
      expect(request.headers['Authorization'], 'Bearer token-1');
      return http.Response(jsonEncode({'success': true}), 200);
    });

    final service = YerimebakExpertizApiService(
      client: client,
      accessToken: 'token-1',
    );

    final result = await service.publishReport('report-1');

    expect(result['success'], isTrue);
  });

  test('publishReport sends optional admin note and reanalyze hits admin endpoint', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.url.path} ${request.body}');
      return http.Response(jsonEncode({'success': true}), 200);
    });
    final service = YerimebakExpertizApiService(client: client, accessToken: 't');

    await service.publishReport('r9', adminNote: '  Pazarlıkta değişenleri dikkate alın ');
    await service.reanalyzeReport('r9');

    expect(calls[0], '/api/v1/expertiz/admin/reports/r9/publish {"admin_note":"Pazarlıkta değişenleri dikkate alın"}');
    expect(calls[1], '/api/v1/expertiz/admin/reports/r9/reanalyze {}');
  });

  test('rejectReport posts reason to central admin reject endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'http://localhost:8000/api/v1/expertiz/admin/reports/report-2/reject',
      );
      expect(jsonDecode(request.body), {'reason': 'Eksik fotograf var'});
      return http.Response(jsonEncode({'success': true}), 200);
    });

    final service = YerimebakExpertizApiService(
      client: client,
      accessToken: 'token-2',
    );

    final result = await service.rejectReport('report-2', 'Eksik fotograf var');

    expect(result['success'], isTrue);
  });

  test('central API errors surface as exceptions', () async {
    final client = MockClient((request) async {
      return http.Response(jsonEncode({'detail': 'Admin yetkisi gerekli'}), 403);
    });
    final service = YerimebakExpertizApiService(
      client: client,
      accessToken: 'token-3',
    );

    expect(
      () => service.publishReport('report-3'),
      throwsA(predicate((error) => error.toString().contains('Admin yetkisi gerekli'))),
    );
  });

  test('getPersonnelCoverage reads central personnel coverage endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        'http://localhost:8000/api/v1/personnel/admin/coverage',
      );
      return http.Response(jsonEncode({'success': true, 'missing_cities': ['Ankara']}), 200);
    });

    final service = YerimebakExpertizApiService(
      client: client,
      accessToken: 'token-4',
    );

    final result = await service.getPersonnelCoverage();

    expect(result['missing_cities'], ['Ankara']);
  });

  test('createPersonnel posts full personnel payload', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'http://localhost:8000/api/v1/personnel/admin/personnel',
      );
      expect(jsonDecode(request.body), {
        'full_name': 'Ayse Yilmaz',
        'email': 'ayse@yerimebak.ai',
        'phone': '+905551112233',
        'city': 'Istanbul',
        'district': 'Kadikoy',
        'expertise': 'Kaporta',
        'temporary_password': 'Gecici-12345',
      });
      return http.Response(jsonEncode({'success': true}), 200);
    });

    final service = YerimebakExpertizApiService(
      client: client,
      accessToken: 'token-5',
    );

    final result = await service.createPersonnel({
      'full_name': 'Ayse Yilmaz',
      'email': 'ayse@yerimebak.ai',
      'phone': '+905551112233',
      'city': 'Istanbul',
      'district': 'Kadikoy',
      'expertise': 'Kaporta',
      'temporary_password': 'Gecici-12345',
    });

    expect(result['success'], isTrue);
  });

  test('deactivatePersonnel posts reason to access lock endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'http://localhost:8000/api/v1/personnel/admin/personnel/staff-1/deactivate',
      );
      expect(jsonDecode(request.body), {'reason': 'Disiplin incelemesi'});
      return http.Response(jsonEncode({'success': true}), 200);
    });

    final service = YerimebakExpertizApiService(
      client: client,
      accessToken: 'token-6',
    );

    final result = await service.deactivatePersonnel('staff-1', 'Disiplin incelemesi');

    expect(result['success'], isTrue);
  });

  test('resetPersonnelPassword posts temporary password', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'http://localhost:8000/api/v1/personnel/admin/personnel/staff-1/reset-password',
      );
      expect(jsonDecode(request.body), {'temporary_password': 'Yeni-12345'});
      return http.Response(jsonEncode({'success': true, 'must_change_password': true}), 200);
    });

    final service = YerimebakExpertizApiService(
      client: client,
      accessToken: 'token-7',
    );

    final result = await service.resetPersonnelPassword('staff-1', 'Yeni-12345');

    expect(result['must_change_password'], isTrue);
  });
  test('triggerCentralAnalysis posts to admin reanalyze endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'http://localhost:8000/api/v1/expertiz/admin/reports/report-9/reanalyze');
      return http.Response(jsonEncode({'success': true, 'status': 'pending_admin'}), 200);
    });

    final service = YerimebakExpertizApiService(client: client, accessToken: 'token-9');
    final result = await service.triggerCentralAnalysis('report-9');

    expect(result['success'], isTrue);
    expect(result['status'], 'pending_admin');
  });

  test('getAnalysisStatus reads central analysis status endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'http://localhost:8000/api/v1/status/report-10');
      return http.Response(jsonEncode({'success': true, 'ai_analizi_yapildi_mi': true}), 200);
    });

    final service = YerimebakExpertizApiService(client: client, accessToken: 'token-10');
    final result = await service.getAnalysisStatus('report-10');

    expect(result['ai_analizi_yapildi_mi'], isTrue);
  });
}
