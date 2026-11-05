import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../api/models.dart';
import '../api/providers.dart';
import '../bilesenler/ana_buton.dart';
import '../bilesenler/ikincil_buton.dart';
import '../bilesenler/kart.dart';
import '../bilesenler/liste_satiri.dart';
import '../bilesenler/ortak.dart';
import '../bilesenler/yakinda_rozeti.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';
import 'hizmet_api.dart';

String hizmetPara(dynamic value) => value is num
    ? '${NumberFormat('#,##0.##', 'tr_TR').format(value)} TL'
    : '—';

String ekspertizYolu(bool acik) =>
    acik ? '/ekspertiz/talep' : '/yerinde-inceleme';

class HizmetKartlari extends ConsumerWidget {
  const HizmetKartlari({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acik = ref.watch(configProvider).valueOrNull?.expertizEnabled == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Olcu.s24),
        const Text('Hizmetlerimiz', style: Yazilar.baslik2),
        const SizedBox(height: Olcu.s16),
        _HizmetKarti(
          'Yerinde ekspertiz yaptırın',
          'Siz gitmeden aracı kurumsal ekspertiz firması incelesin.',
          LucideIcons.clipboardCheck,
          () => context.push(ekspertizYolu(acik)),
          yakinda: !acik,
        ),
        const SizedBox(height: Olcu.s12),
        LayoutBuilder(
          builder: (context, c) {
            final children = [
              _HizmetKarti(
                'Vekaletle satın alma',
                'Aracı doğrudan sizin adınıza alalım.',
                LucideIcons.keyRound,
                () => context.push('/uzaktan-satin-alma'),
              ),
              _HizmetKarti(
                'Çekiciyle ilinize sevk',
                'Aracınız kurumsal çekiciyle gelsin.',
                LucideIcons.truck,
                () => context.push('/uzaktan-satin-alma'),
              ),
            ];
            if (c.maxWidth < Olcu.satirYatayEsik ||
                MediaQuery.textScalerOf(context).scale(1) >
                    Olcu.buyukMetinEsik) {
              return Column(
                children: [
                  children[0],
                  const SizedBox(height: Olcu.s12),
                  children[1],
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: children[0]),
                  const SizedBox(width: Olcu.s12),
                  Expanded(child: children[1]),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HizmetKarti extends StatelessWidget {
  final String baslik, aciklama;
  final IconData ikon;
  final VoidCallback onTap;
  final bool yakinda;
  const _HizmetKarti(
    this.baslik,
    this.aciklama,
    this.ikon,
    this.onTap, {
    this.yakinda = true,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Olcu.kartKose),
      child: Kart(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ikon,
                  size: Olcu.ikonInce,
                  color: YbRenkler.of(context).birincil,
                ),
                const Spacer(),
                if (yakinda) const YakindaRozeti(),
              ],
            ),
            const SizedBox(height: Olcu.s16),
            Text(baslik, style: Yazilar.bolumBaslik),
            const SizedBox(height: Olcu.s8),
            Text(
              aciklama,
              style: Yazilar.govdeKucuk.copyWith(
                color: YbRenkler.of(context).metinIkincil,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class HizmetFiyati extends StatelessWidget {
  final Json veri;
  final bool toplam;
  const HizmetFiyati(this.veri, {super.key, this.toplam = false});
  @override
  Widget build(BuildContext context) {
    final tutarlar = veri['totals'] is Map ? object(veri['totals']) : veri;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('YerimeBak hizmet bedeli', style: Yazilar.etiket),
        Text(hizmetPara(tutarlar['service_fee_tl']), style: Yazilar.rakamBuyuk),
        Text(
          tutarlar['service_fee_incl_vat_tl'] is num
              ? 'KDV hariç · KDV dahil ${hizmetPara(tutarlar['service_fee_incl_vat_tl'])}'
              : 'KDV hariç · KDV dahil hizmet tutarı henüz belirtilmedi.',
          style: Yazilar.govdeKucuk,
        ),
        if (toplam) ...[
          const SizedBox(height: Olcu.s12),
          ValueLine(
            'Kurumsal firma paketi (KDV dahil)',
            hizmetPara(tutarlar['package_price_tl']),
          ),
          ValueLine('Hizmet KDV tutarı', hizmetPara(tutarlar['vat_tl'])),
          ValueLine('Ödenecek toplam', hizmetPara(tutarlar['total_tl'])),
        ],
      ],
    );
  }
}

class YerindeIncelemeEkrani extends ConsumerWidget {
  final Json? arac;
  const YerindeIncelemeEkrani({super.key, this.arac});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider).valueOrNull,
        acik = config?.expertizEnabled == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Yerinde ekspertiz')),
      body: SingleChildScrollView(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Panel('Başka şehirde olsanız da aracın yanında olun', [
                if (!acik) const YakindaRozeti(),
                const SizedBox(height: Olcu.s16),
                const Text(
                  'Başka şehirde olsanız da aracı anlaşmalı kurumsal ekspertiz firmamız inceler; satıcıyla randevuyu biz ayarlarız, tüm raporlar uygulamanıza gelir.',
                ),
                const SizedBox(height: Olcu.s12),
                const Text(
                  'Pilot il İstanbul, ardından 81 il',
                  style: Yazilar.bolumBaslik,
                ),
                const SizedBox(height: Olcu.s8),
                const Text(
                  'İncelemeye katılmanız gerekmez. Hizmet bedeli ve seçtiğiniz firma paketi için tahsilat tek yerden yapılır.',
                ),
              ]),
              const Panel('Hizmetin kapsamı', [
                ListeSatiri(
                  'İç ekspertiz',
                  ikon: LucideIcons.scanEye,
                  aciklama: 'İç mekan ve donanım kontrolleri.',
                ),
                ListeSatiri(
                  'Dış ekspertiz',
                  ikon: LucideIcons.car,
                  aciklama: 'Boya, kaporta ve görünür durum.',
                ),
                ListeSatiri(
                  'Kurumsal ekspertiz',
                  ikon: LucideIcons.clipboardCheck,
                  aciklama: 'Anlaşmalı firmanın cihazlı inceleme raporu.',
                ),
                ListeSatiri(
                  'Yapay zekâ analiz raporu',
                  ikon: LucideIcons.fileSearch,
                  aciklama:
                      'Bulgularla birlikte araç değerinin değerlendirilmesi.',
                ),
              ]),
              ref
                  .watch(hizmetKatalogProvider)
                  .when(
                    data: (data) => Panel('Hizmet bedeli', [
                      HizmetFiyati(data),
                      const SizedBox(height: Olcu.s8),
                      const Text(
                        'Kurumsal ekspertiz paket ücreti ayrıca eklenir.',
                      ),
                    ]),
                    error: (e, _) => FailureView(
                      e,
                      () => ref.invalidate(hizmetKatalogProvider),
                    ),
                    loading: () => const LoadingView(),
                  ),
              if (acik)
                AnaButon(
                  'Talep oluştur',
                  () async => context.push('/ekspertiz/talep', extra: arac),
                )
              else
                AnaButon(
                  'Açılınca bana haber ver',
                  () => ref
                      .read(platformProvider)
                      .openLink(
                        Uri(
                          scheme: 'mailto',
                          path:
                              config?.supportEmail ?? 'destek@yerimebak.com.tr',
                          queryParameters: {
                            'subject': 'Yerinde ekspertiz açılış haberi',
                            'body':
                                'Yerinde ekspertiz hizmeti açıldığında bilgi almak istiyorum.',
                          },
                        ).toString(),
                      ),
                ),
              const SizedBox(height: Olcu.s12),
              IkincilButon(
                'Aracı uzaktan satın alma süreci',
                () async => context.push('/uzaktan-satin-alma'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UzaktanSatinAlmaEkrani extends ConsumerWidget {
  const UzaktanSatinAlmaEkrani({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Aracı uzaktan satın alın')),
    body: SingleChildScrollView(
      child: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Panel('Satın alma yolculuğunuz', [
              Text('Pilot il İstanbul, ardından 81 il', style: Yazilar.baslik2),
              SizedBox(height: Olcu.s12),
              Text(
                'Araç almadan önce doğru bilgiye ulaşın; sonraki adımlarda da yanınızda olmayı planlıyoruz.',
              ),
            ]),
            const _SurecAdimi(
              '1. Yapay zekâ analiz raporu',
              'İlanı, fiyatı ve hasar beyanını değerlendirerek başlayın.',
              LucideIcons.fileSearch,
              simdi: true,
            ),
            _SurecAdimi(
              '2. Yerinde ekspertiz',
              'Anlaşmalı kurumsal ekspertiz firması aracı inceler; randevuyu biz ayarlarız.',
              LucideIcons.clipboardCheck,
              simdi:
                  ref.watch(configProvider).valueOrNull?.expertizEnabled ==
                  true,
            ),
            const _SurecAdimi(
              '3. Vekaletle satın alma',
              'Karar verirseniz personelimiz noterde alış işlemini vekaletle sizin adınıza yapar. Araç YerimeBak üzerine geçmez; doğrudan sizin adınıza tescil edilir.',
              LucideIcons.keyRound,
            ),
            const _SurecAdimi(
              '4. Çekiciyle ilinize sevk',
              'Aracınız kurumsal bir çekici firmasıyla yüklenip bulunduğunuz ile sevk edilir.',
              LucideIcons.truck,
            ),
            AnaButon(
              'Önce araç analizi yapın',
              () async => context.push('/analiz'),
            ),
            const SizedBox(height: Olcu.s12),
            IkincilButon(
              'Yerinde ekspertizi inceleyin',
              () async => context.push('/yerinde-inceleme'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SurecAdimi extends StatelessWidget {
  final String baslik, metin;
  final IconData ikon;
  final bool simdi;
  const _SurecAdimi(this.baslik, this.metin, this.ikon, {this.simdi = false});
  @override
  Widget build(BuildContext context) => Panel(baslik, [
    Icon(ikon, size: Olcu.ikonInce, color: YbRenkler.of(context).birincil),
    const SizedBox(height: Olcu.s12),
    YakindaRozeti(simdi: simdi),
    const SizedBox(height: Olcu.s12),
    Text(metin),
  ]);
}

class SonrakiAdim extends ConsumerWidget {
  final Json arac;
  const SonrakiAdim(this.arac, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Panel('Sonraki adım', [
    const Text(
      'Almaya karar vermeden önce aracı yerinde inceletin. Başka şehirde olsanız da randevuyu biz ayarlarız.',
    ),
    const SizedBox(height: Olcu.s12),
    AnaButon(
      'Yerinde ekspertizi inceleyin',
      () async => context.push(
        ekspertizYolu(
          ref.read(configProvider).valueOrNull?.expertizEnabled == true,
        ),
        extra: arac,
      ),
    ),
  ]);
}
