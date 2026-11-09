/// MÜŞTERİ YÖNETİMİ MODULE
///
/// Müşteri listesi, arama, müşteri detayı (ekspertiz talepleri) ve hesap
/// aktif/pasif yönetimi. Veriler merkezi API'nin `/expertiz/admin/customers`
/// uçlarından gelir.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../tema/renkler.dart';
import '../../bilesenler/bilesenler.dart';
import '../../services/yerimebak_expertiz_api_service.dart';

/// Müşteri Yönetimi Module
class MusteriYonetimiModule extends StatefulWidget {
  const MusteriYonetimiModule({super.key, this.apiService, this.initialFilter});

  /// Testlerde sahte servis vermek için.
  final YerimebakExpertizApiService? apiService;
  final String? initialFilter;

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
  late String _filter;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? 'all';
    _api = widget.apiService ?? YerimebakExpertizApiService();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MusteriYonetimiModule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      _filter = widget.initialFilter ?? 'all';
      _page = 0;
    }
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
      SnackBar(content: Text(message), backgroundColor: error ? context.renkler.tehlike : context.renkler.birincil),
    );
  }

  static String _tl(num value) {
    final parts = value.toDouble().toStringAsFixed(2).split('.');
    final digits = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return parts[1] == '00' ? '$digits TL' : '$digits,${parts[1]} TL';
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Müşteriler', style: Theme.of(context).textTheme.headlineSmall)),
          IconButton(onPressed: _load, icon: const Icon(LucideIcons.refreshCw), tooltip: 'Yenile'),
        ]),
        Text('Hesapları, kredi hareketlerini ve ekspertiz taleplerini yönetin.', style: TextStyle(color: context.renkler.metinIkincil)),
        const SizedBox(height: 16),
        YbArama(controller: _searchController, onChanged: _onSearchChanged, ipucu: 'E-posta, ad veya telefon ara'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final option in const {'all': 'Tümü', 'active': 'Aktif', 'inactive': 'Pasif', 'test': 'Test'}.entries)
            FilterChip(label: Text(option.value), selected: _filter == option.key, onSelected: (_) => setState(() { _filter = option.key; _page = 0; })),
          if (!_loading && _error == null)
            Text('${_customers.length} müşteri • $_activeCount aktif', style: TextStyle(color: context.renkler.metinIkincil)),
        ]),
        const SizedBox(height: 16),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) return ListView(children: const [YbIskelet(height: 52), SizedBox(height: 12), YbIskelet(height: 52), SizedBox(height: 12), YbIskelet(height: 52)]);
    if (_error != null) return YbBosDurum(mesaj: 'Müşteriler yüklenemedi: $_error', eylem: 'Tekrar Dene', onPressed: _load);
    final visible = _customers.where((c) => switch (_filter) {
      'active' => c['is_active'] == true,
      'inactive' => c['is_active'] != true,
      'test' => c['tester'] == true,
      _ => true,
    }).toList();
    if (visible.isEmpty) return YbBosDurum(mesaj: _searchController.text.trim().isEmpty && _filter == 'all' ? 'Henüz müşteri yok.' : 'Aramaya uyan müşteri yok.');
    Widget badges(Map<String, dynamic> c) => Wrap(spacing: 4, runSpacing: 4, children: [
      if (c['tester'] == true) const YbRozet('Test', key: Key('test-rozeti'), tur: YbRozetTuru.bilgi),
      if (c['is_active'] != true) const YbRozet('Pasif'),
      if (c['is_active'] == true && c['tester'] != true) const YbRozet('Aktif', tur: YbRozetTuru.basari),
    ]);
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 900) {
        return SingleChildScrollView(child: YbTablo(
          sayfa: _page,
          onPageChanged: (value) => setState(() => _page = value),
          columns: const [DataColumn(label: Text('Müşteri')), DataColumn(label: Text('E-posta')), DataColumn(label: Text('Kayıt')), DataColumn(label: Text('Kredi'), numeric: true), DataColumn(label: Text('Talepler'), numeric: true), DataColumn(label: Text('Harcama'), numeric: true), DataColumn(label: Text('Durum'))],
          rows: visible.map((c) => DataRow(onSelectChanged: (_) => _openDetail(c), cells: [
            DataCell(Text(_name(c))), DataCell(Text((c['email'] ?? '').toString())), DataCell(Text(_date(c['created_at']))),
            DataCell(Text('${c['credits'] ?? 0} kredi')), DataCell(Text('${c['request_count'] ?? 0} talep')), DataCell(Text(_tl((c['total_spent_tl'] as num?) ?? 0))), DataCell(badges(c)),
          ])).toList(),
        ));
      }
      return RefreshIndicator(onRefresh: _load, child: ListView.builder(
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final c = visible[index];
          return YbKart(margin: const EdgeInsets.only(bottom: 12), onTap: () => _openDetail(c), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(_name(c), style: const TextStyle(fontWeight: FontWeight.w600))), badges(c)]),
            const SizedBox(height: 8),
            Text('${c['email'] ?? ''}', style: TextStyle(color: context.renkler.metinIkincil)),
            const SizedBox(height: 8),
            Text('${c['request_count'] ?? 0} talep · ${_tl((c['total_spent_tl'] as num?) ?? 0)} · ${c['credits'] ?? 0} kredi'),
            Text('Kayıt: ${_date(c['created_at'])}', style: TextStyle(color: context.renkler.metinIkincil)),
          ]));
        },
      ));
    });
  }

  Future<void> _openDetail(Map<String, dynamic> customer) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(alignment: Alignment.centerRight, insetPadding: const EdgeInsets.all(20),
        child: SizedBox(width: 480, child: _MusteriDetay(api: _api, customer: customer, tl: _tl, date: _date, name: _name))),
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

  /// Test kullanıcısı: 'test' durumundaki illerde ve genel anahtar kapalıyken talep açabilir (037).
  Future<void> _toggleTester(bool value) async {
    setState(() => _saving = true);
    try {
      await widget.api.setCustomerTester(_id, value);
      if (!mounted) return;
      setState(() => _customer = {..._customer, 'tester': value});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
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

    return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.name(c), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(aktif ? 'Aktif hesap' : 'Pasif hesap',
              style: TextStyle(color: aktif ? context.renkler.birincil : context.renkler.tehlike)),
          SizedBox(height: 16),
          _row(LucideIcons.mail, 'E-posta', c['email']?.toString() ?? '-'),
          _row(LucideIcons.phone, 'Telefon', (c['phone'] as String?)?.isNotEmpty == true ? c['phone'] as String : '-'),
          _row(LucideIcons.creditCard, 'Kredi', '${c['credits'] ?? 0} kredi'),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              onPressed: _saving || _loading ? null : _editCredits,
              icon: Icon(LucideIcons.walletCards), label: Text('Kredi yükle / düş')),
          ]),
          _row(LucideIcons.calendarDays, 'Kayıt', widget.date(c['created_at'])),
          _row(LucideIcons.logIn, 'Son giriş', widget.date(c['last_login'])),
          _row(LucideIcons.banknote, 'Toplam harcama', widget.tl((c['total_spent_tl'] as num?) ?? 0)),
          SwitchListTile(
            key: const Key('test-kullanicisi'),
            contentPadding: EdgeInsets.zero,
            title: Text('Test kullanıcısı'),
            subtitle: Text('Test illerinde ve hizmet genel olarak kapalıyken yerinde ekspertiz talebi '
                'açabilir; ödemesiz test talebi seçeneğini görür.'),
            value: c['tester'] == true,
            onChanged: _saving ? null : _toggleTester,
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: aktif
                ? OutlinedButton.icon(
                    onPressed: _saving ? null : _toggleActive,
                    icon: Icon(LucideIcons.ban, color: context.renkler.tehlike),
                    label: Text('Pasife Al'),
                  )
                : FilledButton.icon(
                    onPressed: _saving ? null : _toggleActive,
                    icon: Icon(LucideIcons.circleCheck),
                    label: Text('Aktif Et'),
                  ),
          ),
          Divider(height: 32),
          Text('Son kredi hareketleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (!_loading && _movements.isEmpty) Text('Kredi hareketi yok.'),
          ..._movements.map((m) {
            final delta = -((m['credits_used'] as num?)?.toInt() ?? 0);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(m['description']?.toString() ?? m['action']?.toString() ?? '-'),
              subtitle: Text(widget.date(m['created_at'])),
              trailing: Text('${delta > 0 ? '+' : ''}$delta kredi'),
            );
          }),
          Divider(height: 32),
          Text('Ekspertiz Talepleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          if (_loading)
            const YbIskelet(height: 52)
          else if (_error != null)
            Text('Talepler yüklenemedi: $_error', style: TextStyle(color: context.renkler.tehlike))
          else if (_requests.isEmpty)
            Text('Bu müşterinin ekspertiz talebi yok.', style: TextStyle(color: context.renkler.metinIkincil))
          else
            ..._requests.map((r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(LucideIcons.car),
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
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.renkler.metinIkincil),
          SizedBox(width: 12),
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: context.renkler.metinIkincil))),
          Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w600))),
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
  Widget build(BuildContext context) => YbDiyalog(
    baslik: 'Kredi yükle / düş',
    eylemler: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text('Vazgeç')),
      FilledButton(onPressed: () {
        if (!_form.currentState!.validate()) return;
        Navigator.pop(context, {'amount': int.parse(_amount.text.trim()), 'reason': _reason.text.trim()});
      }, child: Text('Kaydet')),
    ],
    child: SizedBox(width: 520, child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
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
    return YbDiyalog(
      baslik: 'Müşteriyi pasife al',
      eylemler: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Vazgeç')),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) Navigator.pop(context, text);
          },
          child: Text('Pasife Al'),
        ),
      ],
      child: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Neden (zorunlu)'),
      ),
);
  }
}
