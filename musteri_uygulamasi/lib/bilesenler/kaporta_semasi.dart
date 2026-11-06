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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('SOL', style: Yazilar.kucuk),
            Text('ÖN', style: Yazilar.kucuk),
            Text('SAĞ', style: Yazilar.kucuk),
          ],
        ),
        const SizedBox(height: Olcu.s8),
        LayoutBuilder(
          builder: (context, c) {
            final scale = c.maxWidth / KaportaGeometri.genislik;
            return SizedBox(
              height: KaportaGeometri.yukseklik * scale,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _KaportaCizimi(
                          renkler: r,
                          durum: _durum,
                          dolgu: fill,
                          kenar: border,
                          harf: letter,
                        ),
                      ),
                    ),
                  ),
                  for (final part in KaportaGeometri.parcalar.entries)
                    Builder(
                      builder: (context) {
                        final s = _durum(part.key), rect = part.value.isabet;
                        void dongu() => _sec(
                          part.key,
                          durumlar.keys.elementAt(
                            (durumlar.keys.toList().indexOf(s) + 1) %
                                durumlar.length,
                          ),
                        );
                        return Positioned(
                          left: rect.left * scale,
                          top: rect.top * scale,
                          width: rect.width * scale,
                          height: rect.height * scale,
                          child: Semantics(
                            label: '${parcalar[part.key]}, ${durumlar[s]}',
                            button: true,
                            onTap: dongu,
                            child: Tooltip(
                              message: '${parcalar[part.key]}: ${durumlar[s]}',
                              child: GestureDetector(
                                key: ValueKey('kaporta-${part.key}'),
                                behavior: HitTestBehavior.opaque,
                                onTap: dongu,
                                onLongPress: () => _menu(context, part.key),
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
        const SizedBox(height: Olcu.s12),
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

class _KaportaCizimi extends CustomPainter {
  final YbRenkler renkler;
  final String Function(String) durum;
  final Color Function(String) dolgu, kenar;
  final String Function(String) harf;
  _KaportaCizimi({
    required this.renkler,
    required this.durum,
    required this.dolgu,
    required this.kenar,
    required this.harf,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = renkler;
    canvas.scale(size.width / KaportaGeometri.genislik);
    final cizgi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = Olcu.odakKenar
      ..strokeJoin = StrokeJoin.round
      ..color = r.ikonPasif.withValues(alpha: .55);
    final dolu = Paint()..style = PaintingStyle.fill;
    canvas.drawPath(KaportaGeometri.govdeler, dolu..color = r.yuzey);
    canvas.drawPath(KaportaGeometri.govdeler, cizgi);
    for (final e in KaportaGeometri.parcalar.entries) {
      final s = durum(e.key);
      canvas.drawPath(e.value.sekil, dolu..color = dolgu(s));
      canvas.drawPath(
        e.value.sekil,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s == 'orijinal' ? Olcu.kenar : Olcu.vurguluKenar
          ..color = s == 'orijinal'
              ? r.ikonPasif.withValues(alpha: .6)
              : kenar(s),
      );
    }
    canvas.drawPath(KaportaGeometri.camlar, dolu..color = r.cam);
    canvas.drawPath(KaportaGeometri.camlar, cizgi);
    canvas.drawPath(KaportaGeometri.detaylar, cizgi);
    canvas.drawPath(KaportaGeometri.lastikler, dolu..color = r.metinIkincil);
    canvas.drawPath(KaportaGeometri.jantlar, dolu..color = r.yuzeyIkincil);
    canvas.drawPath(KaportaGeometri.jantlar, cizgi);
    for (final e in KaportaGeometri.parcalar.entries) {
      final s = durum(e.key), h = harf(s);
      if (h.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: h,
          style: Yazilar.kucuk.copyWith(
            fontSize: Olcu.kaportaHarf,
            fontWeight: FontWeight.w700,
            color: s == 'degisen' ? r.degisenMetin : r.metin,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, e.value.etiket - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_KaportaCizimi old) => true;
}
