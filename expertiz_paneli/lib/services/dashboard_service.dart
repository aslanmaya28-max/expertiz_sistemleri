/// DASHBOARD SERVICE
/// 
/// FAZ-4.0 / Phase 4 - Real-time Dashboard Data Service
/// 
/// 🎯 PURPOSE:
/// Central service for fetching dashboard statistics and metrics.
/// Provides real-time updates via Supabase streams.
/// 
/// 🪨 PRINCIPLE:
/// "Event-driven refresh prevents unnecessary database queries."
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dashboard_stats.dart';
import '../models/chart_data.dart';

/// Dashboard Service
/// 
/// Central authority for dashboard data fetching and real-time updates.
class DashboardService {
  final SupabaseClient _supabase;

  /// Stream controller for dashboard updates
  final StreamController<DashboardUpdateEvent> _updateController =
      StreamController<DashboardUpdateEvent>.broadcast();

  /// Realtime subscription
  RealtimeChannel? _reportsChannel;

  DashboardService(this._supabase);

  /// Get dashboard statistics
  /// 
  /// Fetches core metrics in parallel using Future.wait for optimal performance.
  Future<DashboardStats> getStats() async {
    try {
      debugPrint('📊 Fetching dashboard stats...');

      final results = await Future.wait([
        _getTotalVehicles(),
        _getActiveReportsCount(),
        _getPersonnelCount(),
        _getCustomerCount(),
        _getTotalReportsCount(),
        _getTodayPublishedCount(),
        _getTodaySubmittedCount(),
      ]);

      final stats = DashboardStats(
        totalVehicles: results[0],
        activeReports: results[1],
        personnelCount: results[2],
        customerCount: results[3],
        totalReports: results[4],
        todayPublished: results[5],
        todaySubmitted: results[6],
      );

      debugPrint('✅ Dashboard stats loaded: $stats');
      return stats;
    } catch (e) {
      debugPrint('❌ Failed to fetch dashboard stats: $e');
      rethrow;
    }
  }

  /// Get status distribution
  /// 
  /// Groups reports by status and returns counts for each status.
  Future<StatusDistribution> getStatusDistribution() async {
    try {
      debugPrint('📊 Fetching status distribution...');

      final response = await _supabase
          .from('reports')
          .select('status')
          .order('created_at', ascending: false);

      final reports = response as List<dynamic>;
      final distribution = {
        'draft': 0,
        'pending_ai': 0,
        'pending_admin': 0,
        'published': 0,
        'rejected': 0,
      };

      for (final report in reports) {
        final status = (report as Map<String, dynamic>)['status'] as String?;
        if (status != null && distribution.containsKey(status)) {
          distribution[status] = (distribution[status] ?? 0) + 1;
        }
      }

      final result = StatusDistribution(
        draft: distribution['draft'] ?? 0,
        pendingAi: distribution['pending_ai'] ?? 0,
        pendingAdmin: distribution['pending_admin'] ?? 0,
        published: distribution['published'] ?? 0,
        rejected: distribution['rejected'] ?? 0,
      );

      debugPrint('✅ Status distribution loaded: $result');
      return result;
    } catch (e) {
      debugPrint('❌ Failed to fetch status distribution: $e');
      return StatusDistribution.empty();
    }
  }

  /// Get recent activities
  /// 
  /// Returns the last 5 activities from the audit log.
  Future<List<RecentActivity>> getRecentActivities({int limit = 5}) async {
    try {
      debugPrint('📊 Fetching recent activities...');

      final response = await _supabase
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      final activities = (response as List<dynamic>)
          .map((log) => RecentActivity.fromMap({
                'id': log['id'] as String,
                'type': _mapActionToActivityType(log['action'] as String?),
                'title': _getActivityTitle(log['action'] as String?),
                'description': log['details']?['description'] as String? ??
                    'Sistem işlemi',
                'user_id': log['user_id'] as String?,
                'user_name': log['user_name'] as String?,
                'report_id': log['report_id'] as String?,
                'timestamp': log['created_at'] as String? ?? DateTime.now().toIso8601String(),
              }))
          .toList();

      debugPrint('✅ Recent activities loaded: ${activities.length} items');
      return activities;
    } catch (e) {
      debugPrint('❌ Failed to fetch recent activities: $e');
      return [];
    }
  }

