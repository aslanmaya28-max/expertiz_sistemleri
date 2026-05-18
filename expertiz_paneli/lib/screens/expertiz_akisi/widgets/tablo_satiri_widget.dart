import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/yerimebak_colors.dart';

/// Tablo Satırı Widget'ı
/// Her madde için yatay tablo düzeni sağlar
class TabloSatiriWidget extends StatelessWidget {
  /// Madde başlığı
  final String maddeAdi;
  
  /// Seçili durum (String olarak)
  final String? seciliDurum;
  
  /// Durum değiştiğinde çağrılır
  final Function(String?) onDurumDegisti;
  
  /// Not metni
  final String not;
  
  /// Not değiştiğinde çağrılır
  final Function(String) onNotDegisti;
  
  /// Fotoğraf sayısı
  final int fotografSayisi;
  
  /// Fotoğraf ekle butonuna tıklandığında çağrılır
  final VoidCallback onFotografEkle;
  
  /// Fotoğraf yolu (thumbnail gösterimi için)
  final String? fotografYolu;
  
  /// İdeal açı rehberi gösterilsin mi?
  final bool idealAciGosterilsin;
  
  /// Durum seçimi gösterilsin mi? (Adım 1'de Pazarlık Miktarı için false olabilir)
  final bool durumGosterilsin;
  
  /// Pazarlık miktarı girişi mi? (Adım 1 için özel durum)
  final bool pazarlikMiktariGirisi;
  
  /// Pazarlık miktarı
  final double? pazarlikMiktari;
  
  /// Pazarlık miktarı değiştiğinde çağrılır
  final Function(double?)? onPazarlikMiktariDegisti;

