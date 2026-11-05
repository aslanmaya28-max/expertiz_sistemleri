import 'package:flutter/material.dart';
import '../api/models.dart';
import 'ortak.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';

bool legacySampleWarning(String value, int count) =>
    [3, 4].contains(count) &&
    [
      'Yalnızca $count doğrulanmış emsal ilan bulundu (hedef 5)',
      'Yalnızca $count doğrulanmış emsal ilan bulundu (hedef 5).',
    ].contains(value);

class ReportSummarySection extends StatelessWidget {
  final ReportSnapshot snapshot;
  const ReportSummarySection(this.snapshot, {super.key});
  @override
  Widget build(BuildContext context) {
    final data = snapshot.summary, fair = object(snapshot.summary['adilFiyat']);
    if (data.isEmpty) return const SizedBox.shrink();
    return Panel('Özet', [
      ValueLine(
        'Piyasaya göre fiyatı',
        text(object(data['piyasaKonumu'])['metin']),
      ),
      ValueLine('Adil fiyat', '${money(fair['min'])} – ${money(fair['max'])}'),
      if (strings(data['riskler']).isNotEmpty) ...[
        const Text('En önemli riskler'),
        BulletList(
          strings(data['riskler'])
              .where(
                (s) => !legacySampleWarning(
                  s,
                  integer(snapshot.market['emsalSayisi']),
                ),
              )
              .toList(),
        ),
      ],
      if (strings(data['pazarlikGerekceleri']).isNotEmpty) ...[
        const Text('Pazarlık gerekçeleri'),
        BulletList(strings(data['pazarlikGerekceleri'])),
      ],
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Olcu.s16),
        decoration: BoxDecoration(
          color: YbRenkler.of(context).birincilYuzey,
          borderRadius: BorderRadius.circular(Olcu.butonKose),
        ),
        child: ValueLine('Şimdi ne yapmalı?', text(data['simdiNeYapmali'])),
      ),
    ]);
  }
}

class ReportPrices extends StatelessWidget {
  final ReportSnapshot snapshot;
  const ReportPrices(this.snapshot, {super.key});
  @override
  Widget build(BuildContext context) {
    final v = snapshot.valuation,
        fair = object(snapshot.valuation['adilFiyatAraligi']);
    return Panel('Değerleme', [
      ValueLine('İlan fiyatı', money(snapshot.vehicle['ilanFiyati'])),
      if (snapshot.market['ortalama'] is num && snapshot.market['ortalama'] > 0)
        ValueLine(
          'Benzer ${integer(snapshot.market['emsalSayisi'])} ilanın ortalaması${snapshot.market['duzeltme'] != null ? ' (bu araca göre)' : ''}',
          money(snapshot.market['ortalama']),
        ),
      ValueLine('Tavsiye alım fiyatı', money(v['tavsiyeFiyat'])),
      ValueLine(
        'Adil fiyat aralığı',
        '${money(fair['min'])} – ${money(fair['max'])}',
      ),
      ValueLine('Hasarsız piyasa değeri', money(v['temizPiyasaDegeri'])),
    ]);
  }
}
