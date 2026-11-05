import 'package:flutter/material.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import 'kart.dart';

class Yukleniyor extends StatelessWidget {
  const Yukleniyor({super.key});
  @override
  Widget build(BuildContext context) => Semantics(label:'Yükleniyor',liveRegion:true,child:ExcludeSemantics(child:Column(children:[for(var i=0;i<3;i++) Padding(padding:const EdgeInsets.only(bottom:Olcu.s12),child:Kart(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Container(height:Olcu.yuklemeSatir,color:YbRenkler.of(context).yuzeyIkincil),const SizedBox(height:Olcu.s12),FractionallySizedBox(widthFactor:.65,alignment:Alignment.centerLeft,child:Container(height:Olcu.yuklemeSatir,color:YbRenkler.of(context).yuzeyIkincil))])))])));
}
