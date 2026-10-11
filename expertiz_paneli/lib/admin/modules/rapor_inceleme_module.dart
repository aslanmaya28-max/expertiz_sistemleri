import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../models/expertiz/adim2_dis_ekspertiz_model.dart';
import '../../models/expertiz/adim3_ic_ekspertiz_model.dart';
import '../../models/expertiz/adim4_boya_kaporta_model.dart';
import '../../models/expertiz/kontrol_listesi.dart';
import '../../models/expertiz/rapor_medya.dart';
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
  Timer? _refreshTimer;
  final YerimebakExpertizApiService _expertizApi = YerimebakExpertizApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadReports();
    // Personelin gönderdiği yeni raporlar ekran açıkken de düşsün
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadReports(silent: true));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadReports({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isLoading = true);
    try {
      final response = await _expertizApi.getAdminReports(limit: 200);
      final reports = (response['reports'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      // Önce admin onayı bekleyenler
      const oncelik = {'pending_admin': 0, 'pending_ai': 1, 'rejected': 2, 'published': 3, 'draft': 4};
      reports.sort((a, b) => (oncelik[a['status']] ?? 9).compareTo(oncelik[b['status']] ?? 9));
      if (!mounted) return;
      setState(() {
        _allReports = reports;
        _isLoading = false;
        // Seçili raporu taze veriyle (yeni imzalı fotoğraf bağlantıları) güncelle
        final selectedId = _selectedReport?['id'];
        if (selectedId != null) {
          final fresh = reports.where((r) => r['id'] == selectedId).firstOrNull;
          if (fresh != null) {
            _selectedReport = fresh;
            _tamRapor = _parseTamRapor(fresh);
            _aiSonucu = _parseAiSonuc(fresh);
          }
        }
      });
    } catch (e) {
      debugPrint('Rapor yukleme hatasi: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Raporlar yüklenemedi: $e')));
        }
      }
    }
  }

  List<RaporMedya> _medya(String kategori, {String? bolum, String? maddeKey}) {
    return RaporMedya.listFrom(_selectedReport?['media'])
        .where((m) => m.kategori == kategori && (bolum == null || m.bolum == bolum) && (maddeKey == null || m.maddeKey == maddeKey))
        .toList();
  }

  String _url(RaporMedya medya) => _expertizApi.resolveUrl(medya.url);

  Future<void> _medyaAc(RaporMedya medya) async {
    if (medya.resimMi) {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: InteractiveViewer(child: Image.network(_url(medya), fit: BoxFit.contain))),
              if ((medya.maddeEtiket ?? '').isNotEmpty || medya.not.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    [medya.maddeEtiket, medya.not].where((e) => (e ?? '').isNotEmpty).join(' – '),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      );
      return;
    }
    try {
      final bytes = await _expertizApi.downloadBytes(medya.url);
      await Printing.layoutPdf(onLayout: (_) async => Uint8List.fromList(bytes), name: medya.dosyaAdi ?? 'rapor.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dosya açılamadı: $e')));
      }
    }
  }

  Widget _thumbnails(List<RaporMedya> fotolar, {double size = 64}) {
    if (fotolar.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: fotolar
            .map((m) => InkWell(
                  onTap: () => _medyaAc(m),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      _url(m),
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: size,
                        height: size,
                        color: Colors.white10,
                        child: const Icon(Icons.broken_image, color: Colors.white38),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  /// Kontrol listesi bölümü: durum + not + o maddenin fotoğrafları
  Widget _kontrolBolumu({
    required String title,
    required IconData icon,
    required String bolum,
    required List<KontrolMaddesi> maddeler,
    required String? Function(String key) durum,
    required String Function(String?) etiket,
    required Color Function(String?) renk,
    required bool Function(String?) eksiklik,
    required String Function(String key) not,
    int? Function(String key)? mikron,
  }) {
    final eksikler = maddeler.where((m) => eksiklik(durum(m.key))).length;
    return _buildSectionCard(
      title: '$title  •  $eksikler eksiklik',
      icon: icon,
      color: eksikler > 0 ? Colors.orange : null,
      children: maddeler.map((m) {
        final d = durum(m.key);
        final fotolar = _medya(RaporMedya.kategoriFoto, bolum: bolum, maddeKey: m.key);
        final n = not(m.key);
        final mk = mikron?.call(m.key);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 180,
                  child: Text(m.label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: renk(d).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: renk(d).withValues(alpha: 0.6)),
                  ),
                  child: Text(etiket(d), style: TextStyle(color: renk(d), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                if (mk != null) ...[
                  const SizedBox(width: 8),
                  Text('$mk μm', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
                if (fotolar.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.photo_camera, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                  Text(' ${fotolar.length}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ],
            ),
            if (n.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 180, top: 2),
                child: Text(n, style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
              ),
            if (fotolar.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 180), child: _thumbnails(fotolar)),
            const SizedBox(height: 6),
          ],
        );
      }).toList(),
    );
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
            length: 6,
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
                    Tab(icon: Icon(Icons.photo_library), text: 'Fotoğraflar'),
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
                      _buildFotograflarTab(),
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
          _kontrolBolumu(
            title: 'Adım 2: Dış Ekspertiz',
            icon: Icons.search,
            bolum: 'dis',
            maddeler: Adim2DisEkspertizModel.maddeler,
            durum: rapor.adim2.durum,
            etiket: KontrolDurumu.etiket,
            renk: KontrolDurumu.renk,
            eksiklik: KontrolDurumu.eksiklikMi,
            not: rapor.adim2.not,
          ),
          if ((rapor.adim2.genelNot ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Dış ekspertiz notu', rapor.adim2.genelNot!),
          ],
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
          _kontrolBolumu(
            title: 'Adım 3: İç Ekspertiz',
            icon: Icons.event_seat,
            bolum: 'ic',
            maddeler: Adim3IcEkspertizModel.maddeler,
            durum: rapor.adim3.durum,
            etiket: KontrolDurumu.etiket,
            renk: KontrolDurumu.renk,
            eksiklik: KontrolDurumu.eksiklikMi,
            not: rapor.adim3.not,
          ),
          if ((rapor.adim3.genelNot ?? '').isNotEmpty) _buildInfoRow('İç ekspertiz notu', rapor.adim3.genelNot!),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Adım 4: Boya / Kaporta Özeti',
            icon: Icons.color_lens,
            children: [
              _buildInfoRow('Boyalı parçalar', rapor.adim4.boyaliParcalar.isEmpty ? '-' : rapor.adim4.boyaliParcalar.join(', ')),
              _buildInfoRow('Değişen parçalar', rapor.adim4.degisenParcalar.isEmpty ? '-' : rapor.adim4.degisenParcalar.join(', ')),
              _buildInfoRow('Hasar sayısı', '${rapor.adim4.hasarSayisi}'),
              if ((rapor.adim4.genelNot ?? '').isNotEmpty) _buildInfoRow('Genel not', rapor.adim4.genelNot!),
            ],
          ),
          const SizedBox(height: 16),
          _kontrolBolumu(
            title: 'Kaporta Parçaları',
            icon: Icons.car_repair,
            bolum: 'boya_kaporta',
            maddeler: Adim4BoyaKaportaModel.parcalar,
            durum: (key) => rapor.adim4.parcaDurumlari[key],
            etiket: ParcaDurumu.etiket,
            renk: ParcaDurumu.renk,
            eksiklik: ParcaDurumu.eksiklikMi,
            not: rapor.adim4.not,
            mikron: (key) => rapor.adim4.mikronlar[key],
          ),
          const SizedBox(height: 16),
          _kontrolBolumu(
            title: 'Şasi ve Yapısal Elemanlar',
            icon: Icons.construction,
            bolum: 'boya_kaporta',
            maddeler: Adim4BoyaKaportaModel.yapisal,
            durum: (key) => rapor.adim4.yapisalDurumlar[key],
            etiket: YapisalDurum.etiket,
            renk: YapisalDurum.renk,
            eksiklik: YapisalDurum.eksiklikMi,
            not: rapor.adim4.not,
          ),
          if (rapor.adim4.hasarKayitlari.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Ek Hasar Kayıtları',
              icon: Icons.warning_amber,
              color: Colors.orange,
              children: rapor.adim4.hasarKayitlari
                  .map((h) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('${h.konum} (${h.tip})', '${h.buyukluk}${(h.not ?? '').isEmpty ? '' : ' – ${h.not}'}'),
                          _thumbnails(_medya(RaporMedya.kategoriFoto, bolum: 'boya_kaporta', maddeKey: h.id)),
                        ],
                      ))
                  .toList(),
            ),
          ],
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
    final kurumsalDosyalar = _medya(RaporMedya.kategoriKurumsal);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Kurumsal Ekspertiz Raporu',
            icon: Icons.verified,
            color: adim5.kurumsalTalepVar && kurumsalDosyalar.isEmpty ? Colors.red : null,
            children: [
              _buildInfoRow('Talep', adim5.kurumsalTalepVar ? 'Var' : 'Yok'),
              if ((adim5.kurumsalFirma ?? '').isNotEmpty) _buildInfoRow('Firma', adim5.kurumsalFirma!),
              if ((adim5.kurumsalPaket ?? '').isNotEmpty) _buildInfoRow('Paket', adim5.kurumsalPaket!),
              if ((adim5.kurumsalRaporNo ?? '').isNotEmpty) _buildInfoRow('Rapor No', adim5.kurumsalRaporNo!),
              if (adim5.kurumsalRaporTarihi != null)
                _buildInfoRow('Rapor Tarihi', DateFormat('dd.MM.yyyy').format(adim5.kurumsalRaporTarihi!)),
              if ((adim5.kurumsalSonucOzeti ?? '').isNotEmpty) _buildInfoRow('Sonuç Özeti', adim5.kurumsalSonucOzeti!),
              if (kurumsalDosyalar.isEmpty)
                const Text('Dosya eklenmemiş', style: TextStyle(color: Colors.white38))
              else
                ...kurumsalDosyalar.map((m) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(m.pdfMi ? Icons.picture_as_pdf : Icons.image, color: Colors.redAccent),
                      title: Text(m.dosyaAdi ?? 'Kurumsal rapor', style: const TextStyle(color: Colors.white)),
                      subtitle: const Text('Açmak için dokunun', style: TextStyle(color: Colors.white38)),
                      onTap: () => _medyaAc(m),
                    )),
            ],
          ),
          const SizedBox(height: 16),
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

  Widget _buildFotograflarTab() {
    final fotolar = _medya(RaporMedya.kategoriFoto);
    if (fotolar.isEmpty) return _buildNoData('Bu raporda fotoğraf yok');
    const bolumAdlari = {
      'arac': 'Araç',
      'dis': 'Dış Ekspertiz',
      'ic': 'İç Ekspertiz',
      'boya_kaporta': 'Boya / Kaporta',
      'kurumsal': 'Kurumsal',
      'genel': 'Genel',
    };
    final gruplar = <String, List<RaporMedya>>{};
    for (final m in fotolar) {
      gruplar.putIfAbsent(m.bolum ?? 'genel', () => []).add(m);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in gruplar.entries) ...[
          Text(
            '${bolumAdlari[entry.key] ?? entry.key} (${entry.value.length})',
            style: const TextStyle(color: FuturisticTheme.neon, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: entry.value
                .map((m) => SizedBox(
                      width: 150,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _thumbnails([m], size: 150),
                          Text(m.maddeEtiket ?? '-', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          if (m.not.isNotEmpty)
                            Text(m.not, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
      ],
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

