import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../tema/kaporta_geometri.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';

class KaportaSemasi extends StatelessWidget {
  final Map<String, String> degerler;
  final ValueChanged<Map<String, String>> onChanged;
  const KaportaSemasi({
    super.key,
    required this.degerler,
    required this.onChanged,
  });
  static const parcalar = {
    'onTampon': 'Ön Tampon',
    'kaput': 'Motor Kaputu',
    'solOnCamurluk': 'Sol Ön Çamurluk',
    'solOnKapi': 'Sol Ön Kapı',
    'solArkaKapi': 'Sol Arka Kapı',
    'solArkaCamurluk': 'Sol Arka Çamurluk',
    'sagOnCamurluk': 'Sağ Ön Çamurluk',
    'sagOnKapi': 'Sağ Ön Kapı',
    'sagArkaKapi': 'Sağ Arka Kapı',
    'sagArkaCamurluk': 'Sağ Arka Çamurluk',
    'tavan': 'Tavan',
    'bagajKapagi': 'Bagaj Kapağı',
    'arkaTampon': 'Arka Tampon',
  };
  static const durumlar = {
    'orijinal': 'Orijinal',
    'lokal_boyali': 'Lokal boyalı',
    'boyali': 'Boyalı',
    'degisen': 'Değişen',
  };
  String _durum(String id) =>
      durumlar.containsKey(degerler[id]) ? degerler[id]! : 'orijinal';
  void _sec(String id, String value) => onChanged({...degerler, id: value});
  Future<void> _menu(BuildContext context, String id) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Olcu.s16),
              child: Text(parcalar[id]!, style: Yazilar.bolumBaslik),
            ),
            for (final e in durumlar.entries)
              ListTile(
                title: Text(e.value),
                selected: e.key == _durum(id),
                onTap: () => Navigator.pop(context, e.key),
              ),
          ],
        ),
      ),
    );
    if (result != null) _sec(id, result);
  }

  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    Color fill(String s) => switch (s) {
      'lokal_boyali' => r.lokalYuzey,
      'boyali' => r.boyaliYuzey,
      'degisen' => r.degisenYuzey,
      _ => r.yuzey,
    };
    Color border(String s) => switch (s) {
      'lokal_boyali' => r.lokalKenar,
      'boyali' => r.boyaliKenar,
      'degisen' => r.degisenYuzey,
      _ => r.girdiKenarlik,
    };
    String letter(String s) => switch (s) {
      'lokal_boyali' => 'L',
      'boyali' => 'B',
      'degisen' => 'D',
      _ => '',
    };
    final changed = parcalar.keys
        .where((key) => _durum(key) != 'orijinal')
        .toList();
    final summary = changed.isEmpty
        ? '13 parça orijinal'
        : [
            for (final status in durumlar.keys.skip(1))
              if (changed.any((key) => _durum(key) == status))
                '${durumlar[status]}: ${changed.where((key) => _durum(key) == status).map((key) => parcalar[key]!).join(', ')}',
            if (changed.length < parcalar.length)
              'Diğer ${parcalar.length - changed.length} parça orijinal',
          ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('ÖN', textAlign: TextAlign.center, style: Yazilar.kucuk),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('SOL', style: Yazilar.kucuk),
            Text('SAĞ', style: Yazilar.kucuk),
          ],
        ),
        LayoutBuilder(
          builder: (context, c) {
            final scale = c.maxWidth / Olcu.kaportaGenislik;
            return SizedBox(
              height: Olcu.kaportaYukseklik * scale,
              child: Stack(
                children: [
                  Positioned.fromRect(
                    rect: Rect.fromLTWH(
                      KaportaGeometri.govde.left * scale,
                      KaportaGeometri.govde.top * scale,
                      KaportaGeometri.govde.width * scale,
                      KaportaGeometri.govde.height * scale,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: r.kenarlik),
                        borderRadius: BorderRadius.circular(
                          KaportaGeometri.govdeKose * scale,
                        ),
                      ),
                    ),
                  ),
                  for (final rect in KaportaGeometri.camlar)
                    Positioned.fromRect(
                      rect: Rect.fromLTWH(
                        rect.left * scale,
                        rect.top * scale,
                        rect.width * scale,
                        rect.height * scale,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: r.cam,
                          borderRadius: BorderRadius.circular(Olcu.rozetKose),
                        ),
                      ),
                    ),
                  for (final part in KaportaGeometri.parcalar.entries)
                    Builder(
                      builder: (context) {
                        final s = _durum(part.key), rect = part.value;
                        final w = math.max(Olcu.dokunma, rect.width * scale),
                            h = math.max(Olcu.dokunma, rect.height * scale);
                        return Positioned(
                          left: rect.center.dx * scale - w / 2,
                          top: rect.center.dy * scale - h / 2,
                          width: w,
                          height: h,
                          child: Semantics(
                            label: '${parcalar[part.key]}, ${durumlar[s]}',
                            button: true,
                            onTap: () => _sec(
                              part.key,
                              durumlar.keys.elementAt(
                                (durumlar.keys.toList().indexOf(s) + 1) %
                                    durumlar.length,
                              ),
                            ),
                            child: Tooltip(
                              message: '${parcalar[part.key]}: ${durumlar[s]}',
                              child: GestureDetector(
                                key: ValueKey('kaporta-${part.key}'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _sec(
                                  part.key,
                                  durumlar.keys.elementAt(
                                    (durumlar.keys.toList().indexOf(s) + 1) %
                                        durumlar.length,
                                  ),
                                ),
                                onLongPress: () => _menu(context, part.key),
                                child: Center(
                                  child: Container(
                                    width: rect.width * scale,
                                    height: rect.height * scale,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: fill(s),
                                      border: Border.all(
                                        color: border(s),
                                        width: Olcu.odakKenar,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        Olcu.rozetKose,
                                      ),
                                    ),
                                    child: ExcludeSemantics(
                                      child: Text(
                                        letter(s),
                                        style: Yazilar.kucuk.copyWith(
                                          color: s == 'degisen'
                                              ? r.degisenMetin
                                              : r.metin,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
        Wrap(
          spacing: Olcu.s12,
          runSpacing: Olcu.s8,
          children: [
            for (final entry in durumlar.entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: Olcu.s24,
                    height: Olcu.s24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: fill(entry.key),
                      border: Border.all(color: border(entry.key)),
                      borderRadius: BorderRadius.circular(Olcu.rozetKose),
                    ),
                    child: Text(
                      letter(entry.key),
                      style: Yazilar.kucuk.copyWith(
                        color: entry.key == 'degisen'
                            ? r.degisenMetin
                            : r.metin,
                      ),
                    ),
                  ),
                  const SizedBox(width: Olcu.s4),
                  Text(entry.value, style: Yazilar.etiket),
                ],
              ),
          ],
        ),
        const SizedBox(height: Olcu.s12),
        Text(summary, style: Yazilar.govdeKucuk),
        const SizedBox(height: Olcu.s8),
        const Text(
          'Durumu değiştirmek için dokunun; seçenekler için basılı tutun.',
          style: Yazilar.etiket,
        ),
      ],
    );
  }
}
