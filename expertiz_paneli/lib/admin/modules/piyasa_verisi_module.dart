/// PİYASA VERİSİ MODULE
///
/// arabam.com ve Borusan Next kazıyıcılarını başlatma/durdurma (sadece admin),
/// kazınan ilanlardan güncel piyasa özeti ve marka/model bazında veri kapsamı.
/// Veriler merkezi API'nin `/scrapers`, `/vitrin/stats` ve
/// `/market-coverage/summary` uçlarından gelir.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/yerimebak_expertiz_api_service.dart';

class PiyasaVerisiModule extends StatefulWidget {
  const PiyasaVerisiModule({super.key, this.apiService, this.refreshInterval = const Duration(seconds: 15)});

  /// Testlerde sahte servis vermek için.
  final YerimebakExpertizApiService? apiService;

  /// Kazıyıcı durumunun otomatik yenilenme aralığı.
  final Duration refreshInterval;

  @override
  State<PiyasaVerisiModule> createState() => _PiyasaVerisiModuleState();
}

class _PiyasaVerisiModuleState extends State<PiyasaVerisiModule> {
  static const _sources = ['arabam', 'borusan'];
  static const _sourceLabels = {'arabam': 'Arabam.com', 'borusan': 'Borusan Next'};

  late final YerimebakExpertizApiService _api;
  Timer? _timer;

  bool _loading = true;
  String? _error;
  String? _busy; // işlem yapılan kaynak: arabam | borusan | all
  Map<String, dynamic> _status = const {};
  Map<String, dynamic> _stats = const {};
  Map<String, dynamic> _coverage = const {};
  String? _coverageError;

  @override
  void initState() {
    super.initState();
    _api = widget.apiService ?? YerimebakExpertizApiService();
    _loadAll();
    _timer = Timer.periodic(widget.refreshInterval, (_) => _loadStatus(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_api.getScraperStatus(), _api.getMarketStats()]);
      if (!mounted) return;
      setState(() {
        _status = results[0];
        _stats = results[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      return;
    }
    // Kapsam hesabı ağırdır; ana ekranı bekletmeden ayrıca yüklenir.
    try {
      final coverage = await _api.getMarketCoverageSummary();
      if (mounted) setState(() => _coverage = coverage);
    } catch (e) {
      if (mounted) setState(() => _coverageError = e.toString());
    }
  }

  Future<void> _loadStatus({bool silent = false}) async {
    if (_busy != null) return;
    try {
      final status = await _api.getScraperStatus();
      if (mounted) setState(() => _status = status);
    } catch (e) {
      if (!silent && mounted) _toast('Durum alınamadı: $e', error: true);
    }
  }

  Future<void> _run(String action, String source) async {
    setState(() => _busy = source);
    try {
      final result = action == 'start' ? await _api.startScraper(source) : await _api.stopScraper(source);
      _toast(result['message']?.toString() ?? (action == 'start' ? 'Başlatıldı' : 'Durduruldu'));
    } catch (e) {
      _toast(e is ApiException ? e.message : e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
      await _loadStatus();
    }
  }

  /// Vitrin toplu işlemleri (önceden web'deki /yonetim/vitrin sayfasındaydı).
  Future<void> _vitrinIslemi(String islem) async {
    setState(() => _busy = 'vitrin');
    try {
      if (islem == 'reanalyze') {
        final r = await _api.vitrinReanalyze();
        _toast('${r['analyzed'] ?? 0}/${r['total'] ?? 0} ilanın analizi yenilendi');
      } else {
        final r = await _api.vitrinActivateHidden();
        _toast('${r['activated'] ?? 0} gizli ilan tekrar vitrine alındı');
      }
    } catch (e) {
      _toast(e is ApiException ? e.message : e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
      await _loadAll();
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700));
  }

  static String _tl(num value) {
    final digits = value.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '$digits TL';
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text('Piyasa verisi yüklenemedi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _loadAll, icon: const Icon(Icons.refresh), label: const Text('Tekrar Dene')),
            ],
          ),
        ),
      );
    }

