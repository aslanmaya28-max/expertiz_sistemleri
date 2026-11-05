import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../api/models.dart';
import '../bilesenler/acilir_liste.dart';
import '../bilesenler/ana_buton.dart';
import '../bilesenler/bos_durum.dart';
import '../bilesenler/ikincil_buton.dart';
import '../bilesenler/ortak.dart';
import '../tema/olculer.dart';
import '../tema/yazi.dart';
import '../api/providers.dart';
import 'hizmet_api.dart';
import 'hizmet_dosyalari.dart';
import 'hizmet_tanitim.dart';

String _tarih(dynamic value) => dateText(DateTime.tryParse(text(value)));
String _arac(Json value) => [
  value['marka'] ?? value['brand'],
  value['model'],
  value['yil'] ?? value['year'],
].where((v) => text(v).isNotEmpty).join(' ');
String _durum(dynamic value) =>
    const {
      'payment_pending': 'Ödeme bekleniyor',
      'payment_failed': 'Ödeme tamamlanamadı',
      'OdemeBekliyor': 'Ödeme bekleniyor',
      'Islemde': 'İşlemde',
      'matched': 'Firma/personel eşleşti',
      'assigned': 'Görev atandı',
      'on_the_way': 'Personel yola çıktı',
      'arrived': 'Araç başına ulaşıldı',
      'in_progress': 'İnceleme sürüyor',
      'pending_approval': 'Rapor onay bekliyor',
      'published': 'Rapor hazır',
      'completed': 'Tamamlandı',
      'cancelled': 'İptal edildi',
    }[value] ??
    'Güncel durum: ${text(value)}';

