import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/core/constants/roles.dart';
import 'package:yerimebak_sistemleri/core/mappers/location_mapper.dart';
import 'package:yerimebak_sistemleri/services/personel_service.dart';
import 'package:yerimebak_sistemleri/services/talep_service.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

void main() {
  test('müşteri talebi ödeme başlatmadan yönetici kuyruğu yoluna gönderilir', () async {
    final api = YerimebakExpertizApiService(
      accessToken: 'token',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/expertiz/requests/unpaid');
        expect(jsonDecode(request.body)['vehicle'], {'brand': 'Ford', 'model': 'Focus'});
        return http.Response('{"success":true,"request_id":"r1","payment_status":"not_collected"}', 200);
      }),
    );
    final result = await api.createExpertizRequest(
      firmId: 'f', packageId: 'p', city: 'İstanbul', district: 'Kadıköy',
      vehicle: {'brand': 'Ford', 'model': 'Focus'},
    );
    expect(result['request_id'], 'r1');
    expect(result['payment_status'], 'not_collected');
  });
  group('YerimebakExpertizApiService dispatch endpoints', () {
    test('assignRequest posts personnel id and note', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/expertiz/admin/requests/req-1/assign');
        expect(jsonDecode(request.body), {'personnel_id': '7', 'note': 'Acil'});
        return http.Response(jsonEncode({'success': true}), 200);
      });
      final api = YerimebakExpertizApiService(client: client, accessToken: 't');
      final result = await api.assignRequest('req-1', '7', note: 'Acil');
      expect(result['success'], isTrue);
    });

    test('removePersonnel sends DELETE with reason', () async {
      final client = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/personnel/admin/personnel/5');
        expect(jsonDecode(request.body), {'reason': 'Ayrildi'});
        return http.Response(jsonEncode({'success': true, 'released_task_count': 2}), 200);
      });
      final api = YerimebakExpertizApiService(client: client, accessToken: 't');
      final result = await api.removePersonnel('5', reason: 'Ayrildi');
      expect(result['released_task_count'], 2);
    });

    test('getAdminRequests sends region filter only when set', () async {
      final urls = <String>[];
      final client = MockClient((request) async {
        urls.add(request.url.toString());
        return http.Response(jsonEncode({'requests': [], 'counts': {}}), 200);
      });
      final api = YerimebakExpertizApiService(client: client, accessToken: 't');
      await api.getAdminRequests();
      await api.getAdminRequests(regionId: 3, bucket: 'waiting_assignment');
      expect(urls.first, 'http://localhost:8000/api/v1/expertiz/admin/requests');
      expect(urls.last, contains('region_id=3'));
      expect(urls.last, contains('bucket=waiting_assignment'));
    });

    test('FastAPI validation errors become readable messages', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': [
              {'loc': ['body', 'personnel_id'], 'msg': 'Field required'},
            ],
          }),
          422,
        );
      });
      final api = YerimebakExpertizApiService(client: client, accessToken: 't');
      expect(
        () => api.assignRequest('req-1', ''),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Field required')),
      );
    });
  });

  group('Mapping', () {
    test('backend personel role maps to field staff', () {
      expect(UserRole.fromString('personel'), UserRole.fieldStaff);
      expect(UserRole.fromString('field_staff'), UserRole.fieldStaff);
      expect(UserRole.fromString('user'), UserRole.customer);
      expect(UserRole.fromString('admin'), UserRole.admin);
    });

    test('LocationMapper knows all 81 provinces with official regions', () {
      final mapper = LocationMapper();
      expect(mapper.getAllIlIds().length, 81);
      expect(mapper.getIlId('İSTANBUL'), 34);
      expect(mapper.getIlId('istanbul / Kadıköy'), 34);
      expect(mapper.getIlId('Iğdır'), 76);
      expect(mapper.getBolgeAdi(mapper.getBolgeIdFromIlId(36)), 'Doğu Anadolu'); // Kars
      expect(mapper.getBolgeAdi(mapper.getBolgeIdFromIlId(19)), 'Karadeniz'); // Çorum
      expect(mapper.getIlAdi(1), 'Adana');
    });

    test('PersonelService.fromApi fills il and region ids', () {
      final personel = PersonelService().fromApi({
        'id': '12',
        'full_name': 'Ali Veli',
        'email': 'ali@x.com',
        'role': 'field_staff',
        'active': true,
        'city': 'Ankara',
        'district': 'Çankaya',
        'il_id': 6,
        'region_id': 2,
        'region': 'İç Anadolu',
        'expertise': 'Mekanik',
      });
      expect(personel.id, '12');
      expect(personel.ilId, 6);
      expect(personel.bolgeId, 2);
      expect(personel.bolge, 'İç Anadolu');
      expect(personel.aktif, isTrue);
      expect(personel.rol, UserRole.fieldStaff);
    });

    test('TalepService.fromApiRequest maps dispatch state', () {
      final talep = TalepService.fromApiRequest({
        'id': 'r1',
        'bucket': 'in_progress',
        'status': 'draft',
        'created_at': '2026-10-11T10:00:00+00:00',
        'customer': {'id': 'c1', 'name': 'Ayşe', 'phone': '0555'},
        'vehicle': {'plate': '34 AB 12', 'brand': 'Fiat', 'model': 'Egea'},
        'city': 'İstanbul',
        'firm_name': 'Pilot Garage',
        'package_name': 'Standart',
        'total_tl': 12000,
        'assignment': {'status': 'accepted', 'personnel_id': '7'},
      });
      expect(talep.durum, 'Kabul Edildi');
      expect(talep.atananPersonel, '7');
      expect(talep.aracPlaka, '34 AB 12');
      expect(talep.toplamTutar, 12000);
    });
  });
}
