// PHASE 6.4 - Admin Dashboard Migration to Riverpod
// 
// ARCHITECTURE:
// - ConsumerWidget with Riverpod state management
// - ReportStateProvider for all data operations
// - Optimistic updates with automatic rollback
// - Conflict detection and resolution
// - Operational History Panel integration
// - Real-time sync across all panels

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../providers/report_state_provider.dart';
import '../../core/theme/futuristic_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/dashboard_stats.dart';
import '../../widgets/slide_action.dart';
import 'widgets/operational_history_panel.dart';
import 'modules/finans_yonetimi.dart';
import 'modules/arac_operasyonu.dart';
import '../../core/mappers/location_mapper.dart';
import '../../widgets/status_chip.dart';
import '../../services/personel_service.dart';
import '../../models/personel_model.dart';
import '../../screens/personel/personel_bolge_sistemi.dart';

// ========================================
// MODELS
// ========================================

class AdminMusteriModel {
  final String id;
  final String adSoyad;
  final String email;
  final String telefon;
  final int ilId;
  final String ilce;
  final int toplamExpertiz;
  final double toplamOdeme;
  final DateTime kayitTarihi;

  AdminMusteriModel({
    required this.id,
    required this.adSoyad,
    required this.email,
    required this.telefon,
    required this.ilId,
    required this.ilce,
    required this.toplamExpertiz,
    required this.toplamOdeme,
    required this.kayitTarihi,
  });

  String get ilAdi => LocationMapper().getIlAdi(ilId);
}

class AdminRaporTalepModel {
  final String id;
  final String baslik;
  final String musteriAdi;
  final String musteriId;
  final String aracPlaka;
  final String durum;
  final DateTime talepTarihi;
  final String? aciklama;
  final String? notlar;
  final String? raporUrl;
  final String? personelId;
  final double? ucret;
  final int? aiScore;

  AdminRaporTalepModel({
    required this.id,
    required this.baslik,
    required this.musteriAdi,
    required this.musteriId,
    required this.aracPlaka,
    required this.durum,
    required this.talepTarihi,
    this.aciklama,
    this.notlar,
    this.raporUrl,
    this.personelId,
    this.ucret,
    this.aiScore,
  });

  AdminRaporTalepModel copyWith({
    String? id,
    String? baslik,
    String? musteriAdi,
    String? musteriId,
    String? aracPlaka,
    String? durum,
    DateTime? talepTarihi,
    String? aciklama,
    String? notlar,
    String? raporUrl,
    String? personelId,
    double? ucret,
    int? aiScore,
  }) {
    return AdminRaporTalepModel(
      id: id ?? this.id,
      baslik: baslik ?? this.baslik,
      musteriAdi: musteriAdi ?? this.musteriAdi,
      musteriId: musteriId ?? this.musteriId,
      aracPlaka: aracPlaka ?? this.aracPlaka,
      durum: durum ?? this.durum,
      talepTarihi: talepTarihi ?? this.talepTarihi,
      aciklama: aciklama ?? this.aciklama,
      notlar: notlar ?? this.notlar,
      raporUrl: raporUrl ?? this.raporUrl,
      personelId: personelId ?? this.personelId,
      ucret: ucret ?? this.ucret,
      aiScore: aiScore ?? this.aiScore,
    );
  }
}

