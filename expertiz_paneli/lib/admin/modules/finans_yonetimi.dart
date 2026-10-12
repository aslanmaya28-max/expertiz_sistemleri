import 'package:flutter/material.dart';
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
      final response = await _api.getAdminFinanceSummary();
      if (!mounted) return;
      setState(() {
        _ekspertiz = _map(response['ekspertiz']);
        _kredi = _map(response['kredi_satislari']);
        _personel = _map(response['personel']);
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
                        _buildFinansSatir('Onay bekleyen kredi (${_kredi['pending_count'] ?? 0})',
                            _tl(krediBekleyen), Icons.hourglass_top),
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
