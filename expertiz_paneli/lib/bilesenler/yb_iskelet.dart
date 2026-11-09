import 'package:flutter/material.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';

/// Sonlu yerleşim bloğu; sürekli hareket ve pumpAndSettle beklemesi üretmez.
class YbIskelet extends StatelessWidget {
  const YbIskelet({super.key, this.width, this.height = Olcu.yuklemeSatir});
  final double? width;
  final double height;
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Yükleniyor',
      child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
              color: context.renkler.ayirici,
              borderRadius: BorderRadius.circular(Olcu.rozetKose))));
}
