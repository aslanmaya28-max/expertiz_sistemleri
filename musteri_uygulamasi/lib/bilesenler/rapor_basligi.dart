import 'package:flutter/material.dart';
import '../api/models.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';
import 'marka.dart';
import 'ortak.dart';
import 'rapor_kaynaklar.dart';

/// Rapor kimliği ve sunucunun bildirdiği piyasa konumu.
class ReportHeader extends StatelessWidget {
  final ReportSnapshot snapshot;
  final LinkAction onLink;
  const ReportHeader(this.snapshot, this.onLink, {super.key});

  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    final vehicle = snapshot.vehicle;
    final meta = snapshot.report;
    final position = object(snapshot.summary['piyasaKonumu']);
    final status = text(position['durum']);
    final label = switch (status) {
      'altinda' => 'Piyasanın altında',
      'uyumlu' => 'Piyasayla uyumlu',
      'ustunde' => 'Piyasanın üstünde',
      _ => '',
    };
    final accent = status == 'altinda' || status == 'ustunde'
        ? r.vurguBant
        : r.markaBandiVurgu;
    final title = [
      vehicle['marka'],
      vehicle['model'],
    ].map(text).where((value) => value.isNotEmpty).join(' ');
    final fewListings = [
      3,
      4,
    ].contains(integer(snapshot.market['emsalSayisi']));
    return Container(
      margin: const EdgeInsets.only(bottom: Olcu.kartArasi),
      padding: const EdgeInsets.all(Olcu.kartBuyukIci),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Olcu.raporKose),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            r.markaBandi,
            Color.alphaBlend(
              r.markaBandiVurgu.withValues(alpha: .12),
              r.markaBandi,
            ),
          ],
        ),
      ),
      child: DefaultTextStyle(
        style: Yazilar.govdeKucuk.copyWith(color: r.beyaz),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(fit: BoxFit.scaleDown, child: Marka(bant: true)),
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: Olcu.s20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: r.markaBandiVurgu,
                    size: Olcu.ikonInce,
                  ),
                  const SizedBox(width: Olcu.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (text(meta['report_no']).isNotEmpty)
                          Text(
                            text(meta['report_no']),
                            style: Yazilar.etiket.copyWith(color: r.beyaz),
                          ),
                        Text(
                          dateText(DateTime.tryParse(text(meta['created_at']))),
                          style: Yazilar.etiket.copyWith(
                            color: r.markaBandiMetin,
                          ),
                        ),
                        if (text(meta['verification_code']).isNotEmpty)
                          Text(
                            'Doğrulama kodu: ${text(meta['verification_code'])}',
                            style: Yazilar.etiket.copyWith(color: r.beyaz),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (safeWeb(text(meta['verification_url'])))
                TextButtonTheme(
                  data: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: r.markaBandiVurgu,
                      minimumSize: const Size(
                        Olcu.ikincilButon,
                        Olcu.ikincilButon,
                      ),
                      textStyle: Yazilar.etiket,
                    ),
                  ),
                  child: SourceLinks([text(meta['verification_url'])], onLink),
                ),
            ],
            const SizedBox(height: Olcu.s24),
            Semantics(
              header: true,
              child: Text(
                title,
                style: Yazilar.raporBaslik.copyWith(color: r.beyaz),
              ),
            ),
            if (text(vehicle['paket']).isNotEmpty) ...[
              const SizedBox(height: Olcu.s4),
              Text(
                text(vehicle['paket']),
                style: Yazilar.bolumBaslik.copyWith(color: r.markaBandiVurgu),
              ),
            ],
            const SizedBox(height: Olcu.s12),
            Text(
              'Kredili değerleme raporu — uzman incelemesi içermez.',
              style: Yazilar.etiket.copyWith(color: r.markaBandiMetin),
            ),
            if (position.isNotEmpty) ...[
              const SizedBox(height: Olcu.s24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Olcu.s16),
                decoration: BoxDecoration(
                  color: r.beyaz.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(Olcu.kartKose),
                  border: Border.all(color: accent.withValues(alpha: .4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Piyasaya göre fiyatı',
                      style: Yazilar.etiket.copyWith(color: r.markaBandiMetin),
                    ),
                    if (label.isNotEmpty) ...[
                      const SizedBox(height: Olcu.s8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            status == 'uyumlu'
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            color: accent,
                            size: Olcu.ikonInce,
                          ),
                          const SizedBox(width: Olcu.s8),
                          Expanded(
                            child: Text(
                              label,
                              style: Yazilar.bolumBaslik.copyWith(
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (text(position['metin']).isNotEmpty) ...[
                      const SizedBox(height: Olcu.s8),
                      Text(text(position['metin'])),
                    ],
                    if (fewListings) ...[
                      const SizedBox(height: Olcu.s8),
                      Text(
                        'Fiyatlar yön göstericidir.',
                        style: Yazilar.etiket.copyWith(
                          color: r.markaBandiMetin,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sabit yükseklik kullanmadan iki sütunda sarılan araç bilgileri.
class VehicleChips extends StatelessWidget {
  final ReportSnapshot snapshot;
  const VehicleChips(this.snapshot, {super.key});

  @override
  Widget build(BuildContext context) {
    final vehicle = snapshot.vehicle;
    final r = YbRenkler.of(context);
    final items = [
      (Icons.calendar_today_outlined, 'Model yılı', text(vehicle['yil'])),
      (Icons.route_outlined, 'Kilometre', '${number(vehicle['km'])} km'),
      (Icons.local_gas_station_outlined, 'Yakıt tipi', text(vehicle['yakit'])),
      (Icons.settings_outlined, 'Vites', text(vehicle['vites'])),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: Olcu.kartArasi),
      child: Semantics(
        label: 'Araç bilgileri',
        child: LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: Olcu.s8,
            runSpacing: Olcu.s8,
            children: [
              for (final (icon, label, value) in items)
                SizedBox(
                  width: (constraints.maxWidth - Olcu.s8) / 2,
                  child: Container(
                    padding: const EdgeInsets.all(Olcu.s12),
                    decoration: BoxDecoration(
                      color: r.yuzey,
                      borderRadius: BorderRadius.circular(Olcu.kartKose),
                      border: Border.all(color: r.kenarlik),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: r.birincilMetin, size: Olcu.ikonInce),
                        const SizedBox(height: Olcu.s8),
                        Text(
                          label,
                          style: Yazilar.etiket.copyWith(color: r.metinIkincil),
                        ),
                        const SizedBox(height: Olcu.s4),
                        Text(
                          value.isEmpty ? '—' : value,
                          style: Yazilar.govde.copyWith(
                            color: r.metin,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
