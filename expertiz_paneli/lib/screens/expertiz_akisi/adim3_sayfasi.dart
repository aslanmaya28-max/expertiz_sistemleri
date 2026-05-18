import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/expertiz_provider.dart';
import '../../core/constants/yerimebak_colors.dart';
import 'widgets/tablo_satiri_widget.dart';

/// Adım 3: İç Ekspertiz Sayfası
class Adim3Sayfasi extends StatefulWidget {
  const Adim3Sayfasi({super.key});

  @override
  State<Adim3Sayfasi> createState() => _Adim3SayfasiState();
}

class _Adim3SayfasiState extends State<Adim3Sayfasi> {
  final ImagePicker _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpertizProvider>(
      builder: (context, provider, child) {
        final model = provider.adim3Model;
        if (model == null) {
          return const Center(
            child: Text('Model yükleniyor...'),
          );
        }

        final aciklamalar = model.aciklamalar ?? {};
        final fotografUrl = model.fotografUrl ?? {};
        final fotografYolu = model.fotografYolu ?? {};

        return Scaffold(
          appBar: AppBar(
            title: const Text('3️⃣ İç Ekspertiz', style: TextStyle(color: YerimeBakColors.blue)),
            backgroundColor: Colors.white,
            foregroundColor: YerimeBakColors.blue,
            elevation: 0,
            iconTheme: const IconThemeData(color: YerimeBakColors.blue),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🎛️ KOKPİT
                _buildSectionHeader('🎛️ KOKPİT'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Direksiyon',
                  seciliDurum: model.direksiyon,
                  onDurumDegisti: (durum) {
                    provider.updateAdim3(model.copyWith(direksiyon: durum));
                  },
                  not: aciklamalar['direksiyon'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['direksiyon'] = not;
                    provider.updateAdim3(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['direksiyon'] ?? []).length,
                  fotografYolu: fotografYolu['direksiyon'],
                  onFotografEkle: () => _onFotografEkle('direksiyon', 'Direksiyon'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Gösterge Paneli',
                  seciliDurum: model.gostergePaneli,
                  onDurumDegisti: (durum) {
                    provider.updateAdim3(model.copyWith(gostergePaneli: durum));
                  },
                  not: aciklamalar['gostergePaneli'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['gostergePaneli'] = not;
                    provider.updateAdim3(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['gostergePaneli'] ?? []).length,
                  fotografYolu: fotografYolu['gostergePaneli'],
                  onFotografEkle: () => _onFotografEkle('gostergePaneli', 'Gösterge Paneli'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Klima',
                  seciliDurum: model.klima,
                  onDurumDegisti: (durum) {
                    provider.updateAdim3(model.copyWith(klima: durum));
                  },
                  not: aciklamalar['klima'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['klima'] = not;
                    provider.updateAdim3(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['klima'] ?? []).length,
                  fotografYolu: fotografYolu['klima'],
                  onFotografEkle: () => _onFotografEkle('klima', 'Klima'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Ses Sistemi',
                  seciliDurum: model.sesSistemi,
                  onDurumDegisti: (durum) {
                    provider.updateAdim3(model.copyWith(sesSistemi: durum));
                  },
                  not: aciklamalar['sesSistemi'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['sesSistemi'] = not;
                    provider.updateAdim3(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['sesSistemi'] ?? []).length,
                  fotografYolu: fotografYolu['sesSistemi'],
                  onFotografEkle: () => _onFotografEkle('sesSistemi', 'Ses Sistemi'),
                ),
                 
                const SizedBox(height: 24),

                // 💺 KOLTUKLAR
                _buildSectionHeader('💺 KOLTUKLAR'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Ön Koltuklar',
                  seciliDurum: model.onKoltuklar,
                  onDurumDegisti: (durum) {
                    provider.updateAdim3(model.copyWith(onKoltuklar: durum));
                  },
                  not: aciklamalar['onKoltuklar'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['onKoltuklar'] = not;
                    provider.updateAdim3(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['onKoltuklar'] ?? []).length,
                  fotografYolu: fotografYolu['onKoltuklar'],
                  onFotografEkle: () => _onFotografEkle('onKoltuklar', 'Ön Koltuklar'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Arka Koltuklar',
                  seciliDurum: model.arkaKoltuklar,
                  onDurumDegisti: (durum) {
                    provider.updateAdim3(model.copyWith(arkaKoltuklar: durum));
                  },
                  not: aciklamalar['arkaKoltuklar'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['arkaKoltuklar'] = not;
                    provider.updateAdim3(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['arkaKoltuklar'] ?? []).length,
                  fotografYolu: fotografYolu['arkaKoltuklar'],
                  onFotografEkle: () => _onFotografEkle('arkaKoltuklar', 'Arka Koltuklar'),
                ),
                 
                const SizedBox(height: 24),

                // 🪟 DÖŞEME
                _buildSectionHeader('🪟 DÖŞEME'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Döşeme',
                  seciliDurum: model.dorseme,
                  onDurumDegisti: (durum) {
                    provider.updateAdim3(model.copyWith(dorseme: durum));
                  },
                  not: aciklamalar['dorseme'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['dorseme'] = not;
                    provider.updateAdim3(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['dorseme'] ?? []).length,
                  fotografYolu: fotografYolu['dorseme'],
                  onFotografEkle: () => _onFotografEkle('dorseme', 'Döşeme'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Tavan Döşemesi',
                  seciliDurum: model.tavanDosemesi,
                  onDurumDegisti: (durum) {
                    provider.updateAdim3(model.copyWith(tavanDosemesi: durum));
                  },
                  not: aciklamalar['tavanDosemesi'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['tavanDosemesi'] = not;
                    provider.updateAdim3(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['tavanDosemesi'] ?? []).length,
                  fotografYolu: fotografYolu['tavanDosemesi'],
                  onFotografEkle: () => _onFotografEkle('tavanDosemesi', 'Tavan Döşemesi'),
                ),
                 
                const SizedBox(height: 24),

                // 🪟 PENCERELER
                _buildSectionHeader('🪟 PENCERELER'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Ön Pencereler',
                  seciliDurum: model.onPencereler,
                  onDurumDegisti: (durum) {
                    provider.updateAdim3(model.copyWith(onPencereler: durum));
                  },
                  not: aciklamalar['onPencereler'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['onPencereler'] = not;
                    provider.updateAdim3(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['onPencereler'] ?? []).length,
                  fotografYolu: fotografYolu['onPencereler'],
                  onFotografEkle: () => _onFotografEkle('onPencereler', 'Ön Pencereler'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Arka Pencereler',
                  seciliDurum: model.arkaPencereler,
                  onDurumDegisti: (durum) {
                    provider.updateAdim3(model.copyWith(arkaPencereler: durum));
                  },
                  not: aciklamalar['arkaPencereler'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['arkaPencereler'] = not;
                    provider.updateAdim3(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['arkaPencereler'] ?? []).length,
                  fotografYolu: fotografYolu['arkaPencereler'],
                  onFotografEkle: () => _onFotografEkle('arkaPencereler', 'Arka Pencereler'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Camlar',
                  seciliDurum: model.camlar,
                  onDurumDegisti: (durum) {
                    provider.updateAdim3(model.copyWith(camlar: durum));
                  },
                  not: aciklamalar['camlar'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['camlar'] = not;
                    provider.updateAdim3(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['camlar'] ?? []).length,
                  fotografYolu: fotografYolu['camlar'],
                  onFotografEkle: () => _onFotografEkle('camlar', 'Camlar'),
                ),
                 
                const SizedBox(height: 24),

                // 🔌 ELEKTRONİK
                _buildSectionHeader('🔌 ELEKTRONİK'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Merkezi Kilit',
                  seciliDurum: model.merkeziKilit,
                  onDurumDegisti: (durum) {
                    provider.updateAdim3(model.copyWith(merkeziKilit: durum));
                  },
                  not: aciklamalar['merkeziKilit'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['merkeziKilit'] = not;
                    provider.updateAdim3(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['merkeziKilit'] ?? []).length,
                  fotografYolu: fotografYolu['merkeziKilit'],
                  onFotografEkle: () => _onFotografEkle('merkeziKilit', 'Merkezi Kilit'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Cam Kontrolleri',
                  seciliDurum: model.camKontrolleri,
                  onDurumDegisti: (durum) {
                    provider.updateAdim3(model.copyWith(camKontrolleri: durum));
                  },
                  not: aciklamalar['camKontrolleri'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['camKontrolleri'] = not;
                    provider.updateAdim3(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['camKontrolleri'] ?? []).length,
                  fotografYolu: fotografYolu['camKontrolleri'],
                  onFotografEkle: () => _onFotografEkle('camKontrolleri', 'Cam Kontrolleri'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Ayna Kontrolleri',
                  seciliDurum: model.aynaKontrolleri,
                  onDurumDegisti: (durum) {
                    provider.updateAdim3(model.copyWith(aynaKontrolleri: durum));
                  },
                  not: aciklamalar['aynaKontrolleri'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['aynaKontrolleri'] = not;
                    provider.updateAdim3(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['aynaKontrolleri'] ?? []).length,
                  fotografYolu: fotografYolu['aynaKontrolleri'],
                  onFotografEkle: () => _onFotografEkle('aynaKontrolleri', 'Ayna Kontrolleri'),
                ),
                 
                const SizedBox(height: 24),

                // 📝 GENEL NOTLAR
                _buildSectionHeader('📝 GENEL NOTLAR'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                TextField(
                  controller: TextEditingController(text: model.genelNot ?? ''),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Genel Notlar',
                    border: OutlineInputBorder(),
                    hintText: 'İç ekspertiz hakkında notlarınız...',
                  ),
                  onChanged: (value) {
                    provider.updateAdim3(model.copyWith(genelNot: value));
                  },
                ),
                 
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: YerimeBakColors.blue,
        ),
      ),
    );
  }

  Future<void> _onFotografEkle(String maddeAdi, String maddeGorunenAdi) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null && mounted) {
        final provider = Provider.of<ExpertizProvider>(context, listen: false);
        final model = provider.adim3Model;
        if (model == null) return;

        // fotografUrl listesine ekle
        final yeniFotografUrl = Map<String, List<String>>.from(model.fotografUrl ?? {});
        if (!yeniFotografUrl.containsKey(maddeAdi)) {
          yeniFotografUrl[maddeAdi] = [];
        }
        yeniFotografUrl[maddeAdi]!.add(image.path);

        // fotografYolu'na ilk fotoğrafı kaydet (thumbnail için)
        final yeniFotografYolu = Map<String, String>.from(model.fotografYolu ?? {});
        yeniFotografYolu[maddeAdi] = image.path;

        provider.updateAdim3(model.copyWith(
          fotografUrl: yeniFotografUrl,
          fotografYolu: yeniFotografYolu,
        ));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$maddeGorunenAdi için fotoğraf eklendi'),
              backgroundColor: YerimeBakColors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf seçimi hatası: $e'),
            backgroundColor: YerimeBakColors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

}
