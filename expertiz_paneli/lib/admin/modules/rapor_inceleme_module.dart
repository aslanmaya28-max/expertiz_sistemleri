import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/expertiz/tam_rapor_model.dart';
import '../../models/ai/ai_analiz_sonucu_model.dart';
import '../../providers/admin_provider.dart';
import '../../services/yerimebak_expertiz_api_service.dart';
import '../../core/theme/futuristic_theme.dart';

class RaporIncelemeModule extends StatefulWidget {
  const RaporIncelemeModule({super.key});

  @override
  State<RaporIncelemeModule> createState() => _RaporIncelemeModuleState();
}

class _RaporIncelemeModuleState extends State<RaporIncelemeModule>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allReports = [];
  Map<String, dynamic>? _selectedReport;
  TamRaporModel? _tamRapor;
  AIAnalizSonucu? _aiSonucu;
  bool _isLoading = true;
  bool _isProcessing = false;
  StreamSubscription? _reportSubscription;
  final YerimebakExpertizApiService _expertizApi = YerimebakExpertizApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadReports();
    _subscribeToReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reportSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('reports')
          .select()
          .inFilter('status', ['pending_admin', 'pending_ai', 'published', 'rejected', 'draft'])
          .order('status_updated_at', ascending: false);
      if (mounted) {
        setState(() {
          _allReports = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Rapor yukleme hatasi: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToReports() {
    try {
      final stream = Supabase.instance.client
          .from('reports')
          .stream(primaryKey: ['id'])
          .order('status_updated_at', ascending: false);
      _reportSubscription = stream.listen((data) {
        if (mounted) {
          setState(() {
            _allReports = List<Map<String, dynamic>>.from(data);
          });
        }
      });
    } catch (e) {
      debugPrint('Stream hatasi: $e');
    }
  }

  void _selectReport(Map<String, dynamic> report) {
    final tamRapor = _parseTamRapor(report);
    final aiSonuc = _parseAiSonuc(report);
    setState(() {
      _selectedReport = report;
      _tamRapor = tamRapor;
      _aiSonucu = aiSonuc;
    });
  }

  TamRaporModel? _parseTamRapor(Map<String, dynamic> report) {
    try {
      final data = report['data'];
      if (data is Map && data['tam_rapor'] is Map) {
        return TamRaporModel.fromJson(
            Map<String, dynamic>.from(data['tam_rapor'] as Map));
      }
    } catch (e) {
      debugPrint('TamRapor parse hatasi: $e');
    }
    return null;
  }

  AIAnalizSonucu? _parseAiSonuc(Map<String, dynamic> report) {
    try {
      final aiDetail = report['ai_analiz_detay'];
      if (aiDetail is Map) {
        return AIAnalizSonucu.fromJson(Map<String, dynamic>.from(aiDetail));
      }
      if (_tamRapor?.aiAnalizSonucu != null) {
        return _tamRapor!.aiAnalizSonucu;
      }
    } catch (e) {
      debugPrint('AI sonuc parse hatasi: $e');
    }
    return null;
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'pending_admin':
        return 'Admin Onayi Bekliyor';
      case 'pending_ai':
        return 'AI Analizi Bekliyor';
      case 'published':
        return 'Yayinlandi';
      case 'rejected':
        return 'Reddedildi';
      case 'draft':
        return 'Taslak';
      default:
        return status ?? 'Bilinmiyor';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending_admin':
        return Colors.orange;
      case 'pending_ai':
        return Colors.blue;
      case 'published':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }


  Map<String, dynamic> _reportData(Map<String, dynamic>? report) {
    final data = report?['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _aiMeta(Map<String, dynamic>? report) {
    final data = _reportData(report);
    final meta = data['ai_meta'];
    final ai = report?['ai_analysis_result'] ?? report?['ai_analiz_detay'];
    final aiMap = ai is Map ? Map<String, dynamic>.from(ai) : <String, dynamic>{};
    if (meta is Map) {
      final metaMap = Map<String, dynamic>.from(meta);
      return {
        'source': metaMap['source'] ?? aiMap['source'] ?? 'none',
        'official': metaMap['official'] == true || aiMap['official'] == true,
        'ready': metaMap['ready'] == true || report?['ai_analizi_yapildi_mi'] == true,
      };
    }
    return {
      'source': aiMap['source'] ?? 'none',
      'official': aiMap['official'] == true,
      'ready': report?['ai_analizi_yapildi_mi'] == true,
    };
  }

  bool _hasOfficialCentralAi(Map<String, dynamic>? report) {
    final meta = _aiMeta(report);
    return meta['source'] == 'central_ai' && meta['official'] == true && meta['ready'] == true;
  }

  bool _hasFlutterFallbackPreview(Map<String, dynamic>? report) {
    final data = _reportData(report);
    final preview = data['flutter_fallback_preview'];
    return preview is Map && preview['temporary'] == true;
  }

  Future<void> _approveAndPublish() async {
    if (_selectedReport == null) return;
    setState(() => _isProcessing = true);
    try {
      final reportId = _selectedReport!['id'] as String;
      await _expertizApi.publishReport(reportId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Rapor yayinlandi: $reportId'),
          backgroundColor: Colors.green,
        ));
      }
      await _loadReports();
      if (!mounted) return;
      await context.read<AdminProvider>().loadTalepler();
      if (!mounted) return;
      setState(() {
        _selectedReport = null;
        _tamRapor = null;
        _aiSonucu = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Yayinlama hatasi: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectReport() async {
    if (_selectedReport == null) return;
    final reasonController = TextEditingController();
    final String? reason;
    try {
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Raporu Reddet', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: reasonController,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Red nedenini yazin...',
              hintStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Iptal', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(reasonController.text),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reddet'),
            ),
          ],
        ),
      );
    } finally {
      reasonController.dispose();
    }
    if (!mounted) return;
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final reportId = _selectedReport!['id'] as String;
      await _expertizApi.rejectReport(reportId, reason.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Rapor reddedildi, personele iade edildi'),
          backgroundColor: Colors.orange,
        ));
      }
      await _loadReports();
      if (!mounted) return;
      setState(() {
        _selectedReport = null;
        _tamRapor = null;
        _aiSonucu = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Red hatasi: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FuturisticTheme.bgPrimary,
      body: Row(
        children: [
          Expanded(flex: 2, child: _buildReportList()),
          const VerticalDivider(width: 1, color: Colors.white12),
          Expanded(flex: 3, child: _buildReportDetail()),
        ],
      ),
    );
  }

  Widget _buildReportList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FuturisticTheme.bgSecondary,
            border: Border(
                bottom: BorderSide(color: FuturisticTheme.neon.withValues(alpha: 0.2))),
          ),
          child: Row(
            children: [
              const Icon(Icons.description, color: FuturisticTheme.neon, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Rapor Kuyrugu',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: FuturisticTheme.neon),
                onPressed: _loadReports,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _allReports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              size: 64, color: Colors.green.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text('Tum raporlar incelendi',
                              style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _allReports.length,
                      itemBuilder: (context, index) {
                        final report = _allReports[index];
                        final isSelected = _selectedReport?['id'] == report['id'];
                        final status = report['status']?.toString();
                        final statusColor = _getStatusColor(status);
                        final plaka = report['plaka']?.toString() ?? '-';
                        final updatedAt = report['status_updated_at']?.toString() ?? '';
                        return InkWell(
                          onTap: () => _selectReport(report),
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? FuturisticTheme.neon.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? FuturisticTheme.neon
                                    : Colors.white.withValues(alpha: 0.08),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        plaka,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? FuturisticTheme.neon
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: statusColor),
                                      ),
                                      child: Text(
                                        _getStatusLabel(status),
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: statusColor,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'ID: ${(report['id']?.toString() ?? '').substring(0, report['id'].toString().length > 8 ? 8 : report['id'].toString().length)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white38),
                                ),
                                if (updatedAt.isNotEmpty)
                                  Text(
                                    updatedAt.length > 16
                                        ? updatedAt.substring(0, 16)
                                        : updatedAt,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.white24),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildReportDetail() {
    if (_selectedReport == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description,
                size: 64, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            const Text('Incelemek icin rapor secin',
                style: TextStyle(fontSize: 18, color: Colors.white38)),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildDetailHeader(),
        Expanded(
          child: DefaultTabController(
            length: 5,
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: FuturisticTheme.neon,
                  unselectedLabelColor: Colors.white38,
                  indicatorColor: FuturisticTheme.neon,
                  tabs: const [
                    Tab(icon: Icon(Icons.summarize), text: 'Ozet'),
                    Tab(icon: Icon(Icons.directions_car), text: 'Adim 1-2'),
                    Tab(icon: Icon(Icons.event_seat), text: 'Adim 3-4'),
                    Tab(icon: Icon(Icons.business), text: 'Kurumsal'),
                    Tab(icon: Icon(Icons.psychology), text: 'AI Analiz'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOzetTab(),
                      _buildDisVeAracTab(),
                      _buildIcVeBoyaTab(),
                      _buildKurumsalTab(),
                      _buildAiAnalizTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildActionBar(),
      ],
    );
  }

  Widget _buildDetailHeader() {
    final report = _selectedReport!;
    final status = report['status']?.toString();
    final statusColor = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FuturisticTheme.bgSecondary,
        border: Border(
            bottom:
                BorderSide(color: FuturisticTheme.neon.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rapor #${(report['id']?.toString() ?? '').substring(0, report['id'].toString().length > 8 ? 8 : report['id'].toString().length)}',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Plaka: ${report['plaka'] ?? '-'} | Sehir: ${report['sehir'] ?? '-'}',
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                ),
                if (_tamRapor != null)
                  Text(
                    'Arac: ${_tamRapor!.adim1.marka} ${_tamRapor!.adim1.model} | KM: ${_tamRapor!.adim1.guncelKm}',
                    style: const TextStyle(fontSize: 13, color: Colors.white54),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor, width: 2),
            ),
            child: Text(
              _getStatusLabel(status),
              style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOzetTab() {
    final report = _selectedReport!;
    final rapor = _tamRapor;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Talep Bilgileri',
            icon: Icons.assignment,
            children: [
              _buildInfoRow('Musteri ID', report['user_id']?.toString() ?? '-'),
              _buildInfoRow('Plaka', report['plaka']?.toString() ?? '-'),
              _buildInfoRow('Sehir', report['sehir']?.toString() ?? '-'),
              _buildInfoRow('Ekspertiz Firmasi', report['ekspertiz_firmasi']?.toString() ?? '-'),
              _buildInfoRow('Hizmet Bedeli', '${report['hizmet_bedeli'] ?? 6500} TL'),
              _buildInfoRow('Paket Fiyati', '${report['paket_fiyati'] ?? 0} TL'),
              _buildInfoRow('Toplam Tutar', '${report['toplam_tutar'] ?? 0} TL'),
              _buildInfoRow('Odendi mi?', report['odendi_mi'] == true ? 'Evet' : 'Hayir'),
              _buildInfoRow('Olusturulma', _formatDate(report['created_at'])),
              _buildInfoRow('Son Guncelleme', _formatDate(report['status_updated_at'])),
            ],
          ),
          if (rapor != null) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Rapor Ozeti',
              icon: Icons.summarize,
              children: [
                _buildInfoRow('Personel ID', rapor.personelId),
                _buildInfoRow('Arac', rapor.aracTamAdi),
                _buildInfoRow('Plaka', rapor.aracPlakasi),
                _buildInfoRow('KM', '${rapor.aracKm}'),
                _buildInfoRow('Ruhsat Sahibi', rapor.ruhsatSahibi),
                _buildInfoRow('Durum', rapor.durum),
                _buildInfoRow('Gecen Sure', rapor.gecenSureFormatli),
                _buildInfoRow('Genel Puan', rapor.genelPuan?.toStringAsFixed(1) ?? '-'),
                _buildInfoRow('Toplam Foto', '${rapor.toplamFotografSayisi}'),
                _buildInfoRow('Hasar Sayisi', '${rapor.hasarSayisi}'),
                if (rapor.genelNot != null)
                  _buildInfoRow('Genel Not', rapor.genelNot!),
                if (rapor.oneriler != null)
                  _buildInfoRow('Oneriler', rapor.oneriler!),
              ],
            ),
          ],
          if (_aiSonucu != null) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'AI Ozet',
              icon: Icons.psychology,
              children: [
                _buildInfoRow('Genel Sonuc', _aiSonucu!.raporOzeti.genelSonuc),
                _buildInfoRow(
                    'Genel Puan', _aiSonucu!.skorlar.genelPuan.toStringAsFixed(1)),
                _buildInfoRow('Tahmini Deger',
                    _aiSonucu!.raporOzeti.tahminiDegerFormatli),
                _buildInfoRow(
                    'Deger Kaybi', _aiSonucu!.raporOzeti.degerKaybiFormatli),
                _buildInfoRow('Onay/Red', _aiSonucu!.raporOzeti.onayRedOnerisi),
                _buildInfoRow(
                    'Kritik Sorun', '${_aiSonucu!.kritikSorunSayisi} adet'),
                _buildInfoRow('Analiz Zamani',
                    DateFormat('dd.MM.yyyy HH:mm').format(_aiSonucu!.analizZamani)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDisVeAracTab() {
    final rapor = _tamRapor;
    if (rapor == null) {
      return _buildNoData('Adim 1-2 verisi yok');
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Adim 1: Arac & Satici',
            icon: Icons.directions_car,
            children: [
              _buildInfoRow('Marka', rapor.adim1.marka),
              _buildInfoRow('Model', rapor.adim1.model),
              _buildInfoRow('Yakit', rapor.adim1.yakitTuru),
              _buildInfoRow('Plaka', rapor.adim1.plaka),
              _buildInfoRow('Sase No', rapor.adim1.saseNo),
              _buildInfoRow('Motor No', rapor.adim1.motorNo),
              _buildInfoRow('KM', '${rapor.adim1.guncelKm}'),
              _buildInfoRow('Ruhsat Sahibi', rapor.adim1.ruhsatSahibiAdSoyad),
              _buildInfoRow('Telefon', rapor.adim1.iletisimTelefon),
              if (rapor.adim1.enSonBakimTarihi != null)
                _buildInfoRow('Son Bakim',
                    DateFormat('dd.MM.yyyy').format(rapor.adim1.enSonBakimTarihi!)),
              if (rapor.adim1.sonMuayeneTarihi != null)
                _buildInfoRow('Son Muayene',
                    DateFormat('dd.MM.yyyy').format(rapor.adim1.sonMuayeneTarihi!)),
              if (rapor.adim1.hasarKayitAdet != null)
                _buildInfoRow('Hasar Kayit', '${rapor.adim1.hasarKayitAdet} adet'),
              if (rapor.adim1.hasarKayitToplamTutar != null)
                _buildInfoRow(
                    'Hasar Tutar', '${rapor.adim1.hasarKayitToplamTutar} TL'),
              _buildInfoRow(
                  'Pazarlik Payi', rapor.adim1.pazarlikPayiVar ? 'Var' : 'Yok'),
              if (rapor.adim1.pazarlikMiktari != null)
                _buildInfoRow(
                    'Pazarlik Miktari', '${rapor.adim1.pazarlikMiktari} TL'),
              if (rapor.adim1.genelNot != null)
                _buildInfoRow('Not', rapor.adim1.genelNot!),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Adim 2: Dis Ekspertiz',
            icon: Icons.search,
            children: [
              _buildDurumRow('On Tampon', rapor.adim2.onTampon),
              _buildDurumRow('On Farlar', rapor.adim2.onFarlar),
              _buildDurumRow('On Camurluklar', rapor.adim2.onCamurluklar),
              _buildDurumRow('On Kaput', rapor.adim2.onKaput),
              _buildDurumRow('Arka Tampon', rapor.adim2.arkaTampon),
              _buildDurumRow('Arka Camurluklar', rapor.adim2.arkaCamurluklar),
              _buildDurumRow('Bagaj Kapagi', rapor.adim2.bagajKapagi),
              _buildDurumRow('Sol On Kapi', rapor.adim2.solOnKapi),
              _buildDurumRow('Sag On Kapi', rapor.adim2.sagOnKapi),
              _buildDurumRow('Sol Arka Kapi', rapor.adim2.solArkaKapi),
              _buildDurumRow('Sag Arka Kapi', rapor.adim2.sagArkaKapi),
              _buildDurumRow('Tavan', rapor.adim2.tavan),
              _buildDurumRow('On Sasi', rapor.adim2.onSasi),
              _buildDurumRow('Arka Sasi', rapor.adim2.arkaSasi),
              _buildDurumRow('On Lastikler', rapor.adim2.onLastikler),
              _buildDurumRow('Arka Lastikler', rapor.adim2.arkaLastikler),
              if (rapor.adim2.genelNot != null)
                _buildInfoRow('Not', rapor.adim2.genelNot!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIcVeBoyaTab() {
    final rapor = _tamRapor;
    if (rapor == null) {
      return _buildNoData('Adim 3-4 verisi yok');
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Adim 3: Ic Ekspertiz',
            icon: Icons.event_seat,
            children: [
              _buildDurumRow('Direksiyon', rapor.adim3.direksiyon),
              _buildDurumRow('Gosterge Paneli', rapor.adim3.gostergePaneli),
              _buildDurumRow('Klima', rapor.adim3.klima),
              _buildDurumRow('Ses Sistemi', rapor.adim3.sesSistemi),
              _buildDurumRow('On Koltuklar', rapor.adim3.onKoltuklar),
              _buildDurumRow('Arka Koltuklar', rapor.adim3.arkaKoltuklar),
              _buildDurumRow('Koltuk Dosemesi', rapor.adim3.koltukDosemesi),
              _buildDurumRow('Doseme', rapor.adim3.dorseme),
              _buildDurumRow('Tavan Dosemesi', rapor.adim3.tavanDosemesi),
              _buildDurumRow('On Pencereler', rapor.adim3.onPencereler),
              _buildDurumRow('Arka Pencereler', rapor.adim3.arkaPencereler),
              _buildDurumRow('Merkezi Kilitle', rapor.adim3.merkeziKilit),
              _buildDurumRow('Cam Kontrolleri', rapor.adim3.camKontrolleri),
              _buildDurumRow('Ayna Kontrolleri', rapor.adim3.aynaKontrolleri),
              if (rapor.adim3.genelNot != null)
                _buildInfoRow('Not', rapor.adim3.genelNot!),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Adim 4: Boya / Kaporta',
            icon: Icons.color_lens,
            children: [
              _buildInfoRow('Hasar Sayisi', '${rapor.adim4.hasarSayisi}'),
              if (rapor.adim4.genelNot != null)
                _buildInfoRow('Genel Not', rapor.adim4.genelNot!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKurumsalTab() {
    final rapor = _tamRapor;
    if (rapor == null) {
      return _buildNoData('Kurumsal ekspertiz verisi yok');
    }
    final adim5 = rapor.adim5;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Adim 5: Kurumsal Ekspertiz',
            icon: Icons.business,
            children: [
              _buildInfoRow('Ruhsat Dosyasi',
                  adim5.ruhsatDosyasiVar == true ? 'Mevcut' : 'Yok'),
              _buildInfoRow('Bakim Defteri',
                  adim5.bakimDefteriVar == true ? 'Mevcut' : 'Yok'),
              _buildInfoRow('Sigorta Policesi',
                  adim5.sigortaPolicesiVar == true ? 'Mevcut' : 'Yok'),
              _buildInfoRow('Muayene Belgesi',
                  adim5.muayeneBelgesiVar == true ? 'Mevcut' : 'Yok'),
              _buildDurumRow('Motor Durumu', adim5.motorDurumu),
              _buildDurumRow('Sanziman', adim5.sanzimanDurumu),
              _buildDurumRow('Fren Sistemi', adim5.frenSistemi),
              _buildDurumRow('Direksiyon', adim5.direksiyonSistemi),
              _buildDurumRow('Elektrik Sistemi', adim5.elektrikSistemi),
              if (adim5.bataryaSagligi != null)
                _buildInfoRow('Batarya Sagligi', '%${adim5.bataryaSagligi}'),
              if (adim5.tahminiMenzil != null)
                _buildInfoRow('Tahmini Menzil', adim5.tahminiMenzil!),
              if (adim5.genelPuan != null)
                _buildInfoRow(
                    'Genel Puan', adim5.genelPuan!.toStringAsFixed(1)),
              if (adim5.ozetNot != null)
                _buildInfoRow('Ozet Not', adim5.ozetNot!),
              if (adim5.oneriler != null)
                _buildInfoRow('Oneriler', adim5.oneriler!),
              if (adim5.genelNot != null)
                _buildInfoRow('Genel Not', adim5.genelNot!),
              if (adim5.ekstraOpsiyonlar.isNotEmpty)
                _buildInfoRow('Opsiyonlar', adim5.ekstraOpsiyonlar.join(', ')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiAnalizTab() {
    if (_aiSonucu == null) {
      return _buildNoData('AI analiz sonucu mevcut degil');
    }
    final ai = _aiSonucu!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'AI Skorlari',
            icon: Icons.speed,
            children: [
              _buildScoreBar('Genel Puan', ai.skorlar.genelPuan),
              _buildScoreBar('Arac Durumu', ai.skorlar.aracDurumuPuan),
              _buildScoreBar('Motor/Mekanik', ai.skorlar.motorMekanikPuan),
              _buildScoreBar('Hasar', ai.skorlar.hasarPuan),
              _buildInfoRow('Degerlendirme', ai.skorlar.puanDegerlendirmesi),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Degerlendirme',
            icon: Icons.assessment,
            children: [
              _buildInfoRow('Genel Sonuc', ai.raporOzeti.genelSonuc),
              _buildInfoRow('Tahmini Deger', ai.raporOzeti.tahminiDegerFormatli),
              _buildInfoRow('Deger Kaybi', ai.raporOzeti.degerKaybiFormatli),
              _buildInfoRow('1 Yil Projeksiyon', ai.raporOzeti.degerProjeksiyonuFormatli),
              _buildInfoRow('Onay Onerisi', ai.raporOzeti.onayRedOnerisi),
              _buildInfoRow('Ozet', ai.raporOzeti.ozetAciklama),
            ],
          ),
          if (ai.raporOzeti.anahtarBulgular.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Anahtar Bulgular',
              icon: Icons.lightbulb,
              children: ai.raporOzeti.anahtarBulgular
                  .map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('  \u2022 ',
                                style: TextStyle(
                                    color: FuturisticTheme.neon, fontSize: 14)),
                            Expanded(
                              child: Text(b,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (ai.kritikSorunlar.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Kritik Sorunlar (${ai.kritikSorunlar.length})',
              icon: Icons.warning,
              color: Colors.red,
              children: ai.kritikSorunlar
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('  ! ',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(s,
                                  style: const TextStyle(
                                      color: Colors.redAccent, fontSize: 13)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (ai.oneriler.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Oneriler (${ai.oneriler.length})',
              icon: Icons.tips_and_updates,
              children: ai.oneriler
                  .map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(o.kategori)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(o.kategori,
                                      style: TextStyle(
                                          color: _getCategoryColor(o.kategori),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(o.baslik,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ),
                              ],
                            ),
                            if (o.aciklama.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 16, top: 4),
                                child: Text(o.aciklama,
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 12)),
                              ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Color _getCategoryColor(String kategori) {
    switch (kategori) {
      case 'Kritik':
        return Colors.red;
      case 'Onemli':
        return Colors.orange;
      default:
        return FuturisticTheme.neon;
    }
  }

  Widget _buildActionBar() {
    final status = _selectedReport?['status']?.toString();
    final hasOfficialAi = _hasOfficialCentralAi(_selectedReport);
    final hasFallbackPreview = _hasFlutterFallbackPreview(_selectedReport);
    final canApprove = status == 'pending_admin' && hasOfficialAi;
    final canReject = status == 'pending_admin';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FuturisticTheme.bgSecondary,
        border: Border(
            top: BorderSide(
                color: FuturisticTheme.neon.withValues(alpha: 0.2))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'pending_admin' && !hasOfficialAi)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasFallbackPreview
                          ? 'Gecici on analiz var. Resmi yayin icin merkezi AI sonucu bekleniyor.'
                          : 'Resmi yayin icin merkezi AI analizi gereklidir.',
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : (canReject ? _rejectReport : null),
                  icon: const Icon(Icons.cancel, size: 20),
                  label: const Text('Reddet',
                      style: TextStyle(fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : (canApprove ? _approveAndPublish : null),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.verified, size: 20),
                  label: Text(
                      _isProcessing ? 'Yayinlaniyor...' : 'Onayla & Yayinla',
                      style: const TextStyle(fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canApprove ? FuturisticTheme.neon : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? color,
  }) {
    final accent = color ?? FuturisticTheme.neon;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: accent)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildDurumRow(String label, String? durum) {
    if (durum == null) return const SizedBox.shrink();
    final color = _getDurumColor(durum);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Text(durum,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Color _getDurumColor(String durum) {
    final lower = durum.toLowerCase();
    if (lower.contains('orijinal') || lower.contains('iyi') || lower.contains('mukemmel')) {
      return Colors.green;
    }
    if (lower.contains('boya') || lower.contains('degisen') || lower.contains('orta')) {
      return Colors.orange;
    }
    if (lower.contains('hasar') || lower.contains('kotu') || lower.contains('boyali')) {
      return Colors.red;
    }
    return Colors.white54;
  }

  Widget _buildScoreBar(String label, double score) {
    final color = score >= 80
        ? Colors.green
        : score >= 60
            ? Colors.orange
            : Colors.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text(score.toStringAsFixed(1),
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              color: color,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoData(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline,
              size: 48, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr.toString());
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }
}

