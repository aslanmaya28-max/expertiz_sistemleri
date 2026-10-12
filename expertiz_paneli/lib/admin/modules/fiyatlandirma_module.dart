/// FİYATLANDIRMA MODULE
///
/// YerimeBak hizmet bedeli, aylık araç enflasyonu (değerleme getirisi) ve
/// kurumsal ekspertiz firma / paket fiyat kataloğu. Değişiklikler müşteri
/// panelinde anında geçerli olur. Merkezi API: `/expertiz/admin/pricing`.
library;

import 'package:flutter/material.dart';
import '../../services/yerimebak_expertiz_api_service.dart';

class FiyatlandirmaModule extends StatefulWidget {
  const FiyatlandirmaModule({super.key, this.apiService});

  /// Testlerde sahte servis vermek için.
  final YerimebakExpertizApiService? apiService;

  @override
  State<FiyatlandirmaModule> createState() => _FiyatlandirmaModuleState();
}

class _FiyatlandirmaModuleState extends State<FiyatlandirmaModule> {
  static const _targetFirmCount = 10;

  late final YerimebakExpertizApiService _api;
  final _feeController = TextEditingController();
  final _inflationController = TextEditingController();
  final _inflationNoteController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  double _vatRate = 0.2;
  Map<String, dynamic>? _inflation;
  List<Map<String, dynamic>> _firms = [];

  @override
  void initState() {
    super.initState();
    _api = widget.apiService ?? YerimebakExpertizApiService();
    _load();
  }

  @override
  void dispose() {
    _feeController.dispose();
    _inflationController.dispose();
    _inflationNoteController.dispose();
    super.dispose();
  }

