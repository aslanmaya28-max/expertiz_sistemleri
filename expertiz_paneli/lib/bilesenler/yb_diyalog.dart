import 'package:flutter/material.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';

class YbDiyalog extends StatelessWidget {
  const YbDiyalog(
      {super.key,
      required this.baslik,
      required this.child,
      this.eylemler = const []});
  final String baslik;
  final Widget child;
  final List<Widget> eylemler;
  @override
  Widget build(BuildContext context) => AlertDialog(scrollable: true,
      backgroundColor: context.renkler.yuzey,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Olcu.kartKose)),
      title: Text(baslik,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.renkler.metin)),
      content: child,
      actions: eylemler,
      actionsAlignment: MainAxisAlignment.end);
}

