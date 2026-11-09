import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../tema/renkler.dart';

/// Sitedeki aynı vektör sembolü ve Inter kelime markası.
class YerimeBakLogo extends StatelessWidget {
  const YerimeBakLogo(
      {super.key,
      this.height = 40,
      this.onDark = false,
      this.markOnly = false});
  final double height;
  final bool onDark, markOnly;
  static const _path =
      'M40,42 L521,41 Q537,42 535,61 L410,388 Q404,426 448,442 L466,442 L621,54 Q627,40 641,40 L977,41 L773,511 Q748,568 725,606 Q673,666 633,684 Q583,706 523,708 L195,708 Q103,706 71,601 L54,538 L388,536 Q438,534 452,478 L285,478 Q163,478 131,346 Z';
  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final symbol = onDark ? r.beyaz : r.birincil;
    final text = onDark ? r.beyaz : r.metin;
    final accent = onDark ? YbRenkler.acik.markaBandiVurgu : r.birincil;
    return Semantics(
        label: 'YerimeBak',
        image: true,
        child: ExcludeSemantics(
            child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
          SvgPicture.string(
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1017 748"><path fill="currentColor" d="$_path"/></svg>',
              height: height,
              width: height * 1.36,
              colorFilter: ColorFilter.mode(symbol, BlendMode.srcIn)),
          if (!markOnly) ...[
            SizedBox(width: height * .18),
            Text.rich(
                TextSpan(text: 'Yerime', children: [
                  TextSpan(
                      text: 'Bak',
                      style:
                          TextStyle(color: accent, fontWeight: FontWeight.w700))
                ]),
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: height * .6,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.7,
                    color: text))
          ],
        ]))));
  }
}
