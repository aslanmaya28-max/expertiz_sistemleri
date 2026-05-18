import 'package:yerimebak_sistemleri/models/personel_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromMap accepts central personnel API fields', () {
    final personel = PersonelModel.fromMap({
      'id': 'staff-1',
      'full_name': 'Ayse Yilmaz',
      'email': 'ayse@yerimebak.ai',
      'phone': '+905551112233',
      'role': 'personel',
      'active': false,
      'city': 'Istanbul',
      'district': 'Kadikoy',
      'expertise': 'Kaporta',
    });

    expect(personel.id, 'staff-1');
    expect(personel.ad, 'Ayse');
    expect(personel.soyad, 'Yilmaz');
    expect(personel.adSoyad, 'Ayse Yilmaz');
    expect(personel.email, 'ayse@yerimebak.ai');
    expect(personel.telefon, '+905551112233');
    expect(personel.aktif, isFalse);
    expect(personel.il, 'Istanbul');
    expect(personel.ilce, 'Kadikoy');
    expect(personel.uzmanlikAlani, 'Kaporta');
  });
}
