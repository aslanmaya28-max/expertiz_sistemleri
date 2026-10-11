import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/mappers/location_mapper.dart';
import '../../../core/theme/futuristic_theme.dart';
import '../../../services/yerimebak_expertiz_api_service.dart';
import '../../../widgets/cyber/cyber_error_widget.dart';
import '../../../widgets/cyber/cyber_radar_scan.dart';
import '../../../widgets/cyber/cyber_shimmer_loading.dart';

/// Araç Operasyonu Modülü
///
/// Müşteri talepleri merkezi API'den gelir ve 4 sekmede izlenir:
/// - Atama Bekleyen: müşteri talebi oluşturdu, personel atanmadı
/// - İşlemdeki: personele atandı (kabul / inceleme / düzeltme)
/// - Onay Bekleyen: personel raporu gönderdi (AI / admin onayı)
/// - Tamamlanan: rapor yayınlandı
///
/// Atama, bölge sistemine göre önerilen personel listesinden yapılır
/// (önce aynı il, sonra aynı bölge, en az açık görevi olan önce).
class AracOperasyonu extends StatefulWidget {
  const AracOperasyonu({super.key, this.apiService});

  /// Testler için enjekte edilebilir.
  final YerimebakExpertizApiService? apiService;

  @override
  State<AracOperasyonu> createState() => _AracOperasyonuState();
}

