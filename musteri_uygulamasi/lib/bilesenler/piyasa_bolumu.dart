import 'package:flutter/material.dart';
import '../api/models.dart';
import 'ortak.dart';
import 'rapor_ozet.dart';
import 'rapor_kaynaklar.dart';

class MarketSection extends StatelessWidget {
  final Json data;
  final LinkAction onLink;
  const MarketSection(this.data, this.onLink, {super.key});
  @override
  Widget build(BuildContext context) {
    final count = integer(data['emsalSayisi']),
        correction = object(data['duzeltme']);
    return Panel('Benzer ilanlar', [
      if ([3, 4].contains(count))
        Text(
          '$count benzer ilan bulundu; 5’ten az olduğu için fiyatlar yön göstericidir.',
        ),
      Text(
        '$count güncel emsal ilan (${integer(data['hasarsizEmsalSayisi'])} hasarsız).',
      ),
      ValueLine(
        'Ortalama${correction.isNotEmpty ? ' (bu araca göre)' : ''}',
        money(data['ortalama']),
      ),
      ValueLine('Orta fiyat', money(data['medyan'])),
      ValueLine('Aralık', '${money(data['min'])} – ${money(data['max'])}'),
      if (integer(data['takipIlanSayisi']) > 0)
        Text(
          'Bu değerlendirmede YerimeBak piyasa takibinden ${data['takipIlanSayisi']} ilan da kullanıldı.',
        ),
      if (correction.isNotEmpty)
        Text(
          'İlan fiyatları yıl ve km farkıyla bu araca (${correction['aracYili'] ?? '—'}, ${number(correction['aracKm'])} km) göre düzeltildi.${text(correction['kasa']).isNotEmpty ? ' Yalnız aynı kasa (${correction['kasa']}) ilanları kullanıldı.' : ''}',
        ),
      BulletList(
        strings(
          data['uyarilar'],
        ).where((s) => !legacySampleWarning(s, count)).toList(),
      ),
      ListingEvidence(
        objects(
          data['kaynaklar'],
        ).where((r) => safeWeb(text(r['url']))).toList(),
        onLink,
      ),
    ]);
  }
}

class GenerationSection extends StatelessWidget {
  final Json data;
  const GenerationSection(this.data, {super.key});
  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    return Panel('${data['yil'] ?? 'Bu yıl'} bu model için kasa geçiş yılı', [
      const Text(
        'O yıl iki farklı kasa satıldı ve fiyatları farklıdır. Fiyatlar bu araca (yıl ve km) göre düzeltilmiştir.',
      ),
      for (final key in ['eski', 'yeni'])
        ValueLine(
          '${key == 'eski' ? 'Önceki kasa' : 'Yeni kasa'}${data['secilen'] == key ? ' • değerleme bu kasaya göre' : ''}',
          '${text(object(data[key])['kasa'])} • ${object(data[key])['ortaFiyat'] == null ? 'Yeterli ilan yok' : money(object(data[key])['ortaFiyat'])}',
        ),
      const Text('Kasa kodunu ve ilk tescil tarihini satıcıdan doğrulayın.'),
    ]);
  }
}
