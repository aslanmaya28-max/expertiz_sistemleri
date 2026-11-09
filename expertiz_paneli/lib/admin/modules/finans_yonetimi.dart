import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yerimebak_sistemleri/tema/renkler.dart';
import 'package:yerimebak_sistemleri/bilesenler/bilesenler.dart';
import 'package:intl/intl.dart';
import '../../../services/yerimebak_expertiz_api_service.dart';

/// Finans Yönetimi
///
/// Veriler merkezi API'nin `/expertiz/admin/finance/summary` ucundan gelir:
/// ekspertiz talepleri (ciro/KDV), kredi paketi satışları ve yayınlanan
/// raporlar üzerinden tahakkuk eden personel hakedişi.
class FinansYonetimi extends StatefulWidget {
  const FinansYonetimi({super.key, this.apiService, this.initialFilter});

  /// Testlerde sahte servis vermek için.
  final YerimebakExpertizApiService? apiService;

  /// Ana sayfadaki bekleyen havale bağlantısı kredi siparişlerini süzer.
  final String? initialFilter;

  @override
  State<FinansYonetimi> createState() => _FinansYonetimiState();
}

class _FinansYonetimiState extends State<FinansYonetimi> {
  late final YerimebakExpertizApiService _api;

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _ekspertiz = const {};
  Map<String, dynamic> _kredi = const {};
  Map<String, dynamic> _personel = const {};
  Map<String, dynamic> _iade = const {};
  // Kurumsal firma modeli (sözleşme 2026-11-09 bölüm 3): firma bazında hak ediş ve ödenecek tutar.
  List<Map<String, dynamic>> _firmalar = const [];
  List<Map<String, dynamic>> _orders = [];
  bool _exporting = false;
  late bool _bekleyenHavaleler;
  final _krediSatislariAnahtari = GlobalKey();

