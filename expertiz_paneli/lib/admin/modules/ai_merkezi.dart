import 'package:flutter/material.dart';
import '../../../widgets/ai/ai_skor_gosterge_widget.dart';
import '../../../models/ai/ai_skor_model.dart';
import '../../../models/arac_rapor_model.dart';
import '../../screens/rapor_detay_sayfasi.dart';
import '../../../services/rapor_service.dart';
import '../../../models/expertiz/tam_rapor_model.dart';
import '../../../core/constants/yerimebak_colors.dart';

/// AI Merkezi Modülü
/// Yapay zeka analizlerini ve AI ile ilgili işlemleri yönetir
/// 
/// AI CENTER ACTIVATION PROTOCOL:
/// - Global Analytics: 3 ana AISkorGostergeWidget (boyut: 150)
/// - Smart Lists: AI Fırsat Radarı ve Kritik Uyarılar
/// - Real-time Sync: AIAnalizService ile veri çekimi
class AIMerkezi extends StatefulWidget {
  const AIMerkezi({super.key});

  @override
  State<AIMerkezi> createState() => _AIMerkeziState();
}

class _AIMerkeziState extends State<AIMerkezi> {
  bool _loading = true;
  List<TamRaporModel> _validReports = [];
  double _sistemGenelPuani = 0.0;
  double _ortalamaKarPotansiyeli = 0.0;
  double _riskOrani = 0.0;
  int _kritikRiskliAracSayisi = 0;

  @override
  void initState() {
    super.initState();
    _loadSystemData();
  }