  /// Get pending admin reports
  /// 
  /// Returns reports waiting for admin approval with their AI reliability scores.
  /// 
  /// 🎯 PRIORITY SORTING (FAZ-6.0):
  /// 1. AI Reliability Score < 80 → HIGH priority (top of list)
  /// 2. High severity annotations → HIGH priority
  /// 3. AI Reliability Score < 95 → MEDIUM priority
  /// 4. AI Reliability Score >= 95 → LOW priority
  Future<List<Map<String, dynamic>>> getPendingAdminReports({int limit = 5}) async {
    try {
      debugPrint('📊 Fetching pending admin reports with priority sorting...');

      final response = await _supabase
          .from('reports')
          .select('''
            id,
            plaka,
            status,
            status_updated_at,
            ai_analysis_result,
            admin_annotations
          ''')
          .eq('status', 'pending_admin')
          .order('status_updated_at', ascending: false)
          .limit(limit * 2); // Fetch more to account for priority filtering

      // Apply priority sorting
      final prioritizedReports = _prioritizeReports(response);
      
      // Apply limit after sorting
      final result = prioritizedReports.take(limit).toList();

      debugPrint('✅ Pending admin reports loaded: ${result.length} items (prioritized)');
      return result;
    } catch (e) {
      debugPrint('❌ Failed to fetch pending admin reports: $e');
      return [];
    }
  }

  /// Prioritize reports based on AI score and annotations
  /// 
  /// Priority Levels:
  /// - HIGH: AI score < 80 OR has critical issues OR has pending annotations
  /// - MEDIUM: AI score < 95
  /// - LOW: AI score >= 95, no issues
  List<Map<String, dynamic>> _prioritizeReports(List<Map<String, dynamic>> reports) {
    return reports..sort((a, b) {
      final priorityA = _getReportPriority(a);
      final priorityB = _getReportPriority(b);
      
      // Higher priority (lower enum value) comes first
      if (priorityA != priorityB) {
        return priorityA.index.compareTo(priorityB.index);
      }
      
      // If same priority, sort by AI score (lower score = higher priority)
      final scoreA = _getAIScore(a);
      final scoreB = _getAIScore(b);
      
      if (scoreA != scoreB) {
        return scoreA.compareTo(scoreB);
      }
      
      // If same score, sort by time (newer = higher priority)
      final timeA = DateTime.parse(a['status_updated_at'] as String? ?? DateTime.now().toIso8601String());
      final timeB = DateTime.parse(b['status_updated_at'] as String? ?? DateTime.now().toIso8601String());
      
      return timeB.compareTo(timeA); // Descending time
    });
  }

  /// Get report priority level
  _ReportPriority _getReportPriority(Map<String, dynamic> report) {
    final aiScore = _getAIScore(report);
    final annotations = report['admin_annotations'] as List?;
    final aiAnalysis = report['ai_analysis_result'] as Map<String, dynamic>?;
    
    // Check for critical issues
    final reliabilityScore = aiAnalysis?['reliability_score'] as num?;
    final hasCriticalIssues = aiAnalysis?['timed_out'] == true ||
        (reliabilityScore != null && reliabilityScore.toDouble() < 60);
    
    // Check for pending annotations
    final hasPendingAnnotations = annotations?.any((a) => 
        (a as Map<String, dynamic>)['status'] == 'pending') ?? false;

    // HIGH priority: Critical issues
    if (hasCriticalIssues) {
      return _ReportPriority.high;
    }
    
    // HIGH priority: AI score < 80
    if (aiScore < 80) {
      return _ReportPriority.high;
    }
    
    // HIGH priority: Has pending annotations
    if (hasPendingAnnotations) {
      return _ReportPriority.high;
    }
    
    // MEDIUM priority: AI score < 95
    if (aiScore < 95) {
      return _ReportPriority.medium;
    }
    
    // LOW priority: AI score >= 95, no issues
    return _ReportPriority.low;
  }