// ========================================
// MAIN DASHBOARD WIDGET
// ========================================

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Bulk Seal UI State (local, not provider)
  final Set<String> _selectedReportIds = {};
  bool _isBulkActionInProgress = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    
    // Check for conflicts after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(reportStateProvider);
      if (state.hasConflict) {
        _showConflictDialog();
      }
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  // ========================================
  // BULK SEAL HELPERS
  // ========================================
  
  void _toggleReportSelection(String reportId) {
    setState(() {
      if (_selectedReportIds.contains(reportId)) {
        _selectedReportIds.remove(reportId);
      } else {
        _selectedReportIds.add(reportId);
      }
    });
  }
  
  void _selectAllSafeReports(Iterable<AdminRaporTalepModel> reports) {
    setState(() {
      _selectedReportIds.clear();
      for (final rapor in reports) {
        // Only select if AI score >= 95 and not already sealed
        if ((rapor.aiScore ?? 0) >= 95 && 
            rapor.durum != 'published' && 
            rapor.durum != 'Gönderildi') {
          _selectedReportIds.add(rapor.id);
        }
      }
    });
  }
  
  void _clearSelection() {
    setState(() {
      _selectedReportIds.clear();
    });
  }
  
  Future<void> _handleBulkSeal(Iterable<AdminRaporTalepModel> reports) async {
    if (_selectedReportIds.isEmpty) return;
    
    // Check if any selected report has AI score < 95
    final lowScoreReports = reports
        .where((r) => _selectedReportIds.contains(r.id))
        .where((r) => (r.aiScore ?? 0) < 95)
        .toList();
    
    if (lowScoreReports.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Düşük AI Skor Uyarısı'),
            ],
          ),
          content: Text(
            'Seçilen ${lowScoreReports.length} raporun AI skoru %95\'in altında. '
            'Yine de mühürlemek istiyor musunuz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text('Yine de Mühürle'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;
    }
    
    setState(() => _isBulkActionInProgress = true);
    
    try {
      final notifier = ref.read(reportStateProvider.notifier);
      final result = await notifier.bulkSealReports(_selectedReportIds.toList());
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${result.successCount} rapor başarıyla mühürlendi'
            '${result.failureCount > 0 ? ", ⚠️ ${result.failureCount} başarısız" : ""}',
          ),
          backgroundColor: result.failureCount > 0 ? Colors.orange : Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
      
      _clearSelection();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBulkActionInProgress = false);
      }
    }
  }

  void _showConflictDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Veri Güncel Değil'),
          ],
        ),
        content: Text(
          'Bu rapor başka bir kullanıcı tarafından güncellendi. '
          'En son verileri görmek için sayfayı yenilemek ister misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(reportStateProvider.notifier).clearConflict();
              ref.read(reportStateProvider.notifier).refresh();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Veriler yenilendi'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('Yenile'),
          ),
        ],
      ),
    );
  }

  void _showOperationalHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: OperationalHistoryPanel(
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch all data sources
    final reports = ref.watch(adminReportsProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final state = ref.watch(reportStateProvider);
    final personelService = ref.watch(personelServiceProvider);
    final locationMapper = LocationMapper();

    // Show loading if stats not loaded
    if (stats == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Dashboard yükleniyor...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    // Show conflict snackbar if needed
    if (state.hasConflict) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Veri çakışması tespit edildi. Yenileyin.'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Yenile',
              textColor: Colors.white,
              onPressed: () {
                ref.read(reportStateProvider.notifier).clearConflict();
                ref.read(reportStateProvider.notifier).refresh();
              },
            ),
            duration: Duration(seconds: 5),
          ),
        );
      });
    }

    return Scaffold(
      body: Column(
        children: [
          // HEADER with Operational History Button
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: FuturisticTheme.bgSecondary,
              border: Border(
                bottom: BorderSide(
                  color: FuturisticTheme.neon.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: FuturisticTheme.neon, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin Dashboard', style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      )),
                      Text(DateFormat('dd MMMM yyyy, EEEE').format(DateTime.now()), style: TextStyle(
                        color: Colors.white54,
                      )),
                    ],
                  ),
                ),
                // Operational History Button
                IconButton(
                  icon: Icon(Icons.history, color: FuturisticTheme.neon),
                  tooltip: 'İşlem Geçmişi',
                  onPressed: _showOperationalHistory,
                ),
                IconButton(
                  icon: Icon(Icons.notifications, color: FuturisticTheme.neon),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Bildirimler özelliği devre dışı')),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.exit_to_app, color: FuturisticTheme.neon),
                  onPressed: () => _cikisYap(context),
                ),
              ],
            ),
          ),
          // TABS
          Container(
            color: FuturisticTheme.bgSecondary,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: FuturisticTheme.neon,
              unselectedLabelColor: Colors.white54,
              indicatorColor: FuturisticTheme.neon,
              tabs: [
                Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
                Tab(icon: Icon(Icons.directions_car), text: 'Araç Operasyonu'),
                Tab(icon: Icon(Icons.people), text: 'Personel'),
                Tab(icon: Icon(Icons.person), text: 'Müşteriler'),
                Tab(icon: Icon(Icons.description), text: 'Raporlar'),
                Tab(icon: Icon(Icons.psychology), text: 'AI Merkezi'),
                Tab(icon: Icon(Icons.attach_money), text: 'Finans Yönetimi'),
                Tab(icon: Icon(Icons.settings), text: 'Ayarlar'),
              ],
            ),
          ),
          // BODY
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDashboard(reports, stats, state, personelService, locationMapper),
                const AracOperasyonu(),
                PersonelBolgePaneli(
                  personeller: personelService.personeller.map((p) => p.toMap()).toList(),
                  onPersonelEkle: (p) => _personelEkle(PersonelModel.fromMap(p)),
                  onPersonelDuzenle: (p) => _personelDuzenle(PersonelModel.fromMap(p)),
                  onPersonelSil: (p) => _personelSil(PersonelModel.fromMap(p).id),
                  onPersonelAktiflikDegistir: (p) => _personelAktiflikDegistir(PersonelModel.fromMap(p)),
                ),
                _buildMusterilerTab(),
                _buildRaporlarTab(reports, state),
                Container(), // AI Merkezi
                const FinansYonetimi(),
                const Text('Ayarlar'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // DASHBOARD TAB
  // ========================================

  Widget _buildDashboard(
    Iterable<Map<String, dynamic>> reports,
    DashboardStats stats,
    ReportState state,
    PersonelService personelService,
    LocationMapper locationMapper,
  ) {
    // Convert reports to typed models for display
    final reportModels = reports.map((r) => _mapToReportModel(r)).toList();
    final gelenRaporlar = reportModels.where((r) => 
      r.durum == 'Beklemede' || r.durum == 'İncelemede' || r.durum == 'Personele Atandı'
    ).toList();
    final gonderilecekRaporlar = reportModels.where((r) => 
      r.durum == 'Hazır' || r.durum == 'Gönderim Bekliyor' || r.durum == 'Gönderildi'
    ).toList();

    // Calculate region counters
    final Map<int, int> bolgeCounters = {};
    for (final personel in personelService.personeller) {
      bolgeCounters[personel.bolgeId] = (bolgeCounters[personel.bolgeId] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İstatistik Kartları
          Row(
            children: [
              Expanded(child: _buildStatCard('Toplam Araç', stats.totalVehicles.toString(), Icons.directions_car, Colors.blue)),
              SizedBox(width: 12),
              Expanded(child: _buildStatCard('Aktif Raporlar', stats.activeReports.toString(), Icons.description, Colors.orange)),
              SizedBox(width: 12),
              Expanded(child: _buildStatCard('Bugün Yayınlanan', stats.todayPublished.toString(), Icons.check_circle, Colors.green)),
              SizedBox(width: 12),
              Expanded(child: _buildStatCard('Bugün Gönderilen', stats.todaySubmitted.toString(), Icons.upload, Colors.purple)),
            ],
          ),
          SizedBox(height: 20),
          
          // Bölge Sayaçları
          Text('Bölgeye Göre Personel Dağılımı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: FuturisticTheme.neon)),
          SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: locationMapper.getAllBolgeIds().map((bolgeId) {
              final bolgeAdi = locationMapper.getBolgeAdi(bolgeId);
              final count = bolgeCounters[bolgeId] ?? 0;
              final renk = locationMapper.getBolgeRenk(bolgeId);
              return _buildBolgeStatCard(bolgeAdi, count, renk);
            }).toList(),
          ),
          
          SizedBox(height: 20),
          
          // Gelen Raporlar with Seal Actions
          if (gelenRaporlar.isNotEmpty) ...[
            Row(
              children: [
                Text('Gelen Raporlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: FuturisticTheme.neon)),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: FuturisticTheme.neon.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FuturisticTheme.neon),
                  ),
                  child: Text(
                    '${gelenRaporlar.length}',
                    style: TextStyle(
                      color: FuturisticTheme.neon,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...gelenRaporlar.map((rapor) => _buildRaporCard(rapor, state)),
          ],
          
          if (gonderilecekRaporlar.isNotEmpty) ...[
            SizedBox(height: 20),
            Text('Gönderilecek Raporlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: FuturisticTheme.neon)),
            SizedBox(height: 12),
            ...gonderilecekRaporlar.map((rapor) => _buildRaporCard(rapor, state)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return GlassCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 14, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildBolgeStatCard(String bolgeAdi, int count, Color renk) {
    return GlassCard(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: renk, width: 2),
            ),
            child: Icon(Icons.location_city, color: renk, size: 24),
          ),
          SizedBox(height: 8),
          Text(count.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: renk)),
          SizedBox(height: 4),
          Text(bolgeAdi, style: TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  // ========================================
  // REPORT CARD with Quick Review, Safety Seal & Bulk Seal
  // ========================================

  Widget _buildRaporCard(AdminRaporTalepModel rapor, ReportState state) {
    final personelService = ref.watch(personelServiceProvider);
    final availablePersoneller = personelService.personeller.toList();
    final isSelected = _selectedReportIds.contains(rapor.id);
    final isSealed = rapor.durum == 'published' || rapor.durum == 'Gönderildi';

    return GlassCard(
      child: Container(
        decoration: isSelected ? BoxDecoration(
          border: Border.all(color: FuturisticTheme.neon, width: 2),
          borderRadius: BorderRadius.circular(12),
        ) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER with Checkbox
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Bulk Seal Checkbox
                  Checkbox(
                    value: isSelected,
                    onChanged: isSealed ? null : (value) {
                      _toggleReportSelection(rapor.id);
                    },
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return FuturisticTheme.neon;
                      }
                      return Colors.white24;
                    }),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rapor.baslik, style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        )),
                        SizedBox(height: 4),
                        Text('Müşteri: ${rapor.musteriAdi} • Plaka: ${rapor.aracPlaka}',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  // Quick Review Button
                  OutlinedButton.icon(
                    onPressed: () => _openQuickReviewDrawer(rapor),
                    icon: Icon(Icons.speed, size: 18),
                    label: Text('Hızlı İnceleme'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FuturisticTheme.neon,
                      side: BorderSide(color: FuturisticTheme.neon.withValues(alpha: 0.5)),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            
            // DETAILS
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI Score & Price
                  Row(
                    children: [
                      if (rapor.aiScore != null)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (rapor.aiScore! >= 95 ? Colors.green : Colors.orange).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: rapor.aiScore! >= 95 ? Colors.green : Colors.orange,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.psychology, size: 14, color: rapor.aiScore! >= 95 ? Colors.green : Colors.orange),
                              SizedBox(width: 4),
                              Text('AI: %${rapor.aiScore}', style: TextStyle(
                                color: rapor.aiScore! >= 95 ? Colors.green : Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              )),
                            ],
                          ),
                        ),
                      SizedBox(width: 8),
                      StatusChip(durum: rapor.durum),
                    ],
                  ),
                  SizedBox(height: 8),
                  
                  // ACTION BUTTONS
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showPersonelAtamaDialog(rapor, availablePersoneller),
                          icon: Icon(Icons.person_add, size: 16),
                          label: Text(rapor.personelId?.isNotEmpty == true ? 'Personeli Değiştir' : 'Personel Ata'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FuturisticTheme.neon.withValues(alpha: 0.2),
                            foregroundColor: FuturisticTheme.neon,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            textStyle: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      if (!isSealed) ...[
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildSafetySealButton(rapor.id, state),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // SAFETY SEAL - SLIDE ACTION
  // ========================================

  Widget _buildSafetySealButton(String reportId, ReportState state) {
    return SlideAction(
      text: state.isLoading ? 'Mühürleniyor...' : 'Mühürlemek için kaydır',
      textStyle: TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
      outerColor: Colors.red.withValues(alpha: 0.3),
      innerColor: Colors.green,
      height: 42,
      sliderButtonIcon: Icon(
        state.isLoading ? Icons.hourglass_empty : Icons.verified,
        color: Colors.white,
        size: 20,
      ),
      onSubmit: () async {
        HapticFeedback.mediumImpact();
        await _sealReport(reportId);
      },
      submitted: false,
    );
  }

  // ========================================
  // QUICK REVIEW DRAWER
  // ========================================

  void _openQuickReviewDrawer(AdminRaporTalepModel rapor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                FuturisticTheme.bgSecondary.withValues(alpha: 0.98),
                FuturisticTheme.bgPrimary.withValues(alpha: 0.98),
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: FuturisticTheme.neon.withValues(alpha: 0.3), width: 2),
          ),
          child: Column(
            children: [
              // HANDLE
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // HEADER
              Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.speed, color: FuturisticTheme.neon, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('HIZLI İNCELEME', style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          )),
                          Text(rapor.baslik, style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          )),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              Divider(color: Colors.white12, height: 1),
              
              // CONTENT
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI Score Badge
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              (rapor.aiScore ?? 0) >= 95 
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.orange.withValues(alpha: 0.2),
                              (rapor.aiScore ?? 0) >= 95
                                  ? Colors.green.withValues(alpha: 0.05)
                                  : Colors.orange.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (rapor.aiScore ?? 0) >= 95 ? Colors.green : Colors.orange,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.psychology,
                              size: 32,
                              color: (rapor.aiScore ?? 0) >= 95 ? Colors.green : Colors.orange,
                            ),
                            SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('AI Güven Skoru', style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                )),
                                Text(
                                  '%${rapor.aiScore ?? 0}',
                                  style: TextStyle(
                                    color: (rapor.aiScore ?? 0) >= 95 ? Colors.green : Colors.orange,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      
                      // Info Cards
                      _buildQuickReviewInfoCard(
                        Icons.description,
                        'Açıklama',
                        rapor.aciklama ?? 'Açıklama yok',
                      ),
                      SizedBox(height: 12),
                      _buildQuickReviewInfoCard(
                        Icons.attach_money,
                        'Ücret',
                        rapor.ucret != null ? '₺${rapor.ucret!.toStringAsFixed(2)}' : 'Belirtilmemiş',
                      ),
                      SizedBox(height: 12),
                      _buildQuickReviewInfoCard(
                        Icons.person,
                        'Atanan Personel',
                        rapor.personelId?.isNotEmpty == true ? 'Atandı' : 'Atanmadı',
                      ),
                      SizedBox(height: 20),
                      
                      // ACTIONS
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: Icon(Icons.close),
                              label: Text('Kapat'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: BorderSide(color: Colors.white24),
                                padding: EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: rapor.durum != 'published' && rapor.durum != 'Gönderildi'
                                  ? () {
                                      Navigator.pop(context);
                                      _sealReport(rapor.id);
                                    }
                                  : null,
                              icon: Icon(Icons.verified),
                              label: Text('Mühürle & Yayınla'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.withValues(alpha: 0.2),
                                foregroundColor: Colors.green,
                                disabledBackgroundColor: Colors.white12,
                                disabledForegroundColor: Colors.white24,
                                padding: EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickReviewInfoCard(IconData icon, String title, String content) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: FuturisticTheme.neon, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                )),
                SizedBox(height: 4),
                Text(content, style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // ACTIONS
  // ========================================

  Future<void> _sealReport(String reportId) async {
    final notifier = ref.read(reportStateProvider.notifier);
    final success = await notifier.sealReport(reportId);
    
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Rapor başarıyla mühürlendi ve yayınlandı'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      final state = ref.read(reportStateProvider);
      if (state.hasConflict) {
        _showConflictDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text(state.error ?? 'Mühürleme başarısız'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showPersonelAtamaDialog(
    AdminRaporTalepModel rapor,
    List<PersonelModel> availablePersoneller,
  ) {
    final locationMapper = LocationMapper();
    
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: 500, maxHeight: 600),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                FuturisticTheme.bgSecondary.withValues(alpha: 0.95),
                FuturisticTheme.bgPrimary.withValues(alpha: 0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: FuturisticTheme.neon.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      FuturisticTheme.neon.withValues(alpha: 0.1),
                      FuturisticTheme.neon.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: FuturisticTheme.neon.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.person_add_alt_1,
                        color: FuturisticTheme.neon,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PERSONEL ATAMA',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            rapor.baslik,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Personel Listesi
              Flexible(
                child: availablePersoneller.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(Icons.person_off, size: 64, color: Colors.white.withValues(alpha: 0.3)),
                              SizedBox(height: 16),
                              Text(
                                'Uygun Personel Bulunamadı',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: availablePersoneller.length,
                        itemBuilder: (context, index) {
                          final personel = availablePersoneller[index];
                          final ilAdi = locationMapper.getIlAdi(personel.ilId);
                          final isSelected = rapor.personelId == personel.id;
                          
                          return AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            margin: EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(
                                      colors: [
                                        FuturisticTheme.neon.withValues(alpha: 0.3),
                                        FuturisticTheme.neon.withValues(alpha: 0.1),
                                      ],
                                    )
                                  : LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.05),
                                        Colors.white.withValues(alpha: 0.02),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? FuturisticTheme.neon
                                    : Colors.white.withValues(alpha: 0.1),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          colors: [
                                            FuturisticTheme.neon,
                                            FuturisticTheme.neon.withValues(alpha: 0.6),
                                          ],
                                        )
                                      : LinearGradient(
                                          colors: [
                                            Colors.white.withValues(alpha: 0.1),
                                            Colors.white.withValues(alpha: 0.05),
                                          ],
                                        ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                                  size: 28,
                                ),
                              ),
                              title: Text(
                                personel.adSoyad ?? personel.tamAd,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: 14, color: FuturisticTheme.neon),
                                      SizedBox(width: 4),
                                      Text(
                                        ilAdi,
                                        style: TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                      SizedBox(width: 12),
                                      Icon(Icons.work, size: 14, color: FuturisticTheme.neon),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          personel.uzmanlikAlani ?? personel.unvan,
                                          style: TextStyle(color: Colors.white70, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: isSelected
                                  ? Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: FuturisticTheme.neon,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.check, color: Colors.white, size: 20),
                                    )
                                  : null,
                              onTap: () {
                                Navigator.of(dialogContext).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Personel atandı: ${personel.adSoyad ?? personel.tamAd}'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
              
              // Footer
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: Icon(Icons.close, color: Colors.white70),
                        label: Text('İptal', style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================
  // MÜŞTERİLER TAB
  // ========================================

  Widget _buildMusterilerTab() {
    final mockMusteriler = [
      AdminMusteriModel(
        id: 'M001',
        adSoyad: 'Ahmet Yılmaz',
        email: 'ahmet@email.com',
        telefon: '+905551234567',
        ilId: 34,
        ilce: 'Kadıköy',
        toplamExpertiz: 5,
        toplamOdeme: 18700,
        kayitTarihi: DateTime.now().subtract(Duration(days: 120)),
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Müşteriler', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: FuturisticTheme.neon)),
          SizedBox(height: 20),
          ...mockMusteriler.map((musteri) => _buildMusteriCard(musteri)),
        ],
      ),
    );
  }

  Widget _buildMusteriCard(AdminMusteriModel musteri) {
    final locationMapper = LocationMapper();
    final ilAdi = locationMapper.getIlAdi(musteri.ilId);
    
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ListTile(
          title: Text(musteri.adSoyad, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: ${musteri.email}', style: TextStyle(color: Colors.white70)),
              Text('Konum: $ilAdi, ${musteri.ilce}', style: TextStyle(color: Colors.white70)),
              Text('Toplam Expertiz: ${musteri.toplamExpertiz}', style: TextStyle(color: Colors.white70)),
              Text('Toplam Ödeme: ₺${musteri.toplamOdeme.toStringAsFixed(2)}', style: TextStyle(color: FuturisticTheme.neon)),
            ],
          ),
          trailing: Icon(Icons.arrow_forward_ios, color: FuturisticTheme.neon),
        ),
      ),
    );
  }

  // ========================================
  // RAPORLAR TAB with Bulk Actions
  // ========================================

  Widget _buildRaporlarTab(Iterable<Map<String, dynamic>> reports, ReportState state) {
    final reportModels = reports.map((r) => _mapToReportModel(r)).toList();
    
    return Column(
      children: [
        // HEADER
        Container(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Text('Raporlar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: FuturisticTheme.neon)),
              SizedBox(width: 8),
              if (state.isBulkOperationInProgress || _isBulkActionInProgress)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Toplu İşlem...', style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        
        // BULK ACTIONS TOOLBAR (only visible if selection > 0)
        if (_selectedReportIds.isNotEmpty)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FuturisticTheme.neon.withValues(alpha: 0.15),
                  FuturisticTheme.neon.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FuturisticTheme.neon, width: 2),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.checklist, color: FuturisticTheme.neon, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_selectedReportIds.length} rapor seçildi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _clearSelection,
                      icon: Icon(Icons.close, size: 18),
                      label: Text('Seçimi Temizle'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectedReportIds.isEmpty ? null : () {
                          _selectAllSafeReports(reportModels);
                        },
                        icon: Icon(Icons.select_all, size: 18),
                        label: Text('AI ≥ 95 Olanları Seç'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FuturisticTheme.neon,
                          side: BorderSide(color: FuturisticTheme.neon.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedReportIds.isEmpty || _isBulkActionInProgress
                            ? null
                            : () => _handleBulkSeal(reportModels),
                        icon: Icon(Icons.done_all, size: 18),
                        label: Text('Seçilenleri Mühürle'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.withValues(alpha: 0.2),
                          foregroundColor: Colors.green,
                          disabledBackgroundColor: Colors.white12,
                          disabledForegroundColor: Colors.white24,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        
        // REPORT LIST
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...reportModels.map((rapor) => _buildRaporCard(rapor, state)),
              ],
            ),
          ),
        ),
        
        // BULK ACTIONS BOTTOM PANEL (always visible)
        if (_selectedReportIds.isNotEmpty)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FuturisticTheme.bgSecondary,
              border: Border(
                top: BorderSide(color: FuturisticTheme.neon.withValues(alpha: 0.3), width: 2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Icon(Icons.checklist, color: FuturisticTheme.neon),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_selectedReportIds.length} rapor seçili',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isBulkActionInProgress ? null : () => _handleBulkSeal(reportModels),
                    icon: _isBulkActionInProgress
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(Icons.done_all, size: 18),
                    label: Text(_isBulkActionInProgress ? 'İşleniyor...' : 'Toplu Mühürle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                      foregroundColor: Colors.green,
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white24,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ========================================
  // HELPERS
  // ========================================

  AdminRaporTalepModel _mapToReportModel(Map<String, dynamic> data) {
    return AdminRaporTalepModel(
      id: data['id']?.toString() ?? '',
      baslik: data['baslik']?.toString() ?? data['title']?.toString() ?? 'Rapor',
      musteriAdi: data['musteri_adi']?.toString() ?? data['customer_name']?.toString() ?? 'Bilinmiyor',
      musteriId: data['musteri_id']?.toString() ?? data['customer_id']?.toString() ?? '',
      aracPlaka: data['plaka']?.toString() ?? data['plate']?.toString() ?? '---',
      durum: data['durum']?.toString() ?? data['status']?.toString() ?? 'Beklemede',
      talepTarihi: data['talep_tarihi'] != null
          ? DateTime.parse(data['talep_tarihi'].toString())
          : DateTime.now(),
      aciklama: data['aciklama']?.toString(),
      notlar: data['notlar']?.toString(),
      raporUrl: data['rapor_url']?.toString(),
      personelId: data['personel_id']?.toString(),
      ucret: data['ucret'] is num ? (data['ucret'] as num).toDouble() : null,
      aiScore: data['ai_score'] is int ? data['ai_score'] as int : null,
    );
  }

  Future<void> _personelEkle(PersonelModel personel) async {
    try {
      final personelService = ref.read(personelServiceProvider.notifier);
      await personelService.addPersonel(personel);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Personel eklendi'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _personelDuzenle(PersonelModel personel) async {
    try {
      final personelService = ref.read(personelServiceProvider.notifier);
      await personelService.updatePersonel(personel);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Personel güncellendi'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _personelSil(String personelId) async {
    try {
      final personelService = ref.read(personelServiceProvider.notifier);
      await personelService.deletePersonel(personelId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Personel silindi'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _personelAktiflikDegistir(PersonelModel personel) async {
    try {
      final personelService = ref.read(personelServiceProvider.notifier);
      final updatedPersonel = personel.copyWith(aktif: !personel.aktif);
      await personelService.updatePersonel(updatedPersonel);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Personel durumu güncellendi'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _cikisYap(BuildContext context) async {
    // TODO: Implement logout via UserProvider
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}

// ========================================
// PROVIDERS
// ========================================

final personelServiceProvider = ChangeNotifierProvider<PersonelService>((ref) {
  return PersonelService();
});