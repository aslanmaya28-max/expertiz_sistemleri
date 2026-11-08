import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';
import 'ortak.dart';
import 'rapor_karti.dart';

/// Değer ve kazançlar doğrudan sunucudan gelir. Yalnız eski raporların
/// eksik altı aylık enflasyon oranı, sitedeki gibi aylık orandan türetilir.
class InflationSection extends StatelessWidget {
  final Json data;

  const InflationSection(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final colors = YbRenkler.of(context);
    final monthly = _finite(data['aylikEnflasyonYuzde']);
    final sixMonthly =
        _finite(data['altiAylikEnflasyonYuzde']) ??
        (monthly == null
            ? null
            : _finite((math.pow(1 + monthly / 100, 6) - 1) * 100));

    return ReportCard('Enflasyona göre kazanç tahmini', [
      Text(
        'Aracı tavsiye alım fiyatından (${money(data['alisFiyati'])}) '
        'alırsanız araç enflasyonuna göre tahmini değeri ve kazancınız.',
        style: Yazilar.govdeKucuk.copyWith(color: colors.metinIkincil),
      ),
      const SizedBox(height: Olcu.s16),
      LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < Olcu.satirYatayEsik ||
              MediaQuery.textScalerOf(context).scale(1) > Olcu.buyukMetinEsik;
          final rates = [
            _Rate('6 aylık araç enflasyonu', sixMonthly),
            _Rate(
              'Yıllık araç enflasyonu',
              _finite(data['yillikEnflasyonYuzde']),
            ),
            _Rate('Aylık', monthly),
          ];
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final rate in rates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Olcu.s12),
                    child: rate,
                  ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < rates.length; i++) ...[
                if (i > 0) const SizedBox(width: Olcu.s12),
                Expanded(child: rates[i]),
              ],
            ],
          );
        },
      ),
      const SizedBox(height: Olcu.s12),
      if (object(data['altiAy']).isNotEmpty)
        _Horizon('6 ay sonra', object(data['altiAy'])),
      if (object(data['birYil']).isNotEmpty)
        _Horizon('1 yıl sonra', object(data['birYil']), dark: true),
      Text(
        '${_label(data['kaynak'])} · '
        '${_date(data['gecerlilikTarihi'])}\n'
        '${_label(data['aciklama'])}',
        style: Yazilar.govdeKucuk.copyWith(color: colors.metinIkincil),
      ),
    ], icon: Icons.trending_up_rounded);
  }
}

class _Rate extends StatelessWidget {
  final String label;
  final num? value;

  const _Rate(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Yazilar.etiket.copyWith(
          color: YbRenkler.of(context).metinIkincil,
        ),
      ),
      const SizedBox(height: Olcu.s4),
      Text(
        percent(value),
        style: Yazilar.bolumBaslik.copyWith(
          color: YbRenkler.of(context).birincilMetin,
        ),
      ),
    ],
  );
}

class _Horizon extends StatelessWidget {
  final String title;
  final Json data;
  final bool dark;

  const _Horizon(this.title, this.data, {this.dark = false});

  @override
  Widget build(BuildContext context) {
    final colors = YbRenkler.of(context);
    final foreground = dark ? colors.beyaz : colors.metin;
    final gain = _finite(data['getiriTl']);
    final gainColor = gain != null && gain < 0
        ? (dark ? YbRenkler.koyu.tehlike : colors.tehlike)
        : (dark ? colors.markaBandiVurgu : colors.birincilMetin);
    return ReportCard(title, [
      Text('Tahmini değer', style: Yazilar.etiket.copyWith(color: foreground)),
      const SizedBox(height: Olcu.s4),
      Text(
        money(_finite(data['tahminiDeger'])),
        style: Yazilar.baslik2.copyWith(color: foreground),
      ),
      const SizedBox(height: Olcu.s16),
      Text(
        'Sağladığı kazanç',
        style: Yazilar.etiket.copyWith(color: foreground),
      ),
      const SizedBox(height: Olcu.s4),
      Text(
        '${_signedMoney(gain)} (${percent(_finite(data['getiriYuzde']))})',
        style: Yazilar.bolumBaslik.copyWith(color: gainColor),
      ),
      if (data.containsKey('alimKazanciTl') ||
          data.containsKey('enflasyonKazanciTl')) ...[
        const SizedBox(height: Olcu.s12),
        Text(
          'Uygun alım ${_signedMoney(data['alimKazanciTl'])} · '
          'Değer artışı ${_signedMoney(data['enflasyonKazanciTl'])}',
          style: Yazilar.govdeKucuk.copyWith(color: foreground),
        ),
      ],
    ], dark: dark);
  }
}

num? _finite(dynamic value) => value is num && value.isFinite ? value : null;

String _signedMoney(dynamic value) {
  final amount = _finite(value);
  if (amount == null) return '—';
  return '${amount < 0 ? '−' : '+'}${money(amount.abs())}';
}

String _label(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value : '—';

String _date(dynamic value) {
  if (value is! String) return '—';
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:T|$)').firstMatch(value);
  return match == null ? '—' : '${match[3]}.${match[2]}.${match[1]}';
}
