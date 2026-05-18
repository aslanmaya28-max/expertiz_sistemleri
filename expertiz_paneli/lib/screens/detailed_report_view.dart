import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expertiz/tam_rapor_model.dart';
import '../services/pdf_export_service.dart';

/// DetailedReportView Sayfası
/// Personelin girdiği 5 adımı liste halinde gösterir
/// hasDamage: true veya not girilmiş adımları kırmızı kart içinde gösterir
class DetailedReportView extends StatefulWidget {
  final TamRaporModel rapor;

  const DetailedReportView({
    super.key,
    required this.rapor,
  });

  @override
  State<DetailedReportView> createState() => _DetailedReportViewState();
}

class _DetailedReportViewState extends State<DetailedReportView> {
  /// PDF olarak dışa aktar
  void _exportToPdf() async {
    // Yükleniyor göstergesi göster
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('PDF Hazırlanıyor...'),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
    
    // PDF dışa aktar
    try {
      await PdfExportService.exportReportToPdf(widget.rapor);
      
      // Başarı mesajı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('PDF başarıyla oluşturuldu')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Hata mesajı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('PDF oluşturulurken hata oluştu: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.description, color: isDarkMode ? Colors.white : Colors.black87),
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
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: isDarkMode ? Colors.white : Colors.black87),
            onPressed: _exportToPdf,
            tooltip: 'PDF Olarak İndir',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Araç Özet Bilgileri
            _buildAraozetBilgileri(isDarkMode),
            SizedBox(height: 20),
            
            // Adım Listesi
            Text(
              'Expertiz Adımları',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            
            // Adım 1
            _buildAdimKarti(
              adimNo: 1,
              adimAdi: 'Araç & Satıcı Bilgileri',
              icon: Icons.directions_car,
              renk: Colors.blue,
              hasDamage: _adim1HasDamage(),
              not: widget.rapor.adim1.genelNot,
              fotografYolu: _getAdim1Fotograf(),
              isDarkMode: isDarkMode,
              icerik: _buildAdim1Icerik(isDarkMode),
            ),
            
            SizedBox(height: 16),
            
            // Adım 2
            _buildAdimKarti(
              adimNo: 2,
              adimAdi: 'Dış Ekspertiz',
              icon: Icons.camera_alt,
              renk: Colors.green,
              hasDamage: _adim2HasDamage(),
              not: widget.rapor.adim2.genelNot,
              fotografYolu: _getAdim2Fotograf(),
              isDarkMode: isDarkMode,
              icerik: _buildAdim2Icerik(isDarkMode),
            ),
            
            SizedBox(height: 16),
            
            // Adım 3
            _buildAdimKarti(
              adimNo: 3,
              adimAdi: 'İç Ekspertiz',
              icon: Icons.car_repair,
              renk: Colors.orange,
              hasDamage: _adim3HasDamage(),
              not: widget.rapor.adim3.genelNot,
              fotografYolu: _getAdim3Fotograf(),
              isDarkMode: isDarkMode,
              icerik: _buildAdim3Icerik(isDarkMode),
            ),
            
            SizedBox(height: 16),
            
            // Adım 4
            _buildAdimKarti(
              adimNo: 4,
              adimAdi: 'Boya / Kaporta',
              icon: Icons.palette,
              renk: Colors.purple,
              hasDamage: _adim4HasDamage(),
              not: widget.rapor.adim4.genelNot,
              fotografYolu: _getAdim4Fotograf(),
              isDarkMode: isDarkMode,
              icerik: _buildAdim4Icerik(isDarkMode),
            ),
            
            SizedBox(height: 16),
            
            // Adım 5
            _buildAdimKarti(
              adimNo: 5,
              adimAdi: 'Kurumsal Ekspertiz',
              icon: Icons.business,
              renk: Colors.teal,
              hasDamage: _adim5HasDamage(),
              not: widget.rapor.adim5.genelNot,
              fotografYolu: _getAdim5Fotograf(),
              isDarkMode: isDarkMode,
              icerik: _buildAdim5Icerik(isDarkMode),
            ),
            
            SizedBox(height: 20),
            
            // Genel Özet
            if (widget.rapor.genelNot != null && widget.rapor.genelNot!.isNotEmpty)
              _buildGenelOzet(isDarkMode),
          ],
        ),
      ),
    );
  }

  /// Araç Özet Bilgileri
  Widget _buildAraozetBilgileri(bool isDarkMode) {
    final rapor = widget.rapor;
    
    return Card(
      elevation: 3,
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 24),
                SizedBox(width: 10),
                Text(
                  'Rapor Özeti',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildInfoSatir('Görev ID', rapor.gorevId, isDarkMode),
            _buildInfoSatir('Personel ID', rapor.personelId, isDarkMode),
            _buildInfoSatir('Durum', rapor.durum, isDarkMode),
            _buildInfoSatir('Başlangıç', DateFormat('dd.MM.yyyy HH:mm').format(rapor.baslangicZamani), isDarkMode),
            if (rapor.bitisZamani != null)
              _buildInfoSatir('Bitiş', DateFormat('dd.MM.yyyy HH:mm').format(rapor.bitisZamani!), isDarkMode),
            if (rapor.genelPuan != null)
              _buildInfoSatir('Genel Puan', rapor.genelPuan.toString(), isDarkMode),
          ],
        ),
      ),
    );
  }

  /// Adım Kartı Widget'ı
  Widget _buildAdimKarti({
    required int adimNo,
    required String adimAdi,
    required IconData icon,
    required Color renk,
    required bool hasDamage,
    String? not,
    String? fotografYolu,
    required bool isDarkMode,
    required Widget icerik,
  }) {
    final hasProblem = hasDamage || (not != null && not.isNotEmpty);
    
    return Card(
      elevation: hasProblem ? 4 : 2,
      color: hasProblem 
          ? Colors.red.withValues(alpha: isDarkMode ? 0.15 : 0.08)
          : (isDarkMode ? const Color(0xFF1E1E1E) : Colors.white),
      borderOnForeground: hasProblem,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasProblem 
            ? BorderSide(color: Colors.red, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Adım Başlığı
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: renk.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: renk, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adım $adimNo: $adimAdi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (hasProblem)
                        Text(
                          '⚠️ Sorun Tespit Edildi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasProblem)
                  Icon(Icons.warning, color: Colors.red, size: 28),
              ],
            ),
            
            SizedBox(height: 16),
            
            // İçerik
            icerik,
            
            // Kırmızı Kart (Sorun varsa)
            if (hasProblem) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: isDarkMode ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'DİKKAT: Sorunlu Adım',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    
                    // Fotoğraf
                    if (fotografYolu != null) ...[
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
                            fotografYolu,
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
                      SizedBox(height: 12),
                    ],
                    
                    // Personel Notu
                    if (not != null && not.isNotEmpty) ...[
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.note, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Personel Notu:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              not,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
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

  /// Adım 1 İçerik
  Widget _buildAdim1Icerik(bool isDarkMode) {
    final adim1 = widget.rapor.adim1;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoSatir('Marka', adim1.marka, isDarkMode),
        _buildInfoSatir('Model', adim1.model, isDarkMode),
        _buildInfoSatir('Yakıt Türü', adim1.yakitTuru, isDarkMode),
        _buildInfoSatir('Plaka', adim1.plaka, isDarkMode),
        _buildInfoSatir('Şase No', adim1.saseNo, isDarkMode),
        _buildInfoSatir('Güncel KM', adim1.guncelKm.toString(), isDarkMode),
        _buildInfoSatir('Ruhsat Sahibi', adim1.ruhsatSahibiAdSoyad, isDarkMode),
        _buildInfoSatir('İletişim Telefonu', adim1.iletisimTelefon, isDarkMode),
        if (adim1.enSonBakimTarihi != null)
          _buildInfoSatir('Son Bakım Tarihi', DateFormat('dd.MM.yyyy').format(adim1.enSonBakimTarihi!), isDarkMode),
        if (adim1.sonMuayeneTarihi != null)
          _buildInfoSatir('Son Muayene Tarihi', DateFormat('dd.MM.yyyy').format(adim1.sonMuayeneTarihi!), isDarkMode),
      ],
    );
  }

  /// Adım 2 İçerik
  Widget _buildAdim2Icerik(bool isDarkMode) {
    final adim2 = widget.rapor.adim2;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildParcaDurumu('Ön Tampon', adim2.onTampon, isDarkMode),
        _buildParcaDurumu('Ön Farlar', adim2.onFarlar, isDarkMode),
        _buildParcaDurumu('Ön Çamurluklar', adim2.onCamurluklar, isDarkMode),
        _buildParcaDurumu('Ön Kaput', adim2.onKaput, isDarkMode),
        _buildParcaDurumu('Arka Tampon', adim2.arkaTampon, isDarkMode),
        _buildParcaDurumu('Arka Çamurluklar', adim2.arkaCamurluklar, isDarkMode),
        _buildParcaDurumu('Bagaj Kapagi', adim2.bagajKapagi, isDarkMode),
        _buildParcaDurumu('Sol Ön Kapı', adim2.solOnKapi, isDarkMode),
        _buildParcaDurumu('Sağ Ön Kapı', adim2.sagOnKapi, isDarkMode),
        _buildParcaDurumu('Sol Arka Kapı', adim2.solArkaKapi, isDarkMode),
        _buildParcaDurumu('Sağ Arka Kapı', adim2.sagArkaKapi, isDarkMode),
        _buildParcaDurumu('Tavan', adim2.tavan, isDarkMode),
        _buildParcaDurumu('Ön Lastikler', adim2.onLastikler, isDarkMode),
        _buildParcaDurumu('Arka Lastikler', adim2.arkaLastikler, isDarkMode),
      ],
    );
  }

  /// Adım 3 İçerik
  Widget _buildAdim3Icerik(bool isDarkMode) {
    final adim3 = widget.rapor.adim3;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildParcaDurumu('Direksiyon', adim3.direksiyon, isDarkMode),
        _buildParcaDurumu('Gösterge Paneli', adim3.gostergePaneli, isDarkMode),
        _buildParcaDurumu('Klima', adim3.klima, isDarkMode),
        _buildParcaDurumu('Ses Sistemi', adim3.sesSistemi, isDarkMode),
        _buildParcaDurumu('Ön Koltuklar', adim3.onKoltuklar, isDarkMode),
        _buildParcaDurumu('Arka Koltuklar', adim3.arkaKoltukler, isDarkMode),
        _buildParcaDurumu('Koltuk Döşemesi', adim3.koltukDosemesi, isDarkMode),
        _buildParcaDurumu('Döşeme', adim3.dorseme, isDarkMode),
        _buildParcaDurumu('Tavan Döşemesi', adim3.tavanDosemesi, isDarkMode),
        _buildParcaDurumu('Ön Pencereler', adim3.onPencereler, isDarkMode),
        _buildParcaDurumu('Arka Pencereler', adim3.arkaPencereler, isDarkMode),
        _buildParcaDurumu('Camlar', adim3.camlar, isDarkMode),
        _buildParcaDurumu('Merkezi Kilit', adim3.merkeziKilit, isDarkMode),
        _buildParcaDurumu('Cam Kontrolleri', adim3.camKontrolleri, isDarkMode),
        _buildParcaDurumu('Ayna Kontrolleri', adim3.aynaKontrolleri, isDarkMode),
      ],
    );
  }

  /// Adım 4 İçerik
  Widget _buildAdim4Icerik(bool isDarkMode) {
    final adim4 = widget.rapor.adim4;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildParcaDurumu('Ön Kapı Boya', adim4.onKapiBoya, isDarkMode),
        _buildParcaDurumu('Arka Kapı Boya', adim4.arkaKapiBoya, isDarkMode),
        _buildParcaDurumu('Kaput Boya', adim4.kaputBoya, isDarkMode),
        _buildParcaDurumu('Tampon Boya', adim4.tamponBoya, isDarkMode),
        _buildParcaDurumu('Tavan Boya', adim4.tavanBoya, isDarkMode),
        _buildParcaDurumu('Ön Kapı Kaporta', adim4.onKapiKaporta, isDarkMode),
        _buildParcaDurumu('Arka Kapı Kaporta', adim4.arkaKapiKaporta, isDarkMode),
        _buildParcaDurumu('Kaput Kaporta', adim4.kaputKaporta, isDarkMode),
        _buildParcaDurumu('Tampon Kaporta', adim4.tamponKaporta, isDarkMode),
        _buildParcaDurumu('Ön Şasi', adim4.onSasi, isDarkMode),
        _buildParcaDurumu('Arka Şasi', adim4.arkaSasi, isDarkMode),
        _buildParcaDurumu('Ön Direkler', adim4.onDirekler, isDarkMode),
        _buildParcaDurumu('Arka Direkler', adim4.arkaDirekler, isDarkMode),
        _buildParcaDurumu('Podye', adim4.podye, isDarkMode),
        _buildParcaDurumu('Marsbiyel', adim4.marsbiyel, isDarkMode),
      ],
    );
  }

  /// Adım 5 İçerik
  Widget _buildAdim5Icerik(bool isDarkMode) {
    final adim5 = widget.rapor.adim5;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoSatir('Ruhsat Dosyası', adim5.ruhsatDosyasiVar == true ? 'Var' : 'Yok', isDarkMode),
        _buildInfoSatir('Bakım Defteri', adim5.bakimDefteriVar == true ? 'Var' : 'Yok', isDarkMode),
        _buildInfoSatir('Sigorta Poliçesi', adim5.sigortaPolicesiVar == true ? 'Var' : 'Yok', isDarkMode),
        _buildInfoSatir('Muayene Belgeleri', adim5.muayeneBelgesiVar == true ? 'Var' : 'Yok', isDarkMode),
        SizedBox(height: 8),
        _buildInfoSatir('Motor Durumu', adim5.motorDurumu ?? 'Belirtilmemiş', isDarkMode),
        _buildInfoSatir('Şanzıman Durumu', adim5.sanzimanDurumu ?? 'Belirtilmemiş', isDarkMode),
        _buildInfoSatir('Fren Sistemi', adim5.frenSistemi ?? 'Belirtilmemiş', isDarkMode),
        _buildInfoSatir('Direksiyon Sistemi', adim5.direksiyonSistemi ?? 'Belirtilmemiş', isDarkMode),
        _buildInfoSatir('Elektrik Sistemi', adim5.elektrikSistemi ?? 'Belirtilmemiş', isDarkMode),
        if (adim5.genelPuan != null)
          _buildInfoSatir('Genel Puan', adim5.genelPuan.toString(), isDarkMode),
      ],
    );
  }

  /// Parça Durumu Widget'ı
  Widget _buildParcaDurumu(String parcaAdi, String? durum, bool isDarkMode) {
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
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              parcaAdi,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: durumRengi.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: durumRengi, width: 1),
            ),
            child: Text(
              durumMetni,
              style: TextStyle(
                color: durumRengi,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bilgi Satırı Widget'ı
  Widget _buildInfoSatir(String label, String value, bool isDarkMode) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Genel Özet Widget'ı
  Widget _buildGenelOzet(bool isDarkMode) {
    return Card(
      elevation: 3,
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note_add, color: Colors.blue, size: 24),
                SizedBox(width: 10),
                Text(
                  'Genel Özet ve Öneriler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (widget.rapor.genelNot != null && widget.rapor.genelNot!.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.rapor.genelNot!,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
            if (widget.rapor.oneriler != null && widget.rapor.oneriler!.isNotEmpty) ...[
              SizedBox(height: 12),
              Text(
                'Öneriler:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.rapor.oneriler!,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== HASAR KONTROL FONKSİYONLARI ====================
  
  /// Adım 1'de hasar var mı kontrol et
  bool _adim1HasDamage() {
    return false; // Adım 1 sadece bilgi içerir
  }

  /// Adım 2'de hasar var mı kontrol et
  bool _adim2HasDamage() {
    final adim2 = widget.rapor.adim2;
    final parcalar = [
      adim2.onTampon, adim2.onFarlar, adim2.onCamurluklar, adim2.onKaput,
      adim2.arkaTampon, adim2.arkaCamurluklar, adim2.bagajKapagi,
      adim2.solOnKapi, adim2.sagOnKapi, adim2.solArkaKapi, adim2.sagArkaKapi,
      adim2.tavan, adim2.onLastikler, adim2.arkaLastikler,
    ];
    
    for (final parca in parcalar) {
      if (parca != null && parca.toLowerCase().contains('sorunlu')) {
        return true;
      }
    }
    return false;
  }

  /// Adım 3'te hasar var mı kontrol et
  bool _adim3HasDamage() {
    final adim3 = widget.rapor.adim3;
    final parcalar = [
      adim3.direksiyon, adim3.gostergePaneli, adim3.klima, adim3.sesSistemi,
      adim3.onKoltuklar, adim3.arkaKoltukler, adim3.koltukDosemesi,
      adim3.dorseme, adim3.tavanDosemesi, adim3.onPencereler, adim3.arkaPencereler,
      adim3.camlar, adim3.merkeziKilit, adim3.camKontrolleri, adim3.aynaKontrolleri,
    ];
    
    for (final parca in parcalar) {
      if (parca != null && parca.toLowerCase().contains('sorunlu')) {
        return true;
      }
    }
    return false;
  }

  /// Adım 4'te hasar var mı kontrol et
  bool _adim4HasDamage() {
    final adim4 = widget.rapor.adim4;
    final parcalar = [
      adim4.onKapiBoya, adim4.arkaKapiBoya, adim4.kaputBoya, adim4.tamponBoya, adim4.tavanBoya,
      adim4.onKapiKaporta, adim4.arkaKapiKaporta, adim4.kaputKaporta, adim4.tamponKaporta,
      adim4.onSasi, adim4.arkaSasi, adim4.onDirekler, adim4.arkaDirekler,
      adim4.podye, adim4.marsbiyel,
    ];
    
    for (final parca in parcalar) {
      if (parca != null && parca.toLowerCase().contains('sorunlu')) {
        return true;
      }
    }
    return false;
  }

  /// Adım 5'te hasar var mı kontrol et
  bool _adim5HasDamage() {
    return false; // Adım 5 sadece değerlendirme içerir
  }

  // ==================== FOTOĞRAF ALMA FONKSİYONLARI ====================
  
  /// Adım 1 için fotoğraf yolu
  String? _getAdim1Fotograf() {
    return null; // Adım 1'de fotoğraf yok
  }

  /// Adım 2 için fotoğraf yolu
  String? _getAdim2Fotograf() {
    final adim2 = widget.rapor.adim2;
    if (adim2.fotografYolu != null && adim2.fotografYolu!.isNotEmpty) {
      return adim2.fotografYolu!.values.first;
    }
    return null;
  }

  /// Adım 3 için fotoğraf yolu
  String? _getAdim3Fotograf() {
    final adim3 = widget.rapor.adim3;
    if (adim3.fotografYolu != null && adim3.fotografYolu!.isNotEmpty) {
      return adim3.fotografYolu!.values.first;
    }
    return null;
  }

  /// Adım 4 için fotoğraf yolu
  String? _getAdim4Fotograf() {
    final adim4 = widget.rapor.adim4;
    if (adim4.fotografYolu != null && adim4.fotografYolu!.isNotEmpty) {
      return adim4.fotografYolu!.values.first;
    }
    return null;
  }

  /// Adım 5 için fotoğraf yolu
  String? _getAdim5Fotograf() {
    return null; // Adım 5'te fotoğraf yok
  }
}
