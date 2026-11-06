import 'package:flutter/material.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/hareket.dart';
import '../tema/yazi.dart';
import 'ortak.dart';

class FiyatAraligi extends StatelessWidget {
  final num? alt, ust, hesaplanan, ilan;
  const FiyatAraligi({
    super.key,
    required this.alt,
    required this.ust,
    required this.hesaplanan,
    required this.ilan,
  });
  @override
  Widget build(BuildContext context) {
    if (alt == null ||
        ust == null ||
        !alt!.isFinite ||
        !ust!.isFinite ||
        alt! <= 0 ||
        ust! <= alt!) {
      return const Text('Fiyat aralığı için yeterli veri yok.');
    }
    final r = YbRenkler.of(context), span = ust! - alt!;
    final min = alt! - span * Olcu.fiyatOlcekPayi,
        max = ust! + span * Olcu.fiyatOlcekPayi;
    double position(num value) =>
        ((value - min) / (max - min)).clamp(0.0, 1.0).toDouble();
    final outside = ilan != null && ilan!.isFinite
        ? ilan! > ust!
              ? ' · aralığın üstünde'
              : ilan! < alt!
              ? ' · aralığın altında'
              : ''
        : '';
    return Semantics(
      label:
          'Adil fiyat aralığı ${money(alt)} ile ${money(ust)} arası; ilan fiyatı ${money(ilan)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth - Olcu.fiyatNokta;
              return SizedBox(
                height: Olcu.fiyatGrafikYukseklik,
                child: Stack(
                  children: [
                    Positioned(
                      left: Olcu.fiyatNokta / 2,
                      right: Olcu.fiyatNokta / 2,
                      top: Olcu.fiyatIzUst,
                      child: Container(
                        height: Olcu.izYukseklik,
                        decoration: BoxDecoration(
                          color: r.ayirici,
                          borderRadius: BorderRadius.circular(Olcu.hapKose),
                        ),
                      ),
                    ),
                    Positioned(
                      left: Olcu.fiyatNokta / 2 + width * position(alt!),
                      width: width * (position(ust!) - position(alt!)),
                      top: Olcu.fiyatIzUst,
                      child: Container(
                        height: Olcu.izYukseklik,
                        color: r.birincilAcik,
                      ),
                    ),
                    if (hesaplanan != null && hesaplanan!.isFinite)
                      AnimatedPositioned(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : Hareket.fiyat,
                        left: width * position(hesaplanan!),
                        top:
                            Olcu.fiyatIzUst -
                            (Olcu.fiyatNokta - Olcu.izYukseklik) / 2,
                        child: Container(
                          width: Olcu.fiyatNokta,
                          height: Olcu.fiyatNokta,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: r.birincil,
                            border: Border.all(
                              color: r.yuzey,
                              width: Olcu.vurguluKenar,
                            ),
                          ),
                        ),
                      ),
                    if (ilan != null && ilan!.isFinite)
                      Positioned(
                        left:
                            Olcu.fiyatNokta / 2 +
                            width * position(ilan!) -
                            Olcu.ilanCizgi / 2,
                        top: Olcu.s8,
                        child: Container(
                          width: Olcu.ilanCizgi,
                          height: Olcu.s24,
                          color: r.vurgu,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          // Sınır etiketleri çubuğun iki ucunun altında durur.
          Stack(
            children: [
              for (final v in [alt!, ust!])
                Align(
                  alignment: Alignment(position(v) * 2 - 1, 0),
                  heightFactor: 1,
                  child: Text(money(v), style: Yazilar.etiket),
                ),
            ],
          ),
          const SizedBox(height: Olcu.s8),
          Text(
            'İlan fiyatı: ${money(ilan)}$outside',
            style: Yazilar.govdeKucuk.copyWith(color: r.metinIkincil),
          ),
        ],
      ),
    );
  }
}
