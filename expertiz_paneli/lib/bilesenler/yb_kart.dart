import 'package:flutter/material.dart';
import '../tema/renkler.dart';
import '../tema/olculer.dart';

class YbKart extends StatelessWidget {
  const YbKart(
      {super.key,
      required this.child,
      this.baslik,
      this.eylem,
      this.padding,
      this.margin,
      this.onTap,
      this.width,
      this.height});
  final Widget child;
  final String? baslik;
  final Widget? eylem;
  final EdgeInsetsGeometry? padding, margin;
  final VoidCallback? onTap;
  final double? width, height;
  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: Material(
        color: r.yuzey,
        borderRadius: BorderRadius.circular(Olcu.kartKose),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            child: Padding(
                padding: padding ?? const EdgeInsets.all(Olcu.s20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (baslik != null || eylem != null) ...[
                        Row(children: [
                          if (baslik != null)
                            Expanded(
                                child: Text(baslik!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge)),
                          if (eylem != null) eylem!
                        ]),
                        const SizedBox(height: Olcu.s16),
                      ],
                      child,
                    ]))),
      ),
    );
  }
}