  Future<void> _loadSystemData() async {
    if (!mounted) return;
    
    setState(() {
      _loading = true;
    });

    try {
      // SİSTEMDEKİ GERÇEK RAPORLARI ÇEK
      final result = await RaporService.getAllReports();
      
      if (!result.isSuccess) {
        throw Exception(result.error);
      }

      final tamRaporlar = result.data ?? [];
      
      // AI analiz sonucu mühürlenmiş raporları filtrele
      _validReports = tamRaporlar
          .where((r) => r.aiAnalizSonucu != null && r.aiAnalizSonucu!.tamamlandiMi)
          .toList();

      if (!mounted) return;

      // İstatistikleri dinamik olarak hesapla
      if (_validReports.isNotEmpty) {
        final analizler = _validReports.map((r) => r.aiAnalizSonucu!).toList();
        
        // 1. Sistem Genel Puanı (Ortalama)
        _sistemGenelPuani = analizler.map((a) => a.skorlar.genelPuan).reduce((a, b) => a + b) / analizler.length;
        
        // 2. Ortalama Kar Potansiyeli (%)
        double toplamKarYuzdesi = 0.0;
        for (var a in analizler) {
          final t = a.raporOzeti.tahminiDeger;
          final p = a.raporOzeti.degerProjeksiyonu1Yil;
          if (t > 0) {
            toplamKarYuzdesi += ((p - t) / t) * 100;
          }
        }
        _ortalamaKarPotansiyeli = (toplamKarYuzdesi / analizler.length).clamp(0, 100);
        
        // 3. Risk Oranı ve Kritik Araç Sayısı
        _kritikRiskliAracSayisi = analizler.where((a) => a.skorlar.genelPuan < 50).length;
        _riskOrani = (_kritikRiskliAracSayisi / analizler.length) * 100;
      } else {
        _sistemGenelPuani = 0.0;
        _ortalamaKarPotansiyeli = 0.0;
        _riskOrani = 0.0;
        _kritikRiskliAracSayisi = 0;
      }

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('AI Merkezi Veri Yükleme Hatası: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<TamRaporModel> _getFirsatAraclari() {
    // Skor > 80 olan yüksek kar potansiyelli araçlar
    return _validReports.where((r) => r.aiAnalizSonucu!.skorlar.genelPuan > 80).toList();
  }

  List<TamRaporModel> _getKritikUyarilar() {
    // Skor < 40 olan kritik riskli araçlar
    return _validReports.where((r) => r.aiAnalizSonucu!.skorlar.genelPuan < 40).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadSystemData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // GLOBAL ANALYTICS - 3 Ana Gauge
                  Card(
                    elevation: 4,
                    color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sistem Geneli İstatistikler',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              // Sistem Genel Puanı
                              Expanded(
                                child: AISkorGostergeWidget(
                                  skorlar: AISkorModel(
                                    aracDurumuPuan: _sistemGenelPuani,
                                    motorMekanikPuan: _sistemGenelPuani,
                                    hasarPuan: _sistemGenelPuani,
                                    genelPuan: _sistemGenelPuani,
                                    detayliPuanlar: {},
                                    puanDegerlendirmesi: _sistemGenelPuani >= 80 ? 'Çok İyi' : 
                                                      _sistemGenelPuani >= 60 ? 'İyi' : 'Orta',
                                  ),
                                  baslik: 'Sistem Genel Puanı',
                                  boyut: 150,
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Toplam Kar Potansiyeli
                              Expanded(
                                child: AISkorGostergeWidget(
                                  skorlar: AISkorModel(
                                    aracDurumuPuan: _ortalamaKarPotansiyeli,
                                    motorMekanikPuan: _ortalamaKarPotansiyeli,
                                    hasarPuan: _ortalamaKarPotansiyeli,
                                    genelPuan: _ortalamaKarPotansiyeli,
                                    detayliPuanlar: {},
                                    puanDegerlendirmesi: _ortalamaKarPotansiyeli >= 15 ? 'Yüksek Kar' : 'Stabil Kar',
                                  ),
                                  baslik: 'Ortalama Kar %\n(Analiz Radarı)',
                                  boyut: 150,
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Kritik Risk Oranı
                              Expanded(
                                child: AISkorGostergeWidget(
                                  skorlar: AISkorModel(
                                    aracDurumuPuan: _riskOrani,
                                    motorMekanikPuan: _riskOrani,
                                    hasarPuan: _riskOrani,
                                    genelPuan: _riskOrani,
                                    detayliPuanlar: {},
                                    puanDegerlendirmesi: _riskOrani > 30 ? 'Yüksek Risk' : 'Düşük Risk',
                                  ),
                                  baslik: 'Sistem Risk Oranı\n(Kritik Araçlar %)',
                                  boyut: 150,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // SMART LISTS - İki Ana Bölüm
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI Fırsat Radarı
                      Expanded(
                        child: _buildSmartListCard(
                          isDarkMode: isDarkMode,
                          title: 'AI Fırsat Radarı',
                          icon: Icons.trending_up,
                          iconColor: Colors.green,
                          description: 'Kar potansiyeli yüksek araçlar',
                          items: _getFirsatAraclari(),
                          onTap: (rapor) => _navigateToDetayFromReport(rapor),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Kritik Uyarılar
                      Expanded(
                        child: _buildSmartListCard(
                          isDarkMode: isDarkMode,
                          title: 'Kritik Uyarılar',
                          icon: Icons.warning,
                          iconColor: Colors.red,
                          description: 'Acil müdahale gereken raporlar',
                          items: _getKritikUyarilar(),
                          onTap: (rapor) => _navigateToDetayFromReport(rapor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // GRAFİKLER VE ANALİZ DETAYLARI - Placeholder
                  const SizedBox(
                    height: 200,
                    child: Card(
                      elevation: 4,
                      color: Color(0xFFF5F5F5),
                      child: Center(
                        child: Text(
                          'Grafikler bölümü yakında eklenecek',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSmartListCard({
    required bool isDarkMode,
    required String title,
    required IconData icon,
    required Color iconColor,
    required String description,
    required List<TamRaporModel> items,
    required Function(TamRaporModel) onTap,
  }) {
    return Card(
      elevation: 4,
      color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey[400] : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Center(
                child: Text(
                  'Kayıt yok',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              )
            else
              ...List.generate(items.length, (index) {
                final rapor = items[index];
                final analiz = rapor.aiAnalizSonucu!;
                final puan = analiz.skorlar.genelPuan;
                final renk = _getPuanRengi(puan);
                final plaka = rapor.adim1.plaka;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 2,
                  color: isDarkMode ? const Color(0xFF252525) : Colors.white,
                  child: InkWell(
                    onTap: () => onTap(rapor),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            _getPuanIkonu(puan),
                            color: renk,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plaka,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: YerimeBakColors.cyberNeonTurquoise,
                                  ),
                                ),
                                Text(
                                  '${analiz.raporOzeti.genelSonuc} - AI Puanı: ${puan.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.grey[300] : const Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 16),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _navigateToDetayFromReport(TamRaporModel tamRapor) async {
    if (!mounted) return;
    
    setState(() => _loading = true);
    
    try {
      final analiz = tamRapor.aiAnalizSonucu!;
      final aracRapor = AracRapor(
        id: tamRapor.gorevId,
        musteriId: 'system',
        personelId: tamRapor.personelId,
        olusturmaTarihi: tamRapor.baslangicZamani,
        durum: tamRapor.durum,
        plaka: tamRapor.adim1.plaka,
        marka: tamRapor.adim1.marka,
        model: tamRapor.adim1.model,
        yil: tamRapor.adim1.yil ?? '',
        sehir: 'İstanbul',
        secilenPaket: 'Standart',
        hizmetBedeli: 0,
        paketFiyati: 0,
        toplamTutar: 0,
        hasarTutar: 0,
        aiAnaliziYapildiMi: true,
        aiAnalizSonucu: analiz,
      );

      if (!mounted || !context.mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RaporDetaySayfasi(
            reportId: tamRapor.gorevId,
            rapor: aracRapor,
            aracBilgileri: tamRapor.adim1.toJson(),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Detay navigasyon hatası: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _getPuanRengi(double puan) {
    if (puan >= 71) return Colors.green;
    if (puan >= 41) return Colors.orange;
    return Colors.red;
  }

  IconData _getPuanIkonu(double puan) {
    if (puan >= 71) return Icons.check_circle;
    if (puan >= 41) return Icons.info;
    return Icons.warning;
  }
}
