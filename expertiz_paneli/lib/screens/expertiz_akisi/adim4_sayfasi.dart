import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/expertiz_provider.dart';
import '../../models/expertiz/adim4_boya_kaporta_model.dart';
import '../../core/constants/yerimebak_colors.dart';
import 'widgets/tablo_satiri_widget.dart';

/// Adım 4: Boya / Kaporta Sayfası
class Adim4Sayfasi extends StatefulWidget {
  const Adim4Sayfasi({super.key});

  @override
  State<Adim4Sayfasi> createState() => _Adim4SayfasiState();
}

class _Adim4SayfasiState extends State<Adim4Sayfasi> {
  final ImagePicker _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpertizProvider>(
      builder: (context, provider, child) {
        final model = provider.adim4Model;
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
            title: const Text('4️⃣ Boya / Kaporta', style: TextStyle(color: YerimeBakColors.blue)),
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
                // 🎨 BOYA
                _buildSectionHeader('🎨 BOYA'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Ön Kapı Boya',
                  seciliDurum: model.onKapiBoya,
                  onDurumDegisti: (durum) {
                    provider.updateAdim4(model.copyWith(onKapiBoya: durum));
                  },
                  not: aciklamalar['onKapiBoya'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['onKapiBoya'] = not;
                    provider.updateAdim4(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['onKapiBoya'] ?? []).length,
                  fotografYolu: fotografYolu['onKapiBoya'],
                  onFotografEkle: () => _onFotografEkle('onKapiBoya', 'Ön Kapı Boya'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Arka Kapı Boya',
                  seciliDurum: model.arkaKapiBoya,
                  onDurumDegisti: (durum) {
                    provider.updateAdim4(model.copyWith(arkaKapiBoya: durum));
                  },
                  not: aciklamalar['arkaKapiBoya'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['arkaKapiBoya'] = not;
                    provider.updateAdim4(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['arkaKapiBoya'] ?? []).length,
                  fotografYolu: fotografYolu['arkaKapiBoya'],
                  onFotografEkle: () => _onFotografEkle('arkaKapiBoya', 'Arka Kapı Boya'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Kaput Boya',
                  seciliDurum: model.kaputBoya,
                  onDurumDegisti: (durum) {
                    provider.updateAdim4(model.copyWith(kaputBoya: durum));
                  },
                  not: aciklamalar['kaputBoya'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['kaputBoya'] = not;
                    provider.updateAdim4(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['kaputBoya'] ?? []).length,
                  fotografYolu: fotografYolu['kaputBoya'],
                  onFotografEkle: () => _onFotografEkle('kaputBoya', 'Kaput Boya'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Tampon Boya',
                  seciliDurum: model.tamponBoya,
                  onDurumDegisti: (durum) {
                    provider.updateAdim4(model.copyWith(tamponBoya: durum));
                  },
                  not: aciklamalar['tamponBoya'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['tamponBoya'] = not;
                    provider.updateAdim4(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['tamponBoya'] ?? []).length,
                  fotografYolu: fotografYolu['tamponBoya'],
                  onFotografEkle: () => _onFotografEkle('tamponBoya', 'Tampon Boya'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Tavan Boya',
                  seciliDurum: model.tavanBoya,
                  onDurumDegisti: (durum) {
                    provider.updateAdim4(model.copyWith(tavanBoya: durum));
                  },
                  not: aciklamalar['tavanBoya'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['tavanBoya'] = not;
                    provider.updateAdim4(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['tavanBoya'] ?? []).length,
                  fotografYolu: fotografYolu['tavanBoya'],
                  onFotografEkle: () => _onFotografEkle('tavanBoya', 'Tavan Boya'),
                ),
                 
                const SizedBox(height: 24),

                // 🔩 KAPORTA
                _buildSectionHeader('🔩 KAPORTA'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Ön Kapı Kaporta',
                  seciliDurum: model.onKapiKaporta,
                  onDurumDegisti: (durum) {
                    provider.updateAdim4(model.copyWith(onKapiKaporta: durum));
                  },
                  not: aciklamalar['onKapiKaporta'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['onKapiKaporta'] = not;
                    provider.updateAdim4(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['onKapiKaporta'] ?? []).length,
                  fotografYolu: fotografYolu['onKapiKaporta'],
                  onFotografEkle: () => _onFotografEkle('onKapiKaporta', 'Ön Kapı Kaporta'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Arka Kapı Kaporta',
                  seciliDurum: model.arkaKapiKaporta,
                  onDurumDegisti: (durum) {
                    provider.updateAdim4(model.copyWith(arkaKapiKaporta: durum));
                  },
                  not: aciklamalar['arkaKapiKaporta'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['arkaKapiKaporta'] = not;
                    provider.updateAdim4(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['arkaKapiKaporta'] ?? []).length,
                  fotografYolu: fotografYolu['arkaKapiKaporta'],
                  onFotografEkle: () => _onFotografEkle('arkaKapiKaporta', 'Arka Kapı Kaporta'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Kaput Kaporta',
                  seciliDurum: model.kaputKaporta,
                  onDurumDegisti: (durum) {
                    provider.updateAdim4(model.copyWith(kaputKaporta: durum));
                  },
                  not: aciklamalar['kaputKaporta'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['kaputKaporta'] = not;
                    provider.updateAdim4(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['kaputKaporta'] ?? []).length,
                  fotografYolu: fotografYolu['kaputKaporta'],
                  onFotografEkle: () => _onFotografEkle('kaputKaporta', 'Kaput Kaporta'),
                ),
                 
                const SizedBox(height: 24),

                // 🚗 ŞASİ VE DİREKLER
                _buildSectionHeader('🚗 ŞASİ VE DİREKLER'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Ön Şasi',
                  seciliDurum: model.onSasi,
                  onDurumDegisti: (durum) {
                    provider.updateAdim4(model.copyWith(onSasi: durum));
                  },
                  not: aciklamalar['onSasi'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['onSasi'] = not;
                    provider.updateAdim4(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['onSasi'] ?? []).length,
                  fotografYolu: fotografYolu['onSasi'],
                  onFotografEkle: () => _onFotografEkle('onSasi', 'Ön Şasi'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Arka Şasi',
                  seciliDurum: model.arkaSasi,
                  onDurumDegisti: (durum) {
                    provider.updateAdim4(model.copyWith(arkaSasi: durum));
                  },
                  not: aciklamalar['arkaSasi'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['arkaSasi'] = not;
                    provider.updateAdim4(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['arkaSasi'] ?? []).length,
                  fotografYolu: fotografYolu['arkaSasi'],
                  onFotografEkle: () => _onFotografEkle('arkaSasi', 'Arka Şasi'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Ön Direkler',
                  seciliDurum: model.onDirekler,
                  onDurumDegisti: (durum) {
                    provider.updateAdim4(model.copyWith(onDirekler: durum));
                  },
                  not: aciklamalar['onDirekler'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['onDirekler'] = not;
                    provider.updateAdim4(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['onDirekler'] ?? []).length,
                  fotografYolu: fotografYolu['onDirekler'],
                  onFotografEkle: () => _onFotografEkle('onDirekler', 'Ön Direkler'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Arka Direkler',
                  seciliDurum: model.arkaDirekler,
                  onDurumDegisti: (durum) {
                    provider.updateAdim4(model.copyWith(arkaDirekler: durum));
                  },
                  not: aciklamalar['arkaDirekler'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['arkaDirekler'] = not;
                    provider.updateAdim4(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['arkaDirekler'] ?? []).length,
                  fotografYolu: fotografYolu['arkaDirekler'],
                  onFotografEkle: () => _onFotografEkle('arkaDirekler', 'Arka Direkler'),
                ),
                 
                const SizedBox(height: 24),

                // 🎯 EKSTRA KAPORTA PARÇALARI
                _buildSectionHeader('🎯 EKSTRA KAPORTA PARÇALARI'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Podye',
                  seciliDurum: model.podye,
                  onDurumDegisti: (durum) {
                    provider.updateAdim4(model.copyWith(podye: durum));
                  },
                  not: aciklamalar['podye'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['podye'] = not;
                    provider.updateAdim4(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['podye'] ?? []).length,
                  fotografYolu: fotografYolu['podye'],
                  onFotografEkle: () => _onFotografEkle('podye', 'Podye'),
                ),
                 
                TabloSatiriWidget(
                  maddeAdi: 'Marsbiyel',
                  seciliDurum: model.marsbiyel,
                  onDurumDegisti: (durum) {
                    provider.updateAdim4(model.copyWith(marsbiyel: durum));
                  },
                  not: aciklamalar['marsbiyel'] ?? '',
                  onNotDegisti: (not) {
                    final yeniAciklamalar = Map<String, String>.from(aciklamalar);
                    yeniAciklamalar['marsbiyel'] = not;
                    provider.updateAdim4(model.copyWith(aciklamalar: yeniAciklamalar));
                  },
                  fotografSayisi: (fotografUrl['marsbiyel'] ?? []).length,
                  fotografYolu: fotografYolu['marsbiyel'],
                  onFotografEkle: () => _onFotografEkle('marsbiyel', 'Marsbiyel'),
                ),
                 
                const SizedBox(height: 24),

                // ⚠️ HASAR KAYITLARI
                _buildSectionHeader('⚠️ HASAR KAYITLARI (${model.hasarSayisi})'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                if (model.hasarKayitlari.isEmpty)
                  Card(
                    color: YerimeBakColors.lightGray,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'Henüz hasar kaydı yok',
                          style: TextStyle(color: YerimeBakColors.darkGray),
                        ),
                      ),
                    ),
                  )
                else
                  ...model.hasarKayitlari.asMap().entries.map((entry) {
                    final index = entry.key;
                    final hasar = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Hasar #${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: YerimeBakColors.blue,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: YerimeBakColors.red),
                                  onPressed: () {
                                    provider.updateAdim4(model.hasarSil(hasar.id));
                                  },
                                  tooltip: 'Hasarı Sil',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(text: hasar.konum),
                                    decoration: const InputDecoration(
                                      labelText: 'Konum',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      final yeniHasar = hasar.copyWith(konum: value);
                                      provider.updateAdim4(model.hasarGuncelle(hasar.id, yeniHasar));
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: hasar.tip,
                                    decoration: const InputDecoration(
                                      labelText: 'Tip',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: Adim4BoyaKaportaModel.hasarTipleri
                                        .map((tip) => DropdownMenuItem(
                                              value: tip,
                                              child: Text(tip),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        final yeniHasar = hasar.copyWith(tip: value);
                                        provider.updateAdim4(model.hasarGuncelle(hasar.id, yeniHasar));
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: hasar.buyukluk,
                                    decoration: const InputDecoration(
                                      labelText: 'Büyüklük',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: Adim4BoyaKaportaModel.hasarBuyuklukleri
                                        .map((buyukluk) => DropdownMenuItem(
                                              value: buyukluk,
                                              child: Text(buyukluk),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        final yeniHasar = hasar.copyWith(buyukluk: value);
                                        provider.updateAdim4(model.hasarGuncelle(hasar.id, yeniHasar));
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: TextEditingController(text: hasar.not ?? ''),
                              decoration: const InputDecoration(
                                labelText: 'Not',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                final yeniHasar = hasar.copyWith(not: value);
                                provider.updateAdim4(model.hasarGuncelle(hasar.id, yeniHasar));
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _onHasarFotografEkle(hasar.id);
                                  },
                                  icon: const Icon(Icons.camera_alt),
                                  label: Text('Fotoğraf Ekle (${(hasar.fotografUrl != null && hasar.fotografUrl!.isNotEmpty) ? 1 : 0})'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: YerimeBakColors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                 
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _onHasarEkle(context, provider, model),
                  icon: const Icon(Icons.add),
                  label: const Text('Hasar Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: YerimeBakColors.red,
                    foregroundColor: Colors.white,
                  ),
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
                    hintText: 'Boya/Kaporta hakkında notlarınız...',
                  ),
                  onChanged: (value) {
                    provider.updateAdim4(model.copyWith(genelNot: value));
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
        final model = provider.adim4Model;
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

        provider.updateAdim4(model.copyWith(
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

  void _onHasarFotografEkle(String hasarId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hasar #$hasarId için fotoğraf ekleme özelliği geliştiriliyor...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onHasarEkle(BuildContext context, ExpertizProvider provider, dynamic model) {
    String konum = '';
    String tip = Adim4BoyaKaportaModel.hasarTipleri.first;
    String buyukluk = Adim4BoyaKaportaModel.hasarBuyuklukleri.first;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hasar Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Konum',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => konum = value,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Tip',
                border: OutlineInputBorder(),
              ),
              initialValue: tip,
              items: Adim4BoyaKaportaModel.hasarTipleri
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) tip = value;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Büyüklük',
                border: OutlineInputBorder(),
              ),
              initialValue: buyukluk,
              items: Adim4BoyaKaportaModel.hasarBuyuklukleri
                  .map((b) => DropdownMenuItem(
                        value: b,
                        child: Text(b),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) buyukluk = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (konum.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Konum alanı zorunludur'),
                    backgroundColor: YerimeBakColors.red,
                  ),
                );
                return;
              }
               
              final yeniHasar = HasarKaydi(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                konum: konum,
                tip: tip,
                buyukluk: buyukluk,
              );
               
              provider.updateAdim4(model.hasarEkle(yeniHasar));
              Navigator.pop(context);
               
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hasar başarıyla eklendi'),
                  backgroundColor: YerimeBakColors.green,
                ),
              );
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

}
