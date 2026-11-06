import 'package:flutter/material.dart';
import '../tema/renkler.dart';
import '../tema/olculer.dart';
import '../tema/yazi.dart';

class YakindaRozeti extends StatelessWidget {
  final bool simdi;
  const YakindaRozeti({super.key, this.simdi = false});
  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: Olcu.rozetDikey,
        horizontal: Olcu.s8,
      ),
      decoration: BoxDecoration(
        color: simdi ? r.birincil : null,
        border: Border.all(color: r.vurguKenar),
        borderRadius: BorderRadius.circular(Olcu.rozetKose),
      ),
      child: Text(
        simdi ? 'Şimdi' : 'Yakında',
        style: Yazilar.kucuk.copyWith(
          color: simdi ? r.birincilUstu : r.vurguMetin,
        ),
      ),
    );
  }
}
