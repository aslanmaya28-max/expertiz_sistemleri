import 'package:flutter/material.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';
import 'ortak.dart';

class PazarlikUclusu extends StatelessWidget {
  final num? acilis, hedef, ustSinir;
  const PazarlikUclusu({super.key, this.acilis, this.hedef, this.ustSinir});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final r = YbRenkler.of(context);
      final items = [
        ('Açılış teklifi', acilis),
        ('Hedef fiyat', hedef),
        ('Üst sınırınız', ustSinir),
      ];
      Widget item(int i) => Container(
        padding: const EdgeInsets.all(Olcu.s12),
        decoration: BoxDecoration(
          color: i == 1 ? r.birincilYuzey : r.yuzeyIkincil,
          borderRadius: BorderRadius.circular(Olcu.butonKose),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              items[i].$1,
              style: Yazilar.etiket.copyWith(color: r.metinIkincil),
            ),
            const SizedBox(height: Olcu.s8),
            Text(
              money(items[i].$2),
              style: Yazilar.bolumBaslik.copyWith(
                color: i == 1 ? r.birincilMetin : r.metin,
              ),
            ),
          ],
        ),
      );
      if (c.maxWidth < Olcu.satirYatayEsik ||
          MediaQuery.textScalerOf(context).scale(1) > Olcu.buyukMetinEsik) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Olcu.s8),
                child: item(i),
              ),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: Olcu.s8),
            Expanded(child: item(i)),
          ],
        ],
      );
    },
  );
}
