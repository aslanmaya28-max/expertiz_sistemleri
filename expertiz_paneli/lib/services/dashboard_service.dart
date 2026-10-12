/// DASHBOARD SERVICE
///
/// Admin ana ekranı (Dashboard sekmesi) verileri. Önceden doğrudan Supabase'den
/// okunuyordu; artık merkezi API'nin tek uç noktasından gelir:
/// `GET /expertiz/admin/dashboard` (sayaçlar, durum dağılımı, son işlemler,
/// onay bekleyenler, yayın trendi, AI güven trendi, personel teslim süreleri).
///
/// Ekranın her yenilemesinde tüm bölümler aynı yanıtı paylaşır (tek istek).
/// Canlı güncelleme Supabase Realtime yerine periyodik yenilemeyle yapılır.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chart_data.dart';
import '../models/dashboard_stats.dart';
import 'yerimebak_expertiz_api_service.dart';

class DashboardService {
  DashboardService({YerimebakExpertizApiService? api, this.refreshInterval = const Duration(seconds: 30)})
      : _api = api ?? YerimebakExpertizApiService();

  final YerimebakExpertizApiService _api;
  final Duration refreshInterval;

  Future<Map<String, dynamic>>? _inFlight;
  DateTime? _fetchedAt;
  int? _lastPendingCount;

  /// Aynı yenileme turundaki çağrılar tek isteği paylaşır.
  Future<Map<String, dynamic>> _data() {
    final fresh = _fetchedAt != null && DateTime.now().difference(_fetchedAt!) < const Duration(seconds: 3);
    if (_inFlight != null && fresh) return _inFlight!;
    _fetchedAt = DateTime.now();
    _inFlight = _api.getAdminDashboard();
    _inFlight!.catchError((_) {
      _fetchedAt = null; // hata: bir sonraki çağrı yeniden denesin
      return <String, dynamic>{};
    });
    return _inFlight!;
  }

