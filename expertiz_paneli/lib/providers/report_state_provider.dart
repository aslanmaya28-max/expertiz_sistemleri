/// REPORT STATE PROVIDER
/// 
/// PHASE 6.3 - Enterprise Hardening
/// 
/// 🎯 PURPOSE:
/// Provides a single source of truth for report state across all panels.
/// Ensures data consistency with version control, conflict resolution,
/// and comprehensive audit logging.
/// 
/// 🪨 PRINCIPLE:
/// "Enterprise-grade state management with conflict detection and rollback."
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dashboard_stats.dart';
import '../models/user_model.dart';
import '../services/audit_service.dart';
import '../models/audit_action.dart';

// =====================================================
// REPORT STATE CLASS
// =====================================================

/// Immutable state container for report management.
/// All mutations produce a new instance.
class ReportState {
  final List<Map<String, dynamic>> reports;
  final DashboardStats? stats;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdate;
  final Set<String> selectedReportIds;
  final List<Map<String, dynamic>> offlineQueue;

  /// 🔒 DÜZELTİLDİ (B15): reports tablosunda 'customer_id' kolonu mevcut değil.
  /// Gerçek kolon: 'user_id'. Müşteri dashboard'ı bu kolon üzerinden filtreleme yapar.
  /// DÜZELTİLDİ (B14): reports tablosunda 'marka, model, yil' kolonları mevcut değil.
  /// Bu veriler vehicles tablosunda. JOIN ile alınır veya data->>'marka' JSONB yoluyla.
  /// DÜZELTİLDİ (B14): reports tablosunda 'personnel_id' kolonu mevcut değil.
  /// Bunun yerine reports.user_id (atanan personel) veya data->>'personnel_id' JSONB kullanılır.

  const ReportState({
    this.reports = const [],
    this.stats,
    this.isLoading = false,
    this.error,
    this.lastUpdate,
    this.selectedReportIds = const {},
    this.offlineQueue = const [],
  });

  ReportState copyWith({
    List<Map<String, dynamic>>? reports,
    DashboardStats? stats,
    bool? isLoading,
    String? error,
    DateTime? lastUpdate,
    Set<String>? selectedReportIds,
    List<Map<String, dynamic>>? offlineQueue,
    bool clearError = false,
  }) {
    return ReportState(
      reports: reports ?? this.reports,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastUpdate: lastUpdate ?? this.lastUpdate,
      selectedReportIds: selectedReportIds ?? this.selectedReportIds,
      offlineQueue: offlineQueue ?? this.offlineQueue,
    );
  }

  /// Create snapshot for rollback
  ReportState snapshot() {
    return ReportState(
      reports: List<Map<String, dynamic>>.from(reports.map((r) => Map<String, dynamic>.from(r))),
      stats: stats,
      isLoading: isLoading,
      error: error,
      lastUpdate: lastUpdate,
      selectedReportIds: Set<String>.from(selectedReportIds),
      offlineQueue: List<Map<String, dynamic>>.from(offlineQueue.map((q) => Map<String, dynamic>.from(q))),
    );
  }
}

// =====================================================
// REPORT NOTIFIER
// =====================================================

/// Central report state notifier with comprehensive error handling.
class ReportNotifier extends StateNotifier<ReportState> {
  final SupabaseClient _supabase;
  final AuditService _auditService;

  /// 🔒 DÜZELTİLDİ: Report listesini sakla ve rollback için kullan
  ReportState? _snapshot;

  ReportNotifier(this._supabase, this._auditService) : super(const ReportState());

  // =====================================================
  // PUBLIC API
  // =====================================================

