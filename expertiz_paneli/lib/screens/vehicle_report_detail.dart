import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expertiz/tam_rapor_model.dart';

/// VehicleReportDetail Sayfası
/// Personelin girdiği 1-5 arası adımları görselleştirir
/// Sorunlu parçaları kırmızı bilgi kutusuyla gösterir
class VehicleReportDetail extends StatefulWidget {
  final TamRaporModel rapor;

  const VehicleReportDetail({
    super.key,
    required this.rapor,
  });

  @override
  State<VehicleReportDetail> createState() => _VehicleReportDetailState();
}

class _VehicleReportDetailState extends State<VehicleReportDetail> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.directions_car, color: isDarkMode ? Colors.white : Colors.black87),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.rapor.adim1.marka} ${widget.rapor.adim1.model}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    widget.rapor.adim1.plaka,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
        elevation: 4,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(icon: Icon(Icons.directions_car), text: 'Adım 1'),
            Tab(icon: Icon(Icons.camera_alt), text: 'Adım 2'),
            Tab(icon: Icon(Icons.car_repair), text: 'Adım 3'),
            Tab(icon: Icon(Icons.palette), text: 'Adım 4'),
            Tab(icon: Icon(Icons.business), text: 'Adım 5'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAdim1(isDarkMode),
          _buildAdim2(isDarkMode),
          _buildAdim3(isDarkMode),
          _buildAdim4(isDarkMode),
          _buildAdim5(isDarkMode),
        ],
      ),
    );
  }

  /// ADIM 1: Araç & Satıcı
  Widget _buildAdim1(bool isDarkMode) {
    final adim1 = widget.rapor.adim1;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBolumBaslik('Adım 1: Araç & Satıcı Bilgileri', Icons.directions_car, Colors.blue, isDarkMode),
          SizedBox(height: 20),
          
          // Araç Bilgileri Kartı
          _buildInfoCard(
            'Araç Bilgileri',
            [
              _buildInfoSatir('Marka', adim1.marka),
              _buildInfoSatir('Model', adim1.model),
              _buildInfoSatir('Yakıt Türü', adim1.yakitTuru),
              _buildInfoSatir('Plaka', adim1.plaka),
              _buildInfoSatir('Şase No', adim1.saseNo),
              _buildInfoSatir('Güncel KM', adim1.guncelKm.toString()),
              _buildInfoSatir('Ruhsat Sahibi', adim1.ruhsatSahibiAdSoyad),
              _buildInfoSatir('İletişim Telefonu', adim1.iletisimTelefon),
            ],
            isDarkMode,
          ),
          SizedBox(height: 16),
          
          // Bakım Bilgileri Kartı
          _buildInfoCard(
            'Bakım Bilgileri',
            [
              if (adim1.enSonBakimTarihi != null)
                _buildInfoSatir('Son Bakım Tarihi', DateFormat('dd.MM.yyyy').format(adim1.enSonBakimTarihi!)),
              if (adim1.sonMuayeneTarihi != null)
                _buildInfoSatir('Son Muayene Tarihi', DateFormat('dd.MM.yyyy').format(adim1.sonMuayeneTarihi!)),
            ],
            isDarkMode,
          ),
        ],
      ),
    );
  }

  /// ADIM 2: Dış Ekspertiz
  Widget _buildAdim2(bool isDarkMode) {
    final adim2 = widget.rapor.adim2;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBolumBaslik('Adım 2: Dış Ekspertiz', Icons.camera_alt, Colors.green, isDarkMode),
          SizedBox(height: 20),
          
          // Ön Kısım
          _buildBolumKarti('🚗 Ön Kısım', isDarkMode, children: [
            _buildParcaKarti('Ön Tampon', adim2.onTampon, adim2.aciklamalar, adim2.fotografUrl, adim2.fotografYolu, isDarkMode),
            _buildParcaKarti('Ön Farlar', adim2.onFarlar, adim2.aciklamalar, adim2.fotografUrl, adim2.fotografYolu, isDarkMode),
            _buildParcaKarti('Ön Çamurluklar', adim2.onCamurluklar, adim2.aciklamalar, adim2.fotografUrl, adim2.fotografYolu, isDarkMode),
            _buildParcaKarti('Ön Kaput', adim2.onKaput, adim2.aciklamalar, adim2.fotografUrl, adim2.fotografYolu, isDarkMode),
          ]),
          
          SizedBox(height: 16),
          
          // Arka Kısım
          _buildBolumKarti('🚗 Arka Kısım', isDarkMode, children: [
            _buildParcaKarti('Arka Tampon', adim2.arkaTampon, adim2.aciklamalar, adim2.fotografUrl, adim2.fotografYolu, isDarkMode),
            _buildParcaKarti('Arka Çamurluklar', adim2.arkaCamurluklar, adim2.aciklamalar, adim2.fotografUrl, adim2.fotografYolu, isDarkMode),
            _buildParcaKarti('Bagaj Kapagi', adim2.bagajKapagi, adim2.aciklamalar, adim2.fotografUrl, adim2.fotografYolu, isDarkMode),
          ]),
          
          SizedBox(height: 16),
          
          // Yan Kısımlar
          _buildBolumKarti('🚗 Yan Kısımlar', isDarkMode, children: [
            _buildParcaKarti('Sol Ön Kapı', adim2.solOnKapi, adim2.aciklamalar, adim2.fotografUrl, adim2.fotografYolu, isDarkMode),
            _buildParcaKarti('Sağ Ön Kapı', adim2.sagOnKapi, adim2.aciklamalar, adim2.fotografUrl, adim2.fotografYolu, isDarkMode),
            _buildParcaKarti('Sol Arka Kapı', adim2.solArkaKapi, adim2.aciklamalar, adim2.fotografUrl, adim2.fotografYolu, isDarkMode),
            _buildParcaKarti('Sağ Arka Kapı', adim2.sagArkaKapi, adim2.aciklamalar, adim2.fotografUrl, adim2.fotografYolu, isDarkMode),
          ]),
          
          SizedBox(height: 16),
          
          // Tavan ve Lastikler
          _buildBolumKarti('🚗 Tavan ve Lastikler', isDarkMode, children: [
            _buildParcaKarti('Tavan', adim2.tavan, adim2.aciklamalar, adim2.fotografUrl, adim2.fotografYolu, isDarkMode),
            _buildParcaKarti('Ön Lastikler', adim2.onLastikler, adim2.aciklamalar, adim2.fotografUrl, adim2.fotografYolu, isDarkMode),
            _buildParcaKarti('Arka Lastikler', adim2.arkaLastikler, adim2.aciklamalar, adim2.fotografUrl, adim2.fotografYolu, isDarkMode),
          ]),
          
          if (adim2.genelNot != null && adim2.genelNot!.isNotEmpty) ...[
            SizedBox(height: 16),
            _buildGenelNot(adim2.genelNot!, isDarkMode),
          ],
        ],
      ),
    );
  }

  /// ADIM 3: İç Ekspertiz
  Widget _buildAdim3(bool isDarkMode) {
    final adim3 = widget.rapor.adim3;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBolumBaslik('Adım 3: İç Ekspertiz', Icons.car_repair, Colors.orange, isDarkMode),
          SizedBox(height: 20),
          
          // Kokpit
          _buildBolumKarti('🎛️ Kokpit', isDarkMode, children: [
            _buildParcaKarti('Direksiyon', adim3.direksiyon, adim3.aciklamalar, adim3.fotografUrl, adim3.fotografYolu, isDarkMode),
            _buildParcaKarti('Gösterge Paneli', adim3.gostergePaneli, adim3.aciklamalar, adim3.fotografUrl, adim3.fotografYolu, isDarkMode),
            _buildParcaKarti('Klima', adim3.klima, adim3.aciklamalar, adim3.fotografUrl, adim3.fotografYolu, isDarkMode),
            _buildParcaKarti('Ses Sistemi', adim3.sesSistemi, adim3.aciklamalar, adim3.fotografUrl, adim3.fotografYolu, isDarkMode),
          ]),
          
          SizedBox(height: 16),
          
          // Koltuklar
          _buildBolumKarti('💺 Koltuklar', isDarkMode, children: [
            _buildParcaKarti('Ön Koltuklar', adim3.onKoltuklar, adim3.aciklamalar, adim3.fotografUrl, adim3.fotografYolu, isDarkMode),
            _buildParcaKarti('Arka Koltuklar', adim3.arkaKoltuklar, adim3.aciklamalar, adim3.fotografUrl, adim3.fotografYolu, isDarkMode),
            _buildParcaKarti('Koltuk Döşemesi', adim3.koltukDosemesi, adim3.aciklamalar, adim3.fotografUrl, adim3.fotografYolu, isDarkMode),
          ]),
          
          SizedBox(height: 16),
          
          // Döşeme ve Pencereler
          _buildBolumKarti('🪟 Döşeme ve Pencereler', isDarkMode, children: [
            _buildParcaKarti('Döşeme', adim3.dorseme, adim3.aciklamalar, adim3.fotografUrl, adim3.fotografYolu, isDarkMode),
            _buildParcaKarti('Tavan Döşemesi', adim3.tavanDosemesi, adim3.aciklamalar, adim3.fotografUrl, adim3.fotografYolu, isDarkMode),
            _buildParcaKarti('Ön Pencereler', adim3.onPencereler, adim3.aciklamalar, adim3.fotografUrl, adim3.fotografYolu, isDarkMode),
            _buildParcaKarti('Arka Pencereler', adim3.arkaPencereler, adim3.aciklamalar, adim3.fotografUrl, adim3.fotografYolu, isDarkMode),
            _buildParcaKarti('Camlar', adim3.camlar, adim3.aciklamalar, adim3.fotografUrl, adim3.fotografYolu, isDarkMode),
          ]),
          
          SizedBox(height: 16),
          
          // Elektronik
          _buildBolumKarti('🔌 Elektronik', isDarkMode, children: [
            _buildParcaKarti('Merkezi Kilit', adim3.merkeziKilit, adim3.aciklamalar, adim3.fotografUrl, adim3.fotografYolu, isDarkMode),
            _buildParcaKarti('Cam Kontrolleri', adim3.camKontrolleri, adim3.aciklamalar, adim3.fotografUrl, adim3.fotografYolu, isDarkMode),
            _buildParcaKarti('Ayna Kontrolleri', adim3.aynaKontrolleri, adim3.aciklamalar, adim3.fotografUrl, adim3.fotografYolu, isDarkMode),
          ]),
          
          if (adim3.genelNot != null && adim3.genelNot!.isNotEmpty) ...[
            SizedBox(height: 16),
            _buildGenelNot(adim3.genelNot!, isDarkMode),
          ],
        ],
      ),
    );
  }

  /// ADIM 4: Boya / Kaporta
  Widget _buildAdim4(bool isDarkMode) {
    final adim4 = widget.rapor.adim4;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBolumBaslik('Adım 4: Boya / Kaporta', Icons.palette, Colors.purple, isDarkMode),
          SizedBox(height: 20),
          
          // Boya
          _buildBolumKarti('🎨 Boya', isDarkMode, children: [
            _buildParcaKarti('Ön Kapı Boya', adim4.onKapiBoya, adim4.aciklamalar, adim4.fotografUrl, adim4.fotografYolu, isDarkMode),
            _buildParcaKarti('Arka Kapı Boya', adim4.arkaKapiBoya, adim4.aciklamalar, adim4.fotografUrl, adim4.fotografYolu, isDarkMode),
            _buildParcaKarti('Kaput Boya', adim4.kaputBoya, adim4.aciklamalar, adim4.fotografUrl, adim4.fotografYolu, isDarkMode),
            _buildParcaKarti('Tampon Boya', adim4.tamponBoya, adim4.aciklamalar, adim4.fotografUrl, adim4.fotografYolu, isDarkMode),
            _buildParcaKarti('Tavan Boya', adim4.tavanBoya, adim4.aciklamalar, adim4.fotografUrl, adim4.fotografYolu, isDarkMode),
          ]),
          
          SizedBox(height: 16),
          
          // Kaporta
          _buildBolumKarti('🔩 Kaporta', isDarkMode, children: [
            _buildParcaKarti('Ön Kapı Kaporta', adim4.onKapiKaporta, adim4.aciklamalar, adim4.fotografUrl, adim4.fotografYolu, isDarkMode),
            _buildParcaKarti('Arka Kapı Kaporta', adim4.arkaKapiKaporta, adim4.aciklamalar, adim4.fotografUrl, adim4.fotografYolu, isDarkMode),
            _buildParcaKarti('Kaput Kaporta', adim4.kaputKaporta, adim4.aciklamalar, adim4.fotografUrl, adim4.fotografYolu, isDarkMode),
            _buildParcaKarti('Tampon Kaporta', adim4.tamponKaporta, adim4.aciklamalar, adim4.fotografUrl, adim4.fotografYolu, isDarkMode),
          ]),
          
          SizedBox(height: 16),
          
          // Şasi ve Direkler
          _buildBolumKarti('🚗 Şasi ve Direkler', isDarkMode, children: [
            _buildParcaKarti('Ön Şasi', adim4.onSasi, adim4.aciklamalar, adim4.fotografUrl, adim4.fotografYolu, isDarkMode),
            _buildParcaKarti('Arka Şasi', adim4.arkaSasi, adim4.aciklamalar, adim4.fotografUrl, adim4.fotografYolu, isDarkMode),
            _buildParcaKarti('Ön Direkler', adim4.onDirekler, adim4.aciklamalar, adim4.fotografUrl, adim4.fotografYolu, isDarkMode),
            _buildParcaKarti('Arka Direkler', adim4.arkaDirekler, adim4.aciklamalar, adim4.fotografUrl, adim4.fotografYolu, isDarkMode),
          ]),
          
          SizedBox(height: 16),
          
          // Ekstra Kaporta Parçaları
          _buildBolumKarti('🎯 Ekstra Kaporta Parçaları', isDarkMode, children: [
            _buildParcaKarti('Podye', adim4.podye, adim4.aciklamalar, adim4.fotografUrl, adim4.fotografYolu, isDarkMode),
            _buildParcaKarti('Marsbiyel', adim4.marsbiyel, adim4.aciklamalar, adim4.fotografUrl, adim4.fotografYolu, isDarkMode),
          ]),
          
          // Hasar Kayıtları
          if (adim4.hasarKayitlari.isNotEmpty) ...[
            SizedBox(height: 20),
            _buildHasarKayitlari(adim4.hasarKayitlari, isDarkMode),
          ],
          
          if (adim4.genelNot != null && adim4.genelNot!.isNotEmpty) ...[
            SizedBox(height: 16),
            _buildGenelNot(adim4.genelNot!, isDarkMode),
          ],
        ],
      ),
    );
  }

  /// ADIM 5: Kurumsal Ekspertiz
  Widget _buildAdim5(bool isDarkMode) {
    final adim5 = widget.rapor.adim5;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBolumBaslik('Adım 5: Kurumsal Ekspertiz', Icons.business, Colors.teal, isDarkMode),
          SizedBox(height: 20),
          
          // Dosya Kontrolü
          _buildInfoCard(
            'Dosya Kontrolü',
            [
              _buildInfoSatir('Ruhsat Dosyası', adim5.ruhsatDosyasiVar == true ? 'Var' : (adim5.ruhsatDosyasiVar == false ? 'Yok' : 'Belirtilmemiş')),
              _buildInfoSatir('Bakım Defteri', adim5.bakimDefteriVar == true ? 'Var' : (adim5.bakimDefteriVar == false ? 'Yok' : 'Belirtilmemiş')),
              _buildInfoSatir('Sigorta Poliçesi', adim5.sigortaPolicesiVar == true ? 'Var' : (adim5.sigortaPolicesiVar == false ? 'Yok' : 'Belirtilmemiş')),
              _buildInfoSatir('Muayene Belgeleri', adim5.muayeneBelgesiVar == true ? 'Var' : (adim5.muayeneBelgesiVar == false ? 'Yok' : 'Belirtilmemiş')),
            ],
            isDarkMode,
          ),
          SizedBox(height: 16),
          
          // Motor ve Mekanik
          _buildInfoCard(
            'Motor ve Mekanik',
            [
              _buildInfoSatir('Motor Durumu', adim5.motorDurumu ?? 'Belirtilmemiş'),
              _buildInfoSatir('Şanzıman Durumu', adim5.sanzimanDurumu ?? 'Belirtilmemiş'),
              _buildInfoSatir('Fren Sistemi', adim5.frenSistemi ?? 'Belirtilmemiş'),
              _buildInfoSatir('Direksiyon Sistemi', adim5.direksiyonSistemi ?? 'Belirtilmemiş'),
              _buildInfoSatir('Elektrik Sistemi', adim5.elektrikSistemi ?? 'Belirtilmemiş'),
            ],
            isDarkMode,
          ),
          SizedBox(height: 16),
          
          // Değerlendirme
          _buildInfoCard(
            'Değerlendirme',
            [
              _buildInfoSatir('Genel Puan', adim5.genelPuan?.toString() ?? 'Belirtilmemiş'),
              _buildInfoSatir('Puan Değerlendirmesi', adim5.puanDegerlendirmesi),
              _buildInfoSatir('Kayıt Tarihi', DateFormat('dd.MM.yyyy HH:mm').format(adim5.kayitTarihi)),
            ],
            isDarkMode,
          ),
          SizedBox(height: 16),
          
          // Özet Not
          if (adim5.ozetNot != null && adim5.ozetNot!.isNotEmpty) ...[
            _buildInfoCard(
              'Özet Not',
              [
                _buildInfoSatir('', adim5.ozetNot!),
              ],
              isDarkMode,
            ),
            SizedBox(height: 16),
          ],
          
          // Öneriler
          if (adim5.oneriler != null && adim5.oneriler!.isNotEmpty) ...[
            _buildInfoCard(
              'Öneriler',
              [
                _buildInfoSatir('', adim5.oneriler!),
              ],
              isDarkMode,
            ),
            SizedBox(height: 16),
          ],
          
          // Genel Not
          if (adim5.genelNot != null && adim5.genelNot!.isNotEmpty) ...[
            _buildGenelNot(adim5.genelNot!, isDarkMode),
          ],
        ],
      ),
    );
  }

  /// Bölüm Başlığı Widget'ı
  Widget _buildBolumBaslik(String title, IconData icon, Color color, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bölüm Kartı Widget'ı
  Widget _buildBolumKarti(String title, bool isDarkMode, {required List<Widget> children}) {
    return Card(
      elevation: 2,
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Parça Kartı Widget'ı
  Widget _buildParcaKarti(
    String parcaAdi,
    String? durum,
    Map<String, String>? aciklamalar,
    Map<String, List<String>>? fotografUrl,
    Map<String, String>? fotografYolu,
    bool isDarkMode,
  ) {
    final parcaKey = parcaAdi.toLowerCase().replaceAll(' ', '_');
    final aciklama = aciklamalar?[parcaKey];
    final fotografYoluValue = fotografYolu?[parcaKey];
    
    // Durum rengi belirle
    Color durumRengi = Colors.grey;
    String durumMetni = durum ?? 'Belirtilmemiş';
    
    if (durum != null) {
      final durumLower = durum.toLowerCase();
      if (durumLower.contains('sorunlu') || durumLower.contains('hasarlı') || durumLower.contains('kötü')) {
        durumRengi = Colors.red;
        durumMetni = 'Sorunlu';
      } else if (durumLower.contains('iyi') || durumLower.contains('temiz')) {
        durumRengi = Colors.green;
        durumMetni = 'İyi';
      } else if (durumLower.contains('orta')) {
        durumRengi = Colors.orange;
        durumMetni = 'Orta';
      }
    }
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      color: isDarkMode ? const Color(0xFF252525) : Colors.grey[50],
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Parça Adı ve Durum
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    parcaAdi,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.grey[800],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: durumRengi.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: durumRengi, width: 1),
                  ),
                  child: Text(
                    durumMetni,
                    style: TextStyle(
                      color: durumRengi,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
             
            // Fotoğraf
            if (fotografYoluValue != null) ...[
              SizedBox(height: 12),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    fotografYoluValue,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Fotoğraf yüklenemedi'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
             
            // Kırmızı Bilgi Kutusu (Sorunlu ise veya açıklama varsa)
            if (durumRengi == Colors.red || (aciklama != null && aciklama.isNotEmpty)) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Sorunlu Parça',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (aciklama != null && aciklama.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text(
                        aciklama,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.grey[800],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Hasar Kayıtları Widget'ı
  Widget _buildHasarKayitlari(List<dynamic> hasarKayitlari, bool isDarkMode) {
    return Card(
      elevation: 2,
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 24),
                SizedBox(width: 12),
                Text(
                  'Hasar Kayıtları',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...hasarKayitlari.map((hasar) {
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                color: Colors.red.withValues(alpha: 0.05),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konum: ${hasar['konum'] ?? 'Belirtilmemiş'}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text('Tip: ${hasar['tip'] ?? 'Belirtilmemiş'}'),
                      SizedBox(height: 4),
                      Text('Büyüklük: ${hasar['buyukluk'] ?? 'Belirtilmemiş'}'),
                      if (hasar['not'] != null) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Not: ${hasar['not']}'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Bilgi Kartı Widget'ı
  Widget _buildInfoCard(String title, List<Widget> children, bool isDarkMode) {
    return Card(
      elevation: 2,
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Bilgi Satırı Widget'ı
  Widget _buildInfoSatir(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  /// Genel Not Widget'ı
  Widget _buildGenelNot(String not, bool isDarkMode) {
    return Card(
      elevation: 2,
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(
                  'Genel Not',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                not,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
