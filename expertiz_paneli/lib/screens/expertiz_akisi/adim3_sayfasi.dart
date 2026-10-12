import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expertiz/adim3_ic_ekspertiz_model.dart';
import '../../providers/expertiz_provider.dart';
import 'widgets/kontrol_listesi_widget.dart';

/// Adım 3: İç Ekspertiz
///
/// Kokpit, koltuklar, döşemeler, camlar, elektronik ve genel kontroller.
/// Eksiklik işaretlenen maddelerde fotoğraf zorunludur.
class Adim3Sayfasi extends StatelessWidget {
  const Adim3Sayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpertizProvider>();
    final model = provider.adim3Model;
    if (model == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final duzenlenebilir = provider.duzenlenebilir;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdimEksikleriKarti(eksikler: provider.adimEksikleri(3)),
        const SizedBox(height: 12),
        KontrolListesiBolumu(
          baslik: '💺 İç Ekspertiz',
          bolum: ExpertizProvider.bolumIc,
          maddeler: Adim3IcEkspertizModel.maddeler,
          secenekler: DurumSecenekleri.kontrol,
          duzenlenebilir: duzenlenebilir,
          durum: model.durum,
          onDurum: (key, durum) => provider.updateAdim3(provider.adim3Model!.withDurum(key, durum)),
          not: model.not,
          onNot: (key, not) => provider.updateAdim3(provider.adim3Model!.withNot(key, not)),
          onToplu: (toplu) => provider.updateAdim3(
            provider.adim3Model!.copyWith(durumlar: {...provider.adim3Model!.durumlar, ...toplu}),
          ),
        ),
        const SizedBox(height: 16),
        GenelNotAlani(
          deger: model.genelNot ?? '',
          etiket: 'İç ekspertiz genel notu',
          duzenlenebilir: duzenlenebilir,
          onChanged: (value) => provider.updateAdim3(provider.adim3Model!.copyWith(genelNot: value)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