  static List<Map<String, dynamic>> _maps(dynamic v) =>
      (v as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.getAdminPricing();
      if (!mounted) return;
      final inflation = r['vehicle_inflation'] is Map ? Map<String, dynamic>.from(r['vehicle_inflation'] as Map) : null;
      setState(() {
        _vatRate = (r['vat_rate'] as num?)?.toDouble() ?? 0.2;
        _inflation = inflation;
        _firms = _maps(r['firms']);
        _feeController.text = _plain((r['service_fee_tl'] as num?) ?? 0);
        _inflationController.text = inflation == null ? '' : _plain(inflation['monthly_pct'] as num? ?? 0);
        _inflationNoteController.text = inflation?['note']?.toString() ?? '';
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

  static String _plain(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static double? _parse(String text) => double.tryParse(text.trim().replaceAll('.', '').replaceAll(',', '.'));

  static String _tl(num value) {
    final parts = value.toDouble().toStringAsFixed(2).split('.');
    final digits = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return parts[1] == '00' ? '$digits TL' : '$digits,${parts[1]} TL';
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700),
    );
  }

  String _err(Object e) => e is ApiException ? e.message : e.toString();

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _saving = true);
    try {
      await action();
      _toast(success);
      await _load();
    } catch (e) {
      _toast(_err(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveFee() async {
    final fee = _parse(_feeController.text);
    if (fee == null || fee < 0) {
      _toast('Geçerli bir hizmet bedeli girin', error: true);
      return;
    }
    await _run(() => _api.updatePricingSettings(serviceFeeTl: fee), 'Hizmet bedeli güncellendi');
  }

  Future<void> _saveInflation() async {
    final rate = double.tryParse(_inflationController.text.trim().replaceAll(',', '.'));
    if (rate == null) {
      _toast('Aylık enflasyon oranını girin (ör. 2,5)', error: true);
      return;
    }
    await _run(
      () => _api.updatePricingSettings(inflationMonthlyPct: rate, inflationNote: _inflationNoteController.text.trim()),
      'Araç enflasyonu güncellendi',
    );
  }

  Future<Map<String, String>?> _formDialog(String title, List<(String, String, String)> fields) {
    final controllers = {for (final f in fields) f.$1: TextEditingController(text: f.$3)};
    return showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: fields
                .map((f) => TextField(
                      controller: controllers[f.$1],
                      decoration: InputDecoration(labelText: f.$2),
                      keyboardType: f.$1 == 'price' ? const TextInputType.numberWithOptions(decimal: true) : null,
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {for (final e in controllers.entries) e.key: e.value.text.trim()}),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ).whenComplete(() {
      // Kapanış animasyonu bittikten sonra
      Future.delayed(const Duration(milliseconds: 400), () {
        for (final c in controllers.values) {
          c.dispose();
        }
      });
    });
  }

  Future<void> _addFirm() async {
    final values = await _formDialog('Firma ekle', [('name', 'Firma adı', ''), ('source_url', 'Fiyat kaynağı (web sayfası)', '')]);
    if (values == null || (values['name'] ?? '').isEmpty) return;
    await _run(() => _api.createFirm(values['name']!, sourceUrl: values['source_url']), 'Firma eklendi');
  }

  Future<void> _editFirm(Map<String, dynamic> firm) async {
    final values = await _formDialog('Firmayı düzenle', [
      ('name', 'Firma adı', firm['name']?.toString() ?? ''),
      ('source_url', 'Fiyat kaynağı (web sayfası)', firm['source_url']?.toString() ?? ''),
    ]);
    if (values == null || (values['name'] ?? '').isEmpty) return;
    await _run(() => _api.updateFirm(firm['id'] as String, {'name': values['name'], 'source_url': values['source_url']}), 'Firma güncellendi');
  }

  Future<void> _packageDialog(Map<String, dynamic> firm, [Map<String, dynamic>? pkg]) async {
    final values = await _formDialog(pkg == null ? '${firm['name']} — paket ekle' : 'Paketi düzenle', [
      ('name', 'Paket adı', pkg?['name']?.toString() ?? ''),
      ('price', 'Fiyat (TL)', pkg == null ? '' : _plain(pkg['price'] as num)),
      ('features', 'Kapsam (virgülle ayırın)', ((pkg?['features'] as List?) ?? const []).join(', ')),
    ]);
    if (values == null) return;
    final price = _parse(values['price'] ?? '');
    if ((values['name'] ?? '').isEmpty || price == null || price <= 0) {
      _toast('Paket adı ve geçerli bir fiyat girin', error: true);
      return;
    }
    final features = (values['features'] ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (pkg == null) {
      await _run(() => _api.createPackage(firm['id'] as String, name: values['name']!, price: price, features: features), 'Paket eklendi');
    } else {
      await _run(
        () => _api.updatePackage(firm['id'] as String, pkg['id'] as String, {'name': values['name'], 'price': price, 'features': features}),
        'Paket güncellendi',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF111827);
    final subColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text('Fiyatlandırma yüklenemedi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Tekrar Dene')),
          ],
        ),
      );
    }

    final activeFirms = _firms.where((f) => f['active'] == true && _maps(f['packages']).any((p) => p['active'] == true)).length;
    final monthly = double.tryParse(_inflationController.text.replaceAll(',', '.'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: Text('Fiyatlandırma', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor))),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Yenile'),
            ],
          ),
          Text('Değişiklikler müşteri panelinde hemen geçerli olur.', style: TextStyle(color: subColor)),
          const SizedBox(height: 16),

