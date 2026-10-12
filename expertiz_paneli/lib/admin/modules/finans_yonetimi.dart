import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/yerimebak_colors.dart';
import '../../../services/yerimebak_expertiz_api_service.dart';

/// Finans Yönetimi
///
/// Veriler merkezi API'nin `/expertiz/admin/finance/summary` ucundan gelir:
/// ekspertiz talepleri (ciro/KDV), kredi paketi satışları ve yayınlanan
/// raporlar üzerinden tahakkuk eden personel hakedişi.
class FinansYonetimi extends StatefulWidget {
  const FinansYonetimi({super.key, this.apiService});

  /// Testlerde sahte servis vermek için.
  final YerimebakExpertizApiService? apiService;

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
  List<Map<String, dynamic>> _orders = const [];
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
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
      final results = await Future.wait([_api.getAdminFinanceSummary(), _api.getCreditOrders()]);
      final response = results[0];
      if (!mounted) return;
      setState(() {
        _ekspertiz = _map(response['ekspertiz']);
        _kredi = _map(response['kredi_satislari']);
        _personel = _map(response['personel']);
        _iade = _map(response['iadeler']);
        _orders = (results[1]['orders'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((o) => ['approved', 'refunded'].contains(o['status']))
            .toList();
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

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  /// Muhasebe / e-Arşiv entegratörü için tahsilat dökümü (satış + iade satırları).
  Future<void> _exportCsv() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      helpText: 'Tahsilat dökümü tarih aralığı',
    );
    if (range == null) return;
    final fmt = DateFormat('yyyy-MM-dd');
    setState(() => _exporting = true);
    try {
      final bytes = await _api.downloadInvoiceCsv(start: fmt.format(range.start), end: fmt.format(range.end));
      final name = 'yerimebak_tahsilatlar_${fmt.format(range.start)}_${fmt.format(range.end)}.csv';
      await FilePicker.platform.saveFile(
        dialogTitle: 'Tahsilat dökümünü kaydet',
        fileName: name,
        bytes: Uint8List.fromList(bytes),
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      _snack('Döküm hazır: $name');
    } catch (e) {
      _snack('Döküm alınamadı: ${e is ApiException ? e.message : e}', error: true);
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
            Text('${order['package_name'] ?? 'Paket'} • ${_tl(((order['amount_tl'] as num?) ?? 0).toDouble())} • '
                '${order['user_email'] ?? ''}\nYalnızca hiç kullanılmamış paketler iade edilebilir; krediler bakiyeden düşülür.'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('refundReasonField'),
              controller: controller,
              decoration: const InputDecoration(labelText: 'İade nedeni *', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          FilledButton(
            key: const Key('confirmRefundButton'),
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
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
      _snack('İade yapılamadı: ${e is ApiException ? e.message : e}', error: true);
    }
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static double _num(Map<String, dynamic> m, String key) => (m[key] as num?)?.toDouble() ?? 0.0;

  static String _tl(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '$digits,${parts[1]} TL';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError(isDarkMode);

    final ciro = _num(_ekspertiz, 'ciro_tl');
    final kdv = _num(_ekspertiz, 'kdv_tl');
    final net = _num(_ekspertiz, 'net_tl');
    final hakedis = _num(_personel, 'hakedis_tl');
    final krediOnayli = _num(_kredi, 'approved_tl');
    final krediBekleyen = _num(_kredi, 'pending_tl');
    final paylasimOrani = (_num(_personel, 'share_rate') * 100).toStringAsFixed(0);
    final simulasyon = (_ekspertiz['simulated_payment_count'] as num?)?.toInt() ?? 0;
    final talepAdedi = (_ekspertiz['request_count'] as num?)?.toInt() ?? 0;
    final personelListesi = (_personel['by_personnel'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final textColor = isDarkMode ? Colors.white : const Color(0xFF111827);

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
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('exportCsvButton'),
                  onPressed: _exporting ? null : _exportCsv,
                  icon: _exporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download),
                  label: const Text('Tahsilat Dökümü (CSV)'),
                ),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Yenile'),
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
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
              children: [
                _buildFinansKart('Ekspertiz Cirosu', _tl(ciro), Icons.trending_up, Colors.teal, isDarkMode),
                _buildFinansKart('KDV', _tl(kdv), Icons.receipt_long, Colors.indigo, isDarkMode),
                _buildFinansKart('Personel Hakedişi (%$paylasimOrani)', _tl(hakedis),
                    Icons.account_balance_wallet, Colors.amber, isDarkMode),
                _buildFinansKart('Kredi Satışları', _tl(krediOnayli), Icons.credit_card, Colors.purple, isDarkMode),
              ],
            ),
            const SizedBox(height: 30),
            Card(
              elevation: 4,
              color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Finansal Detaylar',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 20),
                    _buildFinansDetayBolumu(
                      'Gelirler',
                      [
                        _buildFinansSatir('Ekspertiz talebi', '$talepAdedi adet', Icons.assignment),
                        _buildFinansSatir('Ekspertiz cirosu (KDV dahil)', _tl(ciro), Icons.attach_money),
                        _buildFinansSatir('KDV hariç tutar', _tl(net), Icons.calculate),
                        _buildFinansSatir('Onaylı kredi satışı (${_kredi['approved_count'] ?? 0})',
                            _tl(krediOnayli), Icons.credit_card),
                        _buildFinansSatir('Ödemesi bekleyen kredi (${_kredi['pending_count'] ?? 0})',
                            _tl(krediBekleyen), Icons.hourglass_top),
                        _buildFinansSatir(
                            'İade edilen ekspertiz (${_iade['expertiz_count'] ?? 0}) — ciroya dahil değil',
                            _tl(_num(_iade, 'expertiz_tl')), Icons.undo),
                        _buildFinansSatir('İade edilen kredi (${_iade['kredi_count'] ?? 0}) — ciroya dahil değil',
                            _tl(_num(_iade, 'kredi_tl')), Icons.undo),
                      ],
                      Icons.arrow_downward,
                      Colors.green,
                      isDarkMode,
                    ),
                    const SizedBox(height: 20),
                    _buildFinansDetayBolumu(
                      'Giderler',
                      [
                        _buildFinansSatir('Ödenecek KDV', _tl(kdv), Icons.receipt_long),
                        _buildFinansSatir('Personel hakedişi (yayınlanan raporlar)', _tl(hakedis), Icons.people),
                      ],
                      Icons.arrow_upward,
                      Colors.red,
                      isDarkMode,
                    ),
                    const SizedBox(height: 20),
                    _buildNetKar(net + krediOnayli - hakedis, isDarkMode),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text('Kredi Paketi Satışları',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 8),
            if (_orders.isEmpty)
              Text('Henüz ödenmiş kredi paketi yok.',
                  style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]))
            else
              ..._orders.map((o) {
                final refunded = o['status'] == 'refunded';
                return Card(
                  key: Key('order-${o['id']}'),
                  color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  child: ListTile(
                    leading: Icon(refunded ? Icons.undo : Icons.credit_card,
                        color: refunded ? Colors.grey : Colors.purple),
                    title: Text('${o['package_name'] ?? o['package_key'] ?? 'Paket'} • ${o['credits'] ?? 0} kredi',
                        style: TextStyle(color: textColor)),
                    subtitle: Text('${o['user_email'] ?? ''} • ${'${o['approved_at'] ?? o['created_at'] ?? ''}'.split('.').first}'
                        '${refunded ? ' • İADE EDİLDİ' : ''}'),
                    trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(_tl(((o['amount_tl'] as num?) ?? 0).toDouble()),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (!refunded)
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
            Text('Personel Hakedişleri',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 8),
            Text(
              'Hakediş, yayınlanan raporların KDV hariç tutarı üzerinden tahakkuk eder. '
              'Personele yapılan ödemeler henüz sistemde takip edilmiyor.',
              style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            if (personelListesi.isEmpty)
              Text('Henüz yayınlanmış personel raporu yok.',
                  style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]))
            else
              ...personelListesi.map((p) => Card(
                    color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    child: ListTile(
                      leading: const Icon(Icons.badge, color: YerimeBakColors.blue),
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

  Widget _buildError(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text('Finans verileri yüklenemedi',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text(_error ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Tekrar Dene')),
          ],
        ),
      ),
    );
  }

  Widget _buildUyari(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildNetKar(double netKar, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: YerimeBakColors.blue.withValues(alpha: isDarkMode ? 0.1 : 0.05),
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
                      color: isDarkMode ? Colors.white : Colors.grey[800])),
              Text(
                _tl(netKar),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: netKar >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'KDV hariç ekspertiz geliri + onaylı kredi satışı - personel hakedişi',
            style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildFinansKart(String title, String value, IconData icon, Color color, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinansDetayBolumu(String title, List<Widget> items, IconData icon, Color color, bool isDarkMode) {
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
                      color: isDarkMode ? Colors.white : Colors.grey[800])),
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
          Icon(icon, color: Colors.grey, size: 16),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)))),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        ],
      ),
    );
  }
}
