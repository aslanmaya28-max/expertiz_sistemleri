import 'package:flutter/material.dart';
import '../tema/renkler.dart';
import '../tema/olculer.dart';
import '../tema/hareket.dart';

class Kart extends StatelessWidget {
  final Widget child;
  final bool rapor,analiz;
  final EdgeInsetsGeometry? padding;
  const Kart({super.key,required this.child,this.rapor=false,this.analiz=false,this.padding});
  @override Widget build(BuildContext context) => Container(
    decoration:BoxDecoration(color:YbRenkler.of(context).yuzey,
      borderRadius:BorderRadius.circular(rapor ? Olcu.raporKose : Olcu.kartKose),
      boxShadow:analiz && Theme.of(context).brightness==Brightness.light ? Hareket.analizGolgeleri : null),
    padding:padding ?? const EdgeInsets.all(Olcu.kartIci),child:child);
}
