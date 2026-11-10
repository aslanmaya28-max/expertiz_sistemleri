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
import '../hizmetler/kesfet.dart';
import '../tema/renkler.dart';
import '../bilesenler/marka.dart';
import '../bilesenler/kart.dart';
import '../analiz/analiz_ekranlari.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider),
        balance = ref.watch(balanceProvider),
        recent = ref.watch(recentReportsProvider);
    Future<void> refresh() async {
      ref.invalidate(balanceProvider);
      ref.invalidate(recentReportsProvider);
      await ref.read(sessionProvider).refreshProfile();
      await Future.wait([
        ref.read(balanceProvider.future),
        ref.read(recentReportsProvider.future),
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
                  _AnaBaslik(balance: balance),
                  PageBody(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
  const _AnaBaslik({required this.balance});
  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context),
        light = Theme.of(context).brightness == Brightness.light;
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
                        style: Yazilar.bolumBaslik.copyWith(
                          color: r.vurguBant,
                        ),
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
