import 'package:flutter/material.dart';
import '../api/models.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';
import 'ortak.dart';
import 'fiyat_araligi.dart';
import 'rapor_karti.dart';

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
    final risks = strings(snapshot.summary['riskler'])
        .where(
          (s) =>
              !legacySampleWarning(s, integer(snapshot.market['emsalSayisi'])),
        )
        .toList();
    if (risks.isEmpty) return const SizedBox.shrink();
    return ReportCard(
      'En önemli riskler',
      [BulletList(risks)],
      icon: Icons.warning_amber_rounded,
      warning: true,
    );
  }
}

class NextActionSection extends StatelessWidget {
  final Json data;
  const NextActionSection(this.data, {super.key});
  @override
  Widget build(BuildContext context) {
    if (text(data['simdiNeYapmali']).isEmpty &&
        strings(data['pazarlikGerekceleri']).isEmpty) {
      return const SizedBox.shrink();
    }
    return ReportCard('Şimdi ne yapmalı?', [
      if (text(data['simdiNeYapmali']).isNotEmpty)
        Container(
          padding: const EdgeInsets.only(left: Olcu.s12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: YbRenkler.of(context).birincilMetin,
                width: Olcu.vurguluKenar,
              ),
            ),
          ),
          child: Text(text(data['simdiNeYapmali'])),
        ),
      if (strings(data['pazarlikGerekceleri']).isNotEmpty) ...[
        const SizedBox(height: Olcu.s12),
        const Text('Pazarlık gerekçeleri', style: Yazilar.bolumBaslik),
        BulletList(strings(data['pazarlikGerekceleri'])),
      ],
    ], icon: Icons.lightbulb_outline);
  }
}

class FairPriceSection extends StatelessWidget {
  final ReportSnapshot snapshot;
  const FairPriceSection(this.snapshot, {super.key});
  @override
  Widget build(BuildContext context) {
    final fair = object(snapshot.valuation['adilFiyatAraligi']).isNotEmpty
        ? object(snapshot.valuation['adilFiyatAraligi'])
        : object(snapshot.summary['adilFiyat']);
    return ReportCard('Adil fiyat aralığı', [
      Text(
        '${money(fair['min'])} –\n${money(fair['max'])}',
        style: Yazilar.baslik1.copyWith(color: YbRenkler.of(context).metin),
      ),
      const SizedBox(height: Olcu.s12),
      const Text(
        'Bu araç için piyasa koşullarına göre adil fiyat aralığı budur.',
      ),
      const SizedBox(height: Olcu.s16),
      FiyatAraligi(
        alt: fair['min'] as num?,
        ust: fair['max'] as num?,
        hesaplanan: snapshot.valuation['aiDegeri'] as num?,
        ilan: snapshot.vehicle['ilanFiyati'] as num?,
      ),
      ValueLine('Hesaplanan değer', money(snapshot.valuation['aiDegeri'])),
    ], icon: Icons.balance_outlined);
  }
}

class ReportPrices extends StatelessWidget {
  final ReportSnapshot snapshot;
  const ReportPrices(this.snapshot, {super.key});
  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    Widget value(String label, dynamic amount) => Padding(
      padding: const EdgeInsets.only(top: Olcu.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Yazilar.etiket.copyWith(color: r.markaBandiMetin)),
          const SizedBox(height: Olcu.s4),
          Text(
            money(amount),
            style: Yazilar.baslik2.copyWith(color: r.markaBandiVurgu),
          ),
        ],
      ),
    );
    return ReportCard(
      'İlan fiyatı',
      [
        Text(
          money(snapshot.vehicle['ilanFiyati']),
          style: Yazilar.baslik1.copyWith(color: r.beyaz),
        ),
        if (text(
          object(snapshot.summary['piyasaKonumu'])['metin'],
        ).isNotEmpty) ...[
          const SizedBox(height: Olcu.s8),
          Text(text(object(snapshot.summary['piyasaKonumu'])['metin'])),
        ],
        value('Tavsiye alım fiyatı', snapshot.valuation['tavsiyeFiyat']),
        if (snapshot.plan['ustSinir'] != null)
          value('Üst sınır', snapshot.plan['ustSinir']),
      ],
      icon: Icons.sell_outlined,
      dark: true,
    );
  }
}
