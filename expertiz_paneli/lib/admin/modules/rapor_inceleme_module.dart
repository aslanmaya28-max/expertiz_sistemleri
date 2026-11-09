import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yerimebak_sistemleri/tema/renkler.dart';
import 'package:yerimebak_sistemleri/bilesenler/bilesenler.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/expertiz/adim2_dis_ekspertiz_model.dart';
import '../../models/expertiz/adim3_ic_ekspertiz_model.dart';
import '../../models/expertiz/adim4_boya_kaporta_model.dart';
import '../../models/expertiz/kontrol_listesi.dart';
import '../../models/expertiz/rapor_medya.dart';
import '../../models/expertiz/tam_rapor_model.dart';
import '../../models/ai/ai_analiz_sonucu_model.dart';
import '../../providers/admin_provider.dart';
import '../../services/yerimebak_expertiz_api_service.dart';
import 'report_archive_action.dart';

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
  final YerimebakExpertizApiService _expertizApi =
      YerimebakExpertizApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadReports();
    // Personelin gönderdiği yeni raporlar ekran açıkken de düşsün
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _loadReports(silent: true));
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
      const oncelik = {
        'pending_admin': 0,
        'pending_ai': 1,
        'rejected': 2,
        'published': 3,
        'draft': 4
      };
      reports.sort((a, b) =>
          (oncelik[a['status']] ?? 9).compareTo(oncelik[b['status']] ?? 9));
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
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Raporlar yüklenemedi: $e')));
        }
      }
    }
  }

  List<RaporMedya> _medya(String kategori, {String? bolum, String? maddeKey}) {
    return RaporMedya.listFrom(_selectedReport?['media'])
        .where((m) =>
            m.kategori == kategori &&
            (bolum == null || m.bolum == bolum) &&
            (maddeKey == null || m.maddeKey == maddeKey))
        .toList();
  }

  String _url(RaporMedya medya) => _expertizApi.resolveUrl(medya.url);

  Future<void> _medyaAc(RaporMedya medya) async {
    if (medya.resimMi) {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: context.renkler.yuzey,
          insetPadding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                  child: InteractiveViewer(
                      child: Image.network(_url(medya), fit: BoxFit.contain))),
              if ((medya.maddeEtiket ?? '').isNotEmpty || medya.not.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    [medya.maddeEtiket, medya.not]
                        .where((e) => (e ?? '').isNotEmpty)
                        .join(' – '),
                    style: TextStyle(color: context.renkler.metin),
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
      await Printing.layoutPdf(
          onLayout: (_) async => Uint8List.fromList(bytes),
          name: medya.dosyaAdi ?? 'rapor.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Dosya açılamadı: $e')));
      }
    }
  }

  Widget _thumbnails(List<RaporMedya> fotolar, {double size = 64}) {
    if (fotolar.isEmpty) return SizedBox.shrink();
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
                        color: context.renkler.ayirici,
                        child: Icon(LucideIcons.imageOff,
                            color: context.renkler.metinIkincil),
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
      color: eksikler > 0 ? context.renkler.uyari : null,
      children: maddeler.map((m) {
        final d = durum(m.key);
        final fotolar =
            _medya(RaporMedya.kategoriFoto, bolum: bolum, maddeKey: m.key);
        final n = not(m.key);
        final mk = mikron?.call(m.key);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 180,
                  child: Text(m.label,
                      style: TextStyle(
                          color: context.renkler.metinIkincil, fontSize: 13)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: renk(d).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: renk(d).withValues(alpha: 0.6)),
                  ),
                  child: Text(etiket(d),
                      style: TextStyle(
                          color: renk(d),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                if (mk != null) ...[
                  const SizedBox(width: 8),
                  Text('$mk μm',
                      style: TextStyle(
                          color: context.renkler.metinIkincil, fontSize: 13)),
                ],
                if (fotolar.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(LucideIcons.camera,
                      size: 14,
                      color: context.renkler.metin.withValues(alpha: 0.5)),
                  Text(' ${fotolar.length}',
                      style: TextStyle(
                          color: context.renkler.metinIkincil, fontSize: 13)),
                ],
              ],
            ),
            if (n.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 180, top: 2),
                child: Text(n,
                    style: TextStyle(
                        color: context.renkler.metinIkincil,
                        fontSize: 13,
                        fontStyle: FontStyle.italic)),
              ),
            if (fotolar.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(left: 180),
                  child: _thumbnails(fotolar)),
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
        return 'Yönetici onayı bekliyor';
      case 'pending_ai':
        return 'AI Analizi Bekliyor';
      case 'published':
        return 'Yayınlandı';
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
        return context.renkler.uyari;
      case 'pending_ai':
        return context.renkler.birincil;
      case 'published':
        return context.renkler.birincilMetin;
      case 'rejected':
        return context.renkler.tehlike;
      case 'draft':
        return context.renkler.metinIkincil;
      default:
        return context.renkler.metinIkincil;
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
    final aiMap =
        ai is Map ? Map<String, dynamic>.from(ai) : <String, dynamic>{};
    if (meta is Map) {
      final metaMap = Map<String, dynamic>.from(meta);
      return {
        'source': metaMap['source'] ?? aiMap['source'] ?? 'none',
        'official': metaMap['official'] == true || aiMap['official'] == true,
        'ready': metaMap['ready'] == true ||
            report?['ai_analizi_yapildi_mi'] == true,
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
    return meta['source'] == 'central_ai' &&
        meta['official'] == true &&
        meta['ready'] == true;
  }

  bool _hasFlutterFallbackPreview(Map<String, dynamic>? report) {
    final data = _reportData(report);
    final preview = data['flutter_fallback_preview'];
    return preview is Map && preview['temporary'] == true;
  }

  /// AI değerleme bloğu (piyasa değeri − ekspertiz değer kayıpları)
  Map<String, dynamic>? get _degerleme {
    final ai = _selectedReport?['ai_analiz_detay'] ??
        _selectedReport?['ai_analysis_result'];
    if (ai is Map && ai['ekspertizDegerleme'] is Map) {
      return Map<String, dynamic>.from(ai['ekspertizDegerleme'] as Map);
    }
    return null;
  }

  static final NumberFormat _tlFormat = NumberFormat.decimalPattern('tr_TR');

  String _tl(dynamic value) {
    if (value is! num) return '-';
    return '${_tlFormat.format(value.round())} TL';
  }

  String _yuzde(dynamic value) {
    if (value is! num) return '-';
    return '%${value.toStringAsFixed(1).replaceAll('.', ',')}';
  }

  Future<void> _reanalyze() async {
    final report = _selectedReport;
    if (report == null) return;
    setState(() => _isProcessing = true);
    try {
      final result =
          await _expertizApi.reanalyzeReport(report['id'].toString());
      final fresh = result['report'];
      if (fresh is Map && mounted) {
        _selectReport(Map<String, dynamic>.from(fresh));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('AI değerlemesi güncellendi'),
          backgroundColor: context.renkler.birincilMetin,
        ));
      }
      await _loadReports(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('AI analizi çalıştırılamadı: $e'),
          backgroundColor: context.renkler.tehlike,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Admin, kaynak ilanlara bakıp temiz piyasa değerini düzeltir (yapay zekâ değeri de saklanır).
  Future<void> _piyasaDegeriDuzelt() async {
    final report = _selectedReport;
    final d = _degerleme;
    if (report == null) return;
    final duzeltme =
        d?['adminDuzeltmesi'] is Map ? d!['adminDuzeltmesi'] as Map : null;
    final degerCtrl = TextEditingController(
        text: (duzeltme?['value'] ?? d?['piyasaDegeri'] ?? '').toString());
    final notCtrl =
        TextEditingController(text: duzeltme?['note']?.toString() ?? '');
    final sonuc = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Piyasa değerini düzelt'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yapay zekânın bulduğu temiz piyasa değeri: ${_tl(duzeltme?['ai_value'] ?? d?['piyasaDegeri'])}. '
                'Gireceğiniz değer, bulgu kesintilerinden önceki temiz araç değeridir.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: degerCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Temiz piyasa değeri (TL)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Not (neden düzelttiniz?)',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          if (duzeltme != null)
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'kaldir'),
                child: const Text('Düzeltmeyi kaldır')),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'kaydet'),
              child: const Text('Kaydet ve yeniden hesapla')),
        ],
      ),
    );
    if (sonuc == null || !mounted) return;
    final deger =
        int.tryParse(degerCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (sonuc == 'kaydet' && deger == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Geçerli bir TL değeri girin'),
          backgroundColor: context.renkler.tehlike));
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final result = await _expertizApi.setMarketValue(
        report['id'].toString(),
        sonuc == 'kaldir' ? null : deger,
        note: notCtrl.text.trim(),
      );
      final fresh = result['report'];
      if (fresh is Map && mounted) {
        _selectReport(Map<String, dynamic>.from(fresh));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(sonuc == 'kaldir'
              ? 'Düzeltme kaldırıldı'
              : 'Piyasa değeri güncellendi'),
          backgroundColor: context.renkler.birincilMetin,
        ));
      }
      await _loadReports(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Piyasa değeri kaydedilemedi: $e'),
            backgroundColor: context.renkler.tehlike));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _kaynakAc(String? url) async {
    final uri = Uri.tryParse(url ?? '');
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _duzeltmeMetni(Map duzeltme) {
    final fark = duzeltme['diff_pct'];
    final not = (duzeltme['note'] ?? '').toString();
    final farkMetni =
        fark is num ? ' (${fark > 0 ? '+' : ''}${_yuzde(fark)})' : '';
    final notMetni = not.isNotEmpty ? ' — $not' : '';
    return 'Admin düzeltmesi: yapay zekâ ${_tl(duzeltme['ai_value'])} → ${_tl(duzeltme['value'])}$farkMetni$notMetni';
  }

  Widget _kontrolKutusu(List<Map> kontroller) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.renkler.uyari.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.renkler.uyari.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('KONTROL GEREKLİ — yayınlamadan önce kaynak ilanlara bakın',
              style: TextStyle(
                  color: context.renkler.uyari,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (final k in kontroller)
            Text('• ${k['mesaj']}',
                style: TextStyle(
                    color: context.renkler.metinIkincil, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _kaynakListesi(List<Map> kaynaklar) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('Kaynak ilanlar (${kaynaklar.length})',
          style: TextStyle(color: context.renkler.metinIkincil, fontSize: 13)),
      children: [
        for (final k in kaynaklar)
          InkWell(
            onTap: () => _kaynakAc(k['url']?.toString()),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(LucideIcons.externalLink,
                      size: 14, color: context.renkler.metinIkincil),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        (k['site'] ?? '').toString(),
                        if (k['year'] != null) '${k['year']}',
                        if (k['km'] is num) '${_tlFormat.format(k['km'])} km',
                        if ((k['declared'] ?? '').toString().isNotEmpty)
                          k['declared'].toString(),
                      ].join(' • '),
                      style: TextStyle(
                          color: context.renkler.metinIkincil, fontSize: 13),
                    ),
                  ),
                  Text(_tl(k['price']),
                      style: TextStyle(
                          color: context.renkler.metin, fontSize: 13)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Onay ekranı: müşteriye gidecek paketin özeti + opsiyonel müşteri notu
  Future<String?> _yayinOnayDialog() {
    final d = _degerleme;
    final fotoSayisi = _medya(RaporMedya.kategoriFoto).length;
    final kurumsalSayisi = _medya(RaporMedya.kategoriKurumsal).length;
    final maddeler = <Widget>[
      _onayMaddesi('Personel ekspertiz raporu (dış, iç, boya-kaporta)',
          _tamRapor != null),
      _onayMaddesi('Hasar fotoğrafları ($fotoSayisi adet)', fotoSayisi > 0),
      _onayMaddesi('Kurumsal ekspertiz raporu ($kurumsalSayisi dosya)',
          kurumsalSayisi > 0),
      _onayMaddesi(
        d == null
            ? 'Yapay zeka analizi'
            : d['aiDegeri'] != null
                ? 'Yapay zeka değerlemesi: ${_tl(d['aiDegeri'])} (değer kaybı ${_yuzde(d['toplamDegerKaybiYuzde'])})'
                : 'Yapay zeka analizi (piyasa verisi yetersiz, TL değeri yok)',
        _aiSonucu != null,
      ),
    ];
    return showDialog<String>(
      context: context,
      builder: (_) => _YayinOnayDialog(maddeler: maddeler),
    );
  }

  Widget _onayMaddesi(String text, bool mevcut) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(mevcut ? LucideIcons.circleCheck : LucideIcons.circleMinus,
              size: 16,
              color: mevcut
                  ? context.renkler.birincilMetin
                  : context.renkler.ikonPasif),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: mevcut
                          ? context.renkler.metin
                          : context.renkler.metinIkincil,
                      fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _approveAndPublish() async {
    if (_selectedReport == null) return;
    final note = await _yayinOnayDialog();
    if (note == null || !mounted) return;
    setState(() => _isProcessing = true);
    try {
      final reportId = _selectedReport!['id'] as String;
      await _expertizApi.publishReport(reportId, adminNote: note);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Rapor onaylandı ve müşteriye gönderildi'),
          backgroundColor: context.renkler.birincilMetin,
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
          content: Text('Yayınlama hatası: $e'),
          backgroundColor: context.renkler.tehlike,
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
          backgroundColor: context.renkler.yuzey,
          title: Text('Raporu reddet',
              style: TextStyle(color: context.renkler.metin)),
          content: TextField(
            controller: reasonController,
            maxLines: 5,
            style: TextStyle(color: context.renkler.metin),
            decoration: InputDecoration(
              hintText: 'Red nedenini yazın…',
              hintStyle: TextStyle(color: context.renkler.metinIkincil),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('İptal',
                  style: TextStyle(color: context.renkler.metinIkincil)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(reasonController.text),
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.renkler.tehlike),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Rapor reddedildi, personele iade edildi'),
          backgroundColor: context.renkler.uyari,
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
          content: Text('Reddetme hatası: $e'),
          backgroundColor: context.renkler.tehlike,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.renkler.zemin,
      body: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 1000) {
          if (_selectedReport == null) return _buildReportList();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextButton.icon(
              onPressed: () => setState(() => _selectedReport = null),
              icon: const Icon(LucideIcons.arrowLeft),
              label: const Text('Raporlara dön'),
            ),
            Expanded(child: _buildReportDetail()),
          ]);
        }
        return Row(children: [
          SizedBox(width: 380, child: _buildReportList()),
          VerticalDivider(width: 1, color: context.renkler.ayirici),
          Expanded(child: _buildReportDetail()),
        ]);
      }),
    );
  }

  Widget _buildReportList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.renkler.yuzey,
            border: Border(
                bottom: BorderSide(
                    color: context.renkler.birincil.withValues(alpha: 0.2))),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.fileText,
                  color: context.renkler.birincil, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Raporlar',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.renkler.metin),
                ),
              ),
              IconButton(
                icon: Icon(LucideIcons.refreshCw,
                    color: context.renkler.birincil),
                onPressed: _loadReports,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Padding(padding: EdgeInsets.all(24), child: Column(children: [YbIskelet(height: 80), SizedBox(height: 16), YbIskelet(height: 80), SizedBox(height: 16), YbIskelet(height: 80)]))
              : _allReports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.circleCheck,
                              size: 64,
                              color: context.renkler.birincilMetin
                                  .withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text('Tüm raporlar incelendi',
                              style: TextStyle(
                                  color: context.renkler.metinIkincil)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _allReports.length,
                      itemBuilder: (context, index) {
                        final report = _allReports[index];
                        final isSelected =
                            _selectedReport?['id'] == report['id'];
                        final status = report['status']?.toString();
                        final statusColor = _getStatusColor(status);
                        final plaka = report['plaka']?.toString() ?? '-';
                        final updatedAt =
                            report['status_updated_at']?.toString() ?? '';
                        return InkWell(
                          onTap: () => _selectReport(report),
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? context.renkler.birincil
                                      .withValues(alpha: 0.1)
                                  : context.renkler.metin
                                      .withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? context.renkler.birincil
                                    : context.renkler.metin
                                        .withValues(alpha: 0.08),
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
                                              ? context.renkler.birincil
                                              : context.renkler.metin,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            statusColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: statusColor),
                                      ),
                                      child: Text(
                                        _getStatusLabel(status),
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: statusColor,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (isReportArchived(report))
                                  const Chip(
                                    avatar: Icon(LucideIcons.archive, size: 16),
                                    label: Text('Arşivlendi'),
                                  ),
                                Text(
                                  'ID: ${(report['id']?.toString() ?? '').substring(0, report['id'].toString().length > 8 ? 8 : report['id'].toString().length)}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: context.renkler.metinIkincil),
                                ),
                                if (updatedAt.isNotEmpty)
                                  Text(
                                    updatedAt.length > 16
                                        ? updatedAt.substring(0, 16)
                                        : updatedAt,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: context.renkler.kenarlik),
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
            Icon(LucideIcons.fileText,
                size: 64, color: context.renkler.metin.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text('İncelemek için bir rapor seçin',
                style: TextStyle(
                    fontSize: 18, color: context.renkler.metinIkincil)),
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
                  labelColor: context.renkler.birincil,
                  unselectedLabelColor: context.renkler.metinIkincil,
                  indicatorColor: context.renkler.birincil,
                  tabs: const [
                    Tab(icon: Icon(LucideIcons.clipboardList), text: 'Özet'),
                    Tab(icon: Icon(LucideIcons.car), text: 'Adım 1-2'),
                    Tab(icon: Icon(LucideIcons.armchair), text: 'Adım 3-4'),
                    Tab(icon: Icon(LucideIcons.building2), text: 'Kurumsal'),
                    Tab(icon: Icon(LucideIcons.images), text: 'Fotoğraflar'),
                    Tab(icon: Icon(LucideIcons.brain), text: 'AI Analiz'),
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
        color: context.renkler.yuzey,
        border: Border(
            bottom: BorderSide(
                color: context.renkler.birincil.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rapor #${(report['id']?.toString() ?? '').substring(0, report['id'].toString().length > 8 ? 8 : report['id'].toString().length)}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.renkler.metin),
                ),
                const SizedBox(height: 4),
                Text(
                  'Plaka: ${report['plaka'] ?? '-'} | Şehir: ${report['sehir'] ?? '-'}',
                  style: TextStyle(
                      fontSize: 13, color: context.renkler.metinIkincil),
                ),
                if (_tamRapor != null)
                  Text(
                    'Araç: ${_tamRapor!.adim1.marka} ${_tamRapor!.adim1.model} | KM: ${_tamRapor!.adim1.guncelKm}',
                    style: TextStyle(
                        fontSize: 13, color: context.renkler.metinIkincil),
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
            icon: LucideIcons.clipboardList,
            children: [
              _buildInfoRow('Müşteri ID', report['user_id']?.toString() ?? '-'),
              _buildInfoRow('Plaka', report['plaka']?.toString() ?? '-'),
              _buildInfoRow('Şehir', report['sehir']?.toString() ?? '-'),
              _buildInfoRow('Ekspertiz firması',
                  report['ekspertiz_firmasi']?.toString() ?? '-'),
              _buildInfoRow(
                  'Hizmet Bedeli', '${report['hizmet_bedeli'] ?? 6500} TL'),
              _buildInfoRow(
                  'Paket fiyatı', '${report['paket_fiyati'] ?? 0} TL'),
              _buildInfoRow(
                  'Toplam Tutar', '${report['toplam_tutar'] ?? 0} TL'),
              _buildInfoRow(
                  'Ödendi mi?', report['odendi_mi'] == true ? 'Evet' : 'Hayır'),
              _buildInfoRow('Oluşturulma', _formatDate(report['created_at'])),
              _buildInfoRow(
                  'Son güncelleme', _formatDate(report['status_updated_at'])),
            ],
          ),
          if (rapor != null) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Rapor özeti',
              icon: LucideIcons.clipboardList,
              children: [
                _buildInfoRow('Personel ID', rapor.personelId),
                _buildInfoRow('Araç', rapor.aracTamAdi),
                _buildInfoRow('Plaka', rapor.aracPlakasi),
                _buildInfoRow('KM', '${rapor.aracKm}'),
                _buildInfoRow('Ruhsat Sahibi', rapor.ruhsatSahibi),
                _buildInfoRow('Durum', rapor.durum),
                _buildInfoRow('Geçen süre', rapor.gecenSureFormatli),
                _buildInfoRow(
                    'Genel Puan', rapor.genelPuan?.toStringAsFixed(1) ?? '-'),
                _buildInfoRow('Toplam Foto', '${rapor.toplamFotografSayisi}'),
                _buildInfoRow('Hasar sayısı', '${rapor.hasarSayisi}'),
                if (rapor.genelNot != null)
                  _buildInfoRow('Genel Not', rapor.genelNot!),
                if (rapor.oneriler != null)
                  _buildInfoRow('Öneriler', rapor.oneriler!),
              ],
            ),
          ],
          if (_aiSonucu != null) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'AI Özet',
              icon: LucideIcons.brain,
              children: [
                _buildInfoRow('Genel Sonuc', _aiSonucu!.raporOzeti.genelSonuc),
                _buildInfoRow('Genel Puan',
                    _aiSonucu!.skorlar.genelPuan.toStringAsFixed(1)),
                _buildInfoRow('Tahmini değer',
                    _aiSonucu!.raporOzeti.tahminiDegerFormatli),
                _buildInfoRow(
                    'Değer kaybı', _aiSonucu!.raporOzeti.degerKaybiFormatli),
                _buildInfoRow('Onay/Red', _aiSonucu!.raporOzeti.onayRedOnerisi),
                _buildInfoRow(
                    'Kritik Sorun', '${_aiSonucu!.kritikSorunSayisi} adet'),
                _buildInfoRow(
                    'Analiz zamanı',
                    DateFormat('dd.MM.yyyy HH:mm')
                        .format(_aiSonucu!.analizZamani)),
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
      return _buildNoData('Adım 1-2 verisi yok');
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Adım 1: Araç ve Satıcı',
            icon: LucideIcons.car,
            children: [
              _buildInfoRow('Marka', rapor.adim1.marka),
              _buildInfoRow('Model', rapor.adim1.model),
              _buildInfoRow('Yakıt', rapor.adim1.yakitTuru),
              _buildInfoRow('Plaka', rapor.adim1.plaka),
              _buildInfoRow('Şase no', rapor.adim1.saseNo),
              _buildInfoRow('Motor No', rapor.adim1.motorNo),
              _buildInfoRow('KM', '${rapor.adim1.guncelKm}'),
              _buildInfoRow('Ruhsat Sahibi', rapor.adim1.ruhsatSahibiAdSoyad),
              _buildInfoRow('Telefon', rapor.adim1.iletisimTelefon),
              if (rapor.adim1.enSonBakimTarihi != null)
                _buildInfoRow(
                    'Son bakım',
                    DateFormat('dd.MM.yyyy')
                        .format(rapor.adim1.enSonBakimTarihi!)),
              if (rapor.adim1.sonMuayeneTarihi != null)
                _buildInfoRow(
                    'Son Muayene',
                    DateFormat('dd.MM.yyyy')
                        .format(rapor.adim1.sonMuayeneTarihi!)),
              if (rapor.adim1.hasarKayitAdet != null)
                _buildInfoRow(
                    'Hasar kaydı', '${rapor.adim1.hasarKayitAdet} adet'),
              if (rapor.adim1.hasarKayitToplamTutar != null)
                _buildInfoRow(
                    'Hasar Tutar', '${rapor.adim1.hasarKayitToplamTutar} TL'),
              _buildInfoRow(
                  'Pazarlık payı', rapor.adim1.pazarlikPayiVar ? 'Var' : 'Yok'),
              if (rapor.adim1.pazarlikMiktari != null)
                _buildInfoRow(
                    'Pazarlık miktarı', '${rapor.adim1.pazarlikMiktari} TL'),
              if (rapor.adim1.genelNot != null)
                _buildInfoRow('Not', rapor.adim1.genelNot!),
            ],
          ),
          const SizedBox(height: 16),
          _kontrolBolumu(
            title: 'Adım 2: Dış Ekspertiz',
            icon: LucideIcons.search,
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
      return _buildNoData('Adım 3-4 verisi yok');
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kontrolBolumu(
            title: 'Adım 3: İç Ekspertiz',
            icon: LucideIcons.armchair,
            bolum: 'ic',
            maddeler: Adim3IcEkspertizModel.maddeler,
            durum: rapor.adim3.durum,
            etiket: KontrolDurumu.etiket,
            renk: KontrolDurumu.renk,
            eksiklik: KontrolDurumu.eksiklikMi,
            not: rapor.adim3.not,
          ),
          if ((rapor.adim3.genelNot ?? '').isNotEmpty)
            _buildInfoRow('İç ekspertiz notu', rapor.adim3.genelNot!),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Adım 4: Boya / Kaporta Özeti',
            icon: LucideIcons.palette,
            children: [
              _buildInfoRow(
                  'Boyalı parçalar',
                  rapor.adim4.boyaliParcalar.isEmpty
                      ? '-'
                      : rapor.adim4.boyaliParcalar.join(', ')),
              _buildInfoRow(
                  'Değişen parçalar',
                  rapor.adim4.degisenParcalar.isEmpty
                      ? '-'
                      : rapor.adim4.degisenParcalar.join(', ')),
              _buildInfoRow('Hasar sayısı', '${rapor.adim4.hasarSayisi}'),
              if ((rapor.adim4.genelNot ?? '').isNotEmpty)
                _buildInfoRow('Genel not', rapor.adim4.genelNot!),
            ],
          ),
          const SizedBox(height: 16),
          _kontrolBolumu(
            title: 'Kaporta Parçaları',
            icon: LucideIcons.wrench,
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
            icon: LucideIcons.wrench,
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
              icon: LucideIcons.triangleAlert,
              color: context.renkler.uyari,
              children: rapor.adim4.hasarKayitlari
                  .map((h) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('${h.konum} (${h.tip})',
                              '${h.buyukluk}${(h.not ?? '').isEmpty ? '' : ' – ${h.not}'}'),
                          _thumbnails(_medya(RaporMedya.kategoriFoto,
                              bolum: 'boya_kaporta', maddeKey: h.id)),
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
            icon: LucideIcons.badgeCheck,
            color: adim5.kurumsalTalepVar && kurumsalDosyalar.isEmpty
                ? context.renkler.tehlike
                : null,
            children: [
              _buildInfoRow('Talep', adim5.kurumsalTalepVar ? 'Var' : 'Yok'),
              if ((adim5.kurumsalFirma ?? '').isNotEmpty)
                _buildInfoRow('Firma', adim5.kurumsalFirma!),
              if ((adim5.kurumsalPaket ?? '').isNotEmpty)
                _buildInfoRow('Paket', adim5.kurumsalPaket!),
              if ((adim5.kurumsalRaporNo ?? '').isNotEmpty)
                _buildInfoRow('Rapor No', adim5.kurumsalRaporNo!),
              if (adim5.kurumsalRaporTarihi != null)
                _buildInfoRow(
                    'Rapor Tarihi',
                    DateFormat('dd.MM.yyyy')
                        .format(adim5.kurumsalRaporTarihi!)),
              if ((adim5.kurumsalSonucOzeti ?? '').isNotEmpty)
                _buildInfoRow('Sonuç Özeti', adim5.kurumsalSonucOzeti!),
              if (kurumsalDosyalar.isEmpty)
                Text('Dosya eklenmemiş',
                    style: TextStyle(color: context.renkler.metinIkincil))
              else
                ...kurumsalDosyalar.map((m) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                          m.pdfMi ? LucideIcons.fileText : LucideIcons.image,
                          color: context.renkler.tehlike),
                      title: Text(m.dosyaAdi ?? 'Kurumsal rapor',
                          style: TextStyle(color: context.renkler.metin)),
                      subtitle: Text('Açmak için dokunun',
                          style:
                              TextStyle(color: context.renkler.metinIkincil)),
                      onTap: () => _medyaAc(m),
                    )),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Adım 5: Kurumsal Ekspertiz',
            icon: LucideIcons.building2,
            children: [
              _buildInfoRow('Ruhsat dosyası',
                  adim5.ruhsatDosyasiVar == true ? 'Mevcut' : 'Yok'),
              _buildInfoRow('Bakım defteri',
                  adim5.bakimDefteriVar == true ? 'Mevcut' : 'Yok'),
              _buildInfoRow('Sigorta poliçesi',
                  adim5.sigortaPolicesiVar == true ? 'Mevcut' : 'Yok'),
              _buildInfoRow('Muayene Belgesi',
                  adim5.muayeneBelgesiVar == true ? 'Mevcut' : 'Yok'),
              _buildDurumRow('Motor Durumu', adim5.motorDurumu),
              _buildDurumRow('Şanzıman', adim5.sanzimanDurumu),
              _buildDurumRow('Fren Sistemi', adim5.frenSistemi),
              _buildDurumRow('Direksiyon', adim5.direksiyonSistemi),
              _buildDurumRow('Elektrik Sistemi', adim5.elektrikSistemi),
              if (adim5.bataryaSagligi != null)
                _buildInfoRow('Batarya sağlığı', '%${adim5.bataryaSagligi}'),
              if (adim5.tahminiMenzil != null)
                _buildInfoRow('Tahmini Menzil', adim5.tahminiMenzil!),
              if (adim5.genelPuan != null)
                _buildInfoRow(
                    'Genel Puan', adim5.genelPuan!.toStringAsFixed(1)),
              if (adim5.ozetNot != null)
                _buildInfoRow('Özet not', adim5.ozetNot!),
              if (adim5.oneriler != null)
                _buildInfoRow('Öneriler', adim5.oneriler!),
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
            style: TextStyle(
                color: context.renkler.birincil, fontWeight: FontWeight.bold),
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
                          Text(m.maddeEtiket ?? '-',
                              style: TextStyle(
                                  color: context.renkler.metin, fontSize: 13)),
                          if (m.not.isNotEmpty)
                            Text(m.not,
                                style: TextStyle(
                                    color: context.renkler.metinIkincil,
                                    fontSize: 13)),
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

  Widget _yenidenAnalizButonu() {
    final status = _selectedReport?['status'];
    if (status != 'pending_ai' && status != 'pending_admin') {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: _isProcessing ? null : _reanalyze,
        icon: _isProcessing
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(LucideIcons.refreshCw, size: 18),
        label: Text(_aiSonucu == null
            ? 'AI Analizini Çalıştır'
            : 'AI Değerlemesini Yeniden Çalıştır'),
      ),
    );
  }

  /// Piyasa değeri → ekspertiz bulgularının değer kaybı (kalem kalem) → AI fiyatı
  Widget _degerlemeKarti(Map<String, dynamic> d) {
    final kalemler =
        (d['kalemler'] as List? ?? const []).whereType<Map>().toList();
    final duzeltmeler = (d['piyasaDuzeltmeleri'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final aralik =
        d['adilFiyatAraligi'] is Map ? d['adilFiyatAraligi'] as Map : const {};
    final yorum = d['fiyatYorumu'] is Map ? d['fiyatYorumu'] as Map : null;
    final yapildi = d['degerlemeYapildi'] == true;
    final agir = d['agirHasar'] == true;
    final kontroller =
        (d['kontrolGerekli'] as List? ?? const []).whereType<Map>().toList();
    final kaynaklar =
        (d['piyasaKaynaklari'] as List? ?? const []).whereType<Map>().toList();
    final duzeltme =
        d['adminDuzeltmesi'] is Map ? d['adminDuzeltmesi'] as Map : null;
    final duzeltilebilir =
        ['pending_ai', 'pending_admin'].contains(_selectedReport?['status']);
    final kaynakEtiketi = switch (d['piyasaKaynagi']) {
      'ai_estimate' => 'Piyasa değeri (yapay zekâ tahmini)',
      'web_listings' => 'Piyasa değeri (web emsal ilanları)',
      'admin_manual' => 'Piyasa değeri (admin düzeltmesi)',
      _ => 'Piyasa değeri (emsal ilanlar)',
    };
    final yorumRenk = switch (yorum?['karar']) {
      'AVANTAJLI' => context.renkler.birincilMetin,
      'MAKUL' => context.renkler.metinIkincil,
      'PAZARLIK' => context.renkler.uyari,
      'YUKSEK' => context.renkler.tehlike,
      _ => context.renkler.metinIkincil,
    };

    Widget satir(String sol, String sag,
            {Color? renk, bool kalin = false, String? alt}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sol,
                        style: TextStyle(
                            color: context.renkler.metinIkincil,
                            fontSize: 13,
                            fontWeight: kalin ? FontWeight.bold : null)),
                    if (alt != null && alt.isNotEmpty)
                      Text(alt,
                          style: TextStyle(
                              color: context.renkler.metinIkincil,
                              fontSize: 13)),
                  ],
                ),
              ),
              Text(sag,
                  style: TextStyle(
                      color: renk ?? context.renkler.metin,
                      fontSize: kalin ? 15 : 13,
                      fontWeight: kalin ? FontWeight.bold : FontWeight.w500)),
            ],
          ),
        );

    return _buildSectionCard(
      title: 'Ekspertiz Bazlı AI Değerlemesi',
      icon: LucideIcons.badgeCheck,
      color: agir ? context.renkler.tehlike : null,
      children: [
        if (kontroller.isNotEmpty) _kontrolKutusu(kontroller),
        if (duzeltme != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_duzeltmeMetni(duzeltme),
                style: TextStyle(color: context.renkler.bilgi, fontSize: 13)),
          ),
        if (yapildi) ...[
          if (d['piyasaUyarisi'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(' ${d['piyasaUyarisi']}',
                  style: TextStyle(
                      color: context.renkler.uyari,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          satir(kaynakEtiketi, _tl(d['piyasaDegeri']),
              alt: d['piyasaYontemi']?.toString()),
          if (duzeltilebilir)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isProcessing ? null : _piyasaDegeriDuzelt,
                icon: const Icon(LucideIcons.pencil, size: 16),
                label: const Text('Piyasa değerini düzelt'),
              ),
            ),
          if (kaynaklar.isNotEmpty) _kaynakListesi(kaynaklar),
          for (final a in duzeltmeler)
            satir('${a['baslik']} (${_yuzde(a['yuzde'])})',
                '${(a['tutar'] as num? ?? 0) >= 0 ? '+' : ''}${_tl(a['tutar'])}',
                alt: a['aciklama']?.toString()),
          satir('Temiz (hasarsız) piyasa değeri', _tl(d['temizPiyasaDegeri']),
              kalin: true),
          Divider(color: context.renkler.ayirici),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
                d['piyasaYontemi']?.toString() ?? 'Piyasa verisi yetersiz',
                style: TextStyle(color: context.renkler.uyari, fontSize: 13)),
          ),
        if (kalemler.isEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Değer kaybettiren bulgu yok',
                style: TextStyle(
                    color: context.renkler.birincilMetin, fontSize: 13)),
          ),
        for (final k in kalemler)
          satir('${k['baslik']} – ${k['durum']}',
              yapildi ? '−${_tl(k['tutar'])}' : '−${_yuzde(k['yuzde'])}',
              renk: context.renkler.uyari,
              alt: [
                if (yapildi) _yuzde(k['yuzde']),
                if ((k['aciklama'] ?? '').toString().isNotEmpty)
                  k['aciklama'].toString(),
              ].join(' · ')),
        satir(
            'Toplam değer kaybı (${_yuzde(d['toplamDegerKaybiYuzde'])})',
            yapildi
                ? '−${_tl(d['toplamDegerKaybiTutar'])}'
                : _yuzde(d['toplamDegerKaybiYuzde']),
            renk: context.renkler.tehlike,
            kalin: true),
        if (yapildi) ...[
          Divider(color: context.renkler.ayirici),
          satir('AI DEĞERİ (ekspertiz düzeltmeli)', _tl(d['aiDegeri']),
              renk: context.renkler.birincil, kalin: true),
          satir('Adil fiyat aralığı',
              '${_tl(aralik['min'])} – ${_tl(aralik['max'])}'),
          satir(
              'Önerilen alım / pazarlık fiyatı', _tl(d['onerilenAlimFiyati'])),
          if (yorum != null)
            satir('İlan fiyatı ${_tl(d['ilanFiyati'])}',
                '${yorum['farkYuzde'] is num && yorum['farkYuzde'] > 0 ? '+' : ''}${_yuzde(yorum['farkYuzde'])}',
                renk: yorumRenk, alt: yorum['aciklama']?.toString()),
          satir('Güven skoru', '${d['guvenSkoru'] ?? '-'} / 100',
              alt: d['eskiPiyasaVerisi'] == true
                  ? 'Emsal ilanların çoğu 90 günden eski'
                  : null),
        ],
        satir('Hasar seviyesi',
            '${d['hasarSeviyesi'] ?? '-'}${agir ? ' (ağır hasar)' : ''}',
            renk: agir ? context.renkler.tehlike : null),
      ],
    );
  }

  Widget _buildAiAnalizTab() {
    if (_aiSonucu == null) {
      final status = _selectedReport?['status'];
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildNoData(status == 'pending_ai'
              ? 'AI değerlemesi çalışıyor / bekliyor. Birkaç saniye içinde düşmezse tekrar çalıştırın.'
              : 'AI analiz sonucu mevcut değil'),
          _yenidenAnalizButonu(),
        ],
      );
    }
    final ai = _aiSonucu!;
    final degerleme = _degerleme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _yenidenAnalizButonu(),
          if (degerleme != null) ...[
            _degerlemeKarti(degerleme),
            const SizedBox(height: 16),
          ],
          _buildSectionCard(
            title: 'AI Skorları',
            icon: LucideIcons.gauge,
            children: [
              _buildScoreBar('Genel Puan', ai.skorlar.genelPuan),
              _buildScoreBar('Araç durumu', ai.skorlar.aracDurumuPuan),
              _buildScoreBar('Motor/Mekanik', ai.skorlar.motorMekanikPuan),
              _buildScoreBar('Hasar', ai.skorlar.hasarPuan),
              _buildInfoRow('Değerlendirme', ai.skorlar.puanDegerlendirmesi),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Değerlendirme',
            icon: LucideIcons.chartNoAxesCombined,
            children: [
              _buildInfoRow('Genel Sonuc', ai.raporOzeti.genelSonuc),
              _buildInfoRow(
                  'AI Değeri',
                  degerleme != null
                      ? _tl(degerleme['aiDegeri'])
                      : ai.raporOzeti.tahminiDegerFormatli),
              _buildInfoRow('Değer Kaybı', ai.raporOzeti.degerKaybiFormatli),
              _buildInfoRow('Öneri', ai.raporOzeti.onayRedOnerisi),
              _buildInfoRow('Özet', ai.raporOzeti.ozetAciklama),
            ],
          ),
          if (ai.raporOzeti.anahtarBulgular.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Anahtar Bulgular',
              icon: LucideIcons.lightbulb,
              children: ai.raporOzeti.anahtarBulgular
                  .map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('  \u2022 ',
                                style: TextStyle(
                                    color: context.renkler.birincil,
                                    fontSize: 14)),
                            Expanded(
                              child: Text(b,
                                  style: TextStyle(
                                      color: context.renkler.metinIkincil,
                                      fontSize: 13)),
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
              icon: LucideIcons.triangleAlert,
              color: context.renkler.tehlike,
              children: ai.kritikSorunlar
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('  ! ',
                                style: TextStyle(
                                    color: context.renkler.tehlike,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(s,
                                  style: TextStyle(
                                      color: context.renkler.tehlike,
                                      fontSize: 13)),
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
              title: 'Öneriler (${ai.oneriler.length})',
              icon: LucideIcons.lightbulb,
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
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(o.baslik,
                                      style: TextStyle(
                                          color: context.renkler.metin,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ),
                              ],
                            ),
                            if (o.aciklama.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 16, top: 4),
                                child: Text(o.aciklama,
                                    style: TextStyle(
                                        color: context.renkler.metinIkincil,
                                        fontSize: 13)),
                              ),
                            if ((o.onerilenEylem ?? '').isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 16, top: 2),
                                child: Text('→ ${o.onerilenEylem}',
                                    style: TextStyle(
                                        color: context.renkler.metinIkincil,
                                        fontSize: 13)),
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
        return context.renkler.tehlike;
      case 'Onemli':
      case 'Önemli':
        return context.renkler.uyari;
      default:
        return context.renkler.birincil;
    }
  }

  Widget _buildActionBar() {
    final status = _selectedReport?['status']?.toString();
    if (status == 'published') {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ReportArchiveAction(
          key: ValueKey(_selectedReport!['id']),
          report: _selectedReport!,
          api: _expertizApi,
          onArchived: (reportId) async {
            await _loadReports(silent: true);
            final response = await _expertizApi.getAdminReportDetail(reportId);
            final report = response['report'];
            if (mounted &&
                _selectedReport?['id'].toString() == reportId &&
                report is Map) {
              _selectReport(Map<String, dynamic>.from(report));
            }
          },
        ),
      );
    }
    final hasOfficialAi = _hasOfficialCentralAi(_selectedReport);
    final hasFallbackPreview = _hasFlutterFallbackPreview(_selectedReport);
    final canApprove = status == 'pending_admin' && hasOfficialAi;
    final canReject = status == 'pending_admin';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.renkler.yuzey,
        border: Border(
            top: BorderSide(
                color: context.renkler.birincil.withValues(alpha: 0.2))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'pending_ai')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(LucideIcons.hourglass,
                      color: context.renkler.bilgi, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Personel raporu geldi; merkezi AI değerlemesi bekleniyor. Tamamlanınca onaya açılır.',
                      style:
                          TextStyle(color: context.renkler.bilgi, fontSize: 13),
                    ),
                  ),
                  TextButton(
                      onPressed: _isProcessing ? null : _reanalyze,
                      child: const Text('Şimdi çalıştır')),
                ],
              ),
            ),
          if (status == 'pending_admin' && !hasOfficialAi)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(LucideIcons.triangleAlert,
                      color: context.renkler.uyari, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasFallbackPreview
                          ? 'Geçici ön analiz var. Resmî yayın için merkezi AI sonucu bekleniyor.'
                          : 'Resmî yayın için merkezi AI analizi gereklidir.',
                      style:
                          TextStyle(color: context.renkler.uyari, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _isProcessing ? null : (canReject ? _rejectReport : null),
                  icon: const Icon(LucideIcons.circleX, size: 20),
                  label: const Text('Reddet', style: TextStyle(fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.renkler.tehlike,
                    side: BorderSide(color: context.renkler.tehlike),
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
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: context.renkler.metin),
                        )
                      : const Icon(LucideIcons.badgeCheck, size: 20),
                  label: Text(
                      _isProcessing ? 'Yayınlanıyor…' : 'Onayla ve yayınla',
                      style: const TextStyle(fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canApprove
                        ? context.renkler.birincil
                        : context.renkler.metinIkincil,
                    foregroundColor: context.renkler.metin,
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
    final accent = color ?? context.renkler.birincil;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.renkler.metin.withValues(alpha: 0.03),
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
                style: TextStyle(
                    color: context.renkler.metinIkincil, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: context.renkler.metin,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildDurumRow(String label, String? durum) {
    if (durum == null) return SizedBox.shrink();
    final color = _getDurumColor(durum);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: TextStyle(
                    color: context.renkler.metinIkincil, fontSize: 13)),
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
                    color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Color _getDurumColor(String durum) {
    final lower = durum.toLowerCase();
    if (lower.contains('orijinal') ||
        lower.contains('iyi') ||
        lower.contains('mukemmel')) {
      return context.renkler.birincilMetin;
    }
    if (lower.contains('boya') ||
        lower.contains('degisen') ||
        lower.contains('orta')) {
      return context.renkler.uyari;
    }
    if (lower.contains('hasar') ||
        lower.contains('kotu') ||
        lower.contains('boyali')) {
      return context.renkler.tehlike;
    }
    return context.renkler.metinIkincil;
  }

  Widget _buildScoreBar(String label, double score) {
    final color = score >= 80
        ? context.renkler.birincilMetin
        : score >= 60
            ? context.renkler.uyari
            : context.renkler.tehlike;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      color: context.renkler.metinIkincil, fontSize: 13)),
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
              backgroundColor: context.renkler.metin.withValues(alpha: 0.1),
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
          Icon(LucideIcons.info,
              size: 48, color: context.renkler.metin.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: context.renkler.metinIkincil)),
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

/// Yayın onay penceresi; not alanının controller'ı pencereyle birlikte yaşar
/// (kapanış animasyonu sırasında dispose edilmiş controller kullanılmaz).
class _YayinOnayDialog extends StatefulWidget {
  final List<Widget> maddeler;
  const _YayinOnayDialog({required this.maddeler});

  @override
  State<_YayinOnayDialog> createState() => _YayinOnayDialogState();
}

class _YayinOnayDialogState extends State<_YayinOnayDialog> {
  final TextEditingController _not = TextEditingController();

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.renkler.yuzey,
      title: Text('Raporu Onayla ve Müşteriye Gönder',
          style: TextStyle(color: context.renkler.metin)),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Müşteriye gidecekler:',
                style: TextStyle(color: context.renkler.metinIkincil)),
            const SizedBox(height: 8),
            ...widget.maddeler,
            const SizedBox(height: 12),
            TextField(
              controller: _not,
              maxLines: 3,
              maxLength: 2000,
              style: TextStyle(color: context.renkler.metin),
              decoration: InputDecoration(
                labelText: 'Müşteriye not (opsiyonel)',
                labelStyle: TextStyle(color: context.renkler.metinIkincil),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('İptal',
              style: TextStyle(color: context.renkler.metinIkincil)),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(_not.text),
          icon: const Icon(LucideIcons.badgeCheck),
          label: const Text('Onayla & Yayınla'),
          style: ElevatedButton.styleFrom(
              backgroundColor: context.renkler.birincil,
              foregroundColor: context.renkler.metin),
        ),
      ],
    );
  }
}
