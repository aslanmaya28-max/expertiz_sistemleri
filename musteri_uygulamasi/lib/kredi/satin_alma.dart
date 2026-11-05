import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../api/api_client.dart';
import '../api/models.dart';

/// Sunucudaki paket (fiyat sunucudan değil, Google Play'den gösterilir).
class KrediPaketi {
  final String urunKimligi, ad;
  final int kredi;
  final bool populer;
  const KrediPaketi(this.urunKimligi, this.kredi, this.ad, this.populer);
}

class PaketListesi {
  final List<KrediPaketi> paketler;
  final String hesapKimligi;
  const PaketListesi(this.paketler, this.hesapKimligi);
}

class Dogrulama {
  final String durum; // granted | already_granted | pending
  final int? eklenen, yeniBakiye;
  const Dogrulama(this.durum, this.eklenen, this.yeniBakiye);
}

class KrediRepository {
  final ApiClient api;
  KrediRepository(this.api);

  Future<PaketListesi> paketler() async {
    final d = await api.get('/payments/google-play/products');
    return PaketListesi(
      objects(d['products'])
          .map((p) => KrediPaketi(text(p['product_id']), integer(p['credits']), text(p['name']), p['popular'] == true))
          .where((p) => p.urunKimligi.isNotEmpty && p.kredi > 0)
          .toList(),
      text(d['obfuscated_account_id']),
    );
  }

  Future<Dogrulama> dogrula(String urunKimligi, String satinAlmaJetonu) async {
    final d = await api.post('/payments/google-play/verify', {
      'product_id': urunKimligi,
      'purchase_token': satinAlmaJetonu,
    }, timeout: const Duration(seconds: 60));
    int? sayi(Object? v) => v is num ? v.toInt() : null;
    return Dogrulama(text(d['status']), sayi(d['credits_added']), sayi(d['new_balance']));
  }
}

/// Google Play Faturalandırma'nın uygulamanın kullandığı kısmı; testlerde ve simülasyonda değiştirilir.
abstract interface class OdemeMagazasi {
  Stream<List<PurchaseDetails>> get satinAlmalar;
  Future<bool> hazirMi();
  Future<ProductDetailsResponse> urunler(Set<String> kimlikler);
  Future<bool> satinAl(ProductDetails urun, String hesapKimligi);
  Future<void> tamamla(PurchaseDetails satinAlma);
  Future<void> geriYukle();
}

class GooglePlayMagazasi implements OdemeMagazasi {
  final InAppPurchase iap;
  GooglePlayMagazasi([InAppPurchase? iap]) : iap = iap ?? InAppPurchase.instance;
  @override
  Stream<List<PurchaseDetails>> get satinAlmalar => iap.purchaseStream;
  @override
  Future<bool> hazirMi() => iap.isAvailable();
  @override
  Future<ProductDetailsResponse> urunler(Set<String> kimlikler) => iap.queryProductDetails(kimlikler);
  // Tüketim (consume) sunucuda, kredi yüklendikten sonra yapılır; uygulama otomatik tüketmez.
  @override
  Future<bool> satinAl(ProductDetails urun, String hesapKimligi) => iap.buyConsumable(
    purchaseParam: PurchaseParam(productDetails: urun, applicationUserName: hesapKimligi),
    autoConsume: false,
  );
  @override
  Future<void> tamamla(PurchaseDetails satinAlma) => iap.completePurchase(satinAlma);
  @override
  Future<void> geriYukle() => iap.restorePurchases();
}

/// Yalnız hata ayıklama derlemesinde (`--dart-define=PLAY_SIMULASYON=true`) ve sunucuda
/// `GOOGLE_PLAY_SIMULATION=true` iken: gerçek Google Play olmadan tam doğrulama zincirini dener.
class SimulasyonMagazasi implements OdemeMagazasi {
  final _akis = StreamController<List<PurchaseDetails>>.broadcast();
  @override
  Stream<List<PurchaseDetails>> get satinAlmalar => _akis.stream;
  @override
  Future<bool> hazirMi() async => true;
  @override
  Future<ProductDetailsResponse> urunler(Set<String> kimlikler) async => ProductDetailsResponse(
    productDetails: [
      for (final k in kimlikler)
        ProductDetails(id: k, title: k, description: 'Deneme', price: 'Deneme', rawPrice: 0, currencyCode: 'TRY'),
    ],
    notFoundIDs: const [],
  );
  @override
  Future<bool> satinAl(ProductDetails urun, String hesapKimligi) async {
    final jeton = 'test-${DateTime.now().microsecondsSinceEpoch}';
    scheduleMicrotask(() => _akis.add([
      PurchaseDetails(
        productID: urun.id,
        verificationData: PurchaseVerificationData(
          localVerificationData: jeton,
          serverVerificationData: jeton,
          source: 'simulasyon',
        ),
        transactionDate: '${DateTime.now().millisecondsSinceEpoch}',
        status: PurchaseStatus.purchased,
      ),
    ]));
    return true;
  }

