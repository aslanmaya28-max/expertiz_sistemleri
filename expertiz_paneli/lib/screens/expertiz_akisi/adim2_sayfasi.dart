import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/expertiz_provider.dart';
import '../../core/constants/yerimebak_colors.dart';
import 'widgets/tablo_satiri_widget.dart';

/// Adım 2: Dış Ekspertiz Sayfası
class Adim2Sayfasi extends StatefulWidget {
  const Adim2Sayfasi({super.key});

  @override
  State<Adim2Sayfasi> createState() => _Adim2SayfasiState();
}

class _Adim2SayfasiState extends State<Adim2Sayfasi> {
  final ImagePicker _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpertizProvider>(
      builder: (context, provider, child) {
        final model = provider.adim2Model;
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
            title: const Text('2️⃣ Dış Ekspertiz', style: TextStyle(color: YerimeBakColors.blue)),
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
                // 🚗 ÖN KAPORTA
                _buildSectionHeader('🚗 ÖN KAPORTA'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Ön Tampon',
                  seciliDurum: model.onTampon,
                  onDurumDegisti: (durum) {
                    provider.updateAdim2(model.copyWith(onTampon: durum));
                  },
                  not: aciklamalar['onTampon'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['onTampon'] = not;
                    provider.updateAdim2(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['onTampon'] ?? []).length,
                  fotografYolu: fotografYolu['onTampon'],
                  onFotografEkle: () => _onFotografEkle('onTampon', 'Ön Tampon'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Arka Tampon',
                  seciliDurum: model.arkaTampon,
                  onDurumDegisti: (durum) {
                    provider.updateAdim2(model.copyWith(arkaTampon: durum));
                  },
                  not: aciklamalar['arkaTampon'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['arkaTampon'] = not;
                    provider.updateAdim2(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['arkaTampon'] ?? []).length,
                  fotografYolu: fotografYolu['arkaTampon'],
                  onFotografEkle: () => _onFotografEkle('arkaTampon', 'Arka Tampon'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Ön Kapı',
                  seciliDurum: model.onKapi,
                  onDurumDegisti: (durum) {
                    provider.updateAdim2(model.copyWith(onKapi: durum));
                  },
                  not: aciklamalar['onKapi'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['onKapi'] = not;
                    provider.updateAdim2(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['onKapi'] ?? []).length,
                  fotografYolu: fotografYolu['onKapi'],
                  onFotografEkle: () => _onFotografEkle('onKapi', 'Ön Kapı'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Arka Kapı',
                  seciliDurum: model.arkaKapi,
                  onDurumDegisti: (durum) {
                    provider.updateAdim2(model.copyWith(arkaKapi: durum));
                  },
                  not: aciklamalar['arkaKapi'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['arkaKapi'] = not;
                    provider.updateAdim2(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['arkaKapi'] ?? []).length,
                  fotografYolu: fotografYolu['arkaKapi'],
                  onFotografEkle: () => _onFotografEkle('arkaKapi', 'Arka Kapı'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Kaput',
                  seciliDurum: model.onKaput,
                  onDurumDegisti: (durum) {
                    provider.updateAdim2(model.copyWith(onKaput: durum));
                  },
                  not: aciklamalar['onKaput'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['kaput'] = not;
                    provider.updateAdim2(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['kaput'] ?? []).length,
                  fotografYolu: fotografYolu['kaput'],
                  onFotografEkle: () => _onFotografEkle('kaput', 'Kaput'),
                ),
                 
                const SizedBox(height: 24),

                // 🚘 ŞASİ
                _buildSectionHeader('🚘 ŞASİ'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Ön Şasi',
                  seciliDurum: model.onSasi,
                  onDurumDegisti: (durum) {
                    provider.updateAdim2(model.copyWith(onSasi: durum));
                  },
                  not: aciklamalar['onSasi'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['onSasi'] = not;
                    provider.updateAdim2(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['onSasi'] ?? []).length,
                  fotografYolu: fotografYolu['onSasi'],
                  onFotografEkle: () => _onFotografEkle('onSasi', 'Ön Şasi'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Arka Şasi',
                  seciliDurum: model.arkaSasi,
                  onDurumDegisti: (durum) {
                    provider.updateAdim2(model.copyWith(arkaSasi: durum));
                  },
                  not: aciklamalar['arkaSasi'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['arkaSasi'] = not;
                    provider.updateAdim2(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['arkaSasi'] ?? []).length,
                  fotografYolu: fotografYolu['arkaSasi'],
                  onFotografEkle: () => _onFotografEkle('arkaSasi', 'Arka Şasi'),
                ),
                 
                const SizedBox(height: 24),

                // 🚗 KAPORTA
                _buildSectionHeader('🚗 KAPORTA'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Ön Çamurlar',
                  seciliDurum: model.onCamurlar,
                  onDurumDegisti: (durum) {
                    provider.updateAdim2(model.copyWith(onCamurlar: durum));
                  },
                  not: aciklamalar['onCamurlar'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['onCamurlar'] = not;
                    provider.updateAdim2(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['onCamurlar'] ?? []).length,
                  fotografYolu: fotografYolu['onCamurlar'],
                  onFotografEkle: () => _onFotografEkle('onCamurlar', 'Ön Çamurlar'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Arka Çamurlar',
                  seciliDurum: model.arkaCamurlar,
                  onDurumDegisti: (durum) {
                    provider.updateAdim2(model.copyWith(arkaCamurlar: durum));
                  },
                  not: aciklamalar['arkaCamurlar'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['arkaCamurlar'] = not;
                    provider.updateAdim2(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['arkaCamurlar'] ?? []).length,
                  fotografYolu: fotografYolu['arkaCamurlar'],
                  onFotografEkle: () => _onFotografEkle('arkaCamurlar', 'Arka Çamurlar'),
                ),
                 
                const SizedBox(height: 24),

                // 🚙 TENTE
                _buildSectionHeader('🚙 TENTE'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Tavan Tente',
                  seciliDurum: model.tavanTente,
                  onDurumDegisti: (durum) {
                    provider.updateAdim2(model.copyWith(tavanTente: durum));
                  },
                  not: aciklamalar['tavanTente'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['tavanTente'] = not;
                    provider.updateAdim2(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['tavanTente'] ?? []).length,
                  fotografYolu: fotografYolu['tavanTente'],
                  onFotografEkle: () => _onFotografEkle('tavanTente', 'Tavan Tente'),
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
                    hintText: 'Dış ekspertiz hakkında notlarınız...',
                  ),
                  onChanged: (value) {
                    provider.updateAdim2(model.copyWith(genelNot: value));
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
        final model = provider.adim2Model;
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

        provider.updateAdim2(model.copyWith(
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
