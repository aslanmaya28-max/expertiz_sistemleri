import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/models.dart';
import '../api/providers.dart';
import '../bilesenler/ikincil_buton.dart';
import '../bilesenler/ortak.dart';
import '../tema/olculer.dart';
import '../tema/yazi.dart';
import '../hizmetler/hizmet_tanitim.dart';
import '../hizmetler/hizmet_api.dart';
import '../hizmetler/kesfet.dart';
import '../tema/renkler.dart';
import '../bilesenler/marka.dart';
import '../bilesenler/kart.dart';
import '../analiz/analiz_ekranlari.dart';
import '../rehber/ilk_kullanim_rehberi.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final goster = await ref.read(rehberDeposuProvider).ilkAcilis();
      if (goster && mounted && ModalRoute.of(context)?.isCurrent == true) {
        await ilkKullanimRehberiniAc(context, ref);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(okunmamisBildirimSayisiProvider);
    }
  }

  Future<void> _bildirimleriAc() async {
    await context.push('/bildirimler');
    if (mounted) ref.invalidate(okunmamisBildirimSayisiProvider);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider),
        balance = ref.watch(balanceProvider),
        recent = ref.watch(recentReportsProvider);
    final bildirimler = ref.watch(okunmamisBildirimSayisiProvider);
    Future<void> refresh() async {
      ref.invalidate(balanceProvider);
      ref.invalidate(recentReportsProvider);
      ref.invalidate(okunmamisBildirimSayisiProvider);
      await ref.read(sessionProvider).refreshProfile();
      await Future.wait([
        ref.read(balanceProvider.future),
        ref.read(recentReportsProvider.future),
        // Sayaç isteği başarısızsa diğer ana sayfa verileri yine yenilenir.
        ref.read(okunmamisBildirimSayisiProvider.future).catchError((_) => 0),
      ]);
    }

    final r = YbRenkler.of(context);
    // Kaydırılan içerik durum çubuğunun altına girmesin; çubuk alanı başlık
    // rengiyle sabit kalır.
    // Bant koyu olduğundan durum çubuğu simgeleri açık renk olur.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? r.markaBandi
            : r.zemin,
        body: SafeArea(
          bottom: false,
          child: ColoredBox(
            color: r.zemin,
            child: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _AnaBaslik(
                    balance: balance,
                    bildirimler: bildirimler,
                    bildirimleriAc: _bildirimleriAc,
                  ),
                  PageBody(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                ilkKullanimRehberiniAc(context, ref),
                            icon: const Icon(
                              LucideIcons.circleHelp,
                              size: Olcu.ikonInce,
                            ),
                            label: const Text('Nasıl kullanılır?'),
                          ),
                        ),
                        if (session.user?.emailVerified == false)
                          Panel('E-posta adresinizi doğrulayın', [
                            Text(
                              '${session.user!.email} adresini henüz doğrulamadınız. E-postanızdaki bağlantıya tıklayın.',
                            ),
                            const SizedBox(height: Olcu.s12),
                            IkincilButon('Tekrar gönder', () async {
                              final message = await ref
                                  .read(accountRepositoryProvider)
                                  .resendVerification();
                              await ref.read(sessionProvider).refreshProfile();
                              if (context.mounted) {
                                showMessage(context, message);
                              }
                            }),
                          ]),
                        Kart(
                          analiz: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Yeni araç analizi',
                                style: Yazilar.baslik2,
                              ),
                              const SizedBox(height: Olcu.s8),
                              const Text(
                                'İlanı ve araç bilgilerini birlikte değerlendirin.',
                              ),
                              const SizedBox(height: Olcu.s16),
                              const IlanLinkKutusu(sade: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: Olcu.s24),
                        recent.when(
                          data: (page) => Panel('Son raporlar', [
                            if (page.reports.isEmpty)
                              const Text('Henüz değerleme raporunuz yok.'),
                            for (final report in page.reports)
                              ReportTile(report),
                            TextButton(
                              onPressed: () => context.go('/raporlar'),
                              child: const Text('Tüm raporlarım'),
                            ),
                          ]),
                          error: (e, _) => FailureView(
                            e,
                            () => ref.invalidate(recentReportsProvider),
                          ),
                          loading: () => const LoadingView(),
                        ),
                        const KesfetKartlari(),
                        const HizmetKartlari(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReportTile extends StatelessWidget {
  final ReportSummary report;
  const ReportTile(this.report, {super.key});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push('/raporlar/${Uri.encodeComponent(report.id)}'),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: Olcu.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.car,
                size: Olcu.ikonInce,
                color: YbRenkler.of(context).ikonPasif,
              ),
              const SizedBox(width: Olcu.s12),
              Expanded(
                child: Text(
                  report.title.isEmpty ? 'Araç analizi' : report.title,
                  style: Yazilar.bolumBaslik,
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: Olcu.ikonInce),
            ],
          ),
          const SizedBox(height: Olcu.s8),
          Text(
            '${dateText(report.createdAt)} · ${report.summaryOnly ? 'Özet kayıt — tam rapor bulunmuyor' : report.reportNumber}',
            style: Yazilar.etiket.copyWith(
              color: YbRenkler.of(context).metinIkincil,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AnaBaslik extends StatelessWidget {
  final AsyncValue<int> balance;
  final AsyncValue<int> bildirimler;
  final VoidCallback bildirimleriAc;
  const _AnaBaslik({
    required this.balance,
    required this.bildirimler,
    required this.bildirimleriAc,
  });
  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context),
        light = Theme.of(context).brightness == Brightness.light;
    final bildirimEtiketi = bildirimler.when(
      data: (n) => n > 0
          ? 'Bildirimler, $n okunmamış'
          : 'Bildirimler, okunmamış bildirim yok',
      error: (_, _) => 'Bildirimler, sayı alınamadı',
      loading: () => 'Bildirimler',
    );
    return Container(
      color: light ? r.markaBandi : r.zemin,
      child: SafeArea(
        bottom: false,
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Olcu.s12,
                children: [
                  Marka(bant: light),
                  Semantics(
                    container: true,
                    button: true,
                    label: bildirimEtiketi,
                    child: Tooltip(
                      message: bildirimEtiketi,
                      excludeFromSemantics: true,
                      child: IconButton(
                        onPressed: bildirimleriAc,
                        color: light ? r.beyaz : r.metin,
                        icon: Badge(
                          isLabelVisible:
                              (bildirimler.valueOrNull ?? 0) > 0 &&
                              !bildirimler.hasError,
                          label: ExcludeSemantics(
                            child: Text(
                              (bildirimler.valueOrNull ?? 0) > 99
                                  ? '99+'
                                  : '${bildirimler.valueOrNull ?? 0}',
                            ),
                          ),
                          child: const Icon(LucideIcons.bell, size: Olcu.ikon),
                        ),
                      ),
                    ),
                  ),
                  if (!light)
                    balance.when(
                      data: (v) => TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: r.yuzeyIkincil,
                          foregroundColor: r.vurguMetin,
                        ),
                        onPressed: () => context.go('/kredi'),
                        icon: const Icon(
                          LucideIcons.wallet,
                          size: Olcu.ikonInce,
                        ),
                        label: Text('$v kredi'),
                      ),
                      error: (e, _) => TextButton(
                        onPressed: () => context.go('/kredi'),
                        child: const Text('Bakiyeyi gör'),
                      ),
                      loading: () => const SizedBox.shrink(),
                    ),
                ],
              ),
              if (light) ...[
                const SizedBox(height: Olcu.s24),
                Text(
                  'Araç alırken doğru adımı atın.',
                  style: Yazilar.baslik1.copyWith(color: r.beyaz),
                ),
                const SizedBox(height: Olcu.s16),
                balance.when(
                  data: (v) => Wrap(
                    spacing: Olcu.s16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '$v kredi',
                        style: Yazilar.bolumBaslik.copyWith(color: r.vurguBant),
                      ),
                      TextButton(
                        onPressed: () => context.go('/kredi'),
                        child: Text(
                          'Kredi yükle',
                          style: Yazilar.etiket.copyWith(color: r.beyaz),
                        ),
                      ),
                    ],
                  ),
                  error: (e, _) => TextButton(
                    onPressed: () => context.go('/kredi'),
                    child: Text(
                      'Kredi bakiyesi alınamadı · Tekrar dene',
                      style: Yazilar.etiket.copyWith(color: r.markaBandiMetin),
                    ),
                  ),
                  loading: () => Text(
                    'Bakiye yükleniyor',
                    style: Yazilar.etiket.copyWith(color: r.markaBandiMetin),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ComingSoonScreen extends StatelessWidget {
  final bool credits;
  const ComingSoonScreen({super.key, this.credits = false});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(credits ? 'Kredi' : 'Araç analizi')),
    body: PageBody(
      child: Panel(credits ? 'Kredi satın alma yakında' : 'Araç analizi yakında', [
        Text(
          credits
              ? 'Google Play üzerinden kredi satın alma sonraki sürümde açılacak. Mevcut kredileriniz hesabınızda durur.'
              : 'İlan okuma ve analiz formu sonraki sürümde açılacak. Kayıtlı raporlarınızı Raporlarım bölümünde inceleyebilirsiniz.',
        ),
        TextButton(
          onPressed: () => context.go('/'),
          child: const Text('Ana sayfa'),
        ),
      ]),
    ),
  );
}
