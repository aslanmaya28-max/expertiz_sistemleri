import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';

class Marka extends StatelessWidget {
  final bool bant;
  const Marka({super.key,this.bant=false});
  @override
  Widget build(BuildContext context) {
    final r=YbRenkler.of(context),color=bant?r.beyaz:r.metin;
    return Semantics(label:'YerimeBak',excludeSemantics:true,child:Row(mainAxisSize:MainAxisSize.min,children:[SvgPicture.string('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1017 748"><path fill="currentColor" d="M40,42 L521,41 Q537,42 535,61 L410,388 Q404,426 448,442 L466,442 L621,54 Q627,40 641,40 L977,41 L773,511 Q748,568 725,606 Q673,666 633,684 Q583,706 523,708 L195,708 Q103,706 71,601 L54,538 L388,536 Q438,534 452,478 L285,478 Q163,478 131,346 Z"/></svg>',width:Olcu.markaSembol,height:Olcu.markaSembol,colorFilter:ColorFilter.mode(bant?r.markaBandiVurgu:r.birincil,BlendMode.srcIn)),const SizedBox(width:Olcu.s8),Text('YerimeBak',style:Yazilar.baslik2.copyWith(color:color))]));
  }
}
