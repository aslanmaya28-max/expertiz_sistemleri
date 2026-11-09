import 'package:flutter/material.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';
import 'yb_kart.dart';

class YbSayacKarti extends StatelessWidget {
  const YbSayacKarti(
      {super.key,
      required this.baslik,
      required this.deger,
      this.aciklama,
      this.grafik,
      this.onTap});
  final String baslik, deger;
  final String? aciklama;
  final Widget? grafik;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => YbKart(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(baslik,
            style:
                Yazilar.etiket.copyWith(color: context.renkler.metinIkincil)),
        const SizedBox(height: Olcu.s12),
        Text(deger,
            style: Yazilar.rakamBuyuk
                .copyWith(fontSize: 32, color: context.renkler.metin)),
        if (aciklama != null) ...[
          const SizedBox(height: Olcu.s8),
          Text(aciklama!,
              style:
                  Yazilar.etiket.copyWith(color: context.renkler.metinIkincil))
        ],
        if (grafik != null) ...[const SizedBox(height: Olcu.s16), grafik!]
      ]));
}
