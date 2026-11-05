import 'package:flutter/material.dart';

class AcilirListe extends StatefulWidget {
  final List<Widget> children;
  final int ilk;
  const AcilirListe({super.key,required this.children,this.ilk=3});
  @override
  State<AcilirListe> createState()=>_AcilirListeState();
}
class _AcilirListeState extends State<AcilirListe> {
  bool acik=false;
  @override
  Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[...(acik?widget.children:widget.children.take(widget.ilk)),if(widget.children.length>widget.ilk) Align(alignment:Alignment.centerLeft,child:TextButton(onPressed:()=>setState(()=>acik=!acik),child:Text(acik?'Daha az göster':'${widget.children.length-widget.ilk} tane daha göster')))]);
}