class HizmetKayitlariEkrani extends ConsumerWidget {
  final bool raporlar;
  const HizmetKayitlariEkrani({super.key, this.raporlar = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = raporlar ? hizmetRaporlarProvider : hizmetTaleplerProvider;
    return Scaffold(
      appBar: AppBar(
        title: Text(raporlar ? 'Ekspertiz raporlarım' : 'Taleplerim'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(provider);
          await ref.read(provider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            PageBody(
              child: ref
                  .watch(provider)
                  .when(
                    loading: () => const LoadingView(),
                    error: (e, _) =>
                        FailureView(e, () => ref.invalidate(provider)),
                    data: (entries) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (entries.isEmpty)
                          BosDurum(
                            raporlar
                                ? 'Henüz ekspertiz raporunuz yok'
                                : 'Henüz talebiniz yok',
                            raporlar
                                ? 'Yayımlanan kurumsal ekspertiz raporlarınız burada görünür.'
                                : 'Yerinde ekspertiz hizmetinin ayrıntılarını inceleyebilirsiniz.',
                          ),
                        for (final row in entries)
                          Panel(
                            _arac(object(row['vehicle'])).isEmpty
                                ? 'Yerinde ekspertiz'
                                : _arac(object(row['vehicle'])),
                            [
                              Text(
                                text(
                                      object(row['progress'])['label'],
                                    ).isNotEmpty
                                    ? text(object(row['progress'])['label'])
                                    : _durum(row['status']),
                                style: Yazilar.bolumBaslik,
                              ),
                              if (!raporlar)
                                _TalepIlerlemesi(object(row['progress'])),
                              ValueLine(
                                'Tarih',
                                _tarih(
                                  row['published_at'] ?? row['created_at'],
                                ),
                              ),
                              if (text(row['plate']).isNotEmpty)
                                ValueLine('Plaka', text(row['plate'])),
                              if (text(row['firm_name']).isNotEmpty)
                                ValueLine('Firma', text(row['firm_name'])),
                              if (text(row['package_name']).isNotEmpty)
                                ValueLine('Paket', text(row['package_name'])),
                              if (row['total_tl'] is num)
                                ValueLine(
                                  'Toplam tutar',
                                  hizmetPara(row['total_tl']),
                                ),
                              if (raporlar)
                                AnaButon(
                                  'Ekspertiz raporunu aç',
                                  () async => context.push(
                                    '/ekspertiz-raporlari/${Uri.encodeComponent(text(row['id']))}',
                                  ),
                                )
                              else if (text(row['report_id']).isNotEmpty)
                                IkincilButon(
                                  'Ekspertiz raporlarım',
                                  () async =>
                                      context.push('/ekspertiz-raporlari'),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TalepIlerlemesi extends StatelessWidget {
  final Json progress;
  const _TalepIlerlemesi(this.progress);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (text(progress['person_name']).isNotEmpty)
        ValueLine('Uzman', text(progress['person_name'])),
      if (text(progress['next_label']).isNotEmpty)
        ValueLine('Sıradaki adım', text(progress['next_label'])),
      for (final step in objects(progress['steps']))
        if (text(step['label']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  step['done'] == true
                      ? LucideIcons.circleCheck
                      : LucideIcons.circle,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(text(step['label']))),
              ],
            ),
          ),
    ],
  );
}

class EkspertizRaporEkrani extends ConsumerWidget {
  final String id;
  const EkspertizRaporEkrani(this.id, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Ekspertiz raporu')),
    body: SingleChildScrollView(
      child: PageBody(
        child: ref
            .watch(hizmetRaporProvider(id))
            .when(
              loading: () => const LoadingView(),
              error: (e, _) =>
                  FailureView(e, () => ref.invalidate(hizmetRaporProvider(id))),
              data: (r) {
                final summary = object(r['summary']),
                    report = object(r['report']),
                    ai = object(r['ai']);
                final media = [
                  ...objects(r['corporate_reports']),
                  ...objects(r['photos']),
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Panel(
                      _arac(object(r['vehicle'])).isEmpty
                          ? 'Yayımlanan ekspertiz raporu'
                          : _arac(object(r['vehicle'])),
                      [
                        Text(text(r['report_no']), style: Yazilar.bolumBaslik),
                        ValueLine(
                          'Yayımlanma tarihi',
                          _tarih(r['published_at']),
                        ),
                        ValueLine('Firma', text(r['firm_name'])),
                        ValueLine(
                          'Doğrulama kodu',
                          text(r['verification_code']),
                        ),
                        if (summary['market_value'] is num)
                          ValueLine(
                            'Ekspertiz bulgularına göre değer',
                            money(summary['market_value']),
                          ),
                        if (summary['fair_price_min'] is num &&
                            summary['fair_price_max'] is num)
                          ValueLine(
                            'Adil fiyat aralığı',
                            '${money(summary['fair_price_min'])} – ${money(summary['fair_price_max'])}',
                          ),
                        if (text(summary['ai_comment']).isNotEmpty)
                          Text(text(summary['ai_comment'])),
                      ],
                    ),
                    for (final section in const [
                      ('adim2', 'Dış ekspertiz'),
                      ('adim3', 'İç ekspertiz'),
                      ('adim4', 'Boya ve kaporta'),
                    ])
                      if (objects(
                        object(report[section.$1])['kontrolListesi'],
                      ).isNotEmpty)
                        Panel(section.$2, [
                          AcilirListe(
                            children: [
                              for (final item in objects(
                                object(report[section.$1])['kontrolListesi'],
                              ))
                                ValueLine(
                                  text(item['label']),
                                  '${text(item['durumEtiket'] ?? item['durum'])}${item['mikron'] is num ? ' · ${number(item['mikron'])} μm' : ''}${text(item['not']).isEmpty ? '' : '\n${text(item['not'])}'}',
                                ),
                            ],
                          ),
                        ]),
                    if (strings(ai['kritikSorunlar']).isNotEmpty)
                      Panel('Dikkat edilecekler', [
                        BulletList(strings(ai['kritikSorunlar'])),
                      ]),
                    if (strings(
                      object(ai['raporOzeti'])['anahtarBulgular'],
                    ).isNotEmpty)
                      Panel('Önemli bulgular', [
                        BulletList(
                          strings(object(ai['raporOzeti'])['anahtarBulgular']),
                        ),
                      ]),
                    if (media.isNotEmpty)
                      Panel('Kurumsal rapor ve fotoğraflar', [
                        for (final item in media)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Olcu.s8),
                            child: IkincilButon(
                              text(item['original_name']).isEmpty
                                  ? 'Rapor dosyasını aç'
                                  : text(item['original_name']),
                              guvenliMedyaYolu(
                                        text(item['url']),
                                        ref.read(apiProvider).baseUri,
                                      ) ==
                                      null
                                  ? null
                                  : () => ref
                                        .read(hizmetDosyalariProvider)
                                        .ac(
                                          ref.read(apiProvider),
                                          text(item['url']),
                                        ),
                            ),
                          ),
                      ]),
                    Panel('Rapor paketi', [
                      const Text(
                        'PDF, kurumsal rapor ve mevcut fotoğrafları tek ZIP paketinde indirebilirsiniz.',
                      ),
                      const SizedBox(height: Olcu.s12),
                      AnaButon(
                        'Rapor paketini indir / aç',
                        () => ref
                            .read(hizmetDosyalariProvider)
                            .ac(
                              ref.read(apiProvider),
                              '/expertiz/reports/${Uri.encodeComponent(id)}/package',
                            ),
                      ),
                    ]),
                  ],
                );
              },
            ),
      ),
    ),
  );
}

class BildirimEkrani extends ConsumerWidget {
  const BildirimEkrani({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Bildirimler')),
    body: RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bildirimlerProvider);
        await ref.read(bildirimlerProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          PageBody(
            child: ref
                .watch(bildirimlerProvider)
                .when(
                  loading: () => const LoadingView(),
                  error: (e, _) =>
                      FailureView(e, () => ref.invalidate(bildirimlerProvider)),
                  data: (data) {
                    final items = objects(data['notifications']);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (items.isEmpty)
                          const BosDurum(
                            'Yeni bildiriminiz yok',
                            'Talep ve rapor güncellemelerini burada görebilirsiniz.',
                          ),
                        for (final item in items)
                          Panel(text(item['title']), [
                            Text(text(item['body'])),
                            const SizedBox(height: Olcu.s8),
                            Text(
                              _tarih(item['created_at']),
                              style: Yazilar.etiket,
                            ),
                            if (item['read'] != true)
                              IkincilButon('Okundu işaretle', () async {
                                await ref
                                    .read(hizmetRepositoryProvider)
                                    .okundu(integer(item['id']));
                                ref.invalidate(bildirimlerProvider);
                              }),
                            if (text(item['report_id']).isNotEmpty)
                              TextButton(
                                onPressed: () => context.push(
                                  '/ekspertiz-raporlari/${Uri.encodeComponent(text(item['report_id']))}',
                                ),
                                child: const Text('İlgili ekspertiz raporu'),
                              ),
                          ]),
                      ],
                    );
                  },
                ),
          ),
        ],
      ),
    ),
  );
}
