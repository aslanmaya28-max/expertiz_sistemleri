import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expertiz/adim2_dis_ekspertiz_model.dart';
import '../../providers/expertiz_provider.dart';
import 'widgets/kontrol_listesi_widget.dart';

/// Adım 2: Dış Ekspertiz
///
/// Her madde için durum seçilir. Sorunlu / Kötü / Ağır Hasar işaretlenen
/// maddelerde fotoğraf zorunludur; fotoğraf anında sunucuya kaydedilir.
class Adim2Sayfasi extends StatelessWidget {
  const Adim2Sayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpertizProvider>();
    final model = provider.adim2Model;
    if (model == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final duzenlenebilir = provider.duzenlenebilir;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdimEksikleriKarti(eksikler: provider.adimEksikleri(2)),
        const SizedBox(height: 12),
        KontrolListesiBolumu(
          baslik: '🔍 Dış Ekspertiz',
          bolum: ExpertizProvider.bolumDis,
          maddeler: Adim2DisEkspertizModel.maddeler,
          secenekler: DurumSecenekleri.kontrol,
          duzenlenebilir: duzenlenebilir,
          durum: model.durum,
          onDurum: (key, durum) => provider.updateAdim2(provider.adim2Model!.withDurum(key, durum)),
          not: model.not,
          onNot: (key, not) => provider.updateAdim2(provider.adim2Model!.withNot(key, not)),
          onToplu: (toplu) => provider.updateAdim2(
            provider.adim2Model!.copyWith(durumlar: {...provider.adim2Model!.durumlar, ...toplu}),
          ),
        ),
        const SizedBox(height: 16),
        GenelNotAlani(
          deger: model.genelNot ?? '',
          etiket: 'Dış ekspertiz genel notu',
          duzenlenebilir: duzenlenebilir,
          onChanged: (value) => provider.updateAdim2(provider.adim2Model!.copyWith(genelNot: value)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
