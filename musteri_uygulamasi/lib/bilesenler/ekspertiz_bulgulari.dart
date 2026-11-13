import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../api/models.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';
import 'rapor_karti.dart';

class EkspertizBulgulari extends StatelessWidget {
  final dynamic veri;
  const EkspertizBulgulari(this.veri, {super.key});

  @override
  Widget build(BuildContext context) {
    final rapor = object(veri);
    final aciklama = rapor['aciklama'] is String
        ? text(rapor['aciklama']).trim()
        : '';
    final bulgular = objects(rapor['bulgular'])
        .where(
          (b) => b['metin'] is String && text(b['metin']).trim().isNotEmpty,
        )
        .toList();
    if (aciklama.isEmpty && bulgular.isEmpty) return const SizedBox.shrink();
    final r = YbRenkler.of(context);
    return ReportCard('Ekspertiz raporundan okunan bulgular', [
      if (aciklama.isNotEmpty) ...[
        Text(aciklama),
        const SizedBox(height: Olcu.s12),
      ],
      for (final bulgu in bulgular)
        Padding(
          padding: const EdgeInsets.only(bottom: Olcu.s8),
          child: Text(
            '${switch (text(bulgu['ciddiyet'])) {
              'ciddi' => 'Yerinde doğrulatın',
              'pazarlik' => 'Kozmetik / küçük onarım',
              _ => 'Bilgi',
            }}: ${text(bulgu['metin'])}',
            style: Yazilar.raporGovde.copyWith(
              color: bulgu['ciddiyet'] == 'ciddi' ? r.tehlike : r.metinIkincil,
              fontWeight: bulgu['ciddiyet'] == 'ciddi'
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ),
    ], icon: LucideIcons.clipboardCheck);
  }
}