  /// Extract AI reliability score from report
  double _getAIScore(Map<String, dynamic> report) {
    final aiAnalysis = report['ai_analysis_result'] as Map<String, dynamic>?;
    if (aiAnalysis != null) {
      return (aiAnalysis['reliability_score'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  /// Subscribe to dashboard updates
  /// 
  /// Listens to real-time changes in the reports table and emits update events.
  /// Event-driven refresh - only updates when data actually changes.
  Stream<DashboardUpdateEvent> subscribeToDashboardUpdates() {
    if (_reportsChannel == null) {
      _setupRealtimeSubscription();
    }

    return _updateController.stream;
  }

  /// Setup Supabase Realtime subscription
  void _setupRealtimeSubscription() {
    try {
      _reportsChannel = _supabase.channel('public:reports');

      _reportsChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'reports',
        callback: (payload) {
          _handleRealtimeEvent(payload);
        },
      );

      _reportsChannel!.subscribe();
      debugPrint('✅ Dashboard realtime subscription active');
    } catch (e) {
      debugPrint('❌ Failed to setup realtime subscription: $e');
    }
  }

  /// Handle realtime events
  void _handleRealtimeEvent(PostgresChangePayload payload) {
    try {
      final eventType = payload.eventType;
      final newRecord = payload.newRecord as Map<String, dynamic>?;
      final oldRecord = payload.oldRecord as Map<String, dynamic>?;

      final event = DashboardUpdateEvent(
        type: _mapEventType(eventType.toString().split('.').last),
        newStatus: newRecord?['status'] as String?,
        oldStatus: oldRecord?['status'] as String?,
        reportId: newRecord?['id'] as String? ?? oldRecord?['id'] as String?,
        timestamp: DateTime.now(),
      );

      // Emit update event
      if (!_updateController.isClosed) {
        _updateController.add(event);
      }

      // Log for debugging
      debugPrint('📡 Dashboard update: ${event.type} - Report: ${event.reportId}');

      // Haptic feedback for pending admin status
      if (event.newStatus == 'pending_admin') {
        // Note: Haptic feedback should be called from UI layer
        debugPrint('🔔 Pending admin status detected - Notify admin');
      }
    } catch (e) {
      debugPrint('❌ Error handling realtime event: $e');
    }
  }

  /// Map Supabase event type to DashboardUpdateType
  DashboardUpdateType _mapEventType(String? eventType) {
    switch (eventType) {
      case 'INSERT':
        return DashboardUpdateType.insert;
      case 'UPDATE':
        return DashboardUpdateType.update;
      case 'DELETE':
        return DashboardUpdateType.delete;
      default:
        return DashboardUpdateType.unknown;
    }
  }

  /// Map audit action to activity type
  String _mapActionToActivityType(String? action) {
    switch (action) {
      case 'report_created':
        return 'reportCreated';
      case 'status_changed':
        return 'statusChanged';
      case 'ai_analysis_complete':
        return 'aiAnalysisComplete';
      case 'report_published':
        return 'reportPublished';
      case 'report_rejected':
        return 'reportRejected';
      case 'report_approved':
        return 'reportApproved';
      case 'user_created':
        return 'userCreated';
      default:
        return 'other';
    }
  }

  /// Get activity title from action
  String _getActivityTitle(String? action) {
    switch (action) {
      case 'report_created':
        return 'Yeni Rapor Oluşturuldu';
      case 'status_changed':
        return 'Rapor Durumu Değişti';
      case 'ai_analysis_complete':
        return 'AI Analizi Tamamlandı';
      case 'report_published':
        return 'Rapor Yayınlandı';
      case 'report_rejected':
        return 'Rapor Reddedildi';
      case 'report_approved':
        return 'Rapor Onaylandı';
      case 'user_created':
        return 'Yeni Kullanıcı';
      default:
        return 'Sistem Aktivitesi';
    }
  }

  // =====================================================
  // PRIVATE HELPER METHODS
  // =====================================================

  // 🔒 DÜZELTİLDİ (B14): 'arac_bilgileri' tablosu mevcut değil. Gerçek şema: 'vehicles' kullanılıyor.
  Future<int> _getTotalVehicles() async {
    try {
      final response = await _supabase
          .from('vehicles')
          .select('id');
      return response.length;
    } catch (e) {
      debugPrint('❌ Error fetching vehicles count: $e');
      return 0;
    }
  }


  Future<int> _getActiveReportsCount() async {
    try {
      final response = await _supabase
          .from('reports')
          .select('id')
          .neq('status', 'archived');
      return response.length;
    } catch (e) {
      debugPrint('❌ Error fetching reports count: $e');
      return 0;
    }
  }

  // 🔒 DÜZELTİLDİ (B14): 'users' tablosu mevcut değil. Gerçek şema: 'profiles' kullanılıyor.
  Future<int> _getPersonnelCount() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'personnel');
      return response.length;
    } catch (e) {
      debugPrint('❌ Error fetching personnel count: $e');
      return 0;
    }
  }

