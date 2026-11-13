import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../tema/hareket.dart';
import '../tema/olculer.dart';

class BilgiDugmesi extends StatelessWidget {
  final String baslik, aciklama;
  const BilgiDugmesi(this.baslik, this.aciklama, {super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: '$baslik hakkında bilgi',
    child: Tooltip(
      message: '$baslik hakkında bilgi',
      excludeFromSemantics: true,
      child: IconButton(
        constraints: const BoxConstraints(
          minWidth: Olcu.dokunma,
          minHeight: Olcu.dokunma,
        ),
        icon: const Icon(LucideIcons.info, size: Olcu.ikonInce),
        onPressed: () => showGeneralDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierLabel: MaterialLocalizations.of(
            context,
          ).modalBarrierDismissLabel,
          transitionDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : Hareket.kisa,
          pageBuilder: (_, _, _) => AlertDialog(
            scrollable: true,
            title: Semantics(header: true, child: Text(baslik)),
            content: Text(aciklama),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Anladım'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

const aracAlaniBilgileri = {
  'paket':
      'İlandaki donanım ya da motor adı (ör. 1.0 TSI Style). Bilmiyorsanız boş bırakın; benzer ilanlar yine bulunur.',
  'hp':
      'Biliyorsanız girin; aynı modelin farklı motorlu ilanlarını ayırmamıza yardım eder.',
  'yil': 'Ruhsattaki model yılı; ilandaki yılla aynı olmalı.',
  'km':
      'İlandaki kilometre. Rapor, benzer ilanları kilometre farkına göre düzeltir.',
  'fiyat':
      'Satıcının istediği fiyat. Rapor bu fiyatın piyasadaki yerini ve pazarlık hedefinizi hesaplar.',
  'tramer':
      'Sigorta hasar kayıtlarının toplam tutarı. Kayıt yoksa 0 girin; bilmiyorsanız satıcıdan TRAMER sorgusu isteyin.',
};