  const TabloSatiriWidget({
    super.key,
    required this.maddeAdi,
    required this.seciliDurum,
    required this.onDurumDegisti,
    required this.not,
    required this.onNotDegisti,
    required this.fotografSayisi,
    required this.onFotografEkle,
    this.fotografYolu,
    this.idealAciGosterilsin = true,
    this.durumGosterilsin = true,
    this.pazarlikMiktariGirisi = false,
    this.pazarlikMiktari,
    this.onPazarlikMiktariDegisti,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: YerimeBakColors.blue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Madde Başlığı (flex: 2)
            Expanded(
              flex: 2,
              child: Text(
                maddeAdi,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: YerimeBakColors.darkGray,
                ),
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
            ),
            const SizedBox(width: 12),
             
            // Durum Seçimi veya Pazarlık Miktarı (flex: 2)
            if (pazarlikMiktariGirisi) ...[
              Expanded(
                flex: 2,
                child: TextField(
                  controller: TextEditingController(text: pazarlikMiktari?.toString()),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Pazarlık Miktarı (TL)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    prefixText: '₺ ',
                    filled: true,
                    fillColor: YerimeBakColors.lightGray,
                  ),
                  onChanged: (value) {
                    final miktar = double.tryParse(value);
                    if (onPazarlikMiktariDegisti != null) {
                      onPazarlikMiktariDegisti!(miktar);
                    }
                  },
                ),
              ),
            ] else if (durumGosterilsin) ...[
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: seciliDurum,
                  decoration: InputDecoration(
                    labelText: 'Durum',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: YerimeBakColors.lightGray,
                  ),
                  items: _getDurumSecenekleri(),
                  onChanged: onDurumDegisti,
                ),
              ),
            ] else ...[
              // Durum gösterilmeyecekse boş alan
              const Expanded(flex: 2, child: SizedBox()),
            ],
            const SizedBox(width: 12),
             
            // Not/Açıklama (flex: 3)
            Expanded(
              flex: 3,
              child: TextField(
                controller: TextEditingController(text: not),
                textAlign: TextAlign.left,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Not',
                  hintText: 'Not ekleyin...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: YerimeBakColors.lightGray,
                ),
                onChanged: onNotDegisti,
              ),
            ),
            const SizedBox(width: 12),
             
            // Fotoğraf Ekle Kutucuğu ve İdeal Açı Rehberi
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Şık Fotoğraf Ekle Kutucuğu (80x80)
                GestureDetector(
                  onTap: onFotografEkle,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: YerimeBakColors.lightGray,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: fotografSayisi > 0 ? YerimeBakColors.green : YerimeBakColors.blue,
                        width: fotografSayisi > 0 ? 2 : 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (fotografYolu != null && fotografYolu!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(
                              File(fotografYolu!),
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 32,
                                  color: YerimeBakColors.blue.withValues(alpha: 0.7),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Fotoğraf Ekle',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: YerimeBakColors.blue.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        if (fotografSayisi > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: YerimeBakColors.orange,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Text(
                                '$fotografSayisi',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // İdeal Açı Rehberi
                if (idealAciGosterilsin) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: YerimeBakColors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: YerimeBakColors.blue.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 12,
                          color: YerimeBakColors.blue,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _getIdealAciRehberi(maddeAdi),
                            style: const TextStyle(
                              fontSize: 9,
                              color: YerimeBakColors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// İdeal açı rehberi metni
  String _getIdealAciRehberi(String maddeAdi) {
    final lowerMadde = maddeAdi.toLowerCase();
    
    // Ön Tampon
    if (lowerMadde.contains('ön tampon')) {
      return 'Araca 45° açıyla sağ önden bakın';
    }
    // Arka Tampon
    if (lowerMadde.contains('arka tampon')) {
      return 'Araca 45° açıyla sağ arkadan bakın';
    }
    // Kaput
    if (lowerMadde.contains('kaput')) {
      return 'Araca 90° açıyla tam önden bakın';
    }
    // Kapılar
    if (lowerMadde.contains('kapı') || lowerMadde.contains('kapi')) {
      if (lowerMadde.contains('sol')) {
        return 'Araca 90° açıyla soldan bakın';
      }
      if (lowerMadde.contains('sağ')) {
        return 'Araca 90° açıyla sağdan bakın';
      }
      return 'Araca 90° açıyla yandan bakın';
    }
    // Çamurluklar
    if (lowerMadde.contains('çamurluk') || lowerMadde.contains('camurluk')) {
      if (lowerMadde.contains('ön sol')) {
        return 'Araca 45° açıyla ön sol köşeden bakın';
      }
      if (lowerMadde.contains('ön sağ')) {
        return 'Araca 45° açıyla ön sağ köşeden bakın';
      }
      if (lowerMadde.contains('arka sol')) {
        return 'Araca 45° açıyla arka sol köşeden bakın';
      }
      if (lowerMadde.contains('arka sağ')) {
        return 'Araca 45° açıyla arka sağ köşeden bakın';
      }
      return 'Araca 45° açıyla köşeden bakın';
    }
    // Tavan
    if (lowerMadde.contains('tavan')) {
      return 'Araca 90° açıyla yukarıdan bakın';
    }
    // Bagaj Kapağı
    if (lowerMadde.contains('bagaj') || lowerMadde.contains('bağaj')) {
      return 'Araca 90° açıyla tam arkadan bakın';
    }
    // Farlar
    if (lowerMadde.contains('far')) {
      if (lowerMadde.contains('sol')) {
        return 'Farın önünden düz açıyla çekin';
      }
      if (lowerMadde.contains('sağ')) {
        return 'Farın önünden düz açıyla çekin';
      }
      return 'Farların önünden düz açıyla çekin';
    }
    // Silecekler
    if (lowerMadde.contains('silecek')) {
      return 'Ön camdan yukarıdan bakın';
    }
    // Ayna
    if (lowerMadde.contains('ayna')) {
      return 'Aynanın yanından çekin';
    }
    // Jantlar
    if (lowerMadde.contains('jant') || lowerMadde.contains('tekerlek')) {
      return 'Jantın yanından 90° açıyla çekin';
    }
    // Lastikler
    if (lowerMadde.contains('lastik')) {
      return 'Lastiğin yanından 90° açıyla çekin';
    }
    // Motor
    if (lowerMadde.contains('motor')) {
      return 'Motor kaputundan yukarıdan bakın';
    }
    // Şanzıman
    if (lowerMadde.contains('şanzıman') || lowerMadde.contains('sanziman')) {
      return 'Şanzıman bölgesinden yandan çekin';
    }
    // Fren Sistemi
    if (lowerMadde.contains('fren')) {
      return 'Fren disklerinin yanından çekin';
    }
    // Direksiyon
    if (lowerMadde.contains('direksiyon')) {
      return 'Direksiyondan içeriden çekin';
    }
    // Elektrik Sistemi
    if (lowerMadde.contains('elektrik') || lowerMadde.contains('akü')) {
      return 'Akü bölgesinden yakın çekim yapın';
    }
    // Koltuklar
    if (lowerMadde.contains('koltuk')) {
      return 'Koltuktan içeriden çekin';
    }
    // Gösterge Paneli
    if (lowerMadde.contains('gösterge') || lowerMadde.contains('panel')) {
      return 'Gösterge panelinden içeriden çekin';
    }
    // Vites
    if (lowerMadde.contains('vites')) {
      return 'Vites kolundan içeriden çekin';
    }
    // Genel
    return 'Net görünecek şekilde çekin';
  }

  /// Durum seçenekleri
  List<DropdownMenuItem<String>> _getDurumSecenekleri() {
    return [
      DropdownMenuItem(
        value: 'mukemmel',
        child: Row(
          children: [
            const Icon(Icons.star, size: 16, color: YerimeBakColors.green),
            const SizedBox(width: 6),
            const Text('Mükemmel'),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'iyi',
        child: Row(
          children: [
            const Icon(Icons.thumb_up, size: 16, color: YerimeBakColors.green),
            const SizedBox(width: 6),
            const Text('İyi'),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'orta',
        child: Row(
          children: [
            const Icon(Icons.remove, size: 16, color: YerimeBakColors.orange),
            const SizedBox(width: 6),
            const Text('Orta'),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'sorunlu',
        child: Row(
          children: [
            const Icon(Icons.warning, size: 16, color: YerimeBakColors.orange),
            const SizedBox(width: 6),
            const Text('Sorunlu'),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'kotu',
        child: Row(
          children: [
            const Icon(Icons.close, size: 16, color: YerimeBakColors.red),
            const SizedBox(width: 6),
            const Text('Kötü'),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'agirhasar',
        child: Row(
          children: [
            const Icon(Icons.error, size: 16, color: YerimeBakColors.red),
            const SizedBox(width: 6),
            const Text('Ağır Hasar'),
          ],
        ),
      ),
    ];
  }
}
