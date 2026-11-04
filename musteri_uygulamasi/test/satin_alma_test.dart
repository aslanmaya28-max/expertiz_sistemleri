import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:yerimebak/api/api_client.dart';
import 'package:yerimebak/kredi/satin_alma.dart';

class SahteMagaza implements OdemeMagazasi {
  final akis = StreamController<List<PurchaseDetails>>.broadcast();
  final tamamlanan = <String>[];
  @override
  Stream<List<PurchaseDetails>> get satinAlmalar => akis.stream;
  @override
  Future<bool> hazirMi() async => true;
  @override
  Future<ProductDetailsResponse> urunler(Set<String> k) async =>
      ProductDetailsResponse(productDetails: const [], notFoundIDs: k.toList());
  @override
  Future<bool> satinAl(ProductDetails u, String h) async => true;
  @override
  Future<void> tamamla(PurchaseDetails p) async => tamamlanan.add(p.verificationData.serverVerificationData);
  @override
  Future<void> geriYukle() async {}
}

class SahteDepo implements KrediRepository {
  final List<Object> cevaplar; // Dogrulama ya da ApiFailure
  final cagrilar = <String>[];
  SahteDepo(this.cevaplar);
  @override
  ApiClient get api => throw UnimplementedError();
  @override
  Future<PaketListesi> paketler() async => const PaketListesi([], 'hesap');
  @override
  Future<Dogrulama> dogrula(String u, String j) async {
    cagrilar.add(j);
    final c = cevaplar.removeAt(0);
    if (c is ApiFailure) throw c;
    return c as Dogrulama;
  }
}

PurchaseDetails _satin(String jeton, PurchaseStatus durum, {bool tamamlanacak = true}) => PurchaseDetails(
  productID: 'paket5',
  verificationData: PurchaseVerificationData(localVerificationData: jeton, serverVerificationData: jeton, source: 'google_play'),
  transactionDate: '0',
  status: durum,
)..pendingCompletePurchase = tamamlanacak;

void main() {
  late SahteMagaza magaza;
  var bakiye = 0;
  setUp(() {
    magaza = SahteMagaza();
    bakiye = 0;
  });

  SatinAlmaYoneticisi yonetici(SahteDepo depo) => SatinAlmaYoneticisi(
    magaza: magaza,
    depo: depo,
    bakiyeDegisti: () => bakiye++,
    tekrarBekleme: const Duration(milliseconds: 10),
  );

  test('sunucu krediyi yükleyince satın alma tamamlanır ve bakiye yenilenir', () async {
    final y = yonetici(SahteDepo([const Dogrulama('granted', 5, 5)]));
    await y.isle([_satin('j1', PurchaseStatus.purchased)]);
    expect(magaza.tamamlanan, ['j1']);
    expect(bakiye, 1);
    expect(y.durum, SatinAlmaDurumu.tamam);
    expect(y.mesaj, '5 kredi hesabınıza yüklendi.');
  });

  test('daha önce yüklenmiş satın alma (uygulama yeniden açıldı) yine tamamlanır', () async {
    final y = yonetici(SahteDepo([const Dogrulama('already_granted', null, 5)]));
    await y.isle([_satin('j2', PurchaseStatus.restored)]);
    expect(magaza.tamamlanan, ['j2']);
    expect(y.durum, SatinAlmaDurumu.tamam);
  });

  test('ağ hatasında tamamlanmaz, aynı jetonla yeniden denenir ve sonunda yüklenir', () async {
    final depo = SahteDepo([const ApiFailure('ağ yok'), const Dogrulama('granted', 5, 5)]);
    final y = yonetici(depo);
    await y.isle([_satin('j3', PurchaseStatus.purchased)]);
    expect(magaza.tamamlanan, isEmpty);
    expect(y.durum, SatinAlmaDurumu.krediYukleniyor);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(depo.cagrilar, ['j3', 'j3']);
    expect(magaza.tamamlanan, ['j3']);
    expect(y.durum, SatinAlmaDurumu.tamam);
  });

  test('başka hesabın satın alması (403) tamamlanmaz, kredi yüklenmiş sayılmaz', () async {
    final y = yonetici(SahteDepo([const ApiFailure('Bu satın alma başka bir hesaba aittir.', status: 403)]));
    await y.isle([_satin('j4', PurchaseStatus.purchased)]);
    expect(magaza.tamamlanan, isEmpty);
    expect(bakiye, 0);
    expect(y.durum, SatinAlmaDurumu.hata);
    expect(y.mesaj, contains('destek@yerimebak.com.tr'));
  });

  test('bekleyen ödemede kredi yok, sunucu da beklemede derse tamamlanmaz', () async {
    final y = yonetici(SahteDepo([const Dogrulama('pending', null, null)]));
    await y.isle([_satin('j5', PurchaseStatus.pending)]);
    expect(y.durum, SatinAlmaDurumu.odemeBekliyor);
    await y.isle([_satin('j5', PurchaseStatus.purchased)]);
    expect(magaza.tamamlanan, isEmpty);
    expect(y.durum, SatinAlmaDurumu.odemeBekliyor);
  });

  test('aynı jeton aynı anda iki kez gelirse sunucuya bir kez sorulur', () async {
    final depo = SahteDepo([const Dogrulama('granted', 5, 5), const Dogrulama('already_granted', null, 5)]);
    final y = yonetici(depo);
    await Future.wait([y.isle([_satin('j6', PurchaseStatus.purchased)]), y.isle([_satin('j6', PurchaseStatus.purchased)])]);
    expect(depo.cagrilar, ['j6']);
  });

  test('iptal sessiz geçer, hata mesaj verir', () async {
    final y = yonetici(SahteDepo([]));
    await y.isle([_satin('j7', PurchaseStatus.canceled)]);
    expect(y.mesaj, isNull);
    await y.isle([_satin('j8', PurchaseStatus.error)]);
    expect(y.durum, SatinAlmaDurumu.hata);
  });
}
