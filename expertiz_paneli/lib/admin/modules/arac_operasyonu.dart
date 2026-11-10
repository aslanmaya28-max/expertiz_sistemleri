import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../tema/renkler.dart';
import '../../bilesenler/bilesenler.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/mappers/location_mapper.dart';
import '../../services/yerimebak_expertiz_api_service.dart';

/// Araç Operasyonu Modülü
///
/// Müşteri talepleri merkezi API'den gelir ve 4 sekmede izlenir:
/// - Atama Bekleyen: müşteri talebi oluşturdu, personel atanmadı
/// - İşlemdeki: personele atandı (kabul / inceleme / düzeltme)
/// - Onay Bekleyen: personel raporu gönderdi (AI / admin onayı)
/// - Tamamlanan: rapor yayınlandı
///
/// Atama, bölge sistemine göre önerilen personel listesinden yapılır
/// (önce aynı ilçe, sonra aynı il, sonra aynı bölge; görev için pasif personel
/// atanamaz). İşlemdeki taleplerde personelin saha adımı (harekete geçti, araç
/// başında, kurumsal ekspertizde) canlı görünür.
class AracOperasyonu extends StatefulWidget {
  const AracOperasyonu(
      {super.key,
      this.apiService,
      this.openListing,
      this.initialBucket,
      this.refundOnly = false});

  /// Testler için enjekte edilebilir.
  final YerimebakExpertizApiService? apiService;
  final Future<bool> Function(Uri)? openListing;
  final String? initialBucket;
  final bool refundOnly;

  @override
  State<AracOperasyonu> createState() => _AracOperasyonuState();
}

