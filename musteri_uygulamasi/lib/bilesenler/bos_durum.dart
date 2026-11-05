import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';
import 'kart.dart';

class BosDurum extends StatelessWidget {
  final String baslik,aciklama;
  final IconData ikon;
  final Widget? eylem;
  const BosDurum(this.baslik,this.aciklama,{super.key,this.ikon=LucideIcons.fileSearch,this.eylem});
  @override
  Widget build(BuildContext context) => Kart(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(ikon,size:Olcu.ikon,color:YbRenkler.of(context).ikonPasif),const SizedBox(height:Olcu.s16),Text(baslik,style:Yazilar.bolumBaslik),const SizedBox(height:Olcu.s8),Text(aciklama),if(eylem!=null)...[const SizedBox(height:Olcu.s16),eylem!]]));
}
