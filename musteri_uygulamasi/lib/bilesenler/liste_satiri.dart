import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';

class ListeSatiri extends StatelessWidget {
  final String baslik;
  final String? aciklama;
  final IconData? ikon;
  final Widget? son;
  final VoidCallback? onTap;
  const ListeSatiri(this.baslik,{super.key,this.aciklama,this.ikon,this.son,this.onTap});
  @override
  Widget build(BuildContext context) {
    final r=YbRenkler.of(context);
    return InkWell(onTap:onTap,borderRadius:BorderRadius.circular(Olcu.butonKose),child:ConstrainedBox(constraints:const BoxConstraints(minHeight:Olcu.dokunma),child:Padding(padding:const EdgeInsets.symmetric(vertical:Olcu.s12),child:Row(children:[
      if(ikon != null) ...[Container(width:Olcu.ikonKutusu,height:Olcu.ikonKutusu,decoration:BoxDecoration(color:r.yuzeyIkincil,borderRadius:BorderRadius.circular(Olcu.ikonKose)),child:Icon(ikon,size:Olcu.ikonInce,color:r.ikonPasif)),const SizedBox(width:Olcu.s12)],
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(baslik,style:Yazilar.govde.copyWith(color:r.metin)),if(aciklama != null) Text(aciklama!,style:Yazilar.govdeKucuk.copyWith(color:r.metinIkincil))])),
      if(son != null) ...[const SizedBox(width:Olcu.s8),son!]
      else if(onTap != null) Icon(LucideIcons.chevronRight,size:Olcu.ikonInce,color:r.ikonPasif),
    ]))));
  }
}