  /// Fetch all reports from Supabase
  Future<void> fetchReports({Map<String, dynamic>? filters}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      // 🔒 DÜZELTİLDİ (B15): user_id kolonu kullanılır.
      // reports tablosunda 'customer_id' YOK, 'user_id' VAR.
      // Eğer müşteri rolünde kullanıcı sadece kendi raporlarını görür.
      final currentUser = _supabase.auth.currentUser;
      String? userId;
      bool isCustomer = false;
      
      if (currentUser != null) {
        userId = currentUser.id;
        // Check if user is customer from their profile
        try {
          final profile = await _supabase
              .from('profiles')
              .select('rol')
              .eq('id', userId)
              .maybeSingle();
          isCustomer = profile?['rol'] == 'customer';
        } catch (_) {}
      }
      
      var query = _supabase
          .from('reports')
          .select('''
            *,
            vehicles!inner (
              marka,
              model,
              yil
            )
          ''');

      // 🔒 DÜZELTİLDİ (B15): Müşteriler sadece kendi raporlarını görür
      if (isCustomer && userId != null) {
        query = query.eq('user_id', userId);
      }

      // Apply additional filters
      if (filters != null) {
        if (filters.containsKey('status')) {
          query = query.eq('status', filters['status']);
        }
        if (filters.containsKey('user_id')) {
          query = query.eq('user_id', filters['user_id']);
        }
      }

      query = query.order('created_at', ascending: false);

      final response = await query;
      final reports = (response as List<dynamic>)
          .map((r) => r as Map<String, dynamic>)
          .toList();

      state = state.copyWith(
        reports: reports,
        isLoading: false,
        lastUpdate: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Error fetching reports: $e');
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  /// Fetch dashboard statistics
  Future<void> fetchStats() async {
    try {
      final totalReports = await _supabase
          .from('reports')
          .select('id', const FetchOptions(count: CountOption.exact));

      final publishedReports = await _supabase
          .from('reports')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('status', 'published');

      final pendingReports = await _supabase
          .from('reports')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('status', 'pending_admin');

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();

      final todayReports = await _supabase
          .from('reports')
          .select('id', const FetchOptions(count: CountOption.exact))
          .gte('created_at', startOfDay);

      state = state.copyWith(
        stats: DashboardStats(
          totalReports: totalReports.count ?? 0,
          publishedReports: publishedReports.count ?? 0,
          pendingReports: pendingReports.count ?? 0,
          todayReports: todayReports.count ?? 0,
          lastUpdate: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error fetching stats: $e');
    }
  }

  /// Subscribe to realtime updates
  void subscribeToUpdates() {
    final channel = _supabase.channel('reports_changes');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'reports',
      callback: (payload) {
        debugPrint('📡 Realtime update received: ${payload.eventType}');
        fetchReports();
        fetchStats();
      },
    );
    channel.subscribe();
  }

  /// Get a single report by ID
  Future<Map<String, dynamic>?> getReportById(String reportId) async {
    try {
      final response = await _supabase
          .from('reports')
          .select('''
            *,
            vehicles!inner (
              marka,
              model,
              yil
            )
          ''')
          .eq('id', reportId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('❌ Error fetching report $reportId: $e');
      return null;
    }
  }

  // =====================================================
  // CRUD OPERATIONS
  // =====================================================

  /// Create a new report
  Future<String?> createReport(Map<String, dynamic> reportData) async {
    try {
      _snapshot = state.snapshot();
      
      // 🔒 DÜZELTİLDİ (B15): customer_id yerine user_id kullan
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        state = state.copyWith(error: 'Kullanıcı oturumu bulunamadı');
        return null;
      }

      // Ensure user_id is set
      final data = Map<String, dynamic>.from(reportData);
      data['user_id'] = currentUser.id;
      
      // Remove any customer_id key if present
      data.remove('customer_id');
      
      final response = await _supabase
          .from('reports')
          .insert(data)
          .select()
          .single();
      
      state = state.copyWith(
        reports: [response, ...state.reports],
        lastUpdate: DateTime.now(),
      );
      
      return response['id'] as String?;
    } catch (e) {
      debugPrint('❌ Error creating report: $e');
      if (_snapshot != null) {
        state = _snapshot!;
      }
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Update a report
  Future<bool> updateReport(String reportId, Map<String, dynamic> updates) async {
    try {
      _snapshot = state.snapshot();
      
      // 🔒 DÜZELTİLDİ (B15): customer_id'yi kaldır
      updates.remove('customer_id');
      
      final response = await _supabase
          .from('reports')
          .update(updates)
          .eq('id', reportId)
          .select()
          .single();
      
      state = state.copyWith(
        reports: state.reports.map((r) {
          if (r['id'] == reportId) {
            return response;
          }
          return r;
        }).toList(),
        lastUpdate: DateTime.now(),
      );
      
      return true;
    } catch (e) {
      debugPrint('❌ Error updating report $reportId: $e');
      if (_snapshot != null) {
        state = _snapshot!;
      }
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Seal report (change workflow status)
  Future<bool> sealReport(String reportId, String newStatus) async {
    try {
      _snapshot = state.snapshot();
      
      final currentReport = state.reports.firstWhere(
        (r) => r['id'] == reportId,
      );
      final currentVersion = currentReport['version_id'] as int? ?? 0;
      final currentUser = _supabase.auth.currentUser;
      
      final response = await _supabase
          .from('reports')
          .update({
            'status': newStatus,
            'status_updated_at': DateTime.now().toUtc().toIso8601String(),
            'version_id': currentVersion + 1,
          })
          .eq('id', reportId)
          .eq('version_id', currentVersion) // Ensure no conflict
          .select();
      
      if (response.isEmpty) {
        throw Exception('Failed to seal report or version conflict');
      }
      
      // Audit log
      if (currentUser != null) {
        await _auditService.logReportApproved(
          user: currentUser,
          reportId: reportId,
          oldValue: currentReport,
          newValue: response.first,
        );
      }
      
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      debugPrint('❌ Seal report error: $e');
      if (_snapshot != null) {
        state = _snapshot!;
      }
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      return false;
    }
  }

  /// Submit report for AI analysis
  Future<bool> submitForAiAnalysis(String reportId) async {
    return sealReport(reportId, 'pending_ai');
  }

  /// Approve report (publish)
  Future<bool> approveReport(String reportId) async {
    return sealReport(reportId, 'published');
  }

  /// Reject report
  Future<bool> rejectReport(String reportId) async {
    return sealReport(reportId, 'rejected');
  }

  /// Draft report
  Future<bool> draftReport(String reportId) async {
    return sealReport(reportId, 'draft');
  }

  /// Delete a report
  Future<bool> deleteReport(String reportId) async {
    try {
      _snapshot = state.snapshot();
      
      await _supabase
          .from('reports')
          .delete()
          .eq('id', reportId);
      
      state = state.copyWith(
        reports: state.reports.where((r) => r['id'] != reportId).toList(),
        lastUpdate: DateTime.now(),
      );
      
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting report $reportId: $e');
      if (_snapshot != null) {
        state = _snapshot!;
      }
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // =====================================================
  // STATUS WORKFLOW HELPERS
  // =====================================================

  /// Get reports by status
  List<Map<String, dynamic>> getReportsByStatus(String status) {
    return state.reports.where((r) => r['status'] == status).toList();
  }

  /// Get pending reports
  List<Map<String, dynamic>> get pendingReports => getReportsByStatus('pending_admin');

  /// Get published reports
  List<Map<String, dynamic>> get publishedReports => getReportsByStatus('published');

  /// Get draft reports
  List<Map<String, dynamic>> get draftReports => getReportsByStatus('draft');

  // =====================================================
  // OFFLINE SUPPORT
  // =====================================================

  /// Queue an operation for offline execution
  void queueOfflineOperation(Map<String, dynamic> operation) {
    state = state.copyWith(
      offlineQueue: [...state.offlineQueue, operation],
    );
  }

  /// Process offline queue
  Future<void> processOfflineQueue() async {
    final queue = List<Map<String, dynamic>>.from(state.offlineQueue);
    state = state.copyWith(offlineQueue: []);
    
    for (final operation in queue) {
      try {
        switch (operation['action'] as String) {
          case 'create':
            await createReport(operation['data'] as Map<String, dynamic>);
            break;
          case 'update':
            await updateReport(
              operation['reportId'] as String,
              operation['data'] as Map<String, dynamic>,
            );
            break;
          case 'delete':
            await deleteReport(operation['reportId'] as String);
            break;
        }
      } catch (e) {
        debugPrint('❌ Error processing offline operation: $e');
        // Re-queue failed operations
        state = state.copyWith(
          offlineQueue: [...state.offlineQueue, operation],
        );
      }
    }
  }

  // =====================================================
  // PRIVATE HELPER METHODS
  // =====================================================

  /// 🔒 DÜZELTİLDİ (B14): 'arac_bilgileri' tablosu mevcut değil. Gerçek şema: 'vehicles' kullanılıyor.
  Future<int> _getTotalVehicles() async {
    try {
      final response = await _supabase.from('vehicles').select('id');
      return response.length;
    } catch (e) {
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
      return 0;
    }
  }

  /// 🔒 DÜZELTİLDİ (B14): 'users' tablosu mevcut değil. Gerçek şema: 'profiles' kullanılıyor.
  /// 🔒 DÜZELTİLDİ (B6): 'role' kolonu mevcut değil. Gerçek kolon: 'rol'.
  /// 🔒 DÜZELTİLDİ (B6): 'personnel' rol değeri mevcut değil. Gerçek değer: 'field_staff'.
  Future<int> _getPersonnelCount() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('rol', 'field_staff');
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  /// 🔒 DÜZELTİLDİ (B14): 'users' tablosu mevcut değil. Gerçek şema: 'profiles' kullanılıyor.
  /// 🔒 DÜZELTİLDİ (B6): 'role' kolonu mevcut değil. Gerçek kolon: 'rol'.
  Future<int> _getCustomerCount() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('rol', 'customer');
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getTotalReportsCount() async {
    try {
      final response = await _supabase.from('reports').select('id');
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  // =====================================================
  // REPORT TRANSFORMATION HELPERS
  // =====================================================

  /// 🔒 DÜZELTİLDİ (B14): reports tablosunda 'marka, model, yil' kolonları yok.
  /// Bu veriler data->>'marka' veya JOIN ile vehicles'dan gelir.
  /// Örnek kullanım:
  ///   final brand = report['vehicles']?['marka'] ?? report['data']?['marka'] ?? '';
  ///   final model = report['vehicles']?['model'] ?? report['data']?['model'] ?? '';
  ///   final year = report['vehicles']?['yil'] ?? report['data']?['yil'] ?? 0;

  /// 🔒 DÜZELTİLDİ (B14): reports tablosunda 'personnel_id' kolonu mevcut değil.
  /// Bunun yerine reports.user_id (atanan personelin ID'si) kullanılır.
  /// Eğer personel verisi gerekiyorsa profiles tablosundan JOIN ile alınır.
  /// Örnek kullanım:
  ///   final personnelId = report['data']?['personnel_id'] ?? report['user_id'];
  /// NOT: Yukarıdaki örnek JSONB data içinde varsa çalışır. Yoksa user_id kullanılır.

  /// 🔒 DÜZELTİLDİ (B14): 'ai_analysis_result' kolonu reports tablosunda mevcut değil.
  /// Gerçek kolon: 'ai_analiz_detay' (JSONB tipinde).
  /// Örnek kullanım:
  ///   final aiResult = report['ai_analiz_detay'];
  ///   final piyasaDegeri = aiResult?['piyasa_degeri'];
  ///   final yorum = aiResult?['yorum'];
}