          // HİZMET BEDELİ
          Card(
            color: cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YerimeBak hizmet bedeli', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 4),
                  Text('Her ekspertiz talebinde paket fiyatına eklenir (KDV %${(_vatRate * 100).round()} ayrıca hesaplanır).',
                      style: TextStyle(fontSize: 12, color: subColor)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 200,
                        child: TextField(
                          key: const Key('serviceFeeField'),
                          controller: _feeController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Hizmet bedeli', suffixText: 'TL', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(onPressed: _saving ? null : _saveFee, child: const Text('Kaydet')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ARAÇ ENFLASYONU
          Card(
            color: cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aylık araç enflasyonu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 4),
                  Text(
                    _inflation == null
                        ? 'Henüz girilmedi: müşteri değerlemelerinde 6 aylık / yıllık getiri gösterilmez.'
                        : 'Son güncelleme: ${_inflation!['effective_date'] ?? '-'}'
                            '${_inflation!['updated_by'] != null ? ' • ${_inflation!['updated_by']}' : ''}',
                    style: TextStyle(fontSize: 12, color: _inflation == null ? Colors.orange : subColor),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        child: TextField(
                          key: const Key('inflationField'),
                          controller: _inflationController,
                          onChanged: (_) => setState(() {}),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: const InputDecoration(labelText: 'Aylık oran', suffixText: '%', isDense: true),
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _inflationNoteController,
                          decoration: const InputDecoration(labelText: 'Kaynak (ör. TÜİK / ODMD Eylül)', isDense: true),
                        ),
                      ),
                      FilledButton(onPressed: _saving ? null : _saveInflation, child: const Text('Kaydet')),
                    ],
                  ),
                  if (monthly != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Yıllık karşılığı ≈ %${((_pow(1 + monthly / 100, 12) - 1) * 100).toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 12, color: subColor),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // FİRMALAR
          Row(
            children: [
              Expanded(
                child: Text('Kurumsal ekspertiz firmaları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              ),
              FilledButton.icon(onPressed: _saving ? null : _addFirm, icon: const Icon(Icons.add), label: const Text('Firma Ekle')),
            ],
          ),
          const SizedBox(height: 8),
          if (activeFirms < _targetFirmCount)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Müşteriye $activeFirms firma gösteriliyor (hedef $_targetFirmCount). '
                'Başlangıç fiyatları internetteki kaynaklardan alındı; firmalardan teyit edip "Doğrulandı" işaretleyin.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ..._firms.map((firm) => _buildFirm(firm, cardColor, textColor, subColor)),
        ],
      ),
    );
  }

  static double _pow(double base, int exp) {
    var result = 1.0;
    for (var i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  Widget _buildFirm(Map<String, dynamic> firm, Color cardColor, Color textColor, Color? subColor) {
    final active = firm['active'] == true;
    final verified = firm['verified'] == true;
    final packages = _maps(firm['packages']);
    return Card(
      color: cardColor,
      child: Opacity(
        opacity: active ? 1 : 0.55,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(firm['name']?.toString() ?? '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                        if ((firm['source_url'] ?? '').toString().isNotEmpty)
                          Text('Kaynak: ${firm['source_url']}', style: TextStyle(fontSize: 11, color: subColor), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  FilterChip(
                    label: Text(verified ? 'Doğrulandı' : 'Doğrulanmadı'),
                    selected: verified,
                    onSelected: _saving
                        ? null
                        : (v) => _run(() => _api.updateFirm(firm['id'] as String, {'verified': v}), v ? 'Fiyatlar doğrulandı' : 'Doğrulama kaldırıldı'),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: active,
                    onChanged: _saving
                        ? null
                        : (v) => _run(() => _api.updateFirm(firm['id'] as String, {'active': v}), v ? 'Firma yayında' : 'Firma gizlendi'),
                  ),
                  IconButton(icon: const Icon(Icons.edit), tooltip: 'Düzenle', onPressed: _saving ? null : () => _editFirm(firm)),
                ],
              ),
              const Divider(),
              ...packages.map((pkg) {
                final pActive = pkg['active'] == true;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(pkg['name']?.toString() ?? '',
                      style: TextStyle(color: textColor, decoration: pActive ? null : TextDecoration.lineThrough)),
                  subtitle: ((pkg['features'] as List?) ?? const []).isEmpty
                      ? null
                      : Text((pkg['features'] as List).join(' • '), style: TextStyle(fontSize: 11, color: subColor)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_tl((pkg['price'] as num?) ?? 0), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      Switch(
                        value: pActive,
                        onChanged: _saving
                            ? null
                            : (v) => _run(
                                  () => _api.updatePackage(firm['id'] as String, pkg['id'] as String, {'active': v}),
                                  v ? 'Paket yayında' : 'Paket gizlendi',
                                ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: 'Paketi düzenle',
                        onPressed: _saving ? null : () => _packageDialog(firm, pkg),
                      ),
                    ],
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : () => _packageDialog(firm),
                  icon: const Icon(Icons.add),
                  label: const Text('Paket ekle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
