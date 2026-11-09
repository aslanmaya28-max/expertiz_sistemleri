import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../bilesenler/bilesenler.dart';
import '../tema/renkler.dart';
class UnauthorizedScreen extends StatelessWidget {
  const UnauthorizedScreen({super.key});
  @override
  Widget build(BuildContext context)=>Scaffold(body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:480),child:Padding(padding:const EdgeInsets.all(24),child:YbKart(child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(LucideIcons.lockKeyhole,size:36,color:context.renkler.tehlike),const SizedBox(height:20),Text('Yetkisiz Erişim',style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:12),const Text('Bu sayfaya erişim için yönetici yetkisi gereklidir.',textAlign:TextAlign.center),const SizedBox(height:24),YbButon(metin:'Geri Dön',ikon:LucideIcons.arrowLeft,onPressed:()=>Navigator.of(context).pop())]))))));
}
