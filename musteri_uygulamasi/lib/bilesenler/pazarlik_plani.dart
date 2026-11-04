import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/models.dart';
import 'ortak.dart';
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
      ValueLine('Açılış teklifi', money(plan['acilisTeklifi'])),
      ValueLine('Hedef fiyat', money(plan['hedefFiyat'])),
      ValueLine('Üst sınırınız', money(plan['ustSinir'])),
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
      if (text(plan['saticiMesaji']).isNotEmpty) ...[
        const Text('Satıcıya gönderebileceğiniz mesaj'),
        SelectableText(text(plan['saticiMesaji'])),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: text(plan['saticiMesaji'])),
            );
            if (context.mounted) showMessage(context, 'Mesaj kopyalandı.');
          },
          child: const Text('Mesajı kopyala'),
        ),
      ],
    ]);
  }
}
