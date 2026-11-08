import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../tema/renkler.dart';
import '../api/providers.dart';
import '../api/report_list_controller.dart';
import '../bilesenler/ortak.dart';
import '../tema/olculer.dart';
import '../api/models.dart';
import '../bilesenler/alt_eylem_cubugu.dart';
import '../bilesenler/pazarlik_plani.dart';
import '../bilesenler/rapor_gorunumu.dart';
import 'home_screen.dart';
import '../hizmetler/hizmet_tanitim.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(reportListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Raporlarım')),
      body: RefreshIndicator(
        onRefresh: list.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (list.loading)
                    const LoadingView()
                  else ...[
                    if (list.error != null)
                      FailureView(list.error!, list.refresh),
                    if (list.reports.isEmpty && list.error == null)
                      const Panel('Raporlarım', [
                        Text('Henüz değerleme raporunuz yok.'),
                      ]),
                    for (final report in list.reports)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Olcu.kartArasi),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Olcu.kartIci,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ReportTile(report),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: Olcu.s8,
                                    ),
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _sil(context, list, report),
                                      icon: const Icon(
                                        LucideIcons.trash2,
                                        size: Olcu.ikonInce,
                                      ),
                                      label: Text(
                                        'Sil',
                                        semanticsLabel:
                                            '${report.title.isEmpty ? 'Araç analizi' : report.title} raporunu sil',
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: YbRenkler.of(
                                          context,
                                        ).tehlike,
                                        minimumSize: const Size(
                                          48,
                                          Olcu.dokunma,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (list.hasMore)
                      ActionButton('Daha fazla rapor', list.next),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Onay sorar, raporu siler (09.11.2026; sitedeki "Sil" ile aynı: kayıt ve doğrulama korunur).
Future<void> _sil(
  BuildContext context,
  ReportListController list,
  ReportSummary report,
) async {
  final ad = report.title.isEmpty ? 'Bu rapor' : report.title;
  final onay = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rapor silinsin mi?'),
      content: Text(
        '$ad raporu listenizden kalıcı olarak silinecek. Bu işlem geri alınamaz.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
  if (onay != true || !context.mounted) return;
  final mesaj = ScaffoldMessenger.of(context);
  try {
    await list.remove(report.id);
    mesaj.showSnackBar(const SnackBar(content: Text('Rapor silindi.')));
  } catch (e) {
    mesaj.showSnackBar(SnackBar(content: Text('Rapor silinemedi: $e')));
  }
}

class ReportDetailScreen extends ConsumerWidget {
  final String id;
  const ReportDetailScreen(this.id, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(reportDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Rapor detayı')),
      bottomNavigationBar:
          detail.valueOrNull == null || detail.valueOrNull!.summaryOnly
          ? null
          : AltEylemCubugu(
              mesaj: text(detail.valueOrNull!.plan['saticiMesaji']).isEmpty
                  ? null
                  : () async {
                      unawaited(
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => SafeArea(
                            child: SingleChildScrollView(
                              child: PageBody(
                                child: SaticiMesaji(
                                  text(
                                    detail.requireValue.plan['saticiMesaji'],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
              pdf: () =>
                  ref.read(platformProvider).openPdf(ref.read(apiProvider), id),
            ),
      body: SingleChildScrollView(
        child: PageBody(
          child: detail.when(
            data: (snapshot) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ReportView(
                  snapshot,
                  onLink: ref.read(platformProvider).openLink,
                  sonrakiAdim: SonrakiAdim(snapshot.vehicle),
                ),
              ],
            ),
            error: (e, _) =>
                FailureView(e, () => ref.invalidate(reportDetailProvider(id))),
            loading: () => const LoadingView(),
          ),
        ),
      ),
    );
  }
}