  static int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
  static double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;
  static Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  static List<Map<String, dynamic>> _rows(dynamic v) =>
      (v as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Future<DashboardStats> getStats() async {
    final s = _map((await _data())['stats']);
    return DashboardStats(
      totalVehicles: _int(s['total_vehicles']),
      activeReports: _int(s['active_reports']),
      personnelCount: _int(s['personnel_count']),
      customerCount: _int(s['customer_count']),
      totalReports: _int(s['total_reports']),
      todayPublished: _int(s['today_published']),
      todaySubmitted: _int(s['today_submitted']),
    );
  }

  Future<StatusDistribution> getStatusDistribution() async {
    try {
      final d = _map((await _data())['status_distribution']);
      return StatusDistribution(
        draft: _int(d['draft']),
        pendingAi: _int(d['pending_ai']),
        pendingAdmin: _int(d['pending_admin']),
        published: _int(d['published']),
        rejected: _int(d['rejected']),
      );
    } catch (e) {
      debugPrint('Durum dağılımı alınamadı: $e');
      return StatusDistribution.empty();
    }
  }

  Future<List<RecentActivity>> getRecentActivities({int limit = 5}) async {
    try {
      return _rows((await _data())['recent_activities'])
          .take(limit)
          .map((a) => RecentActivity.fromMap({
                ...a,
                'id': '${a['id'] ?? ''}',
                'title': '${a['title'] ?? 'Sistem işlemi'}',
                'description': '${a['description'] ?? ''}',
              }))
          .toList();
    } catch (e) {
      debugPrint('Son işlemler alınamadı: $e');
      return [];
    }
  }

  /// Onay bekleyen raporlar; AI güven skoru düşük olanlar önce.
  Future<List<Map<String, dynamic>>> getPendingAdminReports({int limit = 5}) async {
    try {
      return _rows((await _data())['pending_admin']).take(limit).map((r) {
        final ai = _map(r['ai_analysis_result']);
        return {...r, 'ai_analysis_result': {'reliability_score': _double(ai['reliability_score'])}};
      }).toList();
    } catch (e) {
      debugPrint('Onay bekleyenler alınamadı: $e');
      return [];
    }
  }

  static ChartData _point(String isoDate, double value, Map<String, dynamic> meta) {
    final date = DateTime.tryParse(isoDate) ?? DateTime.now();
    return ChartData(x: date, y: value, label: '${date.day}/${date.month}', metadata: {...meta, 'date': isoDate});
  }

  /// Son 7 günde yayınlanan rapor sayıları.
  Future<List<ChartData>> getWeeklyTrend() async {
    try {
      return _rows((await _data())['weekly_published'])
          .map((p) => _point('${p['date']}', _double(p['count']), {'count': _int(p['count'])}))
          .toList();
    } catch (e) {
      debugPrint('Haftalık trend alınamadı: $e');
      return [];
    }
  }

  /// Son 7 günün ortalama AI güven skoru (piyasa verisi yeterliliği, 0-100).
  Future<List<ChartData>> getAIReliabilityTrend() async {
    try {
      return _rows((await _data())['ai_confidence_trend'])
          .map((p) => _point('${p['date']}', _double(p['avg']), {'reliability': _double(p['avg']), 'count': _int(p['count'])}))
          .toList();
    } catch (e) {
      debugPrint('AI güven trendi alınamadı: $e');
      return [];
    }
  }

  static const _statusLabels = {
    'draft': 'Saha / Atama',
    'pending_ai': 'AI Bekliyor',
    'pending_admin': 'Onay Bekliyor',
    'published': 'Yayınlandı',
    'rejected': 'Düzeltmede',
    'cancelled': 'İptal',
  };
  static const _statusColors = {
    'draft': 0xFF808080,
    'pending_ai': 0xFF4169E1,
    'pending_admin': 0xFFFFD700,
    'published': 0xFF228B22,
    'rejected': 0xFFDC143C,
    'cancelled': 0xFF5A5A5A,
  };

  Future<List<ChartData>> getStatusDistributionData() async {
    try {
      final d = _map((await _data())['status_distribution']);
      return [
        for (final entry in d.entries)
          if (_int(entry.value) > 0)
            ChartData(
              x: DateTime.now(),
              y: _double(entry.value),
              label: _statusLabels[entry.key] ?? entry.key,
              metadata: {'status': entry.key, 'count': _int(entry.value), 'color': _statusColors[entry.key] ?? 0xFF808080},
            ),
      ];
    } catch (e) {
      debugPrint('Durum grafiği alınamadı: $e');
      return [];
    }
  }

  /// Personel başına atamadan yayına ortalama süre (saat).
  Future<List<ChartData>> getPersonnelSLA() async {
    try {
      return _rows((await _data())['personnel_sla']).map((p) {
        final hours = _double(p['avg_hours']);
        return ChartData(
          x: DateTime.now(),
          y: hours,
          label: '${p['personnel_name'] ?? '-'}',
          metadata: {
            'personnel_id': p['personnel_id'],
            'avg_hours': hours,
            'report_count': _int(p['report_count']),
            'exceeded_sla': hours > 48.0,
          },
        );
      }).toList();
    } catch (e) {
      debugPrint('Personel süreleri alınamadı: $e');
      return [];
    }
  }

  /// Periyodik yenileme. Onay bekleyen sayısı artınca `newStatus: pending_admin`
  /// olayı gönderilir (ekran uyarı gösterir). Dinleyici iptal edince durur.
  Stream<DashboardUpdateEvent> subscribeToDashboardUpdates() {
    Timer? timer;
    late final StreamController<DashboardUpdateEvent> controller;
    Future<void> tick() async {
      try {
        _fetchedAt = null;
        final data = await _data();
        final pending = _int(_map(data['status_distribution'])['pending_admin']);
        final increased = _lastPendingCount != null && pending > _lastPendingCount!;
        _lastPendingCount = pending;
        if (!controller.isClosed) {
          controller.add(DashboardUpdateEvent(
            type: DashboardUpdateType.update,
            newStatus: increased ? 'pending_admin' : null,
            timestamp: DateTime.now(),
          ));
        }
      } catch (e) {
        debugPrint('Dashboard yenileme hatası: $e');
      }
    }

    controller = StreamController<DashboardUpdateEvent>(
      onListen: () => timer = Timer.periodic(refreshInterval, (_) => tick()),
      onCancel: () => timer?.cancel(),
    );
    return controller.stream;
  }

  void dispose() {}
}

/// Dashboard güncelleme olayı.
class DashboardUpdateEvent {
  final DashboardUpdateType type;
  final String? newStatus;
  final String? oldStatus;
  final String? reportId;
  final DateTime timestamp;

  DashboardUpdateEvent({
    required this.type,
    this.newStatus,
    this.oldStatus,
    this.reportId,
    required this.timestamp,
  });

  @override
  String toString() => 'DashboardUpdateEvent($type, report: $reportId, $oldStatus → $newStatus)';
}

enum DashboardUpdateType {
  insert,
  update,
  delete,
  unknown,
}
