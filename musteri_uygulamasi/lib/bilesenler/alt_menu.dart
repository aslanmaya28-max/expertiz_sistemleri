import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';

class AltMenu extends StatelessWidget {
  final int secili;
  final ValueChanged<int> onChanged;
  const AltMenu({super.key,required this.secili,required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final r=YbRenkler.of(context);
    const items=[('Ana sayfa',LucideIcons.house),('Raporlarım',LucideIcons.fileText),('Kredi',LucideIcons.wallet),('Profil',LucideIcons.user)];
    return Container(decoration:BoxDecoration(color:r.yuzey,border:Border(top:BorderSide(color:r.kenarlik))),child:SafeArea(top:false,child:ConstrainedBox(constraints:const BoxConstraints(minHeight:Olcu.altMenu),child:Row(children:[for(var i=0;i<items.length;i++) Expanded(child:Semantics(selected:i==secili,button:true,child:InkWell(onTap:()=>onChanged(i),child:Padding(padding:const EdgeInsets.symmetric(vertical:Olcu.s12,horizontal:Olcu.s4),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(items[i].$2,size:i==secili?Olcu.ikon:Olcu.ikonInce,color:i==secili?r.birincil:r.ikonPasif),const SizedBox(height:Olcu.s4),Text(items[i].$1,textAlign:TextAlign.center,style:Yazilar.menu.copyWith(color:i==secili?r.birincilMetin:r.metinIkincil))])))))]))));
  }
}
