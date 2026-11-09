import 'package:flutter/material.dart';
import '../tema/renkler.dart';
import '../tema/olculer.dart';

enum YbButonTuru { ana, ikincil, metin, tehlike }

class YbButon extends StatelessWidget {
  const YbButon(
      {super.key,
      required this.metin,
      this.onPressed,
      this.ikon,
      this.tur = YbButonTuru.ana,
      this.yukleniyor = false,
      this.tamGenislik = false});
  final String metin;
  final VoidCallback? onPressed;
  final IconData? ikon;
  final YbButonTuru tur;
  final bool yukleniyor, tamGenislik;
  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final content = yukleniyor
        ? const SizedBox(
            width: Olcu.s20,
            height: Olcu.s20,
            child: CircularProgressIndicator(strokeWidth: Olcu.kenar * 2))
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                if (ikon != null) ...[
                  Icon(ikon, size: Olcu.ikonInce),
                  const SizedBox(width: Olcu.s8)
                ],
                Flexible(child: Text(metin))
              ]);
    final callback = yukleniyor ? null : onPressed;
    final style = ButtonStyle(visualDensity: VisualDensity.standard,
        minimumSize:
            const WidgetStatePropertyAll(Size(Olcu.dokunma, PanelOlcu.buton)),
        textStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Olcu.butonKose))));
    final button = switch (tur) {
      YbButonTuru.ana =>
        FilledButton(onPressed: callback, style: style, child: content),
      YbButonTuru.ikincil => OutlinedButton(
          onPressed: callback,
          style: style.copyWith(
              foregroundColor: WidgetStatePropertyAll(r.metin),
              backgroundColor: WidgetStatePropertyAll(r.yuzey),
              side: WidgetStatePropertyAll(BorderSide(color: r.girdiKenarlik))),
          child: content),
      YbButonTuru.metin =>
        TextButton(onPressed: callback, style: style, child: content),
      YbButonTuru.tehlike => FilledButton(
          onPressed: callback,
          style: style.copyWith(
              backgroundColor: WidgetStatePropertyAll(r.tehlikeYuzey),
              foregroundColor: WidgetStatePropertyAll(r.tehlike)),
          child: content),
    };
    return Semantics(
        label: yukleniyor ? '$metin, yükleniyor' : null,
        child: tamGenislik
            ? SizedBox(width: double.infinity, child: button)
            : button);
  }
}

