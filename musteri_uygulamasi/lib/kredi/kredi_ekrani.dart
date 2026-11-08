import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../analiz/analiz_durumu.dart';
import '../api/providers.dart';
import '../bilesenler/ortak.dart';
import '../tema/yazi.dart';
import '../bilesenler/kart.dart';
import '../bilesenler/ana_buton.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import 'satin_alma.dart';
import 'rapor_icerigi.dart';

const _playSimulasyonu =
    bool.fromEnvironment('PLAY_SIMULASYON') &&
    !bool.fromEnvironment('dart.vm.product');

final krediRepositoryProvider = Provider(
  (ref) => KrediRepository(ref.watch(apiProvider)),
);
final odemeMagazasiProvider = Provider<OdemeMagazasi>(
  (ref) => _playSimulasyonu ? SimulasyonMagazasi() : GooglePlayMagazasi(),
);
final satinAlmaProvider = ChangeNotifierProvider<SatinAlmaYoneticisi>((ref) {
  final y = SatinAlmaYoneticisi(
    magaza: ref.watch(odemeMagazasiProvider),
    depo: ref.watch(krediRepositoryProvider),
    bakiyeDegisti: () {
      ref.invalidate(balanceProvider);
      ref.invalidate(historyProvider);
    },
  );
  return y;
});

/// Sunucu paketleri + Play'deki fiyatları. Play'de bulunmayan paket gösterilmez.
class SatilabilirPaket {
  final KrediPaketi paket;
  final ProductDetails urun;
  const SatilabilirPaket(this.paket, this.urun);
}

class KrediVitrini {
  final List<SatilabilirPaket> paketler;
  final String hesapKimligi;
  final bool magazaHazir;
  const KrediVitrini(this.paketler, this.hesapKimligi, this.magazaHazir);
}

final krediVitriniProvider = FutureProvider.autoDispose<KrediVitrini>((
  ref,
) async {
  ref.watch(sessionProvider.select((s) => s.user?.id));
  final magaza = ref.watch(odemeMagazasiProvider);
  final liste = await ref.watch(krediRepositoryProvider).paketler();
  if (!await magaza.hazirMi()) {
    return KrediVitrini(const [], liste.hesapKimligi, false);
  }
  final yanit = await magaza.urunler({
    for (final p in liste.paketler) p.urunKimligi,
  });
  final urunler = {for (final u in yanit.productDetails) u.id: u};
  return KrediVitrini(
    [
      for (final p in liste.paketler)
        if (urunler[p.urunKimligi] != null)
          SatilabilirPaket(p, urunler[p.urunKimligi]!),
    ],
    liste.hesapKimligi,
    true,
  );
});

class KrediEkrani extends ConsumerStatefulWidget {
  const KrediEkrani({super.key});
  @override
  ConsumerState<KrediEkrani> createState() => _KrediEkraniState();
}

