/// MÜŞTERİ YÖNETİMİ MODULE
///
/// Müşteri listesi, arama, müşteri detayı (ekspertiz talepleri) ve hesap
/// aktif/pasif yönetimi. Veriler merkezi API'nin `/expertiz/admin/customers`
/// uçlarından gelir.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/yerimebak_expertiz_api_service.dart';

/// Müşteri Yönetimi Module
class MusteriYonetimiModule extends StatefulWidget {
  const MusteriYonetimiModule({super.key, this.apiService});

  /// Testlerde sahte servis vermek için.
  final YerimebakExpertizApiService? apiService;

  @override
  State<MusteriYonetimiModule> createState() => _MusteriYonetimiModuleState();
}

class _MusteriYonetimiModuleState extends State<MusteriYonetimiModule> {
  late final YerimebakExpertizApiService _api;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _customers = [];
  int _activeCount = 0;

  @override
  void initState() {
    super.initState();
    _api = widget.apiService ?? YerimebakExpertizApiService();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.getAdminCustomers(search: _searchController.text);
      final rows = (response['customers'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _customers = rows;
        _activeCount = (response['active'] as num?)?.toInt() ?? rows.where((c) => c['is_active'] == true).length;
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

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700),
    );
  }

  static String _tl(num value) {
    final parts = value.toDouble().toStringAsFixed(2).split('.');
    final digits = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '$digits,${parts[1]} TL';
  }

