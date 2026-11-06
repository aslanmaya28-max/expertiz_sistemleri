import 'package:flutter/material.dart';
import '../tema/renkler.dart';
import '../tema/olculer.dart';
import '../tema/hareket.dart';

class Kart extends StatelessWidget {
  final Widget child;
  final bool rapor, analiz;
  final EdgeInsetsGeometry? padding;

  /// Renkli kart zemini (hizmet kartları); verilmezse yüzey rengi.
  final Color? renk;
  const Kart({
    super.key,
    required this.child,
    this.rapor = false,
    this.analiz = false,
    this.padding,
    this.renk,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: renk ?? YbRenkler.of(context).yuzey,
      borderRadius: BorderRadius.circular(
        rapor ? Olcu.raporKose : Olcu.kartKose,
      ),
      boxShadow: analiz && Theme.of(context).brightness == Brightness.light
          ? Hareket.analizGolgeleri
          : null,
    ),
    padding: padding ?? const EdgeInsets.all(Olcu.kartIci),
    child: child,
  );
}
