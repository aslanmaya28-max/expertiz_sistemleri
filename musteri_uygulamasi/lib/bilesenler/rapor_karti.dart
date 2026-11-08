import 'package:flutter/material.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';

/// Raporun ortak kartı; diğer ekranların Panel sunumunu etkilemez.
class ReportCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final IconData? icon;
  final bool dark, warning;
  const ReportCard(
    this.title,
    this.children, {
    super.key,
    this.icon,
    this.dark = false,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    final foreground = dark ? r.beyaz : r.metin;
    return Container(
      margin: const EdgeInsets.only(bottom: Olcu.kartArasi),
      padding: const EdgeInsets.all(Olcu.kartBuyukIci),
      decoration: BoxDecoration(
        color: warning ? r.uyariYuzey : r.raporYuzey,
        gradient: dark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [r.markaBandi, r.raporKoyu],
              )
            : null,
        borderRadius: BorderRadius.circular(Olcu.raporKose),
        border: Border.all(color: warning ? r.uyariKenar : r.raporKenar),
      ),
      child: TextButtonTheme(
        data: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(Olcu.ikincilButon, Olcu.ikincilButon),
          ),
        ),
        child: DefaultTextStyle.merge(
          style: Yazilar.raporGovde.copyWith(color: foreground),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: Olcu.ikon,
                        color: warning
                            ? r.uyari
                            : dark
                            ? r.markaBandiVurgu
                            : r.birincilMetin,
                      ),
                      const SizedBox(width: Olcu.s12),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: Yazilar.bolumBaslik.copyWith(color: foreground),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Olcu.s16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
