import 'package:flutter/material.dart';
import '../models/arac_rapor_model.dart';
import '../services/ai/ai_analiz_service.dart';
import '../services/market_radar_service.dart';
import '../models/expertiz/adim1_arac_satici_model.dart';
import '../models/ai/ai_analiz_sonucu_model.dart';
import '../core/constants/vehicle_packages.dart';

import 'rapor_duzenle.dart';
import 'ai/ai_analiz_detay_sayfasi.dart';
import '../widgets/cyber/cyber_background.dart';
import '../widgets/cyber/neon_approval_badge.dart';
import '../core/constants/yerimebak_colors.dart';
import '../widgets/ai/ai_analiz_ozet_widget.dart';
import '../widgets/ai/ai_skor_gosterge_widget.dart';
import '../widgets/ai/ai_oneri_karti_widget.dart';

class RaporDetaySayfasi extends StatefulWidget {
  final String reportId;
  final AracRapor? rapor;
  final Map<String, dynamic>? aracBilgileri;
  final String? customerID;
  final String? staffID;

  const RaporDetaySayfasi({
    super.key,
    required this.reportId,
    this.rapor,
    this.aracBilgileri,
    this.customerID,
    this.staffID,
  });

  @override
  State<RaporDetaySayfasi> createState() => _RaporDetaySayfasiState();
}

class _RaporDetaySayfasiState extends State<RaporDetaySayfasi> {
  late AracRapor _rapor;
  bool _aiAnalizYapiliyor = false;
  AIAnalizSonucu? _analizSonucu;
  Map<String, dynamic>? _piyasaDegeri; // Sistem hesaplanan piyasa değeri

  @override
  void initState() {
    super.initState();
    // Eğer rapor widget olarak gelmediyse, reportId'den yükle
    if (widget.rapor != null) {
      _rapor = widget.rapor!;
      _hesaplaPiyasaDegeri();
    } else {
      // TODO: Report ID'den rapor yükleme mantığı eklenecek
      // Şimdilik placeholder rapor oluştur
      _rapor = AracRapor(
        id: widget.reportId,
        musteriId: '',
        personelId: '',
        olusturmaTarihi: DateTime.now(),
        durum: 'beklemede',
      );
    }
  }

