import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/core/constants/roles.dart';
import 'package:yerimebak_sistemleri/models/personel_model.dart';
import 'package:yerimebak_sistemleri/services/personel_service.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

/// Kurumsal firma modeli (037; 9 Kasım 2026): personel firmaya bağlanır, firmasız YerimeBak personeli de olur.
void main() {
  test('personel firması sunucudan okunur ve kayıtta firm_id gider', () async {
    final gonderilen = <Map<String, dynamic>>[];
    final client = MockClient((r) async {
      final body = jsonDecode(r.body.isEmpty ? '{}' : r.body) as Map<String, dynamic>;
      if (r.method == 'POST') gonderilen.add(body);  // ardından kapsam (GET) yüklenir
      return http.Response(
        jsonEncode({
          'personnel': {
            'id': '9', 'full_name': 'Saha Bir', 'email': 's@x.test', 'city': 'İstanbul', 'district': 'Kadıköy',
            'il_id': 34, 'region_id': 1, 'firm_id': body['firm_id'], 'firm_name': body['firm_id'] == 'otorapor' ? 'Otorapor' : '',
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final servis = PersonelService()
      ..apiServiceForTesting = YerimebakExpertizApiService(baseUrl: 'http://api.test/api/v1', client: client, accessToken: 't');
    PersonelModel model(String? firma) => PersonelModel(
          id: '', ad: 'Saha', soyad: 'Bir', unvan: 'Kaporta', ilId: 34, bolgeId: 1, email: 's@x.test',
          sifre: 'Personel123', rol: UserRole.fieldStaff, il: 'İstanbul', ilce: 'Kadıköy', firmaId: firma);

    final firmali = await servis.addPersonel(model('otorapor'));
    expect(gonderilen.last['firm_id'], 'otorapor');
    expect(firmali.firmaId, 'otorapor');
    expect(firmali.firmaAdi, 'Otorapor');

    final firmasiz = await servis.addPersonel(model(null));
    expect(gonderilen.last['firm_id'], '');
    expect(firmasiz.firmaAdi, '');
  });
}
