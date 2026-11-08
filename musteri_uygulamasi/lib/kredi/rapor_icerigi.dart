import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../bilesenler/kart.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';

/// Sitedeki "100 TL'ye neler alırsınız?" kartının uygulama karşılığı (09.11.2026).
/// Fiyat Google Play'den geldiği için başlıkta tutar yazılmaz: "1 kredi ile neler alırsınız?".
/// Maddeler yalnız raporda gerçekten olanlar; sitedeki `DegerlemeKapsami.tsx` ile aynı.
const raporIcerigi = <(String, IconData, List<String>)>[
  (
    'Fiyat',
    LucideIcons.scale,
    [
      'Piyasaya göre konum',
      'Adil fiyat aralığı ve tavsiye alım fiyatı',
      'Hasarın fiyat etkisi',
      'Benzer ilanlar',
    ],
  ),
  (
    'Pazarlık',
    LucideIcons.tag,
    ['Pazarlık planı', 'Satıcıya hazır mesaj', 'Enflasyona göre kazanç'],
  ),
  (
    'Riskler ve kontrol',
    LucideIcons.shieldCheck,
    [
      'Modelin bilinen sorunları',
      'Bakım listesi',
      'Satıcıya sorulacak sorular',
    ],
  ),
  (
    'Teslim',
    LucideIcons.fileText,
    ['Ekranda ve PDF olarak', 'Yerinde incelemeye tek adım'],
  ),
];

class RaporIcerigiKarti extends StatelessWidget {
  const RaporIcerigiKarti({super.key});
  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    return Kart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              '1 kredi ile neler alırsınız?',
              style: Yazilar.bolumBaslik,
            ),
          ),
          const SizedBox(height: Olcu.s4),
          Text(
            'Tek bir araç için tam değerleme raporu. 1 kredi = 1 rapor.',
            style: Yazilar.govdeKucuk.copyWith(color: r.metinIkincil),
          ),
          for (final (ad, ikon, maddeler) in raporIcerigi) ...[
            const SizedBox(height: Olcu.s16),
            Row(
              children: [
                Icon(ikon, size: Olcu.ikonInce, color: r.birincil),
                const SizedBox(width: Olcu.s8),
                Expanded(
                  child: Text(
                    ad,
                    style: Yazilar.etiket.copyWith(
                      color: r.metin,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Olcu.s8),
            for (final m in maddeler)
              Padding(
                padding: const EdgeInsets.only(bottom: Olcu.s4, left: Olcu.s4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.check, size: 16, color: r.birincil),
                    const SizedBox(width: Olcu.s8),
                    Expanded(
                      child: Text(
                        m,
                        style: Yazilar.govdeKucuk.copyWith(color: r.metin),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: Olcu.s12),
          Text(
            'Yeterli benzer ilan bulunamazsa rapor üretilmez, krediniz düşülmez.',
            style: Yazilar.govdeKucuk.copyWith(
              color: r.birincilMetin,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
