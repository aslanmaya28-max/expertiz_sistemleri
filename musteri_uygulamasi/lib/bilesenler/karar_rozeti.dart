import 'package:flutter/material.dart';
import '../tema/renkler.dart';
import '../tema/olculer.dart';
import '../tema/yazi.dart';

class KararRozeti extends StatelessWidget {
  final String karar;
  final bool buyuk;
  const KararRozeti(this.karar,{super.key,this.buyuk=false});
  static String label(String karar) => const {'AL':'Alınabilir','PAZARLIK YAP':'Pazarlık yapın','ALMA':'Önerilmez',
    'EK DOĞRULAMA GEREKLİ':'Ek doğrulama gerekli'}[karar] ?? 'Karar belirtilmemiş';
  @override Widget build(BuildContext context) {
    final r=YbRenkler.of(context);
    final (ink,background)=switch(karar) {'AL'=>(r.birincilMetin,r.birincilYuzey),
      'PAZARLIK YAP'=>(r.uyari,r.uyariYuzey),'ALMA'=>(r.tehlike,r.tehlikeYuzey),_=>(r.bilgi,r.bilgiYuzey)};
    final value=label(karar);
    return Semantics(label:value,child:ExcludeSemantics(child:Container(
      padding:const EdgeInsets.symmetric(vertical:Olcu.rozetDikey,horizontal:Olcu.s8),
      decoration:BoxDecoration(color:background,borderRadius:BorderRadius.circular(Olcu.rozetKose)),
      child:Text(buyuk ? value.replaceAll('i','İ').toUpperCase() : value,
        style:Yazilar.kucuk.copyWith(color:ink,fontWeight:buyuk ? FontWeight.w700 : FontWeight.w600)))));
  }
}
