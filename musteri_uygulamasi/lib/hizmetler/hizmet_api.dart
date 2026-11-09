import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../api/providers.dart';

class HizmetRepository {
  final ApiClient api;
  HizmetRepository(this.api);
  Future<HizmetBolgesi> hizmetBolgesi() async =>
      HizmetBolgesi.fromJson(await api.get('/expertiz/service-area'));
  Future<Json> katalog() => api.get('/expertiz/packages');
  Future<Json> teklif(String firma, String paket) async {
    final result = await api.get(
      '/expertiz/quote?${Uri(queryParameters: {'firm_id': firma, 'package_id': paket}).query}',
    );
    final totals = object(result['totals']);
    bool amount(dynamic value) => value is num && value.isFinite && value >= 0;
    if ([
          'service_fee_tl',
          'package_price_tl',
          'vat_tl',
          'total_tl',
        ].any((key) => !amount(totals[key])) ||
        (totals.containsKey('service_fee_incl_vat_tl') &&
            !amount(totals['service_fee_incl_vat_tl']))) {
      throw const ApiFailure(
        'Güncel fiyat özeti okunamadı. Lütfen yeniden deneyin.',
      );
    }
    return result;
  }

  Future<Json> talep(Json body, {bool odemesiz = false}) async {
    final epoch = api.sessionEpoch;
    final bolge = await hizmetBolgesi();
    if (epoch != api.sessionEpoch) {
      throw const ApiFailure(
        'Oturum değişti. Tekrar giriş yapın.',
        status: 401,
      );
    }
    if (!bolge.iller.any((il) => il.il == body['city'] && il.talepAcabilir)) {
      throw const ApiFailure(
        'Bu ilde henüz hizmet yok.',
        status: 422,
        code: 'il_kapali',
      );
    }
    if (odemesiz && !bolge.tester) {
      throw const ApiFailure(
        'Ödemesiz talep yalnız test kullanıcılarına açıktır.',
        status: 403,
        code: 'odemesiz_talep_yetkisi_yok',
      );
    }
    return api.post(
      odemesiz ? '/expertiz/requests/unpaid' : '/expertiz/requests',
      body,
    );
  }

  Future<Json> siparis(String id) =>
      api.get('/payments/checkout/${Uri.encodeComponent(id)}');
  Future<List<Json>> talepler() async =>
      objects((await api.get('/expertiz/requests'))['requests']);
  Future<List<Json>> raporlar() async =>
      objects((await api.get('/expertiz/reports'))['reports']);
  Future<Json> rapor(String id) async => object(
    (await api.get('/expertiz/reports/${Uri.encodeComponent(id)}'))['report'],
  );
  Future<Json> bildirimler() => api.get('/expertiz/notifications');
  Future<void> okundu(int id) async {
    await api.post('/expertiz/notifications/read', {
      'ids': [id],
    });
  }
}

enum OdemeDonusu { basarili, basarisiz }

OdemeDonusu? odemeDonusu(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.port != 443 ||
      !{'yerimebak.com.tr', 'www.yerimebak.com.tr'}.contains(uri.host) ||
      uri.path != '/odeme/sonuc' ||
      uri.queryParametersAll['durum']?.length != 1) {
    return null;
  }
  return switch (uri.queryParameters['durum']) {
    'basarili' => OdemeDonusu.basarili,
    'basarisiz' => OdemeDonusu.basarisiz,
    _ => null,
  };
}

bool guvenliPaytr(String raw) {
  final uri = Uri.tryParse(raw);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      {'paytr.com', 'www.paytr.com'}.contains(uri.host) &&
      uri.path.startsWith('/odeme/guvenli/');
}

final hizmetRepositoryProvider = Provider(
  (ref) => HizmetRepository(ref.watch(apiProvider)),
);
final hizmetKatalogProvider = FutureProvider.autoDispose<Json>((ref) {
  ref.watch(sessionProvider.select((s) => s.user?.id));
  return ref.watch(hizmetRepositoryProvider).katalog();
});
final hizmetTaleplerProvider = FutureProvider.autoDispose<List<Json>>((ref) {
  ref.watch(sessionProvider.select((s) => s.user?.id));
  return ref.watch(hizmetRepositoryProvider).talepler();
});
final hizmetRaporlarProvider = FutureProvider.autoDispose<List<Json>>((ref) {
  ref.watch(sessionProvider.select((s) => s.user?.id));
  return ref.watch(hizmetRepositoryProvider).raporlar();
});
final hizmetRaporProvider = FutureProvider.autoDispose.family<Json, String>((
  ref,
  id,
) {
  ref.watch(sessionProvider.select((s) => s.user?.id));
  return ref.watch(hizmetRepositoryProvider).rapor(id);
});
final bildirimlerProvider = FutureProvider.autoDispose<Json>((ref) {
  ref.watch(sessionProvider.select((s) => s.user?.id));
  return ref.watch(hizmetRepositoryProvider).bildirimler();
});

const istanbulIlceleri = [
  'Adalar',
  'Arnavutköy',
  'Ataşehir',
  'Avcılar',
  'Bağcılar',
  'Bahçelievler',
  'Bakırköy',
  'Başakşehir',
  'Bayrampaşa',
  'Beşiktaş',
  'Beykoz',
  'Beylikdüzü',
  'Beyoğlu',
  'Büyükçekmece',
  'Çatalca',
  'Çekmeköy',
  'Esenler',
  'Esenyurt',
  'Eyüpsultan',
  'Fatih',
  'Gaziosmanpaşa',
  'Güngören',
  'Kadıköy',
  'Kağıthane',
  'Kartal',
  'Küçükçekmece',
  'Maltepe',
  'Pendik',
  'Sancaktepe',
  'Sarıyer',
  'Silivri',
  'Sultanbeyli',
  'Sultangazi',
  'Şile',
  'Şişli',
  'Tuzla',
  'Ümraniye',
  'Üsküdar',
  'Zeytinburnu',
];

final hizmetTeklifProvider = FutureProvider.autoDispose
    .family<Json, (String, String)>((ref, secim) {
      ref.watch(sessionProvider.select((s) => s.user?.id));
      return ref.watch(hizmetRepositoryProvider).teklif(secim.$1, secim.$2);
    });

class HizmetIli {
  final String il, durum;
  final bool talepAcabilir;
  HizmetIli.fromJson(Json j)
    : il = text(j['il']),
      durum = text(j['durum']),
      talepAcabilir = j['talep_acabilir'] == true;
  String get etiket =>
      '$il${durum == 'test'
          ? ' (test)'
          : !talepAcabilir
          ? ' (yakında)'
          : ''}';
}

class HizmetBolgesi {
  final List<HizmetIli> iller;
  final bool tester;
  HizmetBolgesi.fromJson(Json j)
    : iller = objects(j['cities']).map(HizmetIli.fromJson).toList(),
      tester = j['tester'] == true;
  bool get talepAcabilir => iller.any((il) => il.talepAcabilir);
}

final hizmetBolgesiProvider = FutureProvider<HizmetBolgesi>((ref) {
  ref.watch(sessionProvider.select((s) => s.user?.id));
  return ref.watch(hizmetRepositoryProvider).hizmetBolgesi();
});
final ekspertizAcikProvider = Provider<bool>((ref) {
  final bolge = ref.watch(hizmetBolgesiProvider);
  return !bolge.isLoading &&
      !bolge.hasError &&
      bolge.valueOrNull?.talepAcabilir == true;
});