class _AracOperasyonuState extends State<AracOperasyonu>
    with SingleTickerProviderStateMixin {
  static const _buckets = [
    'waiting_assignment',
    'in_progress',
    'pending_approval',
    'completed',
    'cancelled'
  ];
  static const _bucketTitles = [
    'Atama Bekleyen',
    'İşlemdeki',
    'Onay Bekleyen',
    'Tamamlanan',
    'İptal Edilen'
  ];
  static const _emptyMessages = [
    'Atama bekleyen talep yok',
    'İşlemde talep yok',
    'Onay bekleyen rapor yok',
    'Tamamlanan rapor yok',
    'İptal edilen talep yok',
  ];

  late final TabController _tabController;
  late final YerimebakExpertizApiService _api;
  final LocationMapper _locationMapper = LocationMapper();
  Timer? _autoRefresh;

  List<Map<String, dynamic>> _requests = [];
  Map<String, int> _counts = {};
  bool _isLoading = true;
  String? _error;
  int _regionId = 0;
  DateTime? _lastUpdated;
  String _search = '';
  late bool _refundOnly;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _api = widget.apiService ?? YerimebakExpertizApiService();
    _refundOnly = widget.refundOnly;
    final bucketIndex = _buckets.indexOf(widget.initialBucket ??
        (_refundOnly ? 'in_progress' : 'waiting_assignment'));
    _tabController = TabController(
        length: _buckets.length,
        vsync: this,
        initialIndex: bucketIndex < 0 ? 0 : bucketIndex);
    _load();
    // Yeni müşteri talepleri admin açık ekranda beklerken de düşsün
    _autoRefresh =
        Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AracOperasyonu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialBucket != widget.initialBucket ||
        oldWidget.refundOnly != widget.refundOnly) {
      _refundOnly = widget.refundOnly;
      final index = _buckets.indexOf(widget.initialBucket ??
          (_refundOnly ? 'in_progress' : 'waiting_assignment'));
      _tabController.index = index < 0 ? 0 : index;
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final response = await _api.getAdminRequests(
          regionId: _regionId == 0 ? null : _regionId);
      final rows = (response['requests'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final counts = <String, int>{};
      final rawCounts = response['counts'];
      if (rawCounts is Map) {
        rawCounts.forEach(
            (key, value) => counts['$key'] = (value as num?)?.toInt() ?? 0);
      }
      if (!mounted) return;
      setState(() {
        _requests = rows;
        _counts = counts;
        _isLoading = false;
        _error = null;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // Sessiz yenilemede mevcut listeyi koru, sadece ilk yüklemede hata ekranı göster
        if (!silent || _requests.isEmpty) _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> _itemsFor(String bucket) => _requests.where((r) {
        if (r['bucket'] != bucket || (_refundOnly && !_aracBulunamadi(r))) {
          return false;
        }
        final search = _search.trim().toLowerCase();
        if (search.isEmpty) return true;
        final vehicle = _map(r['vehicle']);
        final customer = _map(r['customer']);
        final assignment = _map(r['assignment']);
        return [
          vehicle['plate'],
          vehicle['title'],
          customer['name'],
          r['city'],
          r['firm_name'],
          assignment['personnel_name']
        ].any(
            (value) => (value ?? '').toString().toLowerCase().contains(search));
      }).toList();

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            error ? context.renkler.tehlike : context.renkler.birincil,
        duration: Duration(seconds: error ? 5 : 3),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.renkler.zemin,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Talepler',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                  'Ekspertiz taleplerini takip edin, personel atayın ve randevuları yönetin.',
                  style: TextStyle(color: context.renkler.metinIkincil)),
              const SizedBox(height: 16),
              YbArama(
                  ipucu: 'Plaka, araç, müşteri veya personel ara',
                  onChanged: (value) => setState(() => _search = value)),
              const SizedBox(height: 12),
              // Süzgeçler aramanın altında, zeminle aynı (ayrı renkli şerit yok)
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: context.renkler.yuzey,
                      border: Border.all(color: context.renkler.girdiKenarlik),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.mapPin,
                          color: context.renkler.metinIkincil, size: 16),
                      const SizedBox(width: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _regionId,
                          isDense: true,
                          dropdownColor: context.renkler.yuzey,
                          borderRadius: BorderRadius.circular(10),
                          icon: Icon(LucideIcons.chevronDown,
                              size: 16, color: context.renkler.metinIkincil),
                          style: TextStyle(
                              color: context.renkler.metin, fontSize: 13),
                          items: [
                            const DropdownMenuItem(
                                value: 0, child: Text('Tüm bölgeler')),
                            ..._locationMapper.getAllBolgeIds().map(
                                  (id) => DropdownMenuItem(
                                      value: id,
                                      child: Text(
                                          _locationMapper.getBolgeAdi(id))),
                                ),
                          ],
                          onChanged: (value) {
                            setState(() => _regionId = value ?? 0);
                            _load();
                          },
                        ),
                      ),
                    ]),
                  ),
                  FilterChip(
                      label: const Text('İade kararı bekleyen'),
                      selected: _refundOnly,
                      onSelected: (value) => setState(() {
                            _refundOnly = value;
                            if (value) _tabController.index = 1;
                          })),
                  if (_lastUpdated != null)
                    Text(
                      'Güncellendi ${DateFormat('HH:mm').format(_lastUpdated!)}',
                      style: TextStyle(
                          color: context.renkler.metinIkincil, fontSize: 13),
                    ),
                  IconButton(
                    tooltip: 'Yenile',
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                    onPressed: _load,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: List.generate(_buckets.length, (i) {
                final count =
                    _counts[_buckets[i]] ?? _itemsFor(_buckets[i]).length;
                return Tab(text: '${_bucketTitles[i]} ($count)');
              }),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(_buckets.length,
                  (i) => _buildListTab(_buckets[i], _emptyMessages[i])),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTab(String bucket, String emptyMessage) {
    if (_error != null && _requests.isEmpty) {
      return YbBosDurum(
          mesaj: _error ?? 'Talepler yüklenemedi',
          eylem: 'Tekrar dene',
          onPressed: _load);
    }
    if (_isLoading && _requests.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: YbIskelet(height: 110),
        ),
      );
    }
    final items = _itemsFor(bucket);
    return RefreshIndicator(
      onRefresh: _load,
      child: items.isEmpty
          ? ListView(children: [
              SizedBox(height: 420, child: _buildEmptyState(emptyMessage))
            ])
          : LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 1000
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _requestTable(items))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) =>
                          _buildRequestCard(items[index]),
                    )),
    );
  }

  Widget _buildEmptyState(String message) => YbBosDurum(mesaj: message);

  Widget _requestTable(List<Map<String, dynamic>> items) => YbTablo(
        sayfa: _page,
        onPageChanged: (value) => setState(() => _page = value),
        columns: const [
          DataColumn(label: Text('Talep / plaka')),
          DataColumn(label: Text('İl / ilçe')),
          DataColumn(label: Text('Firma / personel')),
          DataColumn(label: Text('Durum')),
          DataColumn(label: Text('Randevu')),
          DataColumn(label: Text('Ayrıntı')),
        ],
        rows: items.map((request) {
          final vehicle = _map(request['vehicle']);
          final assignment = _map(request['assignment']);
          final status = _statusOf(request);
          return DataRow(cells: [
            DataCell(
                Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle['title']?.toString() ?? 'Araç',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(_orDash(vehicle['plate']),
                          style:
                              TextStyle(color: context.renkler.metinIkincil)),
                    ]),
                onTap: () => _showDetail(request)),
            DataCell(Text([request['city'], request['district']]
                .where((v) => v != null && v.toString().isNotEmpty)
                .join(' / '))),
            DataCell(Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_orDash(request['firm_name'])),
                  Text(_orDash(assignment['personnel_name']),
                      style: TextStyle(color: context.renkler.metinIkincil)),
                ])),
            DataCell(_chip(status.label, status.color)),
            DataCell(Text(
                'Randevu: ${_formatDate(_map(request['randevu'])['tarih_saat'])}')),
            DataCell(IconButton(
                tooltip: 'Talep ayrıntısı',
                icon: const Icon(LucideIcons.chevronRight),
                onPressed: () => _showDetail(request))),
          ]);
        }).toList(),
      );

  // ---------------------------------------------------------------------------
  // Kart
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '-';
    return DateFormat('dd.MM.yyyy HH:mm').format(date.toLocal());
  }

  ({String label, Color color}) _statusOf(Map<String, dynamic> request) {
    final assignment = _map(request['assignment']);
    final status = request['status']?.toString();
    switch (request['bucket']) {
      case 'waiting_assignment':
        return (label: 'Atama bekliyor', color: context.renkler.uyari);
      case 'pending_approval':
        return status == 'pending_ai'
            ? (label: 'AI analizi bekliyor', color: context.renkler.bilgi)
            : (
                label: 'Admin onayı bekliyor',
                color: context.renkler.birincilMetin
              );
      case 'completed':
        return (label: 'Yayınlandı', color: context.renkler.birincil);
      case 'cancelled':
        final refunded =
            (_map(request['cancellation'])['refunded_tl'] as num?) ?? 0;
        return (
          label: refunded > 0 ? 'İptal + iade edildi' : 'İptal edildi',
          color: context.renkler.metinIkincil
        );
    }
    if (_aracBulunamadi(request)) {
      return (label: 'Araç adreste yok', color: context.renkler.uyari);
    }
    if (request['needs_revision'] == true) {
      return (label: 'Düzeltme bekliyor', color: context.renkler.tehlike);
    }
    switch (assignment['status']) {
      case 'accepted':
        return (
          label: 'Personel kabul etti',
          color: context.renkler.birincilMetin
        );
      case 'on_the_way':
        return (label: 'Harekete geçti', color: context.renkler.uyari);
      case 'at_vehicle':
        return (label: 'Araç başında', color: context.renkler.birincilMetin);
      case 'at_corporate':
        return (label: 'Kurumsal ekspertizde', color: context.renkler.bilgi);
      case 'in_progress':
        return (label: 'Rapor hazırlanıyor', color: context.renkler.bilgi);
      default:
        return (label: 'Personele atandı', color: context.renkler.bilgi);
    }
  }

  /// Saha "araç adreste yok" bildirdi; görev yönetim kararını (paket ücreti iadesi) bekliyor.
  bool _aracBulunamadi(Map<String, dynamic> request) =>
      request['durum_kodu'] == 'vehicle_not_found' &&
      request['bucket'] != 'cancelled';

  String _randevuOzeti(Map<String, dynamic> request) {
    final randevu = _map(request['randevu']);
    if (randevu.isEmpty) return '';
    final zaman = _formatDate(randevu['tarih_saat']);
    final adres = (randevu['adres'] ?? '').toString().trim();
    return [if (zaman != '-') zaman, if (adres.isNotEmpty) adres].join(' • ');
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final vehicle = _map(request['vehicle']);
    final customer = _map(request['customer']);
    final assignment = _map(request['assignment']);
    final status = _statusOf(request);
    final randevuOzeti = _randevuOzeti(request);
    final bucket = request['bucket'];
    final district = request['district']?.toString() ?? '';
    final city = [request['city']?.toString() ?? '', district]
        .where((e) => e.isNotEmpty)
        .join(' / ');
    final region = request['region']?.toString() ?? '';
    final assignedName = assignment['personnel_name']?.toString() ?? '';

    final actions = _requestActions(request);

    return YbKart(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(request),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: status.color.withValues(alpha: 0.2),
                        shape: BoxShape.circle),
                    child: Icon(LucideIcons.car, color: status.color),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      vehicle['title']?.toString() ?? 'Araç',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.renkler.metin),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _chip(status.label, status.color),
                ],
              ),
              SizedBox(height: 10),
              Wrap(
                spacing: 18,
                runSpacing: 4,
                children: [
                  _info(
                      LucideIcons.hash, 'Plaka: ${_orDash(vehicle['plate'])}'),
                  _info(LucideIcons.user,
                      'Müşteri: ${_orDash(customer['name'])}'),
                  _info(LucideIcons.phone, _orDash(customer['phone'])),
                  _info(LucideIcons.mapPin,
                      region.isEmpty ? _orDash(city) : '$city • $region'),
                  _info(LucideIcons.package,
                      '${_orDash(request['firm_name'])} – ${_orDash(request['package_name'])}'),
                  _info(LucideIcons.clock, _formatDate(request['created_at'])),
                  if (randevuOzeti.isNotEmpty)
                    _info(LucideIcons.calendarClock, 'Randevu: $randevuOzeti',
                        color: context.renkler.uyari),
                  if (assignedName.isNotEmpty)
                    _info(LucideIcons.contact, 'Personel: $assignedName',
                        color: context.renkler.bilgi),
                ],
              ),
              if (bucket == 'cancelled' &&
                  _map(request['cancellation']).isNotEmpty) ...[
                SizedBox(height: 6),
                _info(LucideIcons.circleX,
                    'İptal nedeni: ${_orDash(_map(request['cancellation'])['reason'])}',
                    color: context.renkler.metinIkincil),
              ],
              if (request['needs_revision'] == true &&
                  (request['rejection_reason'] ?? '')
                      .toString()
                      .isNotEmpty) ...[
                SizedBox(height: 6),
                _info(LucideIcons.triangleAlert,
                    'Red nedeni: ${request['rejection_reason']}',
                    color: context.renkler.tehlike),
              ],
              if (actions.isNotEmpty) ...[
                SizedBox(height: 10),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }

  VoidCallback _action(VoidCallback action, bool closeDetail) => () {
        if (closeDetail) Navigator.pop(context);
        action();
      };

  List<Widget> _requestActions(Map<String, dynamic> request,
      {bool closeDetail = false}) {
    final bucket = request['bucket'];
    final actions = <Widget>[];
    if (bucket == 'waiting_assignment') {
      actions.add(FilledButton.icon(
        onPressed: _action(() => _openAssignDialog(request), closeDetail),
        icon: Icon(LucideIcons.userPlus, size: 18),
        label: Text('Personel Ata'),
      ));
    } else if (bucket == 'pending_approval') {
      actions.add(Text(
        'Personel raporu gönderdi • İncelemek ve yayınlamak için "Raporlar" sekmesini açın',
        style: TextStyle(color: context.renkler.metinIkincil, fontSize: 13),
      ));
    }
    if (_aracBulunamadi(request)) {
      actions.add(FilledButton.icon(
        key: Key('bulunamadi-iade-${request['id']}'),
        style: FilledButton.styleFrom(backgroundColor: context.renkler.uyari),
        onPressed: _action(() => _confirmNotFoundRefund(request), closeDetail),
        icon: Icon(LucideIcons.rotateCcw, size: 18),
        label: Text('Paket ücretini iade et'),
      ));
    }
    if (bucket == 'in_progress' && !_aracBulunamadi(request)) {
      actions.addAll([
        OutlinedButton.icon(
          onPressed: _action(() => _openAssignDialog(request), closeDetail),
          icon: Icon(LucideIcons.repeat2, size: 18),
          label: Text('Yeniden Ata'),
        ),
        TextButton.icon(
          onPressed: _action(() => _confirmUnassign(request), closeDetail),
          icon: Icon(LucideIcons.userMinus,
              size: 18, color: context.renkler.tehlike),
          label: Text('Atamayı Kaldır',
              style: TextStyle(color: context.renkler.tehlike)),
        ),
      ]);
    }
    if (bucket != 'completed' && bucket != 'cancelled') {
      actions.add(TextButton.icon(
        key: Key('cancel-${request['id']}'),
        onPressed: _action(() => _confirmCancel(request), closeDetail),
        icon: Icon(LucideIcons.ban, size: 18, color: context.renkler.uyari),
        label: Text('İptal / İade',
            style: TextStyle(color: context.renkler.uyari)),
      ));
    }

    return actions;
  }

  String _orDash(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  Widget _chip(String text, Color color) => YbRozet(text,
      tur: color == context.renkler.tehlike
          ? YbRozetTuru.tehlike
          : color == context.renkler.uyari
              ? YbRozetTuru.uyari
              : color == context.renkler.birincil ||
                      color == context.renkler.birincilMetin
                  ? YbRozetTuru.basari
                  : color == context.renkler.bilgi
                      ? YbRozetTuru.bilgi
                      : YbRozetTuru.notr);

  Widget _info(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: context.renkler.ikonPasif),
        SizedBox(width: 4),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(text,
                style: TextStyle(
                    fontSize: 13, color: color ?? context.renkler.metinGovde)),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Detay
  // ---------------------------------------------------------------------------

  void _showDetail(Map<String, dynamic> request) {
    final vehicle = _map(request['vehicle']);
    final listingUrl = (vehicle['listing_url'] ?? '').toString().trim();
    final listingUri = Uri.tryParse(
        listingUrl.contains('://') ? listingUrl : 'https://$listingUrl');
    final canOpenListing = listingUrl.isNotEmpty &&
        listingUri != null &&
        (listingUri.scheme == 'https' || listingUri.scheme == 'http') &&
        listingUri.host.isNotEmpty &&
        listingUri.userInfo.isEmpty;
    final customer = _map(request['customer']);
    final assignment = _map(request['assignment']);
    final history =
        (assignment['history'] as List? ?? const []).whereType<Map>().toList();
    final randevu = _map(request['randevu']);
    final bulunamadiNotu = history.reversed
            .where((h) => h['action'] == 'vehicle_not_found')
            .map((h) => (h['note'] ?? '').toString().trim())
            .firstOrNull ??
        '';
    // İletişim geçmişi yalnız kontrol merkezinin aradığı/not düşülen talepler için dolu gelir.
    final iletisim = _api
        .getContactLog(request['id'].toString())
        .then((r) =>
            (r['kayitlar'] as List? ?? const []).whereType<Map>().toList())
        .catchError((Object _) => <Map>[]);
    const actionLabels = {
      'vehicle_not_found': 'Araç adreste yok bildirildi',
      'assigned': 'Atandı',
      'reassigned': 'Yeniden atandı',
      'unassigned': 'Atama kaldırıldı',
      'released': 'Kuyruğa döndü',
      'accept': 'Personel kabul etti',
      'start': 'İnceleme başladı',
    };

    showDialog<void>(
      context: context,
      builder: (sheetContext) => Dialog(
        alignment: Alignment.centerRight,
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
            width: 480,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(vehicle['title']?.toString() ?? 'Talep',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.renkler.metin)),
                SizedBox(height: 4),
                Text('Talep No: ${request['request_id'] ?? request['id']}',
                    style: TextStyle(
                        color: context.renkler.ikonPasif, fontSize: 13)),
                SizedBox(height: 16),
                _detailRow('Durum', _statusOf(request).label),
                _detailRow('Plaka', _orDash(vehicle['plate'])),
                _detailRow('Marka', _orDash(vehicle['brand'])),
                _detailRow('Model', _orDash(vehicle['model'])),
                _detailRow('İlan', _orDash(vehicle['listing_url'])),
                if (canOpenListing)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('openListingButton'),
                      icon: Icon(LucideIcons.externalLink),
                      label: Text('İlanı aç'),
                      onPressed: () async {
                        bool opened;
                        try {
                          opened =
                              await (widget.openListing?.call(listingUri) ??
                                  launchUrl(listingUri,
                                      mode: LaunchMode.externalApplication,
                                      webOnlyWindowName: '_blank'));
                        } catch (_) {
                          opened = false;
                        }
                        if (!opened && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'İlan açılamadı. Yukarıdaki bağlantıyı kopyalayıp tarayıcıda açabilirsiniz.'),
                          ));
                        }
                      },
                    ),
                  ),
                _detailRow('Müşteri', _orDash(customer['name'])),
                _detailRow('Telefon', _orDash(customer['phone'])),
                _detailRow('E-posta', _orDash(customer['email'])),
                _detailRow('İl / İlçe / Bölge',
                    '${_orDash(request['city'])} / ${_orDash(request['district'])} / ${_orDash(request['region'])}'),
                _detailRow('Firma / Paket',
                    '${_orDash(request['firm_name'])} / ${_orDash(request['package_name'])}'),
                _detailRow('Tutar',
                    '${NumberFormat.decimalPattern('tr').format(request['total_tl'] ?? 0)} TL'),
                _detailRow('Müşteri notu', _orDash(request['note'])),
                _detailRow('Oluşturma', _formatDate(request['created_at'])),
                if (randevu.isNotEmpty) ...[
                  Divider(color: context.renkler.ayirici, height: 28),
                  Text('Randevu',
                      style: TextStyle(
                          color: context.renkler.metin,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  _detailRow(
                      'Tarih / saat', _formatDate(randevu['tarih_saat'])),
                  _detailRow('Adres', _orDash(randevu['adres'])),
                  _detailRow('Satıcı', _orDash(randevu['satici_adi'])),
                  _detailRow('Satıcı tel.', _orDash(randevu['satici_telefon'])),
                ],
                if (_aracBulunamadi(request)) ...[
                  Divider(color: context.renkler.ayirici, height: 28),
                  Container(
                    key: const Key('bulunamadi-uyarisi'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.renkler.uyari.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.renkler.uyari),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Saha personeli aracın randevu adresinde olmadığını bildirdi.',
                            style: TextStyle(
                                color: context.renkler.metin,
                                fontWeight: FontWeight.bold)),
                        if (bulunamadiNotu.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text('Personel notu: $bulunamadiNotu',
                              style:
                                  TextStyle(color: context.renkler.metinGovde)),
                        ],
                        SizedBox(height: 4),
                        Text(
                          'Müşteri ödeme öncesi bu koşulu onayladı: yalnız kurumsal paket ücreti iade edilir, '
                          'hizmet bedeli iade edilmez.',
                          style: TextStyle(
                              color: context.renkler.metinIkincil,
                              fontSize: 13),
                        ),
                        SizedBox(height: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: context.renkler.uyari),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _confirmNotFoundRefund(request);
                          },
                          icon: Icon(LucideIcons.rotateCcw, size: 18),
                          label: Text('Paket ücretini iade et'),
                        ),
                      ],
                    ),
                  ),
                ],
                if ((assignment['personnel_name'] ?? '')
                    .toString()
                    .isNotEmpty) ...[
                  Divider(color: context.renkler.ayirici, height: 28),
                  _detailRow(
                      'Atanan personel', _orDash(assignment['personnel_name'])),
                  _detailRow(
                      'Personel tel.', _orDash(assignment['personnel_phone'])),
                  _detailRow(
                      'Atama zamanı', _formatDate(assignment['assigned_at'])),
                  _detailRow('Atayan', _orDash(assignment['assigned_by'])),
                  _detailRow('Admin notu', _orDash(assignment['note'])),
                  Divider(color: context.renkler.ayirici, height: 28),
                  Text('Saha durumu',
                      style: TextStyle(
                          color: context.renkler.metin,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  _detailRow('Kabul', _formatDate(assignment['accepted_at'])),
                  _detailRow(
                      'Harekete geçti', _formatDate(assignment['departed_at'])),
                  _detailRow(
                      'Araç başında', _formatDate(assignment['arrived_at'])),
                  if (request['corporate_required'] == true)
                    _detailRow('Kurumsal ekspertizde',
                        _formatDate(assignment['corporate_at'])),
                  _detailRow(
                      'Rapora başladı', _formatDate(assignment['started_at'])),
                  _detailRow('Rapor gönderildi',
                      _formatDate(assignment['submitted_at'])),
                ],
                if (history.isNotEmpty) ...[
                  Divider(color: context.renkler.ayirici, height: 28),
                  Text('Atama geçmişi',
                      style: TextStyle(
                          color: context.renkler.metin,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  ...history.reversed.map((h) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(LucideIcons.history,
                            color: context.renkler.ikonPasif, size: 18),
                        title: Text(
                          '${actionLabels[h['action']] ?? h['action']}'
                          '${(h['personnel_name'] ?? '').toString().isNotEmpty ? ' – ${h['personnel_name']}' : ''}',
                          style: TextStyle(
                              color: context.renkler.metinGovde, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${_formatDate(h['at'])} • ${_orDash(h['by'])}'
                          '${(h['note'] ?? '').toString().isNotEmpty ? ' • ${h['note']}' : ''}',
                          style: TextStyle(
                              color: context.renkler.ikonPasif, fontSize: 13),
                        ),
                      )),
                ],
                FutureBuilder<List<Map>>(
                  future: iletisim,
                  builder: (context, snapshot) {
                    final kayitlar = snapshot.data ?? const <Map>[];
                    if (kayitlar.isEmpty) return SizedBox.shrink();
                    return Column(
                      key: const Key('iletisim-gecmisi'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: context.renkler.ayirici, height: 28),
                        Text('Kontrol merkezi iletişim geçmişi',
                            style: TextStyle(
                                color: context.renkler.metin,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        for (final k in kayitlar)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(LucideIcons.headset,
                                color: context.renkler.ikonPasif, size: 18),
                            title: Text(
                              '${_iletisimHedefleri[k['hedef']] ?? k['hedef']} · '
                              '${_iletisimSonuclari[k['sonuc']] ?? k['sonuc']}',
                              style: TextStyle(
                                  color: context.renkler.metinGovde,
                                  fontSize: 13),
                            ),
                            subtitle: Text(
                              '${_formatDate(k['created_at'])} • ${_orDash(k['actor_name'])}'
                              '${(k['note'] ?? '').toString().isNotEmpty ? ' • ${k['note']}' : ''}',
                              style: TextStyle(
                                  color: context.renkler.ikonPasif,
                                  fontSize: 13),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _requestActions(request, closeDetail: true)),
              ],
            )),
      ),
    );
  }

  static const _iletisimHedefleri = {
    'musteri': 'Müşteri',
    'satici': 'Satıcı',
    'personel': 'Personel',
    'kontrol_merkezi': 'Saha notu',
  };
  static const _iletisimSonuclari = {
    'ulasildi': 'Ulaşıldı',
    'ulasilamadi': 'Ulaşılamadı',
    'mesaj_birakildi': 'Mesaj bırakıldı',
    'baglandi': 'Personelle bağlandı',
    'not': 'Not',
  };

  /// Araç adreste bulunamadı: yalnız kurumsal paket ücreti PayTR ile iade edilir, hizmet bedeli kalır.
  Future<void> _confirmNotFoundRefund(Map<String, dynamic> request) async {
    final reason = await showDialog<String>(
        context: context, builder: (_) => const _BulunamadiIadeDialog());
    if (reason == null) return;
    try {
      final yanit =
          await _api.notFoundRefund(request['id'].toString(), reason: reason);
      final iade = (yanit['refund_tl'] as num?)?.toDouble() ?? 0;
      final kalan = (yanit['kept_tl'] as num?)?.toDouble() ?? 0;
      final tl = NumberFormat.decimalPattern('tr');
      _toast(iade > 0
          ? 'Talep kapandı. ${tl.format(iade)} TL paket ücreti iade edildi, ${tl.format(kalan)} TL hizmet bedeli kaldı.'
          : 'Talep kapandı. İade edilecek paket ücreti yoktu.');
      await _load(silent: true);
    } catch (e) {
      _toast('İade yapılamadı: ${e is ApiException ? e.message : e}',
          error: true);
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 130,
              child: Text(label,
                  style: TextStyle(
                      color: context.renkler.metinIkincil, fontSize: 13))),
          Expanded(
              child: SelectableText(value,
                  style:
                      TextStyle(color: context.renkler.metin, fontSize: 13))),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Atama
  // ---------------------------------------------------------------------------

  Future<void> _openAssignDialog(Map<String, dynamic> request) async {
    final assigned = await showDialog<bool>(
      context: context,
      builder: (_) => _PersonelAtamaDialog(api: _api, request: request),
    );
    if (assigned == true) {
      _toast('Talep personele gönderildi. Personel panelinde görünür.');
      await _load(silent: true);
    }
  }

  Future<void> _confirmCancel(Map<String, dynamic> request) async {
    final result = await showDialog<({String reason, bool refund})>(
      context: context,
      builder: (_) => _IptalDialog(request: request),
    );
    if (result == null) return;
    try {
      final response = await _api.cancelRequest(request['id'].toString(),
          reason: result.reason, refund: result.refund);
      final refunded = (response['refunded_tl'] as num?)?.toDouble() ?? 0;
      _toast(refunded > 0
          ? 'Talep iptal edildi, ${NumberFormat.decimalPattern('tr').format(refunded)} TL müşteriye iade edildi'
          : 'Talep iptal edildi');
      await _load(silent: true);
    } catch (e) {
      _toast('İptal edilemedi: ${e is ApiException ? e.message : e}',
          error: true);
    }
  }

  Future<void> _confirmUnassign(Map<String, dynamic> request) async {
    final reasonController = TextEditingController();
    final assignment = _map(request['assignment']);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => YbDiyalog(
        baslik: 'Atamayı kaldır',
        eylemler: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Atamayı Kaldır')),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                '${_orDash(assignment['personnel_name'])} bu talepten alınacak ve talep "Atama Bekleyen" listesine dönecek.'),
            SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                  labelText: 'Neden (isteğe bağlı)',
                  border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true) return;
    try {
      await _api.unassignRequest(request['id'].toString(),
          reason: reason.isEmpty ? null : reason);
      _toast('Atama kaldırıldı');
      await _load(silent: true);
    } catch (e) {
      _toast('Atama kaldırılamadı: $e', error: true);
    }
  }
}

/// Bölge sistemine göre personel önerisi ve atama dialogu.
class _PersonelAtamaDialog extends StatefulWidget {
  const _PersonelAtamaDialog({required this.api, required this.request});

  final YerimebakExpertizApiService api;
  final Map<String, dynamic> request;

  @override
  State<_PersonelAtamaDialog> createState() => _PersonelAtamaDialogState();
}

class _PersonelAtamaDialogState extends State<_PersonelAtamaDialog> {
  static const _matchLabels = {
    'same_district': 'Aynı ilçe',
    'same_city': 'Aynı il',
    'same_region': 'Aynı bölge',
    'other_region': 'Bölge dışı',
  };
  Map<String, Color> get _matchColors => {
        'same_district': context.renkler.birincilMetin,
        'same_city': context.renkler.birincil,
        'same_region': context.renkler.uyari,
        'other_region': context.renkler.metinIkincil,
      };

  final TextEditingController _noteController = TextEditingController();
  List<Map<String, dynamic>> _candidates = [];
  String? _selectedId;
  bool _loading = true;
  bool _saving = false;
  bool _showOtherRegions = false;
  String? _error;
  // Kurumsal firma modeli: talebin firması varsa yalnız o firmanın ve firmasız personel listelenir.
  String _firmaId = '';

  String get _requestId => widget.request['id'].toString();

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.api.getRequestCandidates(_requestId);
      final rows = (response['candidates'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      final recommended = response['recommended_id']?.toString();
      final current = rows
          .where((c) => c['is_current'] == true)
          .map((c) => c['id'].toString())
          .firstOrNull;
      setState(() {
        _candidates = rows;
        _firmaId = response['firm_id']?.toString() ?? '';
        // Mevcut atama varsa (yeniden atama) öneriyi farklı bir personelden seç
        _selectedId = rows
            .where((c) =>
                c['id'].toString() != current && c['assignable'] != false)
            .map((c) => c['id'].toString())
            .firstOrNull;
        if (_selectedId == null &&
            recommended != null &&
            recommended != current) {
          _selectedId = recommended;
        }
        _showOtherRegions = !rows.any((c) => c['match'] != 'other_region');
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _assign() async {
    final selected = _selectedId;
    if (selected == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.assignRequest(_requestId, selected,
          note: _noteController.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ApiException && e.code == 'firma_uyusmuyor'
            ? 'Bu personel başka bir firmaya bağlı. Talebin firmasının personelini ya da firmasız YerimeBak personelini seçin.'
            : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.request['vehicle'] is Map
        ? Map<String, dynamic>.from(widget.request['vehicle'] as Map)
        : {};
    final district = widget.request['district']?.toString() ?? '';
    final city = [widget.request['city']?.toString() ?? '', district]
        .where((e) => e.isNotEmpty)
        .join(' / ');
    final region = widget.request['region']?.toString() ?? '';
    final onDutyCount = _candidates
        .where((c) => c['assignable'] != false && c['is_current'] != true)
        .length;
    final current =
        _candidates.where((c) => c['is_current'] == true).firstOrNull;
    final selectable =
        _candidates.where((c) => c['is_current'] != true).toList();
    final visible = _showOtherRegions
        ? selectable
        : selectable.where((c) => c['match'] != 'other_region').toList();
    final hiddenCount = selectable.length - visible.length;

    return YbDiyalog(
      baslik: 'Personel Ata – ${vehicle['plate'] ?? vehicle['title'] ?? ''}',
      eylemler: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: Text('İptal')),
        FilledButton.icon(
          onPressed: (_saving || _selectedId == null) ? null : _assign,
          icon: _saving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(LucideIcons.send),
          label: Text('Personele Gönder'),
        ),
      ],
      child: SizedBox(
        width: 560,
        child: _loading
            ? const YbIskelet(height: 160)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    city.isEmpty
                        ? 'Talebin ili belirtilmemiş'
                        : 'Talep konumu: $city${region.isEmpty ? '' : ' ($region)'}',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Öneri sırası: aynı ilçe → aynı il → aynı bölge → en az açık görev. '
                    'Görev için pasif personel seçilemez.',
                    style: TextStyle(fontSize: 13),
                  ),
                  if (_firmaId.isNotEmpty) ...[
                    SizedBox(height: 6),
                    Text(
                      key: const Key('atama-firma-basligi'),
                      'Talep firması: ${(widget.request['firm_name'] ?? '').toString().isEmpty ? _firmaId : widget.request['firm_name']}'
                      ' • Önce firmanın personeli, sonra firmasız YerimeBak personeli listelenir.',
                      style:
                          TextStyle(fontSize: 13, color: context.renkler.bilgi),
                    ),
                  ],
                  if (current != null) ...[
                    SizedBox(height: 6),
                    Text(
                      'Şu an atanmış: ${current['full_name']} (${current['city'] ?? '-'})',
                      style:
                          TextStyle(fontSize: 13, color: context.renkler.bilgi),
                    ),
                  ],
                  SizedBox(height: 12),
                  if (selectable.isEmpty || onDutyCount == 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        selectable.isEmpty
                            ? 'Atanabilecek personel yok. Önce Personel sekmesinden personel ekleyin.'
                            : 'Şu an görev için aktif personel yok; personel kendini aktif yaptığında atanabilir.',
                        style: TextStyle(color: context.renkler.uyari),
                      ),
                    ),
                  if (selectable.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: SingleChildScrollView(
                        child: RadioGroup<String>(
                          groupValue: _selectedId,
                          onChanged: (value) =>
                              setState(() => _selectedId = value),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: visible.map((c) {
                              final match =
                                  c['match']?.toString() ?? 'other_region';
                              final openTasks =
                                  (c['open_task_count'] as num?)?.toInt() ?? 0;
                              final assignable = c['assignable'] != false;
                              return RadioListTile<String>(
                                value: c['id'].toString(),
                                enabled: assignable,
                                title: Text(
                                  '${c['full_name']}',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${c['city'] ?? '-'} / ${c['district'] ?? '-'} • ${c['region'] ?? '-'} • '
                                  '${(c['firm_name'] ?? '').toString().isEmpty ? 'YerimeBak (firmasız)' : c['firm_name']}\n'
                                  '${assignable ? '' : 'GÖREV İÇİN PASİF • '}$openTasks açık görev'
                                  '${(c['expertise'] ?? '').toString().isNotEmpty ? ' • ${c['expertise']}' : ''}',
                                ),
                                isThreeLine: true,
                                secondary: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (_matchColors[match] ??
                                            context.renkler.metinIkincil)
                                        .withValues(alpha: .18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _matchLabels[match] ?? match,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: _matchColors[match],
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  if (hiddenCount > 0)
                    TextButton(
                      onPressed: () => setState(() => _showOtherRegions = true),
                      child: Text(
                          'Bölge dışındaki $hiddenCount personeli de göster'),
                    ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Personele not (isteğe bağlı)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    SizedBox(height: 8),
                    Text(_error!,
                        style: TextStyle(color: context.renkler.tehlike)),
                  ],
                ],
              ),
      ),
    );
  }
}

/// "Araç adreste yok" sonrası paket ücreti iadesi: neden zorunlu; onaylanırsa nedeni döner.
class _BulunamadiIadeDialog extends StatefulWidget {
  const _BulunamadiIadeDialog();

  @override
  State<_BulunamadiIadeDialog> createState() => _BulunamadiIadeDialogState();
}

class _BulunamadiIadeDialogState extends State<_BulunamadiIadeDialog> {
  final TextEditingController _reason =
      TextEditingController(text: 'Araç randevu adresinde bulunamadı');
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YbDiyalog(
      baslik: 'Paket ücretini iade et',
      eylemler: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text('Vazgeç')),
        FilledButton(
          key: const Key('bulunamadi-iade-onay'),
          style: FilledButton.styleFrom(backgroundColor: context.renkler.uyari),
          onPressed: () {
            final reason = _reason.text.trim();
            if (reason.isEmpty) {
              setState(() => _error = 'Neden zorunludur');
              return;
            }
            Navigator.pop(context, reason);
          },
          child: Text('İade et ve kapat'),
        ),
      ],
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Talep kapanır. Kurumsal ekspertiz paket ücreti karta iade edilir; '
                'hizmet bedeli müşterinin ödeme öncesi onayı gereği iade edilmez. Müşteriye bildirim gider.'),
            SizedBox(height: 12),
            TextField(
              key: const Key('bulunamadi-neden'),
              controller: _reason,
              maxLines: 2,
              decoration: InputDecoration(
                  labelText: 'Neden *',
                  border: const OutlineInputBorder(),
                  errorText: _error),
            ),
          ],
        ),
      ),
    );
  }
}

/// İptal nedeni + iade seçimi. Ödeme iadesi PayTR üzerinden yapılır.
class _IptalDialog extends StatefulWidget {
  const _IptalDialog({required this.request});

  final Map<String, dynamic> request;

  @override
  State<_IptalDialog> createState() => _IptalDialogState();
}

class _IptalDialogState extends State<_IptalDialog> {
  final TextEditingController _reason = TextEditingController();
  bool _refund = true;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = (widget.request['total_tl'] as num?)?.toDouble() ?? 0;
    final paid = widget.request['is_paid'] == true ||
        ['paid', 'paid_simulation'].contains(widget.request['payment_status']);
    return YbDiyalog(
      baslik: 'Talebi iptal et',
      eylemler: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text('Vazgeç')),
        FilledButton(
          key: const Key('confirmCancelButton'),
          style: FilledButton.styleFrom(backgroundColor: context.renkler.uyari),
          onPressed: () {
            final reason = _reason.text.trim();
            if (reason.isEmpty) {
              setState(() => _error = 'İptal nedeni zorunludur');
              return;
            }
            Navigator.pop(context, (reason: reason, refund: paid && _refund));
          },
          child: Text('İptal Et'),
        ),
      ],
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Talep iptal edilir, personel ataması kaldırılır; müşteriye ve personele bildirim gider.'),
            SizedBox(height: 12),
            TextField(
              key: const Key('cancelReasonField'),
              controller: _reason,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'İptal nedeni *', border: OutlineInputBorder()),
            ),
            if (paid)
              CheckboxListTile(
                key: const Key('refundCheckbox'),
                contentPadding: EdgeInsets.zero,
                value: _refund,
                onChanged: (v) => setState(() => _refund = v ?? true),
                title: Text(
                    '${NumberFormat.decimalPattern('tr').format(total)} TL ödemeyi karta iade et (PayTR)'),
              ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: context.renkler.tehlike)),
          ],
        ),
      ),
    );
  }
}
