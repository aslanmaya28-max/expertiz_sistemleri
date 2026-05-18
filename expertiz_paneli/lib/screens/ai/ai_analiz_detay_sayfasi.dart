import 'package:flutter/material.dart';
import '../../models/expertiz/adim1_arac_satici_model.dart';
import '../../models/ai/ai_analiz_sonucu_model.dart';
import '../../widgets/ai/ai_skor_gosterge_widget.dart';
import '../../widgets/ai/ai_oneri_karti_widget.dart';
import '../../widgets/ai/ai_analiz_ozet_widget.dart';
import '../../widgets/cyber/neon_approval_badge.dart';

/// AI Analiz Detay Sayfası
/// Tüm AI analiz sonuçlarını gösteren ana ekran
class AIAnalizDetaySayfasi extends StatefulWidget {
  final AIAnalizSonucu analizSonucu;
  final Adim1AracSaticiModel aracBilgileri;

  const AIAnalizDetaySayfasi({
    super.key,
    required this.analizSonucu,
    required this.aracBilgileri,
  });

  @override
  State<AIAnalizDetaySayfasi> createState() => _AIAnalizDetaySayfasiState();
}

class _AIAnalizDetaySayfasiState extends State<AIAnalizDetaySayfasi>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      _animationController,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.indigo),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'AI Analiz Sonuçları',
          style: TextStyle(
            color: Colors.indigo,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Neon Onay Mührü - AI puanı 80'in altındaysa göster
          if (widget.analizSonucu.skorlar.genelPuan < 80)
            NeonApprovalBadge(hasCriticalRisk: true),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Araç Bilgileri Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.indigo.shade900,
                    Colors.indigo.shade700,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.aracBilgileri.marka} ${widget.aracBilgileri.model}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.aracBilgileri.plaka,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${widget.aracBilgileri.guncelKm} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.indigo,
                labelColor: Colors.indigo,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'Özet'),
                  Tab(text: 'Puanlar'),
                  Tab(text: 'Öneriler'),
                ],
              ),
            ),
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Özet
                  _buildOzetTab(),
                  // Tab 2: Puanlar
                  _buildPuanlarTab(),
                  // Tab 3: Öneriler
                  _buildOnerilerTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOzetTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          AIAnalizOzetWidget(raporOzeti: widget.analizSonucu.raporOzeti),
          const SizedBox(height: 16),
          _buildKritikSorunlarKarti(),
        ],
      ),
    );
  }

  Widget _buildPuanlarTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          AISkorGostergeWidget(
            skorlar: widget.analizSonucu.skorlar,
            baslik: 'Genel Puan',
            boyut: 250,
          ),
          const SizedBox(height: 24),
          _buildDetayliPuanlarKarti(),
        ],
      ),
    );
  }

  Widget _buildOnerilerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: AIOneriKartiWidget(
        oneriler: widget.analizSonucu.oneriler,
        baslik: 'AI Önerileri',
      ),
    );
  }

  Widget _buildKritikSorunlarKarti() {
    if (widget.analizSonucu.kritikSorunlar.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded, color: Colors.red, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kritik Sorunlar',
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.analizSonucu.kritikSorunlar.map((sorun) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sorun,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetayliPuanlarKarti() {
    final detayliPuanlar = widget.analizSonucu.skorlar.detayliPuanlar;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Text(
              'Detaylı Puanlar',
              style: TextStyle(
                color: Colors.indigo.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: detayliPuanlar.entries.map((entry) {
                final baslik = _getPuanBasligi(entry.key);
                final puan = entry.value;
                final renk = _getPuanRengi(puan);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          baslik,
                          style: TextStyle(
                            color: Colors.blueGrey.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: renk.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: renk, width: 2),
                        ),
                        child: Text(
                          puan.toStringAsFixed(1),
                          style: TextStyle(
                            color: renk,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getPuanBasligi(String key) {
    switch (key) {
      case 'adim1':
        return 'Adım 1: Araç & Satıcı';
      case 'adim2':
        return 'Adım 2: Dış Ekspertiz';
      case 'adim3':
        return 'Adım 3: İç Ekspertiz';
      case 'adim4':
        return 'Adım 4: Boya & Kaporta';
      case 'adim5':
        return 'Adım 5: Kurumsal Ekspertiz';
      case 'aracDurumu':
        return 'Araç Durumu';
      case 'motorMekanik':
        return 'Motor/Mekanik';
      case 'hasar':
        return 'Hasar Durumu';
      default:
        return key;
    }
  }

  Color _getPuanRengi(double puan) {
    if (puan >= 71) return Colors.green;
    if (puan >= 41) return Colors.orange;
    return Colors.red;
  }
}