class _KrediEkraniState extends ConsumerState<KrediEkrani> {
  String? secili;

  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    final vitrin = ref.watch(krediVitriniProvider);
    final bakiye = ref.watch(balanceProvider);
    final yonetici = ref.watch(satinAlmaProvider);
    final taslakVar = ref.watch(analizTaslagiProvider) != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Kredi yükle')),
      body: ListView(
        padding: const EdgeInsets.all(Olcu.sayfa),
        children: [
          Kart(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.wallet,
                  size: Olcu.ikonInce,
                  color: r.birincil,
                ),
                const SizedBox(height: Olcu.s16),
                const Text('Mevcut bakiyeniz', style: Yazilar.etiket),
                Text(
                  bakiye.maybeWhen(data: (b) => '$b kredi', orElse: () => '…'),
                  style: Yazilar.rakamBuyuk,
                ),
                const SizedBox(height: Olcu.s8),
                Text(
                  '1 analiz raporu = 1 kredi',
                  style: Yazilar.govdeKucuk.copyWith(color: r.metinIkincil),
                ),
              ],
            ),
          ),
          const SizedBox(height: Olcu.s16),
          const RaporIcerigiKarti(),
          const SizedBox(height: Olcu.s16),
          if (yonetici.mesaj != null)
            Card(
              color: yonetici.durum == SatinAlmaDurumu.hata
                  ? r.tehlikeYuzey
                  : yonetici.durum == SatinAlmaDurumu.tamam
                  ? r.birincilYuzey
                  : r.uyariYuzey,
              child: ListTile(
                title: Text(
                  yonetici.mesaj!,
                  style: TextStyle(
                    color: yonetici.durum == SatinAlmaDurumu.hata
                        ? r.tehlike
                        : r.metin,
                  ),
                ),
                trailing: yonetici.durum == SatinAlmaDurumu.tamam && taslakVar
                    ? TextButton(
                        onPressed: () => context.go('/analiz/form'),
                        child: const Text('Analize dön'),
                      )
                    : null,
              ),
            ),
          const SizedBox(height: Olcu.s8),
          vitrin.when(
            loading: () => const LoadingView(),
            error: (e, _) =>
                FailureView(e, () => ref.invalidate(krediVitriniProvider)),
            data: (v) {
              if (!v.magazaHazir || v.paketler.isEmpty) {
                return Panel('Google Play şu an kullanılamıyor', [
                  const Text(
                    'Kredi paketleri Google Play üzerinden satılır. Telefonunuzda Google Play hesabının açık olduğundan '
                    've uygulamanın Google Play’den yüklendiğinden emin olun, sonra tekrar deneyin.',
                  ),
                  const SizedBox(height: Olcu.s12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(krediVitriniProvider),
                    child: const Text('Tekrar dene'),
                  ),
                ]);
              }
              final sec =
                  secili ??
                  v.paketler
                      .firstWhere(
                        (p) => p.paket.populer,
                        orElse: () => v.paketler.first,
                      )
                      .paket
                      .urunKimligi;
              final seciliPaket = v.paketler.firstWhere(
                (p) => p.paket.urunKimligi == sec,
                orElse: () => v.paketler.first,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Olcu.s4,
                      vertical: Olcu.s8,
                    ),
                    child: Text(
                      'Paket seçin',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  RadioGroup<String>(
                    groupValue: sec,
                    onChanged: (k) => setState(() => secili = k),
                    child: Column(
                      children: [
                        for (final p in v.paketler)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Olcu.s12),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  Olcu.kartKose,
                                ),
                                side: BorderSide(
                                  color: p.paket.urunKimligi == sec
                                      ? r.birincil
                                      : r.kenarlik,
                                  width: p.paket.urunKimligi == sec
                                      ? Olcu.vurguluKenar
                                      : Olcu.kenar,
                                ),
                              ),
                              child: RadioListTile<String>(
                                value: p.paket.urunKimligi,
                                title: Text('${p.paket.kredi} kredi'),
                                subtitle: p.paket.populer
                                    ? Text(
                                        'En çok tercih edilen',
                                        style: TextStyle(
                                          color: r.birincilMetin,
                                        ),
                                      )
                                    : null,
                                secondary: Text(
                                  p.urun.price,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Olcu.s8),
                  Text(
                    'Krediler hesabınıza tanımlanır; web sitesinde de aynı bakiyeyi kullanırsınız.',
                    style: TextStyle(color: r.metinIkincil),
                  ),
                  const SizedBox(height: Olcu.s16),
                  AnaButon(
                    'Google Play ile öde · ${seciliPaket.urun.price}',
                    yonetici.durum == SatinAlmaDurumu.krediYukleniyor
                        ? null
                        : () async {
                            ref.read(satinAlmaProvider).mesajiTemizle();
                            await ref
                                .read(odemeMagazasiProvider)
                                .satinAl(seciliPaket.urun, v.hesapKimligi);
                          },
                  ),
                  const SizedBox(height: Olcu.s8),
                  Text(
                    'Ödeme Google Play hesabınızdan alınır. Krediler ödeme onaylanınca yüklenir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: r.metinIkincil),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