    final running = _sources.where((s) => _map(_status[s])['status'] == 'running').length;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Piyasa Verisi',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
              ),
              IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh), tooltip: 'Yenile'),
            ],
          ),
          Text(
            'Kazıyıcılar arabam.com ve Borusan Next ilanlarını toplar; bu veri vitrini ve '
            'değerlemelerdeki piyasa ortalamasını besler.',
            style: TextStyle(color: subColor),
          ),
          const SizedBox(height: 20),

          // KAZIYICILAR
          Row(
            children: [
              Expanded(
                child: Text('Kazıyıcılar ($running/${_sources.length} çalışıyor)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              ),
              TextButton.icon(
                onPressed: _busy != null || running == _sources.length ? null : () => _run('start', 'all'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Tümünü Başlat'),
              ),
              TextButton.icon(
                onPressed: _busy != null || running == 0 ? null : () => _run('stop', 'all'),
                icon: const Icon(Icons.stop),
                label: const Text('Tümünü Durdur'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._sources.map((s) => _buildScraperCard(s, cardColor, textColor, subColor)),
          const SizedBox(height: 24),

          // VİTRİN
          Text('Vitrin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('vitrinReanalyzeButton'),
                onPressed: _busy != null ? null : () => _vitrinIslemi('reanalyze'),
                icon: const Icon(Icons.auto_graph),
                label: const Text('Vitrin analizlerini yenile'),
              ),
              OutlinedButton.icon(
                key: const Key('vitrinActivateButton'),
                onPressed: _busy != null ? null : () => _vitrinIslemi('activate'),
                icon: const Icon(Icons.visibility),
                label: const Text('Gizlenen ilanları vitrine al'),
              ),
              if (_busy == 'vitrin') const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 24),

          // GÜNCEL PİYASA
          Text('Güncel Piyasa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          _buildStats(cardColor, textColor, subColor),
          const SizedBox(height: 24),

          // KAPSAM
          Text('Veri Kapsamı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 4),
          Text('Her marka/model/yıl aralığı için hedef sayıda güncel emsal ilan var mı?',
              style: TextStyle(fontSize: 12, color: subColor)),
          const SizedBox(height: 8),
          _buildCoverage(cardColor, textColor, subColor),
        ],
      ),
    );
  }

  Widget _buildScraperCard(String source, Color cardColor, Color textColor, Color? subColor) {
    final s = _map(_status[source]);
    final state = s['status']?.toString() ?? 'unknown';
    final runningNow = state == 'running';
    final busy = _busy == source || _busy == 'all';
    final (label, color) = switch (state) {
      'running' => ('Çalışıyor', Colors.green),
      'idle' => ('Durdu', Colors.grey),
      _ => ('Bilinmiyor', Colors.orange),
    };
    final lastActivity = s['last_activity']?.toString();

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.travel_explore, color: runningNow ? Colors.green : Colors.grey, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_sourceLabels[source] ?? source,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                        backgroundColor: color.withValues(alpha: 0.12),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                      ),
                      if (lastActivity != null && lastActivity.isNotEmpty && lastActivity != '-')
                        Text('Son aktivite: $lastActivity', style: TextStyle(fontSize: 12, color: subColor)),
                    ],
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            else if (runningNow)
              OutlinedButton.icon(
                onPressed: _busy != null ? null : () => _run('stop', source),
                icon: const Icon(Icons.stop, color: Colors.redAccent),
                label: const Text('Durdur'),
              )
            else
              FilledButton.icon(
                onPressed: _busy != null ? null : () => _run('start', source),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Başlat'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(Color cardColor, Color textColor, Color? subColor) {
    int i(String k) => (_stats[k] as num?)?.toInt() ?? 0;
    final bySource = _map(_stats['by_source']);
    final tiles = <(String, String, IconData)>[
      ('Toplam ilan', '${i('total_listings')}', Icons.directions_car),
      ('Analiz edilen', '${i('analyzed_listings')}', Icons.psychology),
      ('Son 24 saatte eklenen', '${i('daily_new_listings')}', Icons.fiber_new),
      ('Alım fırsatı', '${i('buy_opportunities')}', Icons.trending_up),
      ('Ortalama fiyat', _tl((_stats['avg_price'] as num?) ?? 0), Icons.payments),
    ];

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: tiles
                  .map((t) => SizedBox(
                        width: 150,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(t.$3, color: Colors.teal),
                            const SizedBox(height: 6),
                            Text(t.$2, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                            Text(t.$1, style: TextStyle(fontSize: 12, color: subColor)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            if (bySource.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Kaynaklara göre', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 6),
              ...bySource.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: Text(_sourceLabels[e.key] ?? e.key, style: TextStyle(color: subColor))),
                        Text('${e.value} ilan', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCoverage(Color cardColor, Color textColor, Color? subColor) {
    if (_coverageError != null) {
      return Text('Kapsam bilgisi alınamadı: $_coverageError', style: const TextStyle(color: Colors.redAccent));
    }
    if (_coverage.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    }
    int i(String k) => (_coverage[k] as num?)?.toInt() ?? 0;
    final rows = (_coverage['coverage'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((r) => r['coverage_status'] != 'healthy')
        .toList()
      ..sort((a, b) {
        final p = ((a['priority'] as num?) ?? 99).compareTo((b['priority'] as num?) ?? 99);
        return p != 0 ? p : ((b['missing_count'] as num?) ?? 0).compareTo((a['missing_count'] as num?) ?? 0);
      });

    final chips = <(String, int, Color)>[
      ('Yeterli', i('healthy'), Colors.green),
      ('Eksik', i('underfilled'), Colors.orange),
      ('Dengesiz', i('filled_imbalanced'), Colors.blue),
      ('Eski veri', i('stale'), Colors.red),
    ];

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips
                  .map((c) => Chip(
                        label: Text('${c.$1}: ${c.$2}', style: TextStyle(color: c.$3, fontWeight: FontWeight.w600)),
                        backgroundColor: c.$3.withValues(alpha: 0.12),
                        side: BorderSide.none,
                      ))
                  .toList(),
            ),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Öncelikli eksikler', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
              ...rows.take(10).map((r) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${r['brand']} ${r['model']} (${r['year_bucket']})', style: TextStyle(color: textColor)),
                    subtitle: Text('${r['active_count'] ?? 0}/${r['target_count'] ?? 0} güncel ilan',
                        style: TextStyle(color: subColor)),
                    trailing: Text('${r['missing_count'] ?? 0} eksik',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
