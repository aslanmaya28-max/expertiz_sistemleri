import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/providers.dart';
import '../api/report_list_controller.dart';
import '../bilesenler/ortak.dart';
import '../bilesenler/rapor_gorunumu.dart';
import 'home_screen.dart';

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
                      Card(
                        child: Padding(
                          padding: EdgeInsets.zero,
                          child: ReportTile(report),
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

class ReportDetailScreen extends ConsumerWidget {
  final String id;
  const ReportDetailScreen(this.id, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(reportDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Rapor detayı')),
      body: SingleChildScrollView(
        child: PageBody(
          child: detail.when(
            data: (snapshot) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!snapshot.summaryOnly)
                  ActionButton(
                    'PDF raporunu aç',
                    () => ref
                        .read(platformProvider)
                        .openPdf(ref.read(apiProvider), id),
                  ),
                ReportView(
                  snapshot,
                  onLink: ref.read(platformProvider).openLink,
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
