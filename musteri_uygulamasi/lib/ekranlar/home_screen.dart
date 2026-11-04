import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/models.dart';
import '../api/providers.dart';
import '../bilesenler/ortak.dart';
import '../tema/olculer.dart';
import '../tema/yazi.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('YerimeBak')),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (session.user?.emailVerified == false)
                    Panel('E-posta adresinizi doğrulayın', [
                      Text(
                        '${session.user!.email} adresini henüz doğrulamadınız. E-postanızdaki bağlantıya tıklayın.',
                      ),
                      ActionButton('Tekrar gönder', () async {
                        final message = await ref
                            .read(accountRepositoryProvider)
                            .resendVerification();
                        await ref.read(sessionProvider).refreshProfile();
                        if (context.mounted) showMessage(context, message);
                      }),
                    ]),
                  balance.when(
                    data: (value) => Panel('Kredi bakiyeniz', [
                      Text('$value kredi', style: Yazilar.rakamBuyuk),
                      Text(
                        '${ref.watch(configProvider).valueOrNull?.analysisCost ?? 1} kredi ile bir araç analizi',
                      ),
                      TextButton(
                        onPressed: () => context.go('/kredi'),
                        child: const Text('Kredi yükle'),
                      ),
                    ]),
                    error: (e, _) =>
                        FailureView(e, () => ref.invalidate(balanceProvider)),
                    loading: () => const LoadingView(),
                  ),
                  ActionButton(
                    'Araç analizi başlat',
                    () async => context.push('/analiz'),
                  ),
                  const SizedBox(height: Olcu.s16),
                  recent.when(
                    data: (page) => Panel('Son raporlar', [
                      if (page.reports.isEmpty)
                        const Text('Henüz değerleme raporunuz yok.'),
                      for (final report in page.reports) ReportTile(report),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportTile extends StatelessWidget {
  final ReportSummary report;
  const ReportTile(this.report, {super.key});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(report.title.isEmpty ? 'Araç analizi' : report.title),
    subtitle: Text(
      '${dateText(report.createdAt)}\n${report.summaryOnly ? 'Özet kayıt — tam rapor bulunmuyor' : report.reportNumber}${report.decision.isEmpty ? '' : '\n${report.decision}'}',
    ),
    isThreeLine: true,
    onTap: () => context.push('/raporlar/${Uri.encodeComponent(report.id)}'),
  );
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