  /// Paket ağırlığına dayalı piyasa değeri hesaplama
  /// Bu metot AI analizinden bağımsız olarak çalışır
  void _hesaplaPiyasaDegeri() {
    // Paket ağırlığını al
    String packageId = _rapor.secilenPaket ?? '';
    double packageWeight = VehiclePackagesDatabase.getPackageWeight(packageId);
    
    // Araç bilgilerini hazırla (güvenli fallback mekanizmaları ile)
    String brand = _rapor.marka ?? '';
    String model = _rapor.model ?? '';
    int year = int.tryParse(_rapor.yil ?? '2020') ?? 2020;
    
    // KM değeri - _rapor içinde yoksa varsayılan değer kullan
    int km = 0;
    if (_rapor.runtimeType.toString().contains('km')) {
      // Eğer _rapor km alanına sahipse
      try {
        dynamic raporData = _rapor as dynamic;
        km = raporData.km as int? ?? 0;
      } catch (e) {
        km = 0;
      }
    }
    
    // Renk bilgisi - _rapor içinde yoksa varsayılan değer kullan
    String color = 'Beyaz';
    try {
      dynamic raporData = _rapor as dynamic;
      color = raporData.renk as String? ?? 'Beyaz';
    } catch (e) {
      color = 'Beyaz';
    }
    
    // Boyalı ve hasarlı parçalar - _rapor içinde yoksa boş liste kullan
    List<String> paintedParts = [];
    List<String> damagedParts = [];
    try {
      dynamic raporData = _rapor as dynamic;
      paintedParts = raporData.boyaParcalari as List<String>? ?? [];
      damagedParts = raporData.hasarParcalari as List<String>? ?? [];
    } catch (e) {
      paintedParts = [];
      damagedParts = [];
    }
    
    // Kritik loglama - packageWeight değerini açıkça göster
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔍 PİYASA DEĞERİ HESAPLAMA BAŞLADI');
    debugPrint('📦 Seçili Paket: $packageId');
    debugPrint('⚖️ Paket Ağırlığı: $packageWeight (KRİTİK ÇARPAN!)');
    debugPrint('🚗 Araç: $year $brand $model');
    debugPrint('📊 KM: $km, Renk: $color');
    debugPrint('🎨 Boyalı Parçalar: ${paintedParts.length}');
    debugPrint('⚠️ Hasarlı Parçalar: ${damagedParts.length}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    // calculateIntegratedValue çağır (decoupled - ExpertizProvider bağımsız)
    final sonuc = MarketRadarService.calculateIntegratedValue(
      brand: brand,
      model: model,
      year: year,
      km: km,
      color: color,
      packageLevel: packageId,
      packageWeight: packageWeight, // ✅ KRİTİK - Paket ağırlığı çarpanı!
      selectedOptions: {}, // Donanımlar _rapor'dan alınamadı, boş map
      paintedParts: paintedParts,
      damagedParts: damagedParts,
      marketSource: null,
    );
    
    // Sonuçları logla
    debugPrint('💰 TEMEL FİYAT: ${sonuc['basePrice']?.toStringAsFixed(0)} TL');
    debugPrint('📈 FİNAL DEĞER: ${sonuc['finalValue']?.toStringAsFixed(0)} TL');
    debugPrint('📊 TOPLAM AYARLAMA: ${sonuc['adjustmentPercentage']}%');
    
    if (sonuc['adjustments'] != null && sonuc['adjustments'] is List) {
      List<String> adjustments = sonuc['adjustments'] as List<String>;
      debugPrint('📋 AYARLAMALAR:');
      for (String adj in adjustments) {
        debugPrint('   • $adj');
      }
    }
    
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    // State güncelleme
    setState(() {
      _piyasaDegeri = sonuc;
    });
  }

  void _raporGuncelle(dynamic rapor) {
    debugPrint('Rapor güncellendi: $rapor');
  }

  bool _isAdmin() {
    return false;
  }

  /// AI Analizini Başlat
  Future<void> _aiAnaliziniBaslat(BuildContext context) async {
    setState(() {
      _aiAnalizYapiliyor = true;
    });

    try {
      final tamRapor = _rapor.toTamRaporModel();
      final analizSonucu = await AIAnalizService.analizEtVeKaydet(
        raporId: tamRapor.gorevId,
        marka: tamRapor.adim1.marka,
        model: tamRapor.adim1.model,
        yil: tamRapor.adim1.yil ?? DateTime.now().year.toString(),
        km: tamRapor.adim1.guncelKm,
        hasarKayitlar: tamRapor.adim4.hasarKayitlari.map((h) => h.konum).toList(),
        donanimlar: {},
        boyaliParcalar: tamRapor.adim4.boyaliParcalar,
      );
      
      if (!mounted) return;
      if (!context.mounted) return;

      final guncellenenRapor = AracRapor(
        id: _rapor.id,
        musteriId: _rapor.musteriId,
        personelId: _rapor.personelId,
        olusturmaTarihi: _rapor.olusturmaTarihi,
        durum: _rapor.durum,
        ilanLinki: _rapor.ilanLinki,
        plaka: _rapor.plaka,
        marka: _rapor.marka,
        model: _rapor.model,
        yil: _rapor.yil,
        sehir: _rapor.sehir,
        ilce: _rapor.ilce,
        ekspertizFirmasi: _rapor.ekspertizFirmasi,
        secilenPaket: _rapor.secilenPaket,
        hizmetBedeli: _rapor.hizmetBedeli,
        paketFiyati: _rapor.paketFiyati,
        toplamTutar: _rapor.toplamTutar,
        hasarTutar: _rapor.hasarTutar,
        olusturanKullanici: _rapor.olusturanKullanici,
        aiAnaliziYapildiMi: true,
        aiPiyasaDegeri: analizSonucu.raporOzeti.tahminiDeger,
        aiOnerilenAlimFiyati: null,
        aiAltiAylikGetiri: null,
        aiBirYillikGetiri: analizSonucu.raporOzeti.degerProjeksiyonu1Yil,
        aiYorumu: analizSonucu.raporOzeti.ozetAciklama,
        aiDegerKaybi: analizSonucu.raporOzeti.degerKaybiYuzde,
        aiAnalizSonucu: analizSonucu,
      );

      if (!mounted) return;

      setState(() {
        _rapor = guncellenenRapor;
        _aiAnalizYapiliyor = false;
        _analizSonucu = analizSonucu;
      });

      if (!mounted) return;

      final currentContext = context;
      if (!mounted) return;
      if (!context.mounted) return;

      Navigator.push(
        currentContext,
        MaterialPageRoute(
          builder: (context) => AIAnalizDetaySayfasi(
            analizSonucu: analizSonucu,
            aracBilgileri: Adim1AracSaticiModel(
              gorevId: _rapor.id,
              personelId: _rapor.personelId ?? 'unknown',
              marka: _rapor.marka ?? '',
              model: _rapor.model ?? '',
              yakitTuru: 'Benzin',
              plaka: _rapor.plaka ?? '',
              saseNo: '',
              guncelKm: 0,
              ruhsatSahibiAdSoyad: '',
              iletisimTelefon: '',
              motorNo: '',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _aiAnalizYapiliyor = false;
      });
      
      if (!mounted) return;
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI Analizi sırasında hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _raporDuzenle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RaporDuzenle(
          rapor: _rapor,
          onKaydet: (guncellenenRapor) {
            setState(() {
              _rapor = guncellenenRapor;
            });
            _raporGuncelle(guncellenenRapor);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rapor başarıyla güncellendi')),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CyberBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Rapor: ${_rapor.plaka}',
            style: TextStyle(
              color: YerimeBakColors.cyberNeonTurquoise,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: YerimeBakColors.cyberNeonTurquoise),
          actions: [
            NeonApprovalBadge(hasCriticalRisk: _hasCriticalRisk()),
            if (_isAdmin()) ...[
              IconButton(
                icon: Icon(Icons.edit, color: YerimeBakColors.cyberNeonTurquoise),
                onPressed: () => _raporDuzenle(context),
              ),
            ],
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNeonVehicleIdentityHeader(),
                  const SizedBox(height: 24),
                  
                  // Sistem Tahmini Piyasa Değeri Widget'ı
                  if (_piyasaDegeri != null) _buildSistemTahminDegerWidget(),
                  
                  const SizedBox(height: 24),
                   
                  if (!_rapor.aiAnaliziYapildiMi)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: YerimeBakColors.cyberDarkPurple.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yapay Zeka Analizi',
                            style: TextStyle(
                              color: YerimeBakColors.cyberNeonTurquoise,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _aiAnalizYapiliyor
                                ? null
                                : () => _aiAnaliziniBaslat(context),
                            icon: _aiAnalizYapiliyor
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.play_arrow),
                            label: Text(_aiAnalizYapiliyor
                                ? 'Analiz Yapılıyor...'
                                : 'AI Analizini Başlat'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: YerimeBakColors.cyberNeonTurquoise,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (_analizSonucu != null) ...[
                    const SizedBox(height: 24),
                    AIAnalizOzetWidget(raporOzeti: _analizSonucu!.raporOzeti),
                    const SizedBox(height: 16),
                    AISkorGostergeWidget(skorlar: _analizSonucu!.skorlar),
                    const SizedBox(height: 16),
                    AIOneriKartiWidget(
                      oneriler: _analizSonucu!.oneriler,
                      baslik: 'AI Önerileri',
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  _buildBilgiBolumu('Araç Bilgileri', [
                    _bilgiSatiri('Marka', _rapor.marka ?? ''),
                    _bilgiSatiri('Model', _rapor.model ?? ''),
                    _bilgiSatiri('Yıl', _rapor.yil ?? ''),
                    _bilgiSatiri('Plaka', _rapor.plaka ?? ''),
                    _bilgiSatiri('Şehir', _rapor.sehir ?? ''),
                  ]),
                ],
              ),
            ),
            if (_aiAnalizYapiliyor)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _hasCriticalRisk() {
    if (_rapor.aiAnaliziYapildiMi && _rapor.aiAnalizSonucu != null) {
      return _rapor.aiAnalizSonucu!.skorlar.genelPuan < 80;
    }
    return false;
  }

  Widget _buildNeonVehicleIdentityHeader() {
    String packageBadge = _rapor.secilenPaket ?? '';
    bool isSport = MarketRadarService.isSportPackage(_rapor.model ?? '');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.2),
            YerimeBakColors.cyberNeonPurple.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: YerimeBakColors.cyberNeonTurquoise,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_rapor.yil ?? ''} ${_rapor.marka ?? ''} ${_rapor.model ?? ''}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: YerimeBakColors.cyberNeonTurquoise,
                  ),
                ),
              ),
              if (packageBadge.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSport
                        ? Colors.orange.withValues(alpha: 0.3)
                        : YerimeBakColors.cyberNeonPurple.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSport ? Colors.orange : YerimeBakColors.cyberNeonPurple,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    packageBadge,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSport ? Colors.orange : YerimeBakColors.cyberNeonPurple,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Plaka: ${_rapor.plaka ?? ''}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBilgiBolumu(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: YerimeBakColors.cyberDarkPurple.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: YerimeBakColors.cyberNeonTurquoise,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _bilgiSatiri(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Sistem Tahmini Piyasa Değeri Widget'ı
  /// Paket ağırlığına dayalı hesaplanan değeri gösterir
  Widget _buildSistemTahminDegerWidget() {
    if (_piyasaDegeri == null) return const SizedBox.shrink();
    
    double finalValue = _piyasaDegeri!['finalValue'] ?? 0.0;
    double basePrice = _piyasaDegeri!['basePrice'] ?? 0.0;
    List<String> adjustments = (_piyasaDegeri!['adjustments'] as List<String>?) ?? [];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.15),
            YerimeBakColors.cyberNeonPurple.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            children: [
              Icon(
                Icons.calculate_outlined,
                color: YerimeBakColors.cyberNeonTurquoise,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sistem Tahmini Piyasa Değeri',
                  style: TextStyle(
                    color: YerimeBakColors.cyberNeonTurquoise,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Ana değer kartı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Final Değer
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Final Değer',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${finalValue.toStringAsFixed(0)} TL',
                      style: TextStyle(
                        color: YerimeBakColors.cyberNeonTurquoise,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Temel Fiyat
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Temel Fiyat',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${basePrice.toStringAsFixed(0)} TL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Ayarlamalar listesi
          if (adjustments.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Ayarlamalar:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...adjustments.map((adj) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• $adj',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            )),
          ],
          
          // Bilgi notu
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: YerimeBakColors.cyberNeonPurple,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bu değer AI analizinden bağımsız olarak paket ağırlığına göre hesaplanmıştır',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