  @override
  Future<void> tamamla(PurchaseDetails satinAlma) async {}
  @override
  Future<void> geriYukle() async {}
}

enum SatinAlmaDurumu { bos, odemeBekliyor, krediYukleniyor, tamam, hata }

/// Satın alma akışı. Kural: kredi yalnız sunucu doğrulamasından sonra yüklenmiş sayılır;
/// doğrulama ağ hatasıyla düşerse satın alma tamamlanmaz ve yeniden denenir (müşteri parası alınıp kredisiz kalmaz).
class SatinAlmaYoneticisi extends ChangeNotifier {
  final OdemeMagazasi magaza;
  final KrediRepository depo;
  final void Function() bakiyeDegisti;
  final Duration tekrarBekleme;
  SatinAlmaYoneticisi({
    required this.magaza,
    required this.depo,
    required this.bakiyeDegisti,
    this.tekrarBekleme = const Duration(seconds: 10),
  });

  StreamSubscription<List<PurchaseDetails>>? _abonelik;
  final _isleniyor = <String>{};
  final _tekrarSayaci = <String, int>{};
  SatinAlmaDurumu durum = SatinAlmaDurumu.bos;
  String? mesaj;
  bool _kapandi = false;

  void baslat() {
    if (_abonelik != null) return;
    try {
      _abonelik = magaza.satinAlmalar.listen(isle, onError: (Object _) {});
      // Önceki açılışta yarım kalan (tüketilmemiş) satın almalar akışa yeniden gelir.
      unawaited(magaza.geriYukle().catchError((Object _) {}));
    } catch (_) {
      // Google Play yoksa (test, Play'siz cihaz) satın alma dinlenmez; kredi ekranı bunu ayrıca söyler.
    }
  }

  void _bildir(SatinAlmaDurumu d, String? m) {
    if (_kapandi) return;
    durum = d;
    mesaj = m;
    notifyListeners();
  }

  void mesajiTemizle() => _bildir(SatinAlmaDurumu.bos, null);

  Future<void> isle(List<PurchaseDetails> liste) async {
    for (final p in liste) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _bildir(SatinAlmaDurumu.odemeBekliyor, 'Ödemeniz onay bekliyor; onaylanınca krediniz yüklenir.');
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _dogrula(p);
        case PurchaseStatus.error:
          _bildir(SatinAlmaDurumu.hata, 'Ödeme tamamlanamadı. Hesabınızdan para çekildiyse destekle iletişime geçin.');
        case PurchaseStatus.canceled:
          _bildir(SatinAlmaDurumu.bos, null);
      }
    }
  }

  Future<void> _dogrula(PurchaseDetails p) async {
    final jeton = p.verificationData.serverVerificationData;
    if (jeton.isEmpty || !_isleniyor.add(jeton)) return;
    _bildir(SatinAlmaDurumu.krediYukleniyor, 'Ödemeniz alındı, krediniz yükleniyor…');
    try {
      final d = await depo.dogrula(p.productID, jeton);
      if (d.durum == 'pending') {
        _bildir(SatinAlmaDurumu.odemeBekliyor, 'Ödemeniz onay bekliyor; onaylanınca krediniz yüklenir.');
        return;
      }
      if (p.pendingCompletePurchase) await magaza.tamamla(p);
      _tekrarSayaci.remove(jeton);
      bakiyeDegisti();
      _bildir(
        SatinAlmaDurumu.tamam,
        d.durum == 'granted' && d.eklenen != null
            ? '${d.eklenen} kredi hesabınıza yüklendi.'
            : 'Bu ödemenin kredisi hesabınızda.',
      );
    } on ApiFailure catch (e) {
      final gecici = e.status == 0 || e.status >= 500;
      if (gecici) {
        final n = (_tekrarSayaci[jeton] ?? 0) + 1;
        _tekrarSayaci[jeton] = n;
        _bildir(
          SatinAlmaDurumu.krediYukleniyor,
          'Ödemeniz alındı. Bağlantı kurulunca krediniz yüklenecek; uygulamayı kapatsanız da kaybolmaz.',
        );
        if (n <= 6) {
          Timer(tekrarBekleme * n, () {
            _isleniyor.remove(jeton);
            if (!_kapandi) unawaited(_dogrula(p));
          });
          return;
        }
      } else {
        _bildir(SatinAlmaDurumu.hata, '${e.message} Destek: destek@yerimebak.com.tr');
      }
    } finally {
      // Geçici hatada zamanlayıcı yeniden dener; bu arada aynı jeton ikinci kez işlenmez.
      if (!_tekrarSayaci.containsKey(jeton) || (_tekrarSayaci[jeton] ?? 0) > 6) _isleniyor.remove(jeton);
    }
  }

  @override
  void dispose() {
    _kapandi = true;
    _abonelik?.cancel();
    super.dispose();
  }
}