class _AracOperasyonuState extends State<AracOperasyonu> with SingleTickerProviderStateMixin {
  static const _buckets = ['waiting_assignment', 'in_progress', 'pending_approval', 'completed'];
  static const _bucketTitles = ['Atama Bekleyen', 'İşlemdeki', 'Onay Bekleyen', 'Tamamlanan'];
  static const _emptyMessages = [
    'Atama bekleyen talep yok',
    'İşlemde talep yok',
    'Onay bekleyen rapor yok',
    'Tamamlanan rapor yok',
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

  @override
  void initState() {
    super.initState();
    _api = widget.apiService ?? YerimebakExpertizApiService();
    _tabController = TabController(length: _buckets.length, vsync: this);
    _load();
    // Yeni müşteri talepleri admin açık ekranda beklerken de düşsün
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _tabController.dispose();
    super.dispose();
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
      final response = await _api.getAdminRequests(regionId: _regionId == 0 ? null : _regionId);
      final rows = (response['requests'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final counts = <String, int>{};
      final rawCounts = response['counts'];
      if (rawCounts is Map) {
        rawCounts.forEach((key, value) => counts['$key'] = (value as num?)?.toInt() ?? 0);
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

  List<Map<String, dynamic>> _itemsFor(String bucket) => _requests.where((r) => r['bucket'] == bucket).toList();

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
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
      backgroundColor: FuturisticTheme.bgPrimary,
      body: Column(
        children: [
          Container(
            color: FuturisticTheme.bgSecondary,
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.filter_alt_outlined, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _regionId,
                    dropdownColor: FuturisticTheme.bgSecondary,
                    style: const TextStyle(color: Colors.white),
                    items: [
                      const DropdownMenuItem(value: 0, child: Text('Tüm bölgeler')),
                      ..._locationMapper.getAllBolgeIds().map(
                            (id) => DropdownMenuItem(value: id, child: Text(_locationMapper.getBolgeAdi(id))),
                          ),
                    ],
                    onChanged: (value) {
                      setState(() => _regionId = value ?? 0);
                      _load();
                    },
                  ),
                ),
                const Spacer(),
                if (_lastUpdated != null)
                  Text(
                    'Güncellendi ${DateFormat('HH:mm:ss').format(_lastUpdated!)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                IconButton(
                  tooltip: 'Yenile',
                  icon: const Icon(Icons.refresh, color: FuturisticTheme.neon),
                  onPressed: _load,
                ),
              ],
            ),
          ),
          Container(
            color: FuturisticTheme.bgSecondary,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: FuturisticTheme.neon,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.54),
              indicatorColor: FuturisticTheme.neon,
              tabs: List.generate(_buckets.length, (i) {
                final count = _counts[_buckets[i]] ?? _itemsFor(_buckets[i]).length;
                return Tab(text: '${_bucketTitles[i]} ($count)');
              }),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(_buckets.length, (i) => _buildListTab(_buckets[i], _emptyMessages[i])),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTab(String bucket, String emptyMessage) {
    if (_error != null && _requests.isEmpty) {
      return CyberErrorWidget(message: _error, onRetry: _load);
    }
    if (_isLoading && _requests.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: CyberShimmerLoading(height: 110),
        ),
      );
    }
    final items = _itemsFor(bucket);
    return RefreshIndicator(
      onRefresh: _load,
      child: items.isEmpty
          ? ListView(children: [SizedBox(height: 420, child: _buildEmptyState(emptyMessage))])
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) => _buildRequestCard(items[index]),
            ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CyberRadarScan(size: 150, color: FuturisticTheme.neon),
          const SizedBox(height: 30),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              shadows: [Shadow(color: FuturisticTheme.neon.withValues(alpha: 0.8), blurRadius: 15)],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Kart
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

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
        return (label: 'Atama bekliyor', color: Colors.orange);
      case 'pending_approval':
        return status == 'pending_ai'
            ? (label: 'AI analizi bekliyor', color: Colors.lightBlueAccent)
            : (label: 'Admin onayı bekliyor', color: Colors.greenAccent);
      case 'completed':
        return (label: 'Yayınlandı', color: Colors.green);
    }
    if (request['needs_revision'] == true) return (label: 'Düzeltme bekliyor', color: Colors.redAccent);
    switch (assignment['status']) {
      case 'accepted':
        return (label: 'Personel kabul etti', color: Colors.tealAccent);
      case 'in_progress':
        return (label: 'İncelemede', color: Colors.blueAccent);
      default:
        return (label: 'Personele atandı', color: Colors.purpleAccent);
    }
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final vehicle = _map(request['vehicle']);
    final customer = _map(request['customer']);
    final assignment = _map(request['assignment']);
    final status = _statusOf(request);
    final bucket = request['bucket'];
    final city = request['city']?.toString() ?? '';
    final region = request['region']?.toString() ?? '';
    final assignedName = assignment['personnel_name']?.toString() ?? '';

    final actions = <Widget>[];
    if (bucket == 'waiting_assignment') {
      actions.add(FilledButton.icon(
        onPressed: () => _openAssignDialog(request),
        icon: const Icon(Icons.person_add, size: 18),
        label: const Text('Personel Ata'),
      ));
    } else if (bucket == 'pending_approval') {
      actions.add(const Text(
        'Personel raporu gönderdi • İncelemek ve yayınlamak için "Raporlar" sekmesini açın',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ));
    } else if (bucket == 'in_progress') {
      actions.addAll([
        OutlinedButton.icon(
          onPressed: () => _openAssignDialog(request),
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: const Text('Yeniden Ata'),
        ),
        TextButton.icon(
          onPressed: () => _confirmUnassign(request),
          icon: const Icon(Icons.person_off_outlined, size: 18, color: Colors.redAccent),
          label: const Text('Atamayı Kaldır', style: TextStyle(color: Colors.redAccent)),
        ),
      ]);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shadowColor: FuturisticTheme.neon.withValues(alpha: 0.1),
      color: FuturisticTheme.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: status.color.withValues(alpha: 0.35)),
      ),
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
                    decoration: BoxDecoration(color: status.color.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Icon(Icons.directions_car, color: status.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      vehicle['title']?.toString() ?? 'Araç',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _chip(status.label, status.color),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 18,
                runSpacing: 4,
                children: [
                  _info(Icons.pin, 'Plaka: ${_orDash(vehicle['plate'])}'),
                  _info(Icons.person, 'Müşteri: ${_orDash(customer['name'])}'),
                  _info(Icons.phone, _orDash(customer['phone'])),
                  _info(Icons.location_on, region.isEmpty ? _orDash(city) : '$city • $region'),
                  _info(Icons.inventory_2_outlined, '${_orDash(request['firm_name'])} – ${_orDash(request['package_name'])}'),
                  _info(Icons.schedule, _formatDate(request['created_at'])),
                  if (assignedName.isNotEmpty) _info(Icons.badge, 'Personel: $assignedName', color: Colors.purpleAccent),
                ],
              ),
              if (request['needs_revision'] == true && (request['rejection_reason'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                _info(Icons.report_gmailerrorred, 'Red nedeni: ${request['rejection_reason']}', color: Colors.redAccent),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _orDash(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _info(IconData icon, String text, {Color color = Colors.white70}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white38),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(text, style: TextStyle(fontSize: 12, color: color), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Detay
  // ---------------------------------------------------------------------------

  void _showDetail(Map<String, dynamic> request) {
    final vehicle = _map(request['vehicle']);
    final customer = _map(request['customer']);
    final assignment = _map(request['assignment']);
    final history = (assignment['history'] as List? ?? const []).whereType<Map>().toList();
    const actionLabels = {
      'assigned': 'Atandı',
      'reassigned': 'Yeniden atandı',
      'unassigned': 'Atama kaldırıldı',
      'released': 'Kuyruğa döndü',
      'accept': 'Personel kabul etti',
      'start': 'İnceleme başladı',
    };

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FuturisticTheme.bgSecondary,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Text(vehicle['title']?.toString() ?? 'Talep',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text('Talep No: ${request['request_id'] ?? request['id']}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 16),
            _detailRow('Durum', _statusOf(request).label),
            _detailRow('Plaka', _orDash(vehicle['plate'])),
            _detailRow('İlan', _orDash(vehicle['listing_url'])),
            _detailRow('Müşteri', _orDash(customer['name'])),
            _detailRow('Telefon', _orDash(customer['phone'])),
            _detailRow('E-posta', _orDash(customer['email'])),
            _detailRow('İl / Bölge', '${_orDash(request['city'])} / ${_orDash(request['region'])}'),
            _detailRow('Firma / Paket', '${_orDash(request['firm_name'])} / ${_orDash(request['package_name'])}'),
            _detailRow('Tutar', '${NumberFormat.decimalPattern('tr').format(request['total_tl'] ?? 0)} TL'),
            _detailRow('Müşteri notu', _orDash(request['note'])),
            _detailRow('Oluşturma', _formatDate(request['created_at'])),
            if ((assignment['personnel_name'] ?? '').toString().isNotEmpty) ...[
              const Divider(color: Colors.white12, height: 28),
              _detailRow('Atanan personel', _orDash(assignment['personnel_name'])),
              _detailRow('Personel tel.', _orDash(assignment['personnel_phone'])),
              _detailRow('Atama zamanı', _formatDate(assignment['assigned_at'])),
              _detailRow('Atayan', _orDash(assignment['assigned_by'])),
              _detailRow('Admin notu', _orDash(assignment['note'])),
            ],
            if (history.isNotEmpty) ...[
              const Divider(color: Colors.white12, height: 28),
              const Text('Atama geçmişi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...history.reversed.map((h) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history, color: Colors.white38, size: 18),
                    title: Text(
                      '${actionLabels[h['action']] ?? h['action']}'
                      '${(h['personnel_name'] ?? '').toString().isNotEmpty ? ' – ${h['personnel_name']}' : ''}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    subtitle: Text(
                      '${_formatDate(h['at'])} • ${_orDash(h['by'])}'
                      '${(h['note'] ?? '').toString().isNotEmpty ? ' • ${h['note']}' : ''}',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13))),
          Expanded(child: SelectableText(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
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

  Future<void> _confirmUnassign(Map<String, dynamic> request) async {
    final reasonController = TextEditingController();
    final assignment = _map(request['assignment']);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Atamayı kaldır'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_orDash(assignment['personnel_name'])} bu talepten alınacak ve talep "Atama Bekleyen" listesine dönecek.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Neden (isteğe bağlı)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Atamayı Kaldır')),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true) return;
    try {
      await _api.unassignRequest(request['id'].toString(), reason: reason.isEmpty ? null : reason);
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
    'same_city': 'Aynı il',
    'same_region': 'Aynı bölge',
    'other_region': 'Bölge dışı',
  };
  static const _matchColors = {
    'same_city': Colors.green,
    'same_region': Colors.orange,
    'other_region': Colors.grey,
  };

  final TextEditingController _noteController = TextEditingController();
  List<Map<String, dynamic>> _candidates = [];
  String? _selectedId;
  bool _loading = true;
  bool _saving = false;
  bool _showOtherRegions = false;
  String? _error;

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
      final current = rows.where((c) => c['is_current'] == true).map((c) => c['id'].toString()).firstOrNull;
      setState(() {
        _candidates = rows;
        // Mevcut atama varsa (yeniden atama) öneriyi farklı bir personelden seç
        _selectedId = rows
            .where((c) => c['id'].toString() != current)
            .map((c) => c['id'].toString())
            .firstOrNull;
        if (_selectedId == null && recommended != current) _selectedId = recommended;
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
      await widget.api.assignRequest(_requestId, selected, note: _noteController.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.request['vehicle'] is Map ? Map<String, dynamic>.from(widget.request['vehicle'] as Map) : {};
    final city = widget.request['city']?.toString() ?? '';
    final region = widget.request['region']?.toString() ?? '';
    final current = _candidates.where((c) => c['is_current'] == true).firstOrNull;
    final selectable = _candidates.where((c) => c['is_current'] != true).toList();
    final visible = _showOtherRegions ? selectable : selectable.where((c) => c['match'] != 'other_region').toList();
    final hiddenCount = selectable.length - visible.length;

    return AlertDialog(
      title: Text('Personel Ata – ${vehicle['plate'] ?? vehicle['title'] ?? ''}'),
      content: SizedBox(
        width: 560,
        child: _loading
            ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    city.isEmpty ? 'Talebin ili belirtilmemiş' : 'Talep konumu: $city${region.isEmpty ? '' : ' ($region)'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Öneri sırası: aynı il → aynı bölge → en az açık görev.',
                    style: TextStyle(fontSize: 12),
                  ),
                  if (current != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Şu an atanmış: ${current['full_name']} (${current['city'] ?? '-'})',
                      style: const TextStyle(fontSize: 12, color: Colors.purpleAccent),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (selectable.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Atanabilecek aktif personel yok. Önce Personel sekmesinden personel ekleyin.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: SingleChildScrollView(
                        child: RadioGroup<String>(
                          groupValue: _selectedId,
                          onChanged: (value) => setState(() => _selectedId = value),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: visible.map((c) {
                              final match = c['match']?.toString() ?? 'other_region';
                              final openTasks = (c['open_task_count'] as num?)?.toInt() ?? 0;
                              return RadioListTile<String>(
                                value: c['id'].toString(),
                                title: Text(
                                  '${c['full_name']}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${c['city'] ?? '-'} / ${c['district'] ?? '-'} • ${c['region'] ?? '-'}\n'
                                  '$openTasks açık görev'
                                  '${(c['expertise'] ?? '').toString().isNotEmpty ? ' • ${c['expertise']}' : ''}',
                                ),
                                isThreeLine: true,
                                secondary: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (_matchColors[match] ?? Colors.grey).withValues(alpha: .18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _matchLabels[match] ?? match,
                                    style: TextStyle(fontSize: 11, color: _matchColors[match], fontWeight: FontWeight.bold),
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
                      child: Text('Bölge dışındaki $hiddenCount personeli de göster'),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Personele not (isteğe bağlı)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('İptal')),
        FilledButton.icon(
          onPressed: (_saving || _selectedId == null) ? null : _assign,
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send),
          label: const Text('Personele Gönder'),
        ),
      ],
    );
  }
}
