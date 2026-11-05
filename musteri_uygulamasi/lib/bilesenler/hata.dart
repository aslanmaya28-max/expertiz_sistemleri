import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../api/api_client.dart';
import 'bos_durum.dart';
import 'ikincil_buton.dart';

class Hata extends StatelessWidget {
  final Object error;
  final VoidCallback retry;
  const Hata(this.error,this.retry,{super.key});
  @override
  Widget build(BuildContext context) {
    final message=error.toString(),status=error is ApiFailure ? (error as ApiFailure).status : 0;
    final (title,body)=status == 401 ? ('Oturumunuz sona erdi','Devam etmek için yeniden giriş yapın.')
      : message.toLowerCase().contains('gecik') || message.toLowerCase().contains('timeout') ? ('Yanıt gecikti','Sunucuya ulaşmak uzun sürdü. Biraz sonra yeniden deneyin.')
      : status >= 400 && status < 500 ? ('İstek tamamlanamadı',message)
      : ('Bağlantı kurulamadı','İnternet bağlantınızı kontrol edip yeniden deneyin.');
    return BosDurum(title,body,ikon:LucideIcons.circleAlert,eylem:IkincilButon('Tekrar dene',() async=>retry()));
  }
}
