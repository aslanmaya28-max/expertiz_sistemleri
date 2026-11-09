import 'package:flutter/material.dart';
import '../tema/renkler.dart';
import 'yb_rozet.dart';

abstract final class YbBildirim {
  static void goster(BuildContext context, String mesaj,
      {YbRozetTuru tur = YbRozetTuru.bilgi}) {
    final r = context.renkler;
    final color = switch (tur) {
      YbRozetTuru.basari => r.birincilMetin,
      YbRozetTuru.uyari => r.uyari,
      YbRozetTuru.tehlike => r.tehlike,
      YbRozetTuru.bilgi => r.bilgi,
      YbRozetTuru.notr => r.metin
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: r.yuzeyIkincil,
        content: Text(mesaj, style: TextStyle(color: color))));
  }
}
