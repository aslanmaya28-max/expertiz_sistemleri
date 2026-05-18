/// AUDIT SERVICE - Merkezi Audit Logging Servisi
/// 
/// Tüm kritik işlemlerin kaydını tutar
/// Non-blocking: Loglama başarısız olsa bile ana işlem devam eder
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/audit_log.dart';
import '../models/audit_action.dart';
import '../models/user_model.dart';

/// Audit Service
/// 
/// Tüm kritik işlemlerde audit log kaydı atar
class AuditService {
  final SupabaseClient _supabase;

  AuditService({required SupabaseClient supabase})
      : _supabase = supabase;

  // =====================================================
  // LOG METHODS
  // =====================================================

  /// Log an action
  /// 
  /// Non-blocking: Başarısız olsa bile ana işlem devam eder
  /// Ancak debugPrint ile uyarı verir
  Future<void> log({
    required UserModel user,
    required AuditAction action,
    required String entityType,
    String? entityId,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    Map<String, dynamic>? metadata,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      debugPrint('📝 Audit log: ${action.displayName} - $entityType ${entityId ?? ''}');

      final auditLog = {
        'user_id': user.id,
        'user_email': user.email,
        'user_name': user.fullName,
        'action': action.toDatabaseValue,
        'entity_type': entityType,
        'entity_id': entityId,
        'old_value': oldValue,
        'new_value': newValue,
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'metadata': metadata,
      };

      await _supabase.from('audit_logs').insert(auditLog);

      debugPrint('✅ Audit log kaydedildi');
    } catch (e) {
      // Non-blocking: Hata olsa bile ana işlem devam eder
      debugPrint('⚠️ Audit log hatası (non-blocking): $e');
      
      // Critical actions için ekstra log
      if (_isCriticalAction(action)) {
        debugPrint('🚨 KRİTİK AUDIT LOG HATASI: ${action.displayName}');
        debugPrint('📋 Kullanıcı: ${user.fullName} (${user.email})');
        debugPrint('🎯 Entity: $entityType ${entityId ?? ''}');
      }
    }
  }

  /// Log report created
  Future<void> logReportCreated({
    required UserModel user,
    required String reportId,
    required Map<String, dynamic> reportData,
  }) async {
    await log(
      user: user,
      action: AuditAction.reportCreated,
      entityType: 'report',
      entityId: reportId,
      newValue: reportData,
    );
  }

  /// Log report updated
  Future<void> logReportUpdated({
    required UserModel user,
    required String reportId,
    Map<String, dynamic>? oldValue,
    required Map<String, dynamic> newValue,
  }) async {
    await log(
      user: user,
      action: AuditAction.reportUpdated,
      entityType: 'report',
      entityId: reportId,
      oldValue: oldValue,
      newValue: newValue,
    );
  }

  /// Log report deleted
  Future<void> logReportDeleted({
    required UserModel user,
    required String reportId,
    Map<String, dynamic>? oldValue,
  }) async {
    await log(
      user: user,
      action: AuditAction.reportDeleted,
      entityType: 'report',
      entityId: reportId,
      oldValue: oldValue,
      metadata: {'critical': true},
    );
  }

  /// Log report approved
  Future<void> logReportApproved({
    required UserModel user,
    required String reportId,
    Map<String, dynamic>? oldValue,
    required Map<String, dynamic> newValue,
  }) async {
    await log(
      user: user,
      action: AuditAction.reportApproved,
      entityType: 'report',
      entityId: reportId,
      oldValue: oldValue,
      newValue: newValue,
      metadata: {'critical': true},
    );
  }

  /// Log report rejected
  Future<void> logReportRejected({
    required UserModel user,
    required String reportId,
    required String reason,
  }) async {
    await log(
      user: user,
      action: AuditAction.reportRejected,
      entityType: 'report',
      entityId: reportId,
      metadata: {'reason': reason},
    );
  }

  /// Log AI analysis triggered
  Future<void> logAIAnalysisTriggered({
    required UserModel user,
    required String reportId,
  }) async {
    await log(
      user: user,
      action: AuditAction.aiAnalysisTriggered,
      entityType: 'report',
      entityId: reportId,
    );
  }

