import 'package:flutter/material.dart';
import '../tema/renkler.dart';
import '../tema/olculer.dart';
import '../tema/yazi.dart';

enum YbRozetTuru { basari, uyari, tehlike, bilgi, notr }

class YbRozet extends StatelessWidget {
  const YbRozet(this.metin, {super.key, this.tur = YbRozetTuru.notr});
  final String metin;
  final YbRozetTuru tur;
  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final (foreground, background) = switch (tur) {
      YbRozetTuru.basari => (r.birincilMetin, r.birincilYuzey),
      YbRozetTuru.uyari => (r.uyari, r.uyariYuzey),
      YbRozetTuru.tehlike => (r.tehlike, r.tehlikeYuzey),
      YbRozetTuru.bilgi => (r.bilgi, r.bilgiYuzey),
      YbRozetTuru.notr => (r.metinIkincil, r.yuzeyIkincil),
    };
    return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Olcu.s8, vertical: Olcu.rozetDikey),
        decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(Olcu.rozetKose)),
        child: Text(metin, style: Yazilar.kucuk.copyWith(color: foreground)));
  }
}