  // 🔒 DÜZELTİLDİ (B14): 'users' tablosu mevcut değil. Gerçek şema: 'profiles' kullanılıyor.
  Future<int> _getCustomerCount() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'customer');
      return response.length;
    } catch (e) {
      debugPrint('❌ Error fetching customer count: $e');
      return 0;
    }
  }


  Future<int> _getTotalReportsCount() async {
    try {
      final response = await _supabase
          .from('reports')
          .select('id');
      return response.length;
    } catch (e) {
      debugPrint('❌ Error fetching total reports: $e');
      return 0;
    }
  }

  Future<int> _getTodayPublishedCount() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();

      final response = await _supabase
          .from('reports')
          .select('id')
          .eq('status', 'published')
          .gte('status_updated_at', startOfDay)
          .lte('status_updated_at', endOfDay);
      return response.length;
    } catch (e) {
      debugPrint('❌ Error fetching today published: $e');
      return 0;
    }
  }

  Future<int> _getTodaySubmittedCount() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();

      final response = await _supabase
          .from('reports')
          .select('id')
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay);
      return response.length;
    } catch (e) {
      debugPrint('❌ Error fetching today submitted: $e');
      return 0;
    }
  }

  /// Get weekly trend data
  /// 
  /// Returns last 7 days' approved report counts for line chart visualization.
  Future<List<ChartData>> getWeeklyTrend() async {
    try {
      debugPrint('📊 Fetching weekly trend...');

      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      final response = await _supabase
          .from('reports')
          .select('created_at, status')
          .gte('created_at', sevenDaysAgo.toIso8601String())
          .eq('status', 'published')
          .order('created_at', ascending: true);

      final reports = response as List<dynamic>;
      
      // Group by day
      final dailyCounts = <String, int>{};
      for (final report in reports) {
        final date = (report as Map<String, dynamic>)['created_at'] as String;
        final day = date.substring(0, 10); // YYYY-MM-DD
        dailyCounts[day] = (dailyCounts[day] ?? 0) + 1;
      }

      // Create chart data for all 7 days (fill missing days with 0)
      final chartData = <ChartData>[];
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final count = dailyCounts[dateStr] ?? 0;
        
        chartData.add(ChartData(
          x: date,
          y: count.toDouble(),
          label: '${date.day}/${date.month}',
          metadata: {'count': count, 'date': dateStr},
        ));
      }

      debugPrint('✅ Weekly trend loaded: ${chartData.length} points');
      return chartData;
    } catch (e) {
      debugPrint('❌ Failed to fetch weekly trend: $e');
      return [];
    }
  }

  /// Get AI reliability trend
  /// 
  /// Returns daily AI reliability scores (0-100) for line chart visualization.
  Future<List<ChartData>> getAIReliabilityTrend() async {
    try {
      debugPrint('📊 Fetching AI reliability trend...');

      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      final response = await _supabase
          .from('reports')
          .select('created_at, ai_analysis_result')
          .gte('created_at', sevenDaysAgo.toIso8601String())
          .not('ai_analysis_result', 'is', null)
          .order('created_at', ascending: true);

      final reports = response as List<dynamic>;
      
      // Group by day and calculate average reliability
      final dailyReliability = <String, List<double>>{};
      for (final report in reports) {
        final reportData = report as Map<String, dynamic>;
        final date = reportData['created_at'] as String;
        final day = date.substring(0, 10); // YYYY-MM-DD
        
        final aiResult = reportData['ai_analysis_result'] as Map<String, dynamic>?;
        final reliability = aiResult?['reliability_score'] as double? ?? 0.0;
        
        dailyReliability.putIfAbsent(day, () => []).add(reliability);
      }

      // Calculate daily averages
      final chartData = <ChartData>[];
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        
        final scores = dailyReliability[dateStr];
        final avgReliability = scores != null && scores.isNotEmpty
            ? scores.reduce((a, b) => a + b) / scores.length
            : 0.0;
        
        chartData.add(ChartData(
          x: date,
          y: avgReliability,
          label: '${date.day}/${date.month}',
          metadata: {
            'reliability': avgReliability,
            'count': scores?.length ?? 0,
            'date': dateStr,
          },
        ));
      }

      debugPrint('✅ AI reliability trend loaded: ${chartData.length} points');
      return chartData;
    } catch (e) {
      debugPrint('❌ Failed to fetch AI reliability trend: $e');
      return [];
    }
  }

  /// Get status distribution data
  /// 
  /// Returns pie chart data for report status and rejection reasons.
  Future<List<ChartData>> getStatusDistributionData() async {
    try {
      debugPrint('📊 Fetching status distribution data...');

      final response = await _supabase
          .from('reports')
          .select('status, rejection_reason')
          .order('created_at', ascending: false);

      final reports = response as List<dynamic>;
      
      // Count by status
      final statusCounts = <String, int>{
        'draft': 0,
        'pending_ai': 0,
        'pending_admin': 0,
        'published': 0,
        'rejected': 0,
      };

      // Count rejection reasons
      final rejectionReasons = <String, int>{};

      for (final report in reports) {
        final reportData = report as Map<String, dynamic>;
        final status = reportData['status'] as String? ?? 'draft';
        
        if (statusCounts.containsKey(status)) {
          statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        }

        if (status == 'rejected') {
          final reason = reportData['rejection_reason'] as String? ?? 'Belirtilmemiş';
          rejectionReasons[reason] = (rejectionReasons[reason] ?? 0) + 1;
        }
      }

      // Create chart data for status distribution
      final chartData = <ChartData>[];
      final statusLabels = {
        'draft': 'Taslak',
        'pending_ai': 'AI Bekliyor',
        'pending_admin': 'Onay Bekliyor',
        'published': 'Yayınlandı',
        'rejected': 'Reddedildi',
      };

      final colors = {
        'draft': 0xFF808080, // Grey
        'pending_ai': 0xFF4169E1, // Blue
        'pending_admin': 0xFFFFD700, // Yellow
        'published': 0xFF228B22, // Green
        'rejected': 0xFFDC143C, // Red
      };

      for (final entry in statusCounts.entries) {
        if (entry.value > 0) {
          chartData.add(ChartData(
            x: DateTime.now(),
            y: entry.value.toDouble(),
            label: statusLabels[entry.key] ?? entry.key,
            metadata: {
              'status': entry.key,
              'count': entry.value,
              'color': colors[entry.key] ?? 0xFF808080,
            },
          ));
        }
      }

      debugPrint('✅ Status distribution data loaded: ${chartData.length} points');
      return chartData;
    } catch (e) {
      debugPrint('❌ Failed to fetch status distribution data: $e');
      return [];
    }
  }

  /// Get personnel SLA data
  /// 
  /// Returns personnel performance metrics for bar chart visualization.
  Future<List<ChartData>> getPersonnelSLA() async {
    try {
      debugPrint('📊 Fetching personnel SLA data...');

      final response = await _supabase
          .from('reports')
          .select('created_at, status_updated_at, personnel_id')
          .eq('status', 'published')
          .order('created_at', ascending: false);

      final reports = response as List<dynamic>;
      
      // Calculate average approval time per personnel
      final personnelTimes = <String, List<double>>{};

      for (final report in reports) {
        final reportData = report as Map<String, dynamic>;
        final personnelId = reportData['personnel_id'] as String? ?? 'bilinmeyen';
        
        final createdAt = DateTime.parse(reportData['created_at'] as String);
        final updatedAt = reportData['status_updated_at'] as String?;
        
        if (updatedAt != null) {
          final updated = DateTime.parse(updatedAt);
          final duration = updated.difference(createdAt).inHours.toDouble();
          
          personnelTimes.putIfAbsent(personnelId, () => []).add(duration);
        }
      }

      // Create chart data
      final chartData = <ChartData>[];
      for (final entry in personnelTimes.entries) {
        final times = entry.value;
        final avgTime = times.reduce((a, b) => a + b) / times.length;
        
        chartData.add(ChartData(
          x: DateTime.now(),
          y: avgTime,
          label: entry.key,
          metadata: {
            'personnel_id': entry.key,
            'avg_hours': avgTime,
            'report_count': times.length,
            'exceeded_sla': avgTime > 48.0,
          },
        ));
      }

      // Sort by average time (ascending)
      chartData.sort((a, b) => a.y.compareTo(b.y));

      debugPrint('✅ Personnel SLA data loaded: ${chartData.length} points');
      return chartData;
    } catch (e) {
      debugPrint('❌ Failed to fetch personnel SLA data: $e');
      return [];
    }
  }

  /// Cleanup resources
  void dispose() {
    _reportsChannel?.unsubscribe();
    _updateController.close();
    debugPrint('🧹 DashboardService disposed');
  }
}

/// Dashboard Update Event
/// 
/// Represents a real-time update event from the database.
class DashboardUpdateEvent {
  /// Type of update (insert, update, delete)
  final DashboardUpdateType type;
  
  /// New status (if applicable)
  final String? newStatus;
  
  /// Old status (if applicable)
  final String? oldStatus;
  
  /// Affected report ID
  final String? reportId;
  
  /// Timestamp of event
  final DateTime timestamp;

  DashboardUpdateEvent({
    required this.type,
    this.newStatus,
    this.oldStatus,
    this.reportId,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'DashboardUpdateEvent($type, report: $reportId, $oldStatus → $newStatus)';
  }
}

/// Dashboard Update Type Enum
enum DashboardUpdateType {
  insert,
  update,
  delete,
  unknown,
}

/// Report Priority Level
/// 
/// Used for sorting admin review queue
enum _ReportPriority {
  /// High priority: Needs immediate attention
  high,
  
  /// Medium priority: Review needed but not urgent
  medium,
  
  /// Low priority: Can be reviewed later
  low,
}
