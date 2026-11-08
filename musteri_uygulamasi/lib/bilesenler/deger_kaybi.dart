import 'package:flutter/material.dart';
import '../api/models.dart';
import 'ortak.dart';
import 'rapor_karti.dart';

class LossSection extends StatelessWidget {
  final Json data;
  const LossSection(this.data, {super.key});
  @override
  Widget build(BuildContext context) => ReportCard(
    'Değer kaybı (${percent(data['toplamDegerKaybiYuzde'])} • ${money(data['toplamDegerKaybiTutar'])})',
    [
      ValueLine('Hasarsız piyasa değeri', money(data['temizPiyasaDegeri'])),
      const Text('−'),
      ValueLine('Değer kaybı', money(data['toplamDegerKaybiTutar'])),
      const Text('='),
      ValueLine('Hesaplanan değer', money(data['aiDegeri'])),
      if (objects(data['kalemler']).isEmpty)
        const Text('Bildirilen boya, değişen veya hasar kaydı yok.'),
      for (final item in objects(data['kalemler']))
        ValueLine(
          text(item['baslik']),
          '${text(item['durum'])} • -${percent(item['yuzde'])} • -${money(item['tutar'])}',
        ),
      if (text(data['ozet']).isNotEmpty) Text(text(data['ozet'])),
    ],
  );
}
