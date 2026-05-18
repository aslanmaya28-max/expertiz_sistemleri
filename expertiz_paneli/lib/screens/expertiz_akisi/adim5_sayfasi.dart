import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/expertiz_provider.dart';
import '../../core/constants/yerimebak_colors.dart';
import 'widgets/dosya_yukleme_widget.dart';
import 'widgets/tablo_satiri_widget.dart';

/// Adım 5: Kurumsal Ekspertiz Sayfası
class Adim5Sayfasi extends StatefulWidget {
  const Adim5Sayfasi({super.key});

  @override
  State<Adim5Sayfasi> createState() => _Adim5SayfasiState();
}

class _Adim5SayfasiState extends State<Adim5Sayfasi> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ExpertizProvider>(
      builder: (context, provider, child) {
        final model = provider.adim5Model;
        if (model == null) {
          return const Center(
            child: Text('Model yükleniyor...'),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('5️⃣ Kurumsal Ekspertiz', style: TextStyle(color: YerimeBakColors.blue)),
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
                // 📁 DOSYA KONTROLÜ
                _buildSectionHeader('📁 DOSYA KONTROLÜ (${model.dosyaSayisi}/${model.totalDosyaSayisi})'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                DosyaYuklemeWidget(
                  baslik: 'Ruhsat Dosyası',
                  dosyaTipi: 'PDF / Görsel',
                  dosyaSayisi: model.ruhsatFotograflari.length,
                  onDosyaEkle: () => _onDosyaEkle('ruhsat', 'Ruhsat Dosyası'),
                  yuklenenDosyalar: model.ruhsatFotograflari,
                  onDosyaSil: (index) {
                    final yeniListe = List<String>.from(model.ruhsatFotograflari);
                    yeniListe.removeAt(index);
                    provider.updateAdim5(model.copyWith(ruhsatFotograflari: yeniListe));
                  },
                ),
                 
                DosyaYuklemeWidget(
                  baslik: 'Bakım Defteri',
                  dosyaTipi: 'PDF / Görsel',
                  dosyaSayisi: model.bakimDefteriFotograflari.length,
                  onDosyaEkle: () => _onDosyaEkle('bakim', 'Bakım Defteri'),
                  yuklenenDosyalar: model.bakimDefteriFotograflari,
                  onDosyaSil: (index) {
                    final yeniListe = List<String>.from(model.bakimDefteriFotograflari);
                    yeniListe.removeAt(index);
                    provider.updateAdim5(model.copyWith(bakimDefteriFotograflari: yeniListe));
                  },
                ),
                 
                DosyaYuklemeWidget(
                  baslik: 'Sigorta Poliçesi',
                  dosyaTipi: 'PDF / Görsel',
                  dosyaSayisi: model.sigortaFotograflari.length,
                  onDosyaEkle: () => _onDosyaEkle('sigorta', 'Sigorta Poliçesi'),
                  yuklenenDosyalar: model.sigortaFotograflari,
                  onDosyaSil: (index) {
                    final yeniListe = List<String>.from(model.sigortaFotograflari);
                    yeniListe.removeAt(index);
                    provider.updateAdim5(model.copyWith(sigortaFotograflari: yeniListe));
                  },
                ),
                 
                DosyaYuklemeWidget(
                  baslik: 'Muayene Belgesi',
                  dosyaTipi: 'PDF / Görsel',
                  dosyaSayisi: model.muayeneFotograflari.length,
                  onDosyaEkle: () => _onDosyaEkle('muayene', 'Muayene Belgesi'),
                  yuklenenDosyalar: model.muayeneFotograflari,
                  onDosyaSil: (index) {
                    final yeniListe = List<String>.from(model.muayeneFotograflari);
                    yeniListe.removeAt(index);
                    provider.updateAdim5(model.copyWith(muayeneFotograflari: yeniListe));
                  },
                ),
                 
                const SizedBox(height: 24),

                // ⚙️ MEKANİK DURUM (DİNAMİK)
                _buildSectionHeader('⚙️ MEKANİK DURUM'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                   
                // Elektrikli araçlar için özel alanlar
                if (model.yakitTipi == 'Elektrikli') ...[
                  _buildElektrikliAlanlar(provider, model),
                ] else ...[
                  // Dizel/Benzin için klasik mekanik alanlar
                  TabloSatiriWidget(
                    maddeAdi: 'Motor',
                    seciliDurum: model.motorDurumu,
                    onDurumDegisti: (durum) {
                      provider.updateAdim5(model.copyWith(motorDurumu: durum));
                    },
                    not: '',
                    onNotDegisti: (_) {},
                    fotografSayisi: 0,
                    onFotografEkle: () {},
                  ),
                     
                  TabloSatiriWidget(
                    maddeAdi: 'Şanzıman',
                    seciliDurum: model.sanzimanDurumu,
                    onDurumDegisti: (durum) {
                      provider.updateAdim5(model.copyWith(sanzimanDurumu: durum));
                    },
                    not: '',
                    onNotDegisti: (_) {},
                    fotografSayisi: 0,
                    onFotografEkle: () {},
                  ),
                ],
                   
                TabloSatiriWidget(
                  maddeAdi: 'Fren Sistemi',
                  seciliDurum: model.frenSistemi,
                  onDurumDegisti: (durum) {
                    provider.updateAdim5(model.copyWith(frenSistemi: durum));
                  },
                  not: '',
                  onNotDegisti: (_) {},
                  fotografSayisi: 0,
                  onFotografEkle: () {},
                ),
                   
                TabloSatiriWidget(
                  maddeAdi: 'Direksiyon Sistemi',
                  seciliDurum: model.direksiyonSistemi,
                  onDurumDegisti: (durum) {
                    provider.updateAdim5(model.copyWith(direksiyonSistemi: durum));
                  },
                  not: '',
                  onNotDegisti: (_) {},
                  fotografSayisi: 0,
                  onFotografEkle: () {},
                ),
                   
                TabloSatiriWidget(
                  maddeAdi: 'Elektrik Sistemi',
                  seciliDurum: model.elektrikSistemi,
                  onDurumDegisti: (durum) {
                    provider.updateAdim5(model.copyWith(elektrikSistemi: durum));
                  },
                  not: '',
                  onNotDegisti: (_) {},
                  fotografSayisi: 0,
                  onFotografEkle: () {},
                ),
                   
                const SizedBox(height: 24),

                // 🎯 OPSİYON/DONANIM (MarketRadarService ile uyumlu)
                _buildSectionHeader('🎯 OPSİYON/DONANIM'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                _buildOpsiyonSecimi(provider, model),
                const SizedBox(height: 24),

                // 📊 DEĞERLENDİRME
                _buildSectionHeader('📊 DEĞERLENDİRME'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                TextField(
                  controller: TextEditingController(text: model.genelPuan?.toString() ?? ''),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Genel Puan (0-100)',
                    border: OutlineInputBorder(),
                    hintText: '0 ile 100 arası puan girin',
                  ),
                  onChanged: (value) {
                    final puan = double.tryParse(value);
                    if (puan != null && puan >= 0 && puan <= 100) {
                      provider.updateAdim5(model.copyWith(genelPuan: puan));
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (model.genelPuan != null)
                  Card(
                    color: _getPuanColor(model.genelPuan!),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          '${model.genelPuan!.toStringAsFixed(1)} - ${model.puanDegerlendirmesi}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // 📝 NOTLAR
                _buildSectionHeader('📝 NOTLAR'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                TextField(
                  controller: TextEditingController(text: model.ozetNot ?? ''),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Özet Not',
                    border: OutlineInputBorder(),
                    hintText: 'Genel değerlendirme özeti...',
                  ),
                  onChanged: (value) {
                    provider.updateAdim5(model.copyWith(ozetNot: value));
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: TextEditingController(text: model.oneriler ?? ''),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Öneriler',
                    border: OutlineInputBorder(),
                    hintText: 'İyileştirme önerileri...',
                  ),
                  onChanged: (value) {
                    provider.updateAdim5(model.copyWith(oneriler: value));
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: TextEditingController(text: model.genelNot ?? ''),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Genel Notlar',
                    border: OutlineInputBorder(),
                    hintText: 'Kurumsal ekspertiz hakkında notlarınız...',
                  ),
                  onChanged: (value) {
                    provider.updateAdim5(model.copyWith(genelNot: value));
                  },
                ),
                 
                const SizedBox(height: 24),

                // 📷 FOTOĞRAFLAR
                _buildSectionHeader('📷 FOTOĞRAFLAR (${model.fotografUrlleri.length})'),
                const Divider(thickness: 1, color: YerimeBakColors.blue),
                const SizedBox(height: 12),
                 
                _buildPhotoGrid(model.fotografUrlleri),
                 
                const SizedBox(height: 24),

                // Rapor gonderimi ana ExpertizBaslatSayfasi alt barindaki
                // tek resmi "Bitir ve Gonder" aksiyonundan yapilir.
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

  Color _getPuanColor(double puan) {
    if (puan >= 90) return YerimeBakColors.green;
    if (puan >= 80) return YerimeBakColors.green;
    if (puan >= 70) return YerimeBakColors.orange;
    if (puan >= 60) return YerimeBakColors.orange;
    if (puan >= 50) return YerimeBakColors.orange;
    return YerimeBakColors.red;
  }

  Widget _buildPhotoGrid(List<String> photos) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: photos.length + 1,
      itemBuilder: (context, index) {
        if (index == photos.length) {
          return GestureDetector(
            onTap: () {
              // Fotoğraf ekleme işlevi
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fotoğraf ekleme özelliği geliştiriliyor...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                  color: YerimeBakColors.lightGray,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: YerimeBakColors.blue, width: 2),
              ),
              child: Center(
                child: Icon(
                    Icons.add_photo_alternate,
                    size: 32,
                    color: YerimeBakColors.blue,
                  ),
              ),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: YerimeBakColors.blue),
            image: DecorationImage(
              image: NetworkImage(photos[index]),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  void _onDosyaEkle(String dosyaTipi, String dosyaAdi) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$dosyaAdi yükleniyor...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildElektrikliAlanlar(ExpertizProvider provider, dynamic model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Batarya Sağlığı
        TextField(
          controller: TextEditingController(text: model.bataryaSagligi?.toString() ?? ''),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Batarya Sağlığı (SoH %)',
            border: OutlineInputBorder(),
            suffixText: '%',
            prefixIcon: const Icon(Icons.battery_charging_full),
          ),
          onChanged: (value) {
            final soh = double.tryParse(value);
            if (soh != null && soh >= 0 && soh <= 100) {
              provider.updateAdim5(model.copyWith(bataryaSagligi: soh));
            }
          },
        ),
        const SizedBox(height: 12),
        
        // Tahmini Menzil
        TextField(
          controller: TextEditingController(text: model.tahminiMenzil ?? ''),
          decoration: const InputDecoration(
            labelText: 'Tahmini Menzil',
            border: OutlineInputBorder(),
            suffixText: 'km',
            prefixIcon: Icon(Icons.route),
          ),
          onChanged: (value) {
            provider.updateAdim5(model.copyWith(tahminiMenzil: value));
          },
        ),
        const SizedBox(height: 12),
        
        // Şarj Portu Kondisyonu
        DropdownButtonFormField<String>(
          initialValue: model.sarjPortuKondisyonu,
          decoration: const InputDecoration(
            labelText: 'Şarj Portu Kondisyonu',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.ev_station),
          ),
          items: const [
            DropdownMenuItem(value: 'Mükemmel', child: Text('Mükemmel')),
            DropdownMenuItem(value: 'İyi', child: Text('İyi')),
            DropdownMenuItem(value: 'Orta', child: Text('Orta')),
            DropdownMenuItem(value: 'Kötü', child: Text('Kötü')),
            DropdownMenuItem(value: 'Çok Kötü', child: Text('Çok Kötü')),
          ],
          onChanged: (value) {
            if (value != null) {
              provider.updateAdim5(model.copyWith(sarjPortuKondisyonu: value));
            }
          },
        ),
        const SizedBox(height: 12),
        
        // Yazılım Sürümü
        TextField(
          controller: TextEditingController(text: model.yazilimSurumu ?? ''),
          decoration: const InputDecoration(
            labelText: 'Yazılım Sürümü',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.code),
          ),
          onChanged: (value) {
            provider.updateAdim5(model.copyWith(yazilimSurumu: value));
          },
        ),
      ],
    );
  }

  Widget _buildOpsiyonSecimi(ExpertizProvider provider, dynamic model) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    // MarketRadarService ile uyumlu opsiyon listesi
    final opsiyonlar = [
      'Cam Tavan',
      'Sunroof',
      'Panoramik Tavan',
      'Matrix Far',
      'LED Far',
      'Laser Far',
      'Adaptif Far',
      'Vakumlu Kapı',
      'Head-up Display',
      'Navigasyon',
      'Deri Koltuk',
      'Elektrikli Koltuk',
      'Isıtmalı Koltuk',
      'Ventilasyonlu Koltuk',
      'Xenon Far',
      'Bi-Xenon Far',
      'Park Sensörü',
      'Geri Görüş Kamerası',
      'Bluetooth',
      'USB',
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aracın donanım ve opsiyonlarını seçin:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: opsiyonlar.map((opsiyon) {
            final isSelected = (model.ekstraOpsiyonlar ?? []).contains(opsiyon);
            return FilterChip(
              label: Text(opsiyon),
              selected: isSelected,
              onSelected: (selected) {
                final mevcutOpsiyonlar = List<String>.from(model.ekstraOpsiyonlar ?? []);
                if (selected) {
                  if (!mevcutOpsiyonlar.contains(opsiyon)) {
                    mevcutOpsiyonlar.add(opsiyon);
                  }
                } else {
                  mevcutOpsiyonlar.remove(opsiyon);
                }
                provider.updateAdim5(model.copyWith(ekstraOpsiyonlar: mevcutOpsiyonlar));
              },
              selectedColor: YerimeBakColors.blue,
              checkmarkColor: Colors.white,
              backgroundColor: isSelected
                  ? YerimeBakColors.blue
                  : (isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB)),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDarkMode ? Colors.white : const Color(0xFF1A1A1A)),
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: YerimeBakColors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: YerimeBakColors.blue, width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: YerimeBakColors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Seçilen opsiyonlar MarketRadarService ile otomatik fiyat hesaplaması için kullanılacaktır.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}
