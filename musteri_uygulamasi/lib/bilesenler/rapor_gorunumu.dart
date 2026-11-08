import 'package:flutter/material.dart';
import '../api/models.dart';
import 'ortak.dart';
import 'rapor_ozet.dart';
import 'pazarlik_plani.dart';
import 'model_bulgulari.dart';
import 'deger_kaybi.dart';
import 'piyasa_bolumu.dart';
import 'rapor_kaynaklar.dart';
import 'rapor_basligi.dart';
import 'rapor_karti.dart';
import 'enflasyon_karti.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';

/// Yalnız müşteriye açık alanlar; sıralama sitedeki raporla aynıdır.
class ReportView extends StatelessWidget {
  final ReportSnapshot snapshot;
  final LinkAction onLink;
  final Widget? sonrakiAdim;
  const ReportView(
    this.snapshot, {
    super.key,
    required this.onLink,
    this.sonrakiAdim,
  });
  @override
  Widget build(BuildContext context) {
    if (snapshot.summaryOnly) {
      return Panel('Özet kayıt', [
        const Text('Tam rapor bulunmuyor. Bu eski kaydın PDF raporu yok.'),
        Text(text(snapshot.raw['report_no'])),
      ]);
    }
    final r = YbRenkler.of(context);
    return DefaultTextStyle.merge(
      style: Yazilar.raporGovde.copyWith(color: r.metin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReportHeader(snapshot, onLink),
          VehicleChips(snapshot),
          FairPriceSection(snapshot),
          ReportPrices(snapshot),
          ReportSummarySection(snapshot),
          NegotiationSection(snapshot.plan, onLink),
          if (text(snapshot.plan['saticiMesaji']).isNotEmpty)
            SaticiMesaji(text(snapshot.plan['saticiMesaji']), onLink: onLink),
          InflationSection(object(snapshot.raw['getiri'])),
          NextActionSection(snapshot.summary),
          ModelFindings(snapshot, onLink),
          MarketSection(snapshot.market, onLink),
          LossSection(snapshot.valuation),
          GenerationSection(object(snapshot.market['gecisYili'])),
          if (objects(snapshot.raw['bilgiKaynaklari']).isNotEmpty)
            ReportCard('Bu rapordaki bilgiler nereden geliyor?', [
              for (final source in objects(snapshot.raw['bilgiKaynaklari']))
                ValueLine(
                  text(source['alan']),
                  '${_sourceLabel(text(source['kaynak']))}: ${text(source['aciklama'])}',
                ),
            ], icon: Icons.info_outline),
          if (object(snapshot.raw['kredi']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Olcu.s16),
              child: Text(
                '${integer(object(snapshot.raw['kredi'])['dusulen'])} kredi kullanıldı • Rapor anındaki kalan: ${integer(object(snapshot.raw['kredi'])['kalan'])}',
                style: Yazilar.etiket.copyWith(color: r.metinIkincil),
              ),
            ),
          if (sonrakiAdim != null)
            ReportCard(
              'Güvenli alım için son adım',
              [
                Theme(
                  data: Theme.of(context).copyWith(
                    textTheme: Theme.of(context).textTheme.apply(
                      bodyColor: r.beyaz,
                      displayColor: r.beyaz,
                    ),
                    extensions: [
                      for (final extension in Theme.of(
                        context,
                      ).extensions.values)
                        if (extension is YbRenkler)
                          r.copyWith(
                            values: {
                              'yuzey': r.raporKoyu,
                              'metin': r.beyaz,
                              'metinIkincil': r.markaBandiMetin,
                            },
                          )
                        else
                          extension,
                    ],
                  ),
                  child: sonrakiAdim!,
                ),
              ],
              icon: Icons.verified_user_outlined,
              dark: true,
            ),
        ],
      ),
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
