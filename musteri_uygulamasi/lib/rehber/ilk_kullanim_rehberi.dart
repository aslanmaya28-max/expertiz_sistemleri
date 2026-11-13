import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/providers.dart';
import '../tema/hareket.dart';
import '../tema/olculer.dart';
import '../tema/yazi.dart';

/// Kalıcı tercih kullanılamasa da aynı uygulama oturumunda tur tekrarlanmaz.
class RehberDeposu {
  static const anahtar = 'yerimebak_ilk_kullanim_v1';
  final Future<SharedPreferences> Function() yukle;
  bool _sunuldu = false;
  RehberDeposu({this.yukle = SharedPreferences.getInstance});

  Future<bool> ilkAcilis() async {
    if (_sunuldu) return false;
    _sunuldu = true;
    try {
      return (await yukle()).getBool(anahtar) != true;
    } catch (_) {
      return true;
    }
  }

  Future<void> tamamla() async {
    _sunuldu = true;
    try {
      await (await yukle()).setBool(anahtar, true);
    } catch (_) {
      // Tercih kaydedilemediğinde uygulama ve tur kullanılabilir kalır.
    }
  }
}

final rehberDeposuProvider = Provider((ref) => RehberDeposu());

Future<void> ilkKullanimRehberiniAc(BuildContext context, WidgetRef ref) async {
  final depo = ref.read(rehberDeposuProvider);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Hareket.kisa,
    pageBuilder: (_, _, _) => Consumer(
      builder: (_, ref, _) =>
          _RehberDiyalogu(bakiye: ref.watch(balanceProvider).valueOrNull),
    ),
  );
  await depo.tamamla();
}

class _RehberDiyalogu extends StatefulWidget {
  final int? bakiye;
  const _RehberDiyalogu({this.bakiye});
  @override
  State<_RehberDiyalogu> createState() => _RehberDiyaloguState();
}

class _RehberDiyaloguState extends State<_RehberDiyalogu> {
  int adim = 0;
  @override
  Widget build(BuildContext context) {
    final adimlar = [
      (
        'İlanı ekleyin',
        'Ana sayfaya ilan linkini yapıştırın veya ilanı açtığınız uygulamada Paylaş → YerimeBak yolunu kullanın.',
      ),
      (
        'Site erişim vermiyorsa',
        'İlan sitesi erişim vermezse “Site erişim vermiyor” mesajı ve ekran görüntüsü ekleme seçeneği çıkar. Bu durumda ilanın ekran görüntüsünü ekleyebilirsiniz.',
      ),
      (
        'İlan yok mu?',
        '“İlan yok mu? Bilgileri elle girin” seçeneğini kullanın. Araç formundaki bilgileri kontrol edin; alanların yanındaki “i” düğmeleri kısa açıklamaları açar.',
      ),
      (
        'Raporunuzu alın',
        'Her rapor 1 kredi kullanır ve Raporlarım’da saklanır. ${widget.bakiye == 0 ? 'Bakiyeniz şu an 0. Hesabınıza kredi tanımlandığında analiz yapabilirsiniz. ' : ''}Google Play üzerinden kredi satın alma yakında.',
      ),
    ];
    return AlertDialog(
      scrollable: true,
      title: Semantics(header: true, child: Text(adimlar[adim].$1)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              'Adım ${adim + 1} / ${adimlar.length}',
              style: Yazilar.etiket,
            ),
          ),
          const SizedBox(height: Olcu.s16),
          Text(adimlar[adim].$2),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Atla'),
        ),
        if (adim > 0)
          TextButton(
            onPressed: () => setState(() => adim--),
            child: const Text('Geri'),
          ),
        FilledButton(
          onPressed: () {
            if (adim == adimlar.length - 1) {
              Navigator.pop(context);
            } else {
              setState(() => adim++);
            }
          },
          child: Text(adim == adimlar.length - 1 ? 'Başlayalım' : 'İleri'),
        ),
      ],
    );
  }
}
