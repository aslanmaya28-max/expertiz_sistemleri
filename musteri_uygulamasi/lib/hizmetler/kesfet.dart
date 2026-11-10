import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
import '../bilesenler/rapor_gorunumu.dart';
import '../kredi/rapor_icerigi.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';
import 'hizmet_api.dart';
import 'hizmet_tanitim.dart';

/// Ana sayfadaki "Keşfet": sitedeki Yerinde inceleme, Araç değerleme, Örnek rapor ve Fiyatlar
/// sayfalarının uygulama karşılıkları (kullanıcı isteği, 11.11.2026).
///
/// Google Play kuralı: uygulamada kredi (dijital ürün) için site ya da başka ödeme yoluna
/// yönlendirilmez; kredi fiyatları yalnız Kredi ekranında, Google Play'den gelir.
class KesfetKartlari extends StatelessWidget {
  const KesfetKartlari({super.key});
  @override
  Widget build(BuildContext context) {
    final kartlar = [
      _KesfetKarti(
        'Yerinde inceleme',
        'Uzman aracı sizin yerinize incelesin.',
        LucideIcons.clipboardCheck,
        '/yerinde-inceleme',
      ),
      _KesfetKarti(
        'Araç değerleme',
        'İlan fiyatı doğru mu?',
        LucideIcons.scale,
        '/arac-degerleme',
      ),
      _KesfetKarti(
        'Örnek rapor',
        'Raporun tamamını görün.',
        LucideIcons.fileText,
        '/ornek-rapor',
      ),
      _KesfetKarti(
        'Fiyatlar',
        'Değerleme ve inceleme ücretleri.',
        LucideIcons.tag,
        '/fiyatlar',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Olcu.s24),
        const Text('Keşfet', style: Yazilar.baslik2),
        const SizedBox(height: Olcu.s16),
        LayoutBuilder(
          builder: (context, c) {
            final tekSutun =
                c.maxWidth < Olcu.satirYatayEsik ||
                MediaQuery.textScalerOf(context).scale(1) > Olcu.buyukMetinEsik;
            if (tekSutun) {
              return Column(
                children: [
                  for (final k in kartlar) ...[
                    k,
                    const SizedBox(height: Olcu.s12),
                  ],
                ],
              );
            }
            return Column(
              children: [
                for (var i = 0; i < kartlar.length; i += 2) ...[
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: kartlar[i]),
                        const SizedBox(width: Olcu.s12),
                        Expanded(child: kartlar[i + 1]),
                      ],
                    ),
                  ),
                  const SizedBox(height: Olcu.s12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _KesfetKarti extends StatelessWidget {
  final String baslik, aciklama, yol;
  final IconData ikon;
  const _KesfetKarti(this.baslik, this.aciklama, this.ikon, this.yol);
  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    return Semantics(
      button: true,
      label: baslik,
      child: InkWell(
        onTap: () => context.push(yol),
        borderRadius: BorderRadius.circular(Olcu.kartKose),
        child: Kart(
          // Simge üstte, başlık ve kısa açıklama altta: telefonda iki sütunda da yazı sıkışmaz.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(ikon, size: Olcu.ikonInce, color: r.birincil),
                  const Spacer(),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 20,
                    color: r.metinIkincil,
                  ),
                ],
              ),
              const SizedBox(height: Olcu.s12),
              Text(baslik, style: Yazilar.bolumBaslik),
              const SizedBox(height: Olcu.s4),
              Text(aciklama, style: Yazilar.govdeKucuk),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sitedeki /arac-degerleme sayfasının sade uygulama sürümü.
class AracDegerlemeEkrani extends StatelessWidget {
  const AracDegerlemeEkrani({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Araç değerleme')),
    body: SingleChildScrollView(
      child: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Panel('İlan fiyatı doğru mu? Aracı görmeden öğrenin', [
              Text(
                'İlan bilgilerini girin; benzer ilanları sizin aracınıza göre düzelterek adil fiyat aralığını, '
                'bildirilen hasarın fiyat etkisini, pazarlık planını ve modelin bilinen sorunlarını tek raporda verelim. '
                'Türkiye genelindeki ilanlar için geçerlidir.',
              ),
            ]),
            const RaporIcerigiKarti(),
            const SizedBox(height: Olcu.kartArasi),
            const Panel('Kimler için?', [
              BulletList([
                'Beğendiği ilanın fiyatının piyasaya uygun olup olmadığını öğrenmek isteyenler',
                'Satıcıyla pazarlığa hazırlıklı gitmek isteyenler',
                'Türkiye’nin herhangi bir yerindeki aracı, gitmeden önce elemek isteyenler',
              ]),
            ]),
            const Panel('Nasıl işler?', [
              ListeSatiri(
                'Bilgileri girin',
                ikon: LucideIcons.link,
                aciklama:
                    'İlan linkini yapıştırın ya da ilan uygulamasında Paylaş → YerimeBak deyin; bilgiler otomatik dolar. '
                    'Boyalı ve değişen parçaları araç çizimi üzerinde işaretleyin.',
              ),
              ListeSatiri(
                'Kredi',
                ikon: LucideIcons.coins,
                aciklama:
                    'Her rapor 1 kredi kullanır. Yeterli benzer ilan bulunamazsa kredi düşülmez.',
              ),
              ListeSatiri(
                'Rapor',
                ikon: LucideIcons.fileCheck,
                aciklama:
                    'Genellikle bir dakikadan kısa sürede hazırlanır; Raporlarım’da saklanır ve PDF olarak indirilebilir.',
              ),
            ]),
            const Panel('Ne teslim edilir?', [
              Text(
                'Ekranda ve PDF olarak değerleme raporu; YerimeBak doğrulama kodu ile.',
              ),
              SizedBox(height: Olcu.s8),
              Text(
                'Önemli: değerleme raporu ilan bilgilerine, sizin beyanınıza ve internetteki ilanlara dayanır; araç yerinde '
                'incelenmez. Boya, değişen ve hasar bilgisini doğrulatmak için yerinde inceleme isteyebilirsiniz.',
              ),
            ]),
            const Panel('Sık sorulan sorular', [
              _Soru(
                'Yeterli benzer ilan bulunamazsa ne olur?',
                'Aynı model ve kasadan yeterli ilan bulunamazsa rapor üretilmez ve krediniz düşülmez.',
              ),
              _Soru(
                'Sahibinden ilanını değerletebilir miyim?',
                'Evet. İlan uygulamasında Paylaş → YerimeBak deyin ya da ilanın ekran görüntüsünü yükleyin; marka, model, paket, '
                    'yıl, kilometre ve fiyat otomatik dolar. İsterseniz kendiniz düzeltebilirsiniz.',
              ),
              _Soru(
                'Rapor ne kadar sürede hazırlanır?',
                'Genellikle bir dakikadan kısa sürede. Rapor Raporlarım’da saklanır.',
              ),
            ]),
            AnaButon('Değerleme başlat', () async => context.go('/analiz')),
            const SizedBox(height: Olcu.s12),
            IkincilButon(
              'Örnek raporu incele',
              () async => context.push('/ornek-rapor'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Soru extends StatelessWidget {
  final String soru, yanit;
  const _Soru(this.soru, this.yanit);
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: Olcu.s12),
      expandedAlignment: Alignment.centerLeft,
      title: Text(soru, style: Yazilar.bolumBaslik),
      children: [Text(yanit)],
    ),
  );
}

/// Sitedeki örnek raporun aynısı (assets/ornek-rapor/degerleme.json; testte siteyle eşliği denetlenir).
final ornekRaporProvider = FutureProvider<ReportSnapshot>((ref) async {
  // loadString yerine load: önbelleğe alınmaz ve büyük dosyada ayrı isolate açmaz.
  final veri = await rootBundle.load('assets/ornek-rapor/degerleme.json');
  final metin = utf8.decode(
    veri.buffer.asUint8List(veri.offsetInBytes, veri.lengthInBytes),
  );
  return ReportSnapshot.fromJson(object(jsonDecode(metin)));
});

class OrnekRaporEkrani extends ConsumerWidget {
  const OrnekRaporEkrani({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = YbRenkler.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Örnek rapor')),
      body: SingleChildScrollView(
        child: PageBody(
          child: ref
              .watch(ornekRaporProvider)
              .when(
                loading: () => const LoadingView(),
                error: (e, _) =>
                    FailureView(e, () => ref.invalidate(ornekRaporProvider)),
                data: (snapshot) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Kart(
                      renk: r.vurguYuzey,
                      child: const Text(
                        'ÖRNEK RAPOR · Gerçek bir araç için hazırlanmış örnek değerleme raporudur; doğrulanamaz. '
                        '1 kredi ile kendi aracınız için aynısını alırsınız.',
                        style: Yazilar.govdeKucuk,
                      ),
                    ),
                    const SizedBox(height: Olcu.kartArasi),
                    ReportView(
                      snapshot,
                      onLink: ref.read(platformProvider).openLink,
                    ),
                    const SizedBox(height: Olcu.s16),
                    AnaButon(
                      'Kendi aracım için değerleme al',
                      () async => context.go('/analiz'),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}

/// Fiyatlar: değerleme kredisi fiyatları Google Play'den (Kredi ekranı); yerinde inceleme bedeli sunucudan.
class FiyatlarEkrani extends ConsumerWidget {
  const FiyatlarEkrani({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Fiyatlar')),
    body: SingleChildScrollView(
      child: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Panel('Araç değerleme raporu', [
              const Text('1 rapor = 1 kredi', style: Yazilar.bolumBaslik),
              const SizedBox(height: Olcu.s8),
              const BulletList([
                'Kredi paketleri ve güncel fiyatlar Kredi ekranındadır.',
                'Yeterli benzer ilan bulunamazsa rapor üretilmez, kredi düşülmez.',
                'Krediler süresizdir; hesabınızda saklanır.',
              ]),
              const SizedBox(height: Olcu.s12),
              IkincilButon(
                'Kredi paketlerini gör',
                () async => context.go('/kredi'),
              ),
            ]),
            ref
                .watch(hizmetKatalogProvider)
                .when(
                  data: (data) => Panel('Yerinde inceleme', [
                    HizmetFiyati(data),
                    const SizedBox(height: Olcu.s8),
                    const Text(
                      'Seçtiğiniz kurumsal ekspertiz firmasının paket ücreti, firmanın KDV dahil fiyatıyla ayrıca eklenir. '
                      'Toplam tutar ödemeden önce açıkça gösterilir.',
                    ),
                  ]),
                  error: (e, _) => FailureView(
                    e,
                    () => ref.invalidate(hizmetKatalogProvider),
                  ),
                  loading: () => const LoadingView(),
                ),
            const Panel('Vekaletle satın alma ve çekici', [
              Text(
                'Bu hizmetler yakında. Ücret, aracın ve mesafenin durumuna göre ayrıca bildirilir.',
              ),
            ]),
          ],
        ),
      ),
    ),
  );
}