  /// Log AI analysis completed
  Future<void> logAIAnalysisCompleted({
    required UserModel user,
    required String reportId,
    required Map<String, dynamic> analysisResult,
  }) async {
    await log(
      user: user,
      action: AuditAction.aiAnalysisCompleted,
      entityType: 'report',
      entityId: reportId,
      newValue: analysisResult,
    );
  }

  /// Log AI analysis failed
  Future<void> logAIAnalysisFailed({
    required UserModel user,
    required String reportId,
    required String error,
  }) async {
    await log(
      user: user,
      action: AuditAction.aiAnalysisFailed,
      entityType: 'report',
      entityId: reportId,
      metadata: {'error': error},
    );
  }

  /// Log user login
  Future<void> logUserLogin({
    required UserModel user,
    String? ipAddress,
    String? userAgent,
  }) async {
    await log(
      user: user,
      action: AuditAction.userLogin,
      entityType: 'auth',
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  /// Log user logout
  Future<void> logUserLogout({
    required UserModel user,
  }) async {
    await log(
      user: user,
      action: AuditAction.userLogout,
      entityType: 'auth',
    );
  }

  /// Log login failed
  Future<void> logLoginFailed({
    required String email,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      debugPrint('📝 Audit log: Login failed - $email');

      await _supabase.from('audit_logs').insert({
        'user_id': null, // No user ID for failed login
        'user_email': email,
        'user_name': 'Unknown',
        'action': AuditAction.loginFailed.toDatabaseValue,
        'entity_type': 'auth',
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'metadata': {'failed_attempt': true},
      });

      debugPrint('✅ Audit log kaydedildi');
    } catch (e) {
      debugPrint('⚠️ Audit log hatası (non-blocking): $e');
    }
  }

  /// Log user created
  Future<void> logUserCreated({
    required UserModel adminUser,
    required String createdUserId,
    required String createdUserName,
    required Map<String, dynamic> userData,
  }) async {
    await log(
      user: adminUser,
      action: AuditAction.userCreated,
      entityType: 'user',
      entityId: createdUserId,
      newValue: userData,
      metadata: {'created_user_name': createdUserName},
    );
  }

  /// Log user updated
  Future<void> logUserUpdated({
    required UserModel adminUser,
    required String updatedUserId,
    Map<String, dynamic>? oldValue,
    required Map<String, dynamic> newValue,
  }) async {
    await log(
      user: adminUser,
      action: AuditAction.userUpdated,
      entityType: 'user',
      entityId: updatedUserId,
      oldValue: oldValue,
      newValue: newValue,
    );
  }

  /// Log user deleted
  Future<void> logUserDeleted({
    required UserModel adminUser,
    required String deletedUserId,
    required String deletedUserName,
    Map<String, dynamic>? oldValue,
  }) async {
    await log(
      user: adminUser,
      action: AuditAction.userDeleted,
      entityType: 'user',
      entityId: deletedUserId,
      oldValue: oldValue,
      metadata: {
        'critical': true,
        'deleted_user_name': deletedUserName,
      },
    );
  }

  /// Log user role changed
  Future<void> logUserRoleChanged({
    required UserModel adminUser,
    required String targetUserId,
    required String targetUserName,
    required String oldRole,
    required String newRole,
  }) async {
    await log(
      user: adminUser,
      action: AuditAction.userRoleChanged,
      entityType: 'user',
      entityId: targetUserId,
      oldValue: {'role': oldRole},
      newValue: {'role': newRole},
      metadata: {
        'critical': true,
        'target_user_name': targetUserName,
      },
    );
  }

  /// Log payment received
  Future<void> logPaymentReceived({
    required UserModel user,
    required String paymentId,
    required double amount,
    required Map<String, dynamic> paymentData,
  }) async {
    await log(
      user: user,
      action: AuditAction.paymentReceived,
      entityType: 'payment',
      entityId: paymentId,
      newValue: {
        'amount': amount,
        ...paymentData,
      },
      metadata: {'critical': true},
    );
  }

  /// Log payment refunded
  Future<void> logPaymentRefunded({
    required UserModel adminUser,
    required String paymentId,
    required double amount,
    required String reason,
  }) async {
    await log(
      user: adminUser,
      action: AuditAction.paymentRefunded,
      entityType: 'payment',
      entityId: paymentId,
      newValue: {
        'amount': amount,
        'reason': reason,
      },
      metadata: {'critical': true},
    );
  }

  /// Log invoice created
  Future<void> logInvoiceCreated({
    required UserModel user,
    required String invoiceId,
    required Map<String, dynamic> invoiceData,
  }) async {
    await log(
      user: user,
      action: AuditAction.invoiceCreated,
      entityType: 'invoice',
      entityId: invoiceId,
      newValue: invoiceData,
    );
  }

  /// Log financial report viewed
  Future<void> logFinancialReportViewed({
    required UserModel user,
    required String reportType,
    Map<String, dynamic>? filters,
  }) async {
    await log(
      user: user,
      action: AuditAction.financialReportViewed,
      entityType: 'financial_report',
      metadata: {
        'report_type': reportType,
        'filters': filters,
      },
    );
  }

  // =====================================================
  // QUERY METHODS
  // =====================================================

  /// Get audit logs
  Future<List<AuditLog>> getAuditLogs({
    AuditLogFilter? filter,
    int limit = 50,
    int offset = 0,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      debugPrint('📋 Audit log sorgusu başlatılıyor...');

      // Build Supabase query with proper chain
      PostgrestFilterBuilder query = _supabase.from('audit_logs').select();
      
      // Apply filters after select
      if (filter != null && !filter.isEmpty) {
        final filters = filter.toSupabaseFilter();
        
        if (filters['action'] != null) {
          query = query.eq('action', filters['action']);
        }
        
        if (filters['entity_type'] != null) {
          query = query.eq('entity_type', filters['entity_type']);
        }
        
        if (filters['entity_id'] != null) {
          query = query.eq('entity_id', filters['entity_id']);
        }
        
        if (filters['user_id'] != null) {
          query = query.eq('user_id', filters['user_id']);
        }
      }
      
      // Apply order and range
      final response = await query
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      final logs = response.map((json) => AuditLog.fromJson(json)).toList();

      debugPrint('✅ ${logs.length} audit log bulundu');
      return logs;
    } catch (e) {
      debugPrint('❌ Audit log sorgu hatası: $e');
      return [];
    }
  }

  /// Get audit logs by entity
  Future<List<AuditLog>> getAuditLogsByEntity({
    required String entityType,
    String? entityId,
    int limit = 50,
  }) async {
    return getAuditLogs(
      filter: AuditLogFilter(
        entityType: entityType,
        entityId: entityId,
      ),
      limit: limit,
    );
  }

  /// Get audit logs by user
  Future<List<AuditLog>> getAuditLogsByUser({
    required String userId,
    int limit = 50,
  }) async {
    return getAuditLogs(
      filter: AuditLogFilter(userId: userId),
      limit: limit,
    );
  }

  /// Get recent audit logs
  Future<List<AuditLog>> getRecentAuditLogs({int limit = 20}) async {
    return getAuditLogs(
      limit: limit,
      orderBy: 'created_at',
      ascending: false,
    );
  }

  // =====================================================
  // PRIVATE METHODS
  // =====================================================

  /// Check if action is critical
  bool _isCriticalAction(AuditAction action) {
    return [
      AuditAction.reportDeleted,
      AuditAction.reportApproved,
      AuditAction.userDeleted,
      AuditAction.userRoleChanged,
      AuditAction.paymentRefunded,
      AuditAction.systemSettingChanged,
    ].contains(action);
  }
}

/// Audit Service Extension for convenience
extension AuditServiceExtension on AuditService {
  /// Log generic action
  Future<void> logAction({
    required UserModel user,
    required AuditAction action,
    required String entityType,
    String? entityId,
    Map<String, dynamic>? data,
  }) async {
    await log(
      user: user,
      action: action,
      entityType: entityType,
      entityId: entityId,
      newValue: data,
    );
  }
}