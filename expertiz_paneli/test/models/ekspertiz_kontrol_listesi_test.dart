import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak_sistemleri/models/expertiz/adim2_dis_ekspertiz_model.dart';
import 'package:yerimebak_sistemleri/models/expertiz/adim3_ic_ekspertiz_model.dart';
import 'package:yerimebak_sistemleri/models/expertiz/adim4_boya_kaporta_model.dart';
import 'package:yerimebak_sistemleri/models/expertiz/adim5_kurumsal_ekspertiz_model.dart';
import 'package:yerimebak_sistemleri/models/expertiz/kontrol_listesi.dart';

void main() {
  group('Dış ekspertiz', () {
    test('tüm maddeler seçilince geçerli, eski alanlar türetilir', () {
      var model = Adim2DisEkspertizModel.empty(gorevId: 'r1', personelId: 'p1');
      expect(model.isValid, isFalse);
      for (final m in Adim2DisEkspertizModel.maddeler) {
        model = model.withDurum(m.key, KontrolDurumu.iyi);
      }
      expect(model.isValid, isTrue);
      model = model.withDurum('sagOnCamurluk', KontrolDurumu.kotu);
      expect(model.onCamurluklar, KontrolDurumu.kotu); // en kötü durum
      expect(model.eksiklikliMaddeler.map((m) => m.key), ['sagOnCamurluk']);
    });

    test('JSON gidiş-dönüş ve kontrolListesi', () {
      final model = Adim2DisEkspertizModel.empty(gorevId: 'r1', personelId: 'p1')
          .withDurum('onTampon', KontrolDurumu.sorunlu)
          .withNot('onTampon', 'Çizik');
      final json = jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>;
      final geri = Adim2DisEkspertizModel.fromJson(json);
      expect(geri.durum('onTampon'), KontrolDurumu.sorunlu);
      expect(geri.not('onTampon'), 'Çizik');
      final liste = (json['kontrolListesi'] as List).cast<Map<String, dynamic>>();
      final tampon = liste.firstWhere((e) => e['key'] == 'onTampon');
      expect(tampon['eksiklik'], isTrue);
      expect(tampon['label'], 'Ön Tampon');
    });

    test('eski taslak (maddeDurumlari yok) okunur', () {
      final geri = Adim2DisEkspertizModel.fromJson({'gorevId': 'r', 'personelId': 'p', 'onTampon': 'iyi', 'onCamurluklar': 'orta'});
      expect(geri.durum('onTampon'), 'iyi');
      expect(geri.durum('solOnCamurluk'), 'orta');
      expect(geri.durum('sagOnCamurluk'), 'orta');
    });
  });

  group('İç ekspertiz', () {
    test('eski kurucu parametreleri haritaya aktarılır', () {
      final model = Adim3IcEkspertizModel(gorevId: 'r', personelId: 'p', direksiyon: 'iyi', klima: 'kotu');
      expect(model.direksiyon, 'iyi');
      expect(model.eksiklikliMaddeler.map((m) => m.key), ['klima']);
      expect(model.isValid, isFalse);
    });
  });

  group('Boya / kaporta', () {
    test('parça durumlarından boyalı/değişen listesi ve AI sözlüğü türetilir', () {
      var model = Adim4BoyaKaportaModel.empty(gorevId: 'r', personelId: 'p');
      for (final p in Adim4BoyaKaportaModel.parcalar) {
        model = model.withParca(p.key, ParcaDurumu.orijinal);
      }
      for (final y in Adim4BoyaKaportaModel.yapisal) {
        model = model.withYapisal(y.key, YapisalDurum.orijinal);
      }
      expect(model.isValid, isTrue);
      model = model.withParca('kaput', ParcaDurumu.boyali).withParca('solOnKapi', ParcaDurumu.degisen).withMikron('kaput', 240);
      expect(model.boyaliParcalar, ['Motor Kaputu']);
      expect(model.degisenParcalar, ['Sol Ön Kapı']);
      expect(model.kaputBoya, 'Boyalı');
      expect(model.onKapiBoya, 'Değişmiş');
      expect(model.eksiklikliMaddeler.length, 2);

      final geri = Adim4BoyaKaportaModel.fromJson(jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>);
      expect(geri.mikronlar['kaput'], 240);
      expect(geri.degisenParcalar, ['Sol Ön Kapı']);
    });

    test('eski model (testler / eski raporlar) davranışını korur', () {
      final model = Adim4BoyaKaportaModel(gorevId: 'r', personelId: 'p', boyaliParcalar: ['Kaput'], degisenParcalar: []);
      expect(model.boyaliParcalar, ['Kaput']);
    });
  });

  group('Kurumsal ekspertiz', () {
    test('talep varsa rapor numarası zorunlu', () {
      var model = Adim5KurumsalEkspertizModel.empty(gorevId: 'r', personelId: 'p');
      expect(model.isValid, isTrue);
      model = model.copyWith(kurumsalTalepVar: true);
      expect(model.isValid, isFalse);
      model = model.copyWith(kurumsalRaporNo: 'PG-1');
      expect(model.isValid, isTrue);
      final geri = Adim5KurumsalEkspertizModel.fromJson(jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>);
      expect(geri.kurumsalTalepVar, isTrue);
      expect(geri.kurumsalRaporNo, 'PG-1');
    });
  });
}
