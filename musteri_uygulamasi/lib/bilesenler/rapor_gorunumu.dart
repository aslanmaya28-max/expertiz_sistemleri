import 'package:flutter/material.dart';
import '../api/models.dart';
import 'ortak.dart';
import 'rapor_ozet.dart';
import 'pazarlik_plani.dart';
import 'model_bulgulari.dart';
import 'deger_kaybi.dart';
import 'piyasa_bolumu.dart';
import 'rapor_kaynaklar.dart';

/// Web müşteriye admin karar alanlarını göstermez; burada da gösterilmez.
class ReportView extends StatelessWidget {
  final ReportSnapshot snapshot;
  final LinkAction onLink;
  const ReportView(this.snapshot, {super.key, required this.onLink});
  @override
  Widget build(BuildContext context) {
    final vehicle = snapshot.vehicle,
        meta = snapshot.report,
        income = object(snapshot.raw['getiri']);
    if (snapshot.summaryOnly) {
      return Panel('Özet kayıt', [
        const Text('Tam rapor bulunmuyor. Bu eski kaydın PDF raporu yok.'),
        Text(text(snapshot.raw['report_no'])),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          [
            vehicle['marka'],
            vehicle['model'],
            vehicle['yil'],
          ].where((e) => e != null).join(' '),
          [
            if (text(vehicle['paket']).isNotEmpty) Text(text(vehicle['paket'])),
            Text('${number(vehicle['km'])} km'),
            if (meta.isNotEmpty) ...[
              Text(text(meta['report_no'])),
              Text(dateText(DateTime.tryParse(text(meta['created_at'])))),
              Text('Doğrulama kodu: ${text(meta['verification_code'])}'),
              SourceLinks([text(meta['verification_url'])], onLink),
            ],
            const Text('Kredili değerleme raporu — uzman incelemesi içermez.'),
          ],
        ),
        ReportSummarySection(snapshot),
        NegotiationSection(snapshot.plan, onLink),
        ModelFindings(snapshot, onLink),
        ReportPrices(snapshot),
        LossSection(snapshot.valuation),
        GenerationSection(object(snapshot.market['gecisYili'])),
        MarketSection(snapshot.market, onLink),
        if (income.isNotEmpty)
          Panel('Getiri tahmini (araç enflasyonu)', [
            Text(
              'Aylık ${percent(income['aylikEnflasyonYuzde'])} (yıllık ≈ ${percent(income['yillikEnflasyonYuzde'])})',
            ),
            if (text(income['kaynak']).isNotEmpty) Text(text(income['kaynak'])),
            if (text(income['gecerlilikTarihi']).isNotEmpty)
              Text(text(income['gecerlilikTarihi'])),
            ValueLine('Alış fiyatı', money(income['alisFiyati'])),
            for (final key in ['altiAy', 'birYil'])
              if (object(income[key]).isNotEmpty) ...[
                ValueLine(
                  key == 'altiAy' ? '6 ay sonra' : '1 yıl sonra',
                  money(object(income[key])['tahminiDeger']),
                ),
                ValueLine(
                  'Getiri',
                  '${money(object(income[key])['getiriTl'])} (${percent(object(income[key])['getiriYuzde'])})',
                ),
              ],
            if (text(income['aciklama']).isNotEmpty)
              Text(text(income['aciklama'])),
          ]),
        if (objects(snapshot.raw['bilgiKaynaklari']).isNotEmpty)
          Panel('Bu rapordaki bilgiler nereden geliyor?', [
            for (final source in objects(snapshot.raw['bilgiKaynaklari']))
              ValueLine(
                text(source['alan']),
                '${_sourceLabel(text(source['kaynak']))}: ${text(source['aciklama'])}',
              ),
          ]),
        if (object(snapshot.raw['kredi']).isNotEmpty)
          Text(
            '${integer(object(snapshot.raw['kredi'])['dusulen'])} kredi kullanıldı • Rapor anındaki kalan: ${integer(object(snapshot.raw['kredi'])['kalan'])}',
          ),
      ],
    );
  }

  String _sourceLabel(String source) =>
      const {
        'musteri_beyani': 'Beyan',
        'kayitli_ilan': 'Kayıtlı ilan',
        'internet_ilanlari': 'İnternet ilanları',
        'kayitli_ilanlar': 'Kayıtlı ilanlar',
        'hesaplama': 'Hesaplama',
        'tahmin': 'Tahmin',
      }[source] ??
      source;
}
