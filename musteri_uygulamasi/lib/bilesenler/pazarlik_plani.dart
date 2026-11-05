import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/models.dart';
import 'ortak.dart';
import '../tema/olculer.dart';
import '../tema/yazi.dart';
import 'pazarlik_uclusu.dart';
import 'package:share_plus/share_plus.dart';
import 'rapor_kaynaklar.dart';

class NegotiationSection extends StatelessWidget {
  final Json plan;
  final LinkAction onLink;
  const NegotiationSection(this.plan, this.onLink, {super.key});
  @override
  Widget build(BuildContext context) {
    if (plan.isEmpty) return const SizedBox.shrink();
    return Panel('Pazarlık planı', [
      if (text(plan['uyari']).isNotEmpty) Text(text(plan['uyari'])),
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
        const Text('Gerekçeleriniz'),
        BulletList(strings(plan['gerekceler'])),
      ],
      if (objects(plan['kanitIlanlar']).isNotEmpty) ...[
        const Text('Satıcıya gösterebileceğiniz benzer ilanlar'),
        ListingEvidence(objects(plan['kanitIlanlar']), onLink),
      ],
      if (text(plan['saticiMesaji']).isNotEmpty)
        SaticiMesaji(text(plan['saticiMesaji'])),
    ]);
  }
}

class SaticiMesaji extends StatelessWidget {
  final String mesaj;
  const SaticiMesaji(this.mesaj, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Satıcıya gönderebileceğiniz mesaj',
        style: Yazilar.bolumBaslik,
      ),
      const SizedBox(height: Olcu.s12),
      SelectableText(mesaj, style: Yazilar.govde),
      const SizedBox(height: Olcu.s12),
      TextButton(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: mesaj));
          if (context.mounted) showMessage(context, 'Mesaj kopyalandı.');
        },
        child: const Text('Mesajı kopyala'),
      ),
      TextButton(
        onPressed: () => SharePlus.instance.share(ShareParams(text: mesaj)),
        child: const Text('Mesajı paylaş'),
      ),
    ],
  );
}
