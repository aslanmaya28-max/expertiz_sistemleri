import 'package:flutter/material.dart';
import 'package:yerimebak_sistemleri/bilesenler/bilesenler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../services/yerimebak_expertiz_api_service.dart';

/// Yalnız AdminShell üzerinden açılır; sunucu ayrıca admin yetkisini doğrular.
class PiyasaTakibiModule extends StatefulWidget {
  const PiyasaTakibiModule({super.key, this.apiService});

  final YerimebakExpertizApiService? apiService;

  @override
  State<PiyasaTakibiModule> createState() => _PiyasaTakibiModuleState();
}

class _PiyasaTakibiModuleState extends State<PiyasaTakibiModule> {
  late final YerimebakExpertizApiService _api;
  final _paste = TextEditingController();
  final _brand = TextEditingController();
  final _number = NumberFormat.decimalPattern('tr_TR');
  List<Map<String, dynamic>> _gaps = [];
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _busy = false;
  int? _skipped;
  String? _gapsError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = widget.apiService ?? YerimebakExpertizApiService();
    _loadGaps();
  }

  @override
  void dispose() {
    _paste.dispose();
    _brand.dispose();
    super.dispose();
  }

  static List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List? ?? [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

  String _message(Object error) => error is ApiException
      ? error.message
      : 'İşlem tamamlanamadı. Lütfen tekrar deneyin.';

  Future<void> _loadGaps() async {
    setState(() {
      _loading = true;
      _gapsError = null;
    });
    try {
      final result = await _api.getMarketGaps();
      if (!mounted) return;
      setState(() => _gaps = _maps(result['modeller']));
    } catch (error) {
      if (mounted) setState(() => _gapsError = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _preview() async {
    if (_busy || _paste.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _rows = [];
      _skipped = null;
    });
    try {
      final result = await _api.previewMarketList(_paste.text.trim());
      if (!mounted) return;
      setState(() {
        _rows = _maps(result['satirlar']);
        _brand.text = result['marka']?.toString() ?? '';
        _skipped = (result['atlanan'] as num?)?.toInt() ?? 0;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _rows.isEmpty || _brand.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result =
          await _api.saveMarketList(brand: _brand.text.trim(), rows: _rows);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
        '${result['eklenen'] ?? 0} yeni kayıt, ${result['tekrar'] ?? 0} zaten vardı',
      )));
      setState(() {
        _paste.clear();
        _brand.clear();
        _rows = [];
        _skipped = null;
      });
      await _loadGaps();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _display(dynamic value) => value == null
      ? '—'
      : value is num
          ? _number.format(value)
          : value.toString();

  Widget _errorText(String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(message,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );

  Widget _gapsTable() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          key: const Key('marketGapsTable'),
          columns: [
            for (final label in [
              'Marka',
              'Model',
              'Yıl',
              'İstek sayısı',
              'Son bulunan ilan',
              'Takipteki ilan'
            ])
              DataColumn(label: Text(label))
          ],
          rows: [
            for (final row in _gaps)
              DataRow(
                color: row['takip_ilan'] == 0
                    ? WidgetStatePropertyAll(
                        Theme.of(context)
                            .colorScheme
                            .errorContainer
                            .withValues(alpha: .4),
                      )
                    : null,
                cells: [
                  for (final key in [
                    'brand',
                    'model',
                    'year',
                    'requests',
                    'last_count',
                    'takip_ilan'
                  ])
                    DataCell(Text(key == 'year'
                        ? '${row[key] ?? '—'}'
                        : _display(row[key])))
                ],
              )
          ],
        ),
      );

  Widget _previewTable() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            for (final label in [
              'Seri',
              'Model',
              'Yıl',
              'Km',
              'Fiyat',
              'Beygir',
              'İlan tarihi',
              'İl',
              ''
            ])
              DataColumn(label: Text(label))
          ],
          rows: [
            for (var i = 0; i < _rows.length; i++)
              DataRow(cells: [
                for (final key in [
                  'seri',
                  'model',
                  'yil',
                  'km',
                  'fiyat',
                  'beygir',
                  'ilan_tarihi',
                  'il'
                ])
                  DataCell(Text(key == 'yil'
                      ? '${_rows[i][key] ?? '—'}'
                      : _display(_rows[i][key]))),
                DataCell(IconButton(
                  key: Key('removeMarketRow-$i'),
                  tooltip: 'Satırı çıkar',
                  icon: const Icon(LucideIcons.circleMinus),
                  onPressed:
                      _busy ? null : () => setState(() => _rows.removeAt(i)),
                )),
              ])
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final title = Theme.of(context).textTheme.titleLarge;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Piyasa takibi', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text(
            'Yalnız rakamlar saklanır; ilan başlığı, açıklama, fotoğraf, satıcı ve link kaydedilmez. '
            'Bu veriler müşteriye tek tek gösterilmez.'),
        const SizedBox(height: 16),
        YbKart(padding: EdgeInsets.zero,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Verisi az olan modeller', style: title),
                    const SizedBox(height: 8),
                    const Text(
                        'Bu modellerde internet aramasında 5 ilan bulunamadı. İlan sitesinde aynı marka/modeli '
                        'arayıp sonuç listesini aşağıya yapıştırın.'),
                    TextButton.icon(
                        onPressed: _loading || _busy ? null : _loadGaps,
                        icon: const Icon(LucideIcons.refreshCw),
                        label: const Text('Yenile')),
                    if (_loading) const LinearProgressIndicator(),
                    if (_gapsError != null) _errorText(_gapsError!),
                    if (!_loading && _gapsError == null && _gaps.isEmpty)
                      const Text('Şu anda verisi az olan model yok.'),
                    if (_gaps.isNotEmpty) _gapsTable(),
                  ],
                ))),
        const SizedBox(height: 16),
        YbKart(padding: EdgeInsets.zero,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Liste yapıştır', style: title),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('marketPaste'),
                      controller: _paste,
                      minLines: 4,
                      maxLines: 8,
                      readOnly: _busy,
                      decoration: const InputDecoration(
                          labelText: 'İlan sitesinin sonuç listesi',
                          border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {
                        _rows = [];
                        _brand.clear();
                        _skipped = null;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                          onPressed: _busy || _paste.text.trim().isEmpty
                              ? null
                              : _preview,
                          child: const Text('Önizle'),
                        )),
                    if (_busy)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator()),
                    if (_error != null) _errorText(_error!),
                    if (_skipped != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                              '${_rows.length} ilan hazır, $_skipped satır atlandı.')),
                    if (_rows.isNotEmpty) _previewTable(),
                    const SizedBox(height: 12),
                    TextField(
                        key: const Key('marketBrand'),
                        controller: _brand,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                            labelText: 'Marka (zorunlu)',
                            border: OutlineInputBorder()),
                        onChanged: (_) => setState(() {})),
                    const SizedBox(height: 12),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                          onPressed: _busy ||
                                  _rows.isEmpty ||
                                  _brand.text.trim().isEmpty
                              ? null
                              : _save,
                          child: const Text('Kaydet'),
                        )),
                  ],
                ))),
      ]),
    );
  }
}