  static String _date(dynamic value) {
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    if (parsed == null) return '-';
    final d = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  static String _name(Map<String, dynamic> c) {
    final name = (c['full_name'] as String?)?.trim() ?? '';
    return name.isNotEmpty ? name : (c['email'] as String? ?? 'Müşteri #${c['id']}');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF111827);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text('Müşteri Yönetimi',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Yenile'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'E-posta, ad veya telefon ara',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
        ),
        if (!_loading && _error == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              '${_customers.length} müşteri • $_activeCount aktif',
              style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
        Expanded(child: _buildBody(isDarkMode, textColor)),
      ],
    );
  }

  Widget _buildBody(bool isDarkMode, Color textColor) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text('Müşteriler yüklenemedi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Tekrar Dene')),
            ],
          ),
        ),
      );
    }
    if (_customers.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.trim().isEmpty ? 'Henüz müşteri yok.' : 'Aramaya uyan müşteri yok.',
          style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _customers.length,
        itemBuilder: (context, index) {
          final c = _customers[index];
          final aktif = c['is_active'] == true;
          return Card(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            child: ListTile(
              onTap: () => _openDetail(c),
              leading: CircleAvatar(
                backgroundColor: aktif ? Colors.teal.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
                child: Icon(Icons.person, color: aktif ? Colors.teal : Colors.grey),
              ),
              title: Text(_name(c), style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${c['email'] ?? ''}\n'
                '${c['request_count'] ?? 0} talep • ${_tl((c['total_spent_tl'] as num?) ?? 0)} • ${c['credits'] ?? 0} kredi',
              ),
              isThreeLine: true,
              trailing: aktif
                  ? null
                  : const Chip(label: Text('Pasif'), visualDensity: VisualDensity.compact),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openDetail(Map<String, dynamic> customer) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MusteriDetay(api: _api, customer: customer, tl: _tl, date: _date, name: _name),
    );
    if (changed == true) {
      _toast('Müşteri durumu güncellendi');
    }
    if (mounted) _load();
  }
}

class _MusteriDetay extends StatefulWidget {
  const _MusteriDetay({
    required this.api,
    required this.customer,
    required this.tl,
    required this.date,
    required this.name,
  });

  final YerimebakExpertizApiService api;
  final Map<String, dynamic> customer;
  final String Function(num) tl;
  final String Function(dynamic) date;
  final String Function(Map<String, dynamic>) name;

  @override
  State<_MusteriDetay> createState() => _MusteriDetayState();
}

class _MusteriDetayState extends State<_MusteriDetay> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  late Map<String, dynamic> _customer = widget.customer;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _movements = [];

  static const _reportStatusLabels = {
    'draft': 'Personel bekliyor',
    'pending_ai': 'AI analizinde',
    'pending_admin': 'Onay bekliyor',
    'published': 'Yayınlandı',
    'rejected': 'Reddedildi',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get _id => (_customer['id'] as num).toInt();

  Future<void> _load() async {
    try {
      final response = await widget.api.getAdminCustomer(_id);
      if (!mounted) return;
      setState(() {
        _error = null;
        if (response['customer'] is Map) _customer = Map<String, dynamic>.from(response['customer'] as Map);
        _requests = (response['requests'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _movements = (response['credit_movements'] as List? ?? const [])
            .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
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

  Future<void> _toggleActive() async {
    final aktif = _customer['is_active'] == true;
    String? reason;
    if (aktif) {
      reason = await _askReason();
      if (reason == null) return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.setCustomerActive(_id, active: !aktif, reason: reason);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    }
  }

  Future<String?> _askReason() {
    return showDialog<String>(context: context, builder: (_) => const _PasifNedeniDialog());
  }

  Future<void> _editCredits() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _CreditDialog(),
    );
    if (payload == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.api.adjustCustomerCredits(_id, amount: payload['amount'] as int, reason: payload['reason'] as String);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _customer;
    final aktif = c['is_active'] == true;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.name(c), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(aktif ? 'Aktif hesap' : 'Pasif hesap',
              style: TextStyle(color: aktif ? Colors.teal : Colors.redAccent)),
          const SizedBox(height: 16),
          _row(Icons.email, 'E-posta', c['email']?.toString() ?? '-'),
          _row(Icons.phone, 'Telefon', (c['phone'] as String?)?.isNotEmpty == true ? c['phone'] as String : '-'),
          _row(Icons.credit_card, 'Kredi', '${c['credits'] ?? 0} kredi'),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              onPressed: _saving || _loading ? null : _editCredits,
              icon: const Icon(Icons.add_card), label: const Text('Kredi yükle / düş')),
          ]),
          _row(Icons.calendar_today, 'Kayıt', widget.date(c['created_at'])),
          _row(Icons.login, 'Son giriş', widget.date(c['last_login'])),
          _row(Icons.payments, 'Toplam harcama', widget.tl((c['total_spent_tl'] as num?) ?? 0)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: aktif
                ? OutlinedButton.icon(
                    onPressed: _saving ? null : _toggleActive,
                    icon: const Icon(Icons.block, color: Colors.redAccent),
                    label: const Text('Pasife Al'),
                  )
                : FilledButton.icon(
                    onPressed: _saving ? null : _toggleActive,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Aktif Et'),
                  ),
          ),
          const Divider(height: 32),
          const Text('Son kredi hareketleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (!_loading && _movements.isEmpty) const Text('Kredi hareketi yok.'),
          ..._movements.map((m) {
            final delta = -((m['credits_used'] as num?)?.toInt() ?? 0);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(m['description']?.toString() ?? m['action']?.toString() ?? '-'),
              subtitle: Text(widget.date(m['created_at'])),
              trailing: Text('${delta > 0 ? '+' : ''}$delta kredi'),
            );
          }),
          const Divider(height: 32),
          const Text('Ekspertiz Talepleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Text('Talepler yüklenemedi: $_error', style: const TextStyle(color: Colors.redAccent))
          else if (_requests.isEmpty)
            const Text('Bu müşterinin ekspertiz talebi yok.', style: TextStyle(color: Colors.grey))
          else
            ..._requests.map((r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.directions_car),
                  title: Text([r['plate'], r['package_name']]
                      .where((v) => v != null && v.toString().isNotEmpty)
                      .join(' • ')),
                  subtitle: Text(
                    '${widget.date(r['created_at'])} • '
                    '${_reportStatusLabels[r['report_status']] ?? r['status'] ?? '-'}',
                  ),
                  trailing: Text(widget.tl((r['total_tl'] as num?) ?? 0)),
                )),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _CreditDialog extends StatefulWidget {
  const _CreditDialog();

  @override
  State<_CreditDialog> createState() => _CreditDialogState();
}

class _CreditDialogState extends State<_CreditDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Kredi yükle / düş'),
    content: SizedBox(width: 520, child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(
        controller: _amount,
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        decoration: const InputDecoration(labelText: 'Miktar (+ yükle / - düş)'),
        validator: (value) {
          final amount = int.tryParse(value?.trim() ?? '');
          return amount == null || amount == 0 || amount.abs() > 10000 ? '±1 ile ±10000 arasında tam sayı girin' : null;
        },
      ),
      TextFormField(
        controller: _reason,
        maxLength: 2000,
        decoration: const InputDecoration(labelText: 'Neden (zorunlu)'),
        validator: (value) => (value?.trim().isEmpty ?? true) ? 'Neden zorunludur' : null,
      ),
    ]))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
      FilledButton(onPressed: () {
        if (!_form.currentState!.validate()) return;
        Navigator.pop(context, {'amount': int.parse(_amount.text.trim()), 'reason': _reason.text.trim()});
      }, child: const Text('Kaydet')),
    ],
  );
}

/// Pasife alma nedeni sorar; controller kapanış animasyonu bitince dispose edilir.
class _PasifNedeniDialog extends StatefulWidget {
  const _PasifNedeniDialog();

  @override
  State<_PasifNedeniDialog> createState() => _PasifNedeniDialogState();
}

class _PasifNedeniDialogState extends State<_PasifNedeniDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Müşteriyi pasife al'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Neden (zorunlu)'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) Navigator.pop(context, text);
          },
          child: const Text('Pasife Al'),
        ),
      ],
    );
  }
}
