import 'package:flutter/material.dart';
import '../api/models.dart';
import 'ortak.dart';

class LossSection extends StatelessWidget {
  final Json data;
  const LossSection(this.data, {super.key});
  @override
  Widget build(BuildContext context) => Panel(
    'Değer kaybı (${percent(data['toplamDegerKaybiYuzde'])} • ${money(data['toplamDegerKaybiTutar'])})',
    [
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
