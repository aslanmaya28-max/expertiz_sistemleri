import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../api/models.dart';
import 'ortak.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';
import 'pazarlik_uclusu.dart';
import 'rapor_kaynaklar.dart';
import 'rapor_karti.dart';

class NegotiationSection extends StatelessWidget {
  final Json plan;
  final LinkAction onLink;
  const NegotiationSection(this.plan, this.onLink, {super.key});
  @override
  Widget build(BuildContext context) {
    if (plan.isEmpty) return const SizedBox.shrink();
    return ReportCard('Pazarlık planı', [
      if (text(plan['uyari']).isNotEmpty) ...[
        Text(text(plan['uyari'])),
        const SizedBox(height: Olcu.s12),
      ],
      PazarlikUclusu(
        acilis: plan['acilisTeklifi'] as num?,
        hedef: plan['hedefFiyat'] as num?,
        ustSinir: plan['ustSinir'] as num?,
      ),
      if (plan['potansiyelKazanc'] is num && plan['potansiyelKazanc'] > 0)
        Text(
          'Hedefe ulaşırsanız ilan fiyatına göre yaklaşık ${money(plan['potansiyelKazanc'])} tasarruf edersiniz.',
        ),
      BulletList(strings(plan['adimlar'])),
      if (strings(plan['gerekceler']).isNotEmpty) ...[
        const Text('Gerekçeleriniz', style: Yazilar.bolumBaslik),
        BulletList(strings(plan['gerekceler'])),
      ],
      if (objects(plan['kanitIlanlar']).isNotEmpty) ...[
        const Text(
          'Satıcıya gösterebileceğiniz benzer ilanlar',
          style: Yazilar.bolumBaslik,
        ),
        ListingEvidence(objects(plan['kanitIlanlar']), onLink),
      ],
    ], icon: Icons.handshake_outlined);
  }
}

class SaticiMesaji extends StatelessWidget {
  final String mesaj;
  final LinkAction? onLink;
  const SaticiMesaji(this.mesaj, {super.key, this.onLink});
  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    return ReportCard('Satıcıya gönderilecek mesaj', [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Olcu.s16),
        decoration: BoxDecoration(
          color: r.yuzey,
          border: Border.all(color: r.raporKenar),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(Olcu.kartKose),
            topRight: Radius.circular(Olcu.kartKose),
            bottomRight: Radius.circular(Olcu.kartKose),
          ),
        ),
        child: SelectableText(
          mesaj,
          style: Yazilar.raporGovde.copyWith(color: r.metin),
        ),
      ),
      const SizedBox(height: Olcu.s12),
      Wrap(
        spacing: Olcu.s8,
        runSpacing: Olcu.s8,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: mesaj));
              if (context.mounted) showMessage(context, 'Mesaj kopyalandı.');
            },
            icon: const Icon(Icons.copy_outlined),
            label: Text(onLink == null ? 'Mesajı kopyala' : 'Kopyala'),
          ),
          FilledButton.icon(
            onPressed: () async {
              try {
                if (onLink != null) {
                  await onLink!(
                    'https://wa.me/?text=${Uri.encodeComponent(mesaj)}',
                  );
                } else {
                  await SharePlus.instance.share(ShareParams(text: mesaj));
                }
              } catch (e) {
                if (context.mounted) showMessage(context, e.toString());
              }
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(
              onLink == null ? 'Mesajı paylaş' : "WhatsApp'ta paylaş",
            ),
          ),
        ],
      ),
    ], icon: Icons.forum_outlined);
  }
}
