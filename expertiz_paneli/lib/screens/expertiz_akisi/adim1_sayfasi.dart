import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/yerimebak_colors.dart';
import '../../models/expertiz/adim1_arac_satici_model.dart';
import '../../providers/expertiz_provider.dart';
import 'widgets/adim1_arac_satici_form_widget.dart';
import 'widgets/kontrol_listesi_widget.dart';

/// Adim 1: Arac ve satici bilgileri.
///
/// Final rapor gonderimi bu sayfadan yapilmaz. Tek resmi gonderim aksiyonu
/// ExpertizBaslatSayfasi alt barindaki "Bitir ve Gonder" butonudur.
class Adim1Sayfasi extends StatefulWidget {
  const Adim1Sayfasi({super.key});

  @override
  State<Adim1Sayfasi> createState() => _Adim1SayfasiState();
}

class _Adim1SayfasiState extends State<Adim1Sayfasi> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ExpertizProvider>(
      builder: (context, provider, child) {
        final model = provider.adim1Model;
        if (model == null) {
          return const Center(child: Text('Model yukleniyor...'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdimEksikleriKarti(eksikler: provider.adimEksikleri(1)),
              const SizedBox(height: 12),
              Adim1AracSaticiFormWidget(
                model: model,
                enabled: provider.duzenlenebilir,
                onChanged: provider.updateAdim1,
              ),
              const SizedBox(height: 24),
              _buildPaketOzeti(model),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaketOzeti(Adim1AracSaticiModel model) {
    final paket = model.paket?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: YerimeBakColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: YerimeBakColors.blue.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: YerimeBakColors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paket bilgisi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: YerimeBakColors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  paket == null || paket.isEmpty ? 'Belirtilmedi' : paket,
                  style: const TextStyle(color: YerimeBakColors.darkGray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