  @override
  void initState() {
    super.initState();
    _bekleyenHavaleler = widget.initialFilter == 'bekleyen_havale';
    _api = widget.apiService ?? YerimebakExpertizApiService();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait(
          [_api.getAdminFinanceSummary(), _api.getCreditOrders()]);
      final response = results[0];
      if (!mounted) return;
      setState(() {
        _ekspertiz = _map(response['ekspertiz']);
        _kredi = _map(response['kredi_satislari']);
        _personel = _map(response['personel']);
        _iade = _map(response['iadeler']);
        _firmalar = (response['firmalar'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _orders = (results[1]['orders'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
      if (_bekleyenHavaleler) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final hedef = _krediSatislariAnahtari.currentContext;
          if (mounted && hedef != null) Scrollable.ensureVisible(hedef);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(text),
          backgroundColor: error ? context.renkler.tehlike : null),
    );
  }

  /// Muhasebe / e-Arşiv entegratörü için tahsilat dökümü (satış + iade satırları).
  Future<void> _exportCsv() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange:
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      helpText: 'Tahsilat dökümü tarih aralığı',
    );
    if (range == null) return;
    final fmt = DateFormat('yyyy-MM-dd');
    setState(() => _exporting = true);
    try {
      final bytes = await _api.downloadInvoiceCsv(
          start: fmt.format(range.start), end: fmt.format(range.end));
      final name =
          'yerimebak_tahsilatlar_${fmt.format(range.start)}_${fmt.format(range.end)}.csv';
      await FilePicker.platform.saveFile(
        dialogTitle: 'Tahsilat dökümünü kaydet',
        fileName: name,
        bytes: Uint8List.fromList(bytes),
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      _snack('Döküm hazır: $name');
    } catch (e) {
      _snack('Döküm alınamadı: ${e is ApiException ? e.message : e}',
          error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _refundOrder(Map<String, dynamic> order) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kredi paketini iade et'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                '${order['package_name'] ?? 'Paket'} • ${_tl(((order['amount_tl'] as num?) ?? 0).toDouble())} • '
                '${order['user_email'] ?? ''}\nYalnızca hiç kullanılmamış paketler iade edilebilir; krediler bakiyeden düşülür.'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('refundReasonField'),
              controller: controller,
              decoration: const InputDecoration(
                  labelText: 'İade nedeni *', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç')),
          FilledButton(
            key: const Key('confirmRefundButton'),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('İade Et'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (reason == null) return;
    if (reason.isEmpty) return _snack('İade nedeni zorunludur', error: true);
    try {
      await _api.refundCreditOrder('${order['id']}', reason: reason);
      _snack('Paket iade edildi');
      await _load();
    } catch (e) {
      _snack('İade yapılamadı: ${e is ApiException ? e.message : e}',
          error: true);
    }
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static double _num(Map<String, dynamic> m, String key) =>
      (m[key] as num?)?.toDouble() ?? 0.0;

  static String _tl(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits =
        parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return parts[1] == '00' ? '$digits TL' : '$digits,${parts[1]} TL';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_loading) return const Padding(padding: EdgeInsets.all(24), child: Column(children: [YbIskelet(height: 80), SizedBox(height: 16), YbIskelet(height: 80), SizedBox(height: 16), YbIskelet(height: 80)]));
    if (_error != null) return _buildError(isDarkMode);

    final gorunenSiparisler = _orders.where((o) => _bekleyenHavaleler
      ? o['status'] == 'pending'
      : ['approved', 'refunded'].contains(o['status'])).toList();
    final bekleyenAdedi = _orders.where((o) => o['status'] == 'pending').length;
    final ciro = _num(_ekspertiz, 'ciro_tl');
    final kdv = _num(_ekspertiz, 'kdv_tl');
    final net = _num(_ekspertiz, 'net_tl');
    final firmaPaketi = _num(_ekspertiz, 'firma_paketi_tl');
    final hakedis = _num(_personel, 'hakedis_tl');
    final krediOnayli = _num(_kredi, 'approved_tl');
    final krediBekleyen = _num(_kredi, 'pending_tl');
    final paylasimOrani =
        (_num(_personel, 'share_rate') * 100).toStringAsFixed(0);
    final simulasyon =
        (_ekspertiz['simulated_payment_count'] as num?)?.toInt() ?? 0;
    final talepAdedi = (_ekspertiz['request_count'] as num?)?.toInt() ?? 0;
    final personelListesi = (_personel['by_personnel'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final textColor = context.renkler.metin;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Finans Yönetimi',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor),
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('exportCsvButton'),
                  onPressed: _exporting ? null : _exportCsv,
                  icon: _exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.download),
                  label: const Text('Tahsilat Dökümü (CSV)'),
                ),
                IconButton(
                    onPressed: _load,
                    icon: const Icon(LucideIcons.refreshCw),
                    tooltip: 'Yenile'),
              ],
            ),
            if (simulasyon > 0) ...[
              const SizedBox(height: 8),
              _buildUyari(
                '$simulasyon talebin ödemesi simülasyon (paid_simulation). '
                'Gerçek ödeme altyapısı bağlanana kadar ciro tahminidir.',
              ),
            ],
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, constraints) {
              final sutunlar = constraints.maxWidth >= 1100 ? 4 : constraints.maxWidth >= 600 ? 2 : 1;
              return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: sutunlar,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: ((constraints.maxWidth - (sutunlar - 1) * 10) / sutunlar) / 144,
              children: [
                _buildFinansKart(
                    'Ekspertiz Cirosu',
                    _tl(ciro),
                    LucideIcons.trendingUp,
                    context.renkler.birincil,
                    isDarkMode),
                _buildFinansKart('KDV', _tl(kdv), LucideIcons.receiptText,
                    context.renkler.bilgi, isDarkMode),
                _buildFinansKart(
                    'Personel Hakedişi (%$paylasimOrani)',
                    _tl(hakedis),
                    LucideIcons.wallet,
                    context.renkler.uyari,
                    isDarkMode),
                _buildFinansKart('Kredi Satışları', _tl(krediOnayli),
                    LucideIcons.creditCard, context.renkler.bilgi, isDarkMode),
              ],
            );
            }),
            const SizedBox(height: 30),
            Card(
              elevation: 0,
              color: context.renkler.yuzey,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Finansal Detaylar',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                    const SizedBox(height: 20),
                    _buildFinansDetayBolumu(
                      'Gelirler',
                      [
                        _buildFinansSatir('Ekspertiz talebi',
                            '$talepAdedi adet', LucideIcons.clipboardList),
                        _buildFinansSatir('Ekspertiz cirosu (KDV dahil)',
                            _tl(ciro), LucideIcons.banknote),
                        _buildFinansSatir('YerimeBak hizmet geliri (KDV hariç)',
                            _tl(net), LucideIcons.calculator),
                        _buildFinansSatir(
                            'Onaylı kredi satışı (${_kredi['approved_count'] ?? 0})',
                            _tl(krediOnayli),
                            LucideIcons.creditCard),
                        _buildFinansSatir(
                            'Ödemesi bekleyen kredi (${_kredi['pending_count'] ?? 0})',
                            _tl(krediBekleyen),
                            LucideIcons.hourglass),
                        _buildFinansSatir(
                            'İade edilen ekspertiz (${_iade['expertiz_count'] ?? 0}) — ciroya dahil değil',
                            _tl(_num(_iade, 'expertiz_tl')),
                            LucideIcons.undo2),
                        _buildFinansSatir(
                            'İade edilen kredi (${_iade['kredi_count'] ?? 0}) — ciroya dahil değil',
                            _tl(_num(_iade, 'kredi_tl')),
                            LucideIcons.undo2),
                      ],
                      LucideIcons.arrowDown,
                      context.renkler.birincilMetin,
                      isDarkMode,
                    ),
                    const SizedBox(height: 20),
                    _buildFinansDetayBolumu(
                      'Giderler',
                      [
                        _buildFinansSatir(
                            'Ödenecek KDV', _tl(kdv), LucideIcons.receiptText),
                        _buildFinansSatir(
                            'Firmalara aktarılacak paket ücreti (KDV dahil)',
                            _tl(firmaPaketi),
                            LucideIcons.building2),
                        _buildFinansSatir(
                            'Personel hakedişi (yayınlanan raporlar)',
                            _tl(hakedis),
                            LucideIcons.users),
                      ],
                      LucideIcons.arrowUp,
                      context.renkler.tehlike,
                      isDarkMode,
                    ),
                    const SizedBox(height: 20),
                    _buildNetKar(net + krediOnayli - hakedis, isDarkMode),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text('Kredi Paketi Satışları', key: _krediSatislariAnahtari,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(label: const Text('Ödenmiş ve iadeler'), selected: !_bekleyenHavaleler,
                onSelected: (_) => setState(() => _bekleyenHavaleler = false)),
              ChoiceChip(key: const Key('bekleyen-havale-suzgeci'), label: Text('Bekleyen havale ($bekleyenAdedi)'), selected: _bekleyenHavaleler,
                onSelected: (_) => setState(() => _bekleyenHavaleler = true)),
            ]),
            const SizedBox(height: 12),
            if (gorunenSiparisler.isEmpty)
              Text(_bekleyenHavaleler ? 'Bekleyen havale yok.' : 'Henüz ödenmiş kredi paketi yok.',
                  style: TextStyle(color: context.renkler.metinIkincil))
            else
              ...gorunenSiparisler.map((o) {
                final refunded = o['status'] == 'refunded';
                return Card(
                  key: Key('order-${o['id']}'),
                  color: context.renkler.yuzey,
                  child: ListTile(
                    leading: Icon(
                        refunded ? LucideIcons.undo2 : LucideIcons.creditCard,
                        color: refunded
                            ? context.renkler.metinIkincil
                            : context.renkler.bilgi),
                    title: Text(
                        '${o['package_name'] ?? o['package_key'] ?? 'Paket'} • ${o['credits'] ?? 0} kredi',
                        style: TextStyle(color: textColor)),
                    subtitle: Text(
                        '${o['user_email'] ?? ''} • ${'${o['approved_at'] ?? o['created_at'] ?? ''}'.split('.').first}'
                        '${refunded ? ' • İADE EDİLDİ' : o['status'] == 'pending' ? ' • ONAY BEKLİYOR' : ''}'),
                    trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(_tl(((o['amount_tl'] as num?) ?? 0).toDouble()),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        if (o['status'] == 'approved')
                          TextButton(
                            key: Key('refund-${o['id']}'),
                            onPressed: () => _refundOrder(o),
                            child: const Text('İade Et'),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 30),
            Text('Firma Hak Edişleri',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
            const SizedBox(height: 8),
            Text(
              'Ödenecek = tamamlanan işlerin kurumsal paket ücreti + %25 saha payı (KDV hariç; firma faturasına KDV eklenir). '
              'Araç adreste bulunamadığında paket iade edilir, saha payı firmaya kalır.',
              style:
                  TextStyle(fontSize: 13, color: context.renkler.metinIkincil),
            ),
            const SizedBox(height: 12),
            if (_firmalar.isEmpty)
              Text('Henüz firma işi yok.',
                  style: TextStyle(color: context.renkler.metinIkincil))
            else
              SingleChildScrollView(
                key: const Key('firma-hakedis-tablosu'),
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Firma')),
                    DataColumn(label: Text('İş'), numeric: true),
                    DataColumn(label: Text('Bulunamadı'), numeric: true),
                    DataColumn(label: Text('Saha payı'), numeric: true),
                    DataColumn(label: Text('Paket'), numeric: true),
                    DataColumn(label: Text('Ödenecek'), numeric: true),
                  ],
                  rows: [
                    for (final f in _firmalar)
                      DataRow(cells: [
                        DataCell(Text(_firmaAdi(f),
                            style: TextStyle(color: textColor))),
                        DataCell(Text('${f['is_sayisi'] ?? 0}',
                            style: TextStyle(color: textColor))),
                        DataCell(Text('${f['bulunamadi_sayisi'] ?? 0}',
                            style: TextStyle(color: textColor))),
                        DataCell(Text(_tl(_num(f, 'hakedis_tl')),
                            style: TextStyle(color: textColor))),
                        DataCell(Text(_tl(_num(f, 'paket_tl')),
                            style: TextStyle(color: textColor))),
                        DataCell(Text(_tl(_num(f, 'odenecek_tl')),
                            style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold))),
                      ]),
                  ],
                ),
              ),
            const SizedBox(height: 30),
            Text('Personel Hakedişleri',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
            const SizedBox(height: 8),
            Text(
              'Hakediş, yayınlanan raporların KDV hariç tutarı üzerinden tahakkuk eder. '
              'Personele yapılan ödemeler henüz sistemde takip edilmiyor.',
              style:
                  TextStyle(fontSize: 13, color: context.renkler.metinIkincil),
            ),
            const SizedBox(height: 12),
            if (personelListesi.isEmpty)
              Text('Henüz yayınlanmış personel raporu yok.',
                  style: TextStyle(color: context.renkler.metinIkincil))
            else
              ...personelListesi.map((p) => Card(
                    color: context.renkler.yuzey,
                    child: ListTile(
                      leading: Icon(LucideIcons.badgeCheck,
                          color: context.renkler.birincil),
                      title: Text(
                        (p['personnel_name'] as String?)?.isNotEmpty == true
                            ? p['personnel_name'] as String
                            : 'Personel #${p['personnel_id']}',
                        style: TextStyle(color: textColor),
                      ),
                      subtitle: Text('${p['report_count'] ?? 0} rapor'),
                      trailing: Text(
                        _tl((p['hakedis_tl'] as num?)?.toDouble() ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  String _firmaAdi(Map<String, dynamic> f) {
    final ad = (f['firm_name'] ?? '').toString().trim();
    if (ad.isNotEmpty) return ad;
    final id = (f['firm_id'] ?? '').toString();
    return id.isEmpty || id == 'firmasiz' ? 'YerimeBak (firmasız)' : id;
  }

  Widget _buildError(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleAlert,
                color: context.renkler.tehlike, size: 48),
            const SizedBox(height: 12),
            Text('Finans verileri yüklenemedi',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.renkler.metin)),
            const SizedBox(height: 8),
            Text(_error ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.renkler.metinIkincil)),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: _load,
                icon: const Icon(LucideIcons.refreshCw),
                label: const Text('Tekrar Dene')),
          ],
        ),
      ),
    );
  }

  Widget _buildUyari(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.renkler.uyari.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.renkler.uyari.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, color: context.renkler.uyari),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildNetKar(double netKar, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.renkler.birincil
            .withValues(alpha: isDarkMode ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Net Kar',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.renkler.metinIkincil)),
              Text(
                _tl(netKar),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: netKar >= 0
                      ? context.renkler.birincilMetin
                      : context.renkler.tehlike,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'KDV hariç ekspertiz geliri + onaylı kredi satışı - personel hakedişi',
            style: TextStyle(fontSize: 13, color: context.renkler.metinIkincil),
          ),
        ],
      ),
    );
  }

  Widget _buildFinansKart(
      String title, String value, IconData icon, Color color, bool isDarkMode) {
    return YbKart(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(title, style: TextStyle(fontSize: 13, color: context.renkler.metinIkincil))),
          const SizedBox(width: 8),
          Icon(icon, size: 20, color: color),
        ]),
        const SizedBox(height: 16),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: context.renkler.metin, fontWeight: FontWeight.w600))),
        const SizedBox(height: 8),
      ],
    ));
  }

  Widget _buildFinansDetayBolumu(String title, List<Widget> items,
      IconData icon, Color color, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.renkler.metinIkincil)),
            ],
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }

  Widget _buildFinansSatir(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: context.renkler.metinIkincil, size: 16),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style:
                      TextStyle(fontSize: 14, color: context.renkler.metin))),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.renkler.metin)),
        ],
      ),
    );
  }
}
