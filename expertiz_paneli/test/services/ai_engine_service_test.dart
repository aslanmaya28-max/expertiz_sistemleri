import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak_sistemleri/services/ai/ai_engine_service.dart';
import 'package:yerimebak_sistemleri/models/expertiz/tam_rapor_model.dart';
import 'package:yerimebak_sistemleri/models/expertiz/adim1_arac_satici_model.dart';
import 'package:yerimebak_sistemleri/models/expertiz/adim2_dis_ekspertiz_model.dart';
import 'package:yerimebak_sistemleri/models/expertiz/adim3_ic_ekspertiz_model.dart';
import 'package:yerimebak_sistemleri/models/expertiz/adim4_boya_kaporta_model.dart';
import 'package:yerimebak_sistemleri/models/expertiz/adim5_kurumsal_ekspertiz_model.dart';

void main() {
  group('AIEngineService', () {
    test('analyzeReport returns valid AIAnalizSonucu', () async {
      final rapor = TamRaporModel(
        gorevId: 'test-001',
        personelId: 'personel-001',
        adim1: Adim1AracSaticiModel(
          gorevId: 'test-001',
          personelId: 'personel-001',
          marka: 'Renault',
          model: 'Megane',
          yakitTuru: 'Dizel',
          plaka: '34 ABC 123',
          saseNo: 'TESTSASE001',
          motorNo: 'TESTMOTOR001',
          guncelKm: 85000,
          hasarKayitAdet: 0,
          hasarKayitToplamTutar: 0,
          ruhsatSahibiAdSoyad: 'Test Kullanici',
          iletisimTelefon: '05000000000',
          paket: 'Standart',
        ),
        adim2: Adim2DisEkspertizModel.empty(
          gorevId: 'test-001',
          personelId: 'personel-001',
        ),
        adim3: Adim3IcEkspertizModel.empty(
          gorevId: 'test-001',
          personelId: 'personel-001',
        ),
        adim4: Adim4BoyaKaportaModel(
          gorevId: 'test-001',
          personelId: 'personel-001',
          boyaliParcalar: ['Sag On Kaporta'],
          degisenParcalar: [],
          hasarKayitlari: [],
        ),
        adim5: Adim5KurumsalEkspertizModel.empty(
          gorevId: 'test-001',
          personelId: 'personel-001',
        ),
        durum: 'AnalizEdiliyor',
        baslangicZamani: DateTime.now(),
        bitisZamani: null,
        genelNot: '',
        oneriler: '',
        genelPuan: 0,
      );

      final sonuc = await AIEngineService.analyzeReport(rapor);

      expect(sonuc, isNotNull);
      expect(sonuc.tamamlandiMi, true);
      expect(sonuc.gorevId, 'test-001');
      expect(sonuc.skorlar.genelPuan, greaterThan(0));
      expect(sonuc.raporOzeti.tahminiDeger, greaterThan(0));
      expect(sonuc.raporOzeti.anahtarBulgular.length, greaterThan(0));
    });

    test('analyzeReport handles empty report gracefully', () async {
      final rapor = TamRaporModel(
        gorevId: 'test-empty',
        personelId: 'personel-001',
        adim1: Adim1AracSaticiModel(
          gorevId: 'test-empty',
          personelId: 'personel-001',
          marka: '',
          model: '',
          yakitTuru: '',
          plaka: '',
          saseNo: '',
          motorNo: '',
          guncelKm: 0,
          hasarKayitAdet: 0,
          hasarKayitToplamTutar: 0,
          ruhsatSahibiAdSoyad: '',
          iletisimTelefon: '',
          paket: '',
        ),
        adim2: Adim2DisEkspertizModel.empty(
          gorevId: 'test-empty',
          personelId: 'personel-001',
        ),
        adim3: Adim3IcEkspertizModel.empty(
          gorevId: 'test-empty',
          personelId: 'personel-001',
        ),
        adim4: Adim4BoyaKaportaModel(
          gorevId: 'test-empty',
          personelId: 'personel-001',
          boyaliParcalar: [],
          degisenParcalar: [],
          hasarKayitlari: [],
        ),
        adim5: Adim5KurumsalEkspertizModel.empty(
          gorevId: 'test-empty',
          personelId: 'personel-001',
        ),
        durum: 'AnalizEdiliyor',
        baslangicZamani: DateTime.now(),
        bitisZamani: null,
        genelNot: '',
        oneriler: '',
        genelPuan: 0,
      );

      final sonuc = await AIEngineService.analyzeReport(rapor);

      expect(sonuc, isNotNull);
      expect(sonuc.tamamlandiMi, true);
      // Empty rapor should still produce valid output
      expect(sonuc.skorlar.genelPuan, greaterThanOrEqualTo(0));
    });
  });
}
