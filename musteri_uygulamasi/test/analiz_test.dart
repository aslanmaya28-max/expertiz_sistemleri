import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak/analiz/analiz_api.dart';
import 'package:yerimebak/analiz/arac_formu.dart';
import 'package:yerimebak/analiz/ilan_metni.dart';
import 'package:yerimebak/api/api_client.dart';
import 'api_client_test.dart' show MemoryTokens;

ApiClient _api(Future<http.Response> Function(http.Request) cevap) =>
    ApiClient(store: MemoryTokens('belirtec'), client: MockClient(cevap), baseUri: Uri.parse('https://api.test/api/v1'));

void main() {
  group('paylaşılan metinden link', () {
    test('sahibinden paylaşım metninden linki ve sondaki noktalamayı ayıklar', () {
      final u = paylasimdanLink('Bu ilana bak: https://www.sahibinden.com/ilan/vasita-chery-1341900348/detay.');
      expect(u.toString(), 'https://www.sahibinden.com/ilan/vasita-chery-1341900348/detay');
      expect(sahibindenMi(u!), isTrue);
    });
    test('web adresi olmayan, uygulama açan ve kullanıcı bilgisi içeren adresleri reddeder', () {
      expect(paylasimdanLink('link yok'), isNull);
      expect(paylasimdanLink('sahibinden://ilan/123'), isNull);
      expect(paylasimdanLink('https://kullanici:sifre@ornek.com/ilan'), isNull);
      expect(sahibindenMi(Uri.parse('https://sahibinden.com.sahte.net/ilan')), isFalse);
    });
  });

  group('sayfa durumu ve metin', () {
    final ilan = 'Chery Tiggo 7 Pro Max 1.730.000 TL\nİlan No 1341900348\nMarka Chery\nModel Tiggo 7 Pro Max\nKM 44.000\n'
        '${'Açıklama satırı. ' * 40}';
    test('ilan bilgileri gelince hazır, doğrulama sayfasında doğrulama gerekli sayılır', () {
      expect(sayfaDurumu(ilan), SayfaDurumu.ilanHazir);
      expect(sayfaDurumu('Lütfen robot değilim kutusunu işaretleyin'), SayfaDurumu.dogrulamaGerekli);
      expect(sayfaDurumu('Yükleniyor'), SayfaDurumu.yukleniyor);
      final liste = 'Chery Tiggo 7 Pro Max Intelligent (86 ilan)\nMarka Model Filtre\n${'TİGGO 7 PRO MAX 1.6 TGDI 2024 25.000 km 1.665.000 TL\n' * 20}';
      expect(sayfaDurumu(liste), SayfaDurumu.yukleniyor);
    });
    test('WebView JSON dizesi çözülür', () {
      expect(jsSonucunuCoz(jsonEncode('Satır 1\nİlan "No"')), 'Satır 1\nİlan "No"');
      expect(jsSonucunuCoz('null'), '');
      expect(jsSonucunuCoz(null), '');
    });
    test('kırpma 8000 sınırına uyar, ilan bloğunu öne alır, boya-değişen satırını kaybetmez', () {
      final menu = List.generate(400, (i) => 'Menü bağlantısı $i').join('\n');
      final dip = List.generate(300, (i) => 'Alt bilgi $i').join('\n');
      final sayfa = '$menu\n$ilan\n$dip\nBoya-değişen: Sol ön kapı değişen\nTramer: 180.000 TL';
      final k = ilanMetniniKirp(sayfa);
      expect(k.length, lessThanOrEqualTo(8000));
      expect(k, contains('İlan No 1341900348'));
      expect(k, contains('Sol ön kapı değişen'));
      expect(k, contains('Tramer: 180.000 TL'));
      expect(k.indexOf('İlan No'), lessThan(1000));
    });
  });

  group('form kuralları (web ile aynı)', () {
    test('yıl, km ve fiyat sınırları', () {
      expect(formHatasi(yil: '1979', km: '0', fiyat: '500000', buYil: 2026), contains('1980 ile 2027'));
      expect(formHatasi(yil: '2025', km: '2000001', fiyat: '500000', buYil: 2026), contains('2.000.000'));
      expect(formHatasi(yil: '2025', km: '44000', fiyat: '9999', buYil: 2026), contains('10.000 TL'));
      expect(formHatasi(yil: '2025', km: '44000', fiyat: '1730000', buYil: 2026), isNull);
    });
    test('Türkçe arama ve marka eşleme', () {
      expect(sadelestir('Şkoda İzmir'), 'skoda izmir');
      expect(katalogAra(markalar, 'che').first, anyOf('Chery', 'Chevrolet'));
      expect(modelleri('chery'), contains('Tiggo 7'));
      expect(binlikNokta(sadeceRakam('1.730.000 TL')), '1.730.000');
    });
    test('istek gövdesi: orijinal parça gönderilmez, boş alan atlanır, tramer yoksa 0', () {
      final f = AracFormu(marka: 'Chery', model: 'Tiggo 7 Pro Max', yil: '2025', km: '44000', fiyat: '1730000',
          parcalar: {'solOnKapi': 'degisen', 'kaput': 'orijinal'});
      final g = f.istek('id-1');
      expect(g['parts'], {'solOnKapi': 'degisen'});
      expect(g['tramer_amount'], 0);
      expect(g.containsKey('hp'), isFalse);
      expect(g['listed_price'], 1730000);
      expect(AracFormu(marka: 'A', model: 'B', yil: '2025', km: '1', fiyat: '100000', hp: '20').hata, contains('Motor gücü'));
    });
    test('ön doldurma forma aktarılır, doğrulanan alanlar işaretlenir', () {
      final od = OnDoldurma.fromJson({
        'vehicle': {'brand': 'Chery', 'model': 'Tiggo 7 Pro Max', 'year': 2025, 'km': 44000, 'price': 1730000, 'tramer_amount': 180000},
        'parts': {'solOnKapi': 'degisen', 'bilinmeyen': 'xyz'},
        'fields': {'brand': {'deger': 'Chery', 'dogrulandi': true}, 'price': {'deger': 1730000, 'dogrulandi': true}},
        'verified_count': 2,
      });
      final f = od.forma('https://ornek.com/ilan');
      expect(od.yeterli, isTrue);
      expect(f.fiyat, '1730000');
      expect(f.tramer, '180000');
      expect(f.parcalar, {'solOnKapi': 'degisen'});
      expect(f.ilandanOkunan, containsAll(['marka', 'fiyat', 'parcalar']));
      expect(f.ilandanOkunan, isNot(contains('model')));
    });
  });

  group('analiz isteği', () {
    final form = AracFormu(marka: 'Chery', model: 'Tiggo 7 Pro Max', yil: '2025', km: '44000', fiyat: '1730000');
    test('bağlantı koparsa aynı istek numarasıyla yeniden dener, rapor numarasını döndürür', () async {
      final numaralar = <String>[];
      var n = 0;
      final repo = AnalizRepository(_api((r) async {
        numaralar.add(jsonDecode(r.body)['request_id'] as String);
        if (++n < 3) return http.Response('<html>Gateway timeout</html>', 504);
        return http.Response(jsonEncode({'rapor': {'id': 'r-1'}, 'kredi': {'kalan': 3}}), 200);
      }), bekle: (_) async {});
      final s = await repo.analizEt(form, 'istek-42');
      expect(s.raporId, 'r-1');
      expect(s.kalanKredi, 3);
      expect(numaralar, ['istek-42', 'istek-42', 'istek-42']);
    });
    test('yetersiz kredi yeniden denenmez', () async {
      var n = 0;
      final repo = AnalizRepository(_api((r) async {
        n++;
        return http.Response(jsonEncode({'detail': {'message': 'Yetersiz kredi.', 'code': 'insufficient_credits'}}), 402);
      }), bekle: (_) async {});
      await expectLater(repo.analizEt(form, 'x'), throwsA(isA<InsufficientCredits>()));
      expect(n, 1);
    });
    test('deneme hakkı bitince bağlantı koptu mesajı verir', () async {
      final repo = AnalizRepository(_api((r) async => http.Response('', 502)), bekle: (_) async {});
      await expectLater(
        repo.analizEt(form, 'x', deneme: 2),
        throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 'baglanti_koptu')),
      );
    });
    test('istek numarası UUID v4 biçiminde', () {
      expect(yeniIstekNo(), matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });
    test('kasa sorusu yalnız geçiş yılında seçenek döndürür', () async {
      final repo = AnalizRepository(_api((r) async => http.Response(
        jsonEncode({'gecisYili': true, 'secenekler': [
          {'kod': 'yeni', 'kasa': 'Yeni kasa', 'baslangic': 2024},
          {'kod': 'eski', 'kasa': 'Önceki kasa', 'baslangic': 2019, 'bitis': 2024},
        ]}), 200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      )));
      final s = await repo.kasaSecenekleri('Chery', 'Tiggo 7', '2024');
      expect(s.map((e) => e.kod), ['yeni', 'eski']);
      expect(s.last.ad, 'Önceki kasa (2019–2024)');
    });
  });

  group('ekran görüntüsünden doldurma', () {
    test('görüntüler files alanıyla çok parçalı olarak prefill-screenshot ucuna gider', () async {
      late http.Request giden;
      final repo = AnalizRepository(_api((r) async {
        giden = r;
        return http.Response(jsonEncode({'marka': {'deger': 'Seat', 'kaynak': 'ilan'}, 'metin': 'Seat Ibiza'}), 200);
      }));
      await repo.ekrandanOku([
        DosyaParcasi('files', 'ilan-1.png', Uint8List.fromList([1, 2, 3])),
        DosyaParcasi('files', 'ilan-2.png', Uint8List.fromList([4, 5])),
      ]);
      expect(giden.method, 'POST');
      expect(giden.url.path, endsWith('/valuation/prefill-screenshot'));
      expect(giden.headers['content-type'], startsWith('multipart/form-data; boundary='));
      expect(giden.headers['Authorization'], startsWith('Bearer '));
      final govde = utf8.decode(giden.bodyBytes, allowMalformed: true);
      expect('name="files"'.allMatches(govde).length, 2);
      expect(govde, contains('filename="ilan-1.png"'));
    });
  });
}
