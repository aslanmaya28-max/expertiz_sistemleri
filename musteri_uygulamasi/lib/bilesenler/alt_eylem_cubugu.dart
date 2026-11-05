import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import 'ana_buton.dart';
import 'ikincil_buton.dart';

class AltEylemCubugu extends StatelessWidget {
  final Future<void> Function()? mesaj,pdf;
  const AltEylemCubugu({super.key,this.mesaj,this.pdf});
  @override
  Widget build(BuildContext context) => Container(decoration:BoxDecoration(color:YbRenkler.of(context).yuzey,border:Border(top:BorderSide(color:YbRenkler.of(context).kenarlik))),child:SafeArea(top:false,child:Padding(padding:const EdgeInsets.all(Olcu.s12),child:LayoutBuilder(builder:(context,c) {
    final message=AnaButon('Satıcıya mesaj',mesaj,icon:LucideIcons.messageCircle),document=IkincilButon('PDF rapor',pdf,icon:LucideIcons.fileDown);
    if(c.maxWidth < Olcu.satirYatayEsik || MediaQuery.textScalerOf(context).scale(1)>Olcu.buyukMetinEsik) return Column(mainAxisSize:MainAxisSize.min,children:[message,const SizedBox(height:Olcu.s8),document]);
    return Row(children:[Expanded(child:message),const SizedBox(width:Olcu.s8),Expanded(child:document)]);
  }))));
}
