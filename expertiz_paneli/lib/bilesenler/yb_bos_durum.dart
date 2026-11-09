import 'package:flutter/material.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import 'yb_buton.dart';

class YbBosDurum extends StatelessWidget {
  const YbBosDurum(
      {super.key, required this.mesaj, this.eylem, this.onPressed});
  final String mesaj;
  final String? eylem;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(Olcu.s24),
      child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(mesaj,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.renkler.metinIkincil)),
        if (eylem != null && onPressed != null) ...[
          const SizedBox(height: Olcu.s12),
          YbButon(metin: eylem!, onPressed: onPressed, tur: YbButonTuru.ikincil)
        ]
      ])));
}
