/// TASK REASSIGNMENT SERVICE
///
/// FAZ-3.0 / S4 — Personnel Deactivation → Open Task Reassignment
///
/// 🎯 PURPOSE:
/// When a personnel is deactivated (pasife alınma), all their open tasks
/// must be automatically reassigned to available personnel in the same region.
///
/// 🪨 PRINCIPLE:
/// "No task is left orphaned. Every open task has an owner at all times."
///
/// FLOW:
/// 1. Personnel deactivation triggered → PersonelService.deactivatePersonel()
/// 2. This service fetches all open tasks for that personnel
/// 3. Finds available personnel in same region (city/district)
/// 4. Reassigns tasks with load balancing (fewest tasks first)
/// 5. Sends notifications to both old and new assignees
/// 6. Logs all reassignments to audit trail
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/audit_action.dart';
import '../services/audit_service.dart';
import '../services/notification_service.dart';

/// Result of a task reassignment operation
class ReassignmentResult {
  final bool isSuccess;
  final int totalReassigned;
  final int totalFailed;
  final List<String> reassignedTaskIds;
  final List<String> failedTaskIds;
  final String? error;

  const ReassignmentResult({
    required this.isSuccess,
    this.totalReassigned = 0,
    this.totalFailed = 0,
    this.reassignedTaskIds = const [],
    this.failedTaskIds = const [],
    this.error,
  });

  factory ReassignmentResult.success({
    required int totalReassigned,
    required List<String> reassignedTaskIds,
    int totalFailed = 0,
    List<String> failedTaskIds = const [],
  }) {
    return ReassignmentResult(
      isSuccess: true,
      totalReassigned: totalReassigned,
      totalFailed: totalFailed,
      reassignedTaskIds: reassignedTaskIds,
      failedTaskIds: failedTaskIds,
    );
  }

  factory ReassignmentResult.failure(String error) {
    return ReassignmentResult(isSuccess: false, error: error);
  }
}

/// Task Reassignment Service
///
/// SINGLE SOURCE OF TRUTH for all task reassignment operations.
/// Works exclusively with Supabase — no local state, no SharedPreferences.
class TaskReassignmentService {
  final SupabaseClient _supabase;
  final AuditService _auditService;

  TaskReassignmentService({
    required SupabaseClient supabase,
    AuditService? auditService,
  }) : _supabase = supabase,
       _auditService = auditService ?? AuditService(supabase: supabase);

  /// =====================================================
  // MAIN ENTRY POINT
  // =====================================================

  /// Reassign all open tasks from deactivated personnel
  ///
  /// Called automatically when a personnel is deactivated.
  /// Returns detailed reassignment result.
  Future<ReassignmentResult> reassignOpenTasks({
    required String deactivatedPersonelId,
    required String deactivatedPersonelName,
    String? reason,
    String? triggeredByUserId,
  }) async {
    try {
      debugPrint('🔄 Task reassignment başlatılıyor: $deactivatedPersonelId');

      // 1. Fetch all open tasks for this personnel
      final openTasks = await _fetchOpenTasks(deactivatedPersonelId);
      if (openTasks.isEmpty) {
        debugPrint('✅ Açık görev yok, yeniden atama gerekmiyor');
        return ReassignmentResult.success(
          totalReassigned: 0,
          reassignedTaskIds: [],
        );
      }

      debugPrint('📋 ${openTasks.length} açık görev bulundu');

      // 2. Get deactivated personnel's region info
      final personelProfile = await _fetchPersonelProfile(deactivatedPersonelId);
      if (personelProfile == null) {
        return ReassignmentResult.failure(
          'Personel profili bulunamadı: $deactivatedPersonelId',
        );
      }

      // 3. Find available personnel in same region
      final availablePersonnel = await _findAvailablePersonnel(
        ilId: personelProfile.ilId,
        excludePersonelId: deactivatedPersonelId,
      );

      if (availablePersonnel.isEmpty) {
        // No available personnel in region — escalate to admin
        await _escalateToAdmin(
          deactivatedPersonelId: deactivatedPersonelId,
          deactivatedPersonelName: deactivatedPersonelName,
          taskCount: openTasks.length,
          taskIds: openTasks.map((t) => t['id'] as String).toList(),
          reason: reason,
        );

        return ReassignmentResult.failure(
          'Bölgede uygun personel bulunamadı. Görevler admin\'e iletildi.',
        );
      }

      // 4. Load balance: assign tasks to personnel with fewest current tasks
      final assignments = await _loadBalanceAssign(
        tasks: openTasks,
        availablePersonnel: availablePersonnel,
      );

      // 5. Execute reassignments
      final reassignedIds = <String>[];
      final failedIds = <String>[];

      for (final assignment in assignments) {
        try {
          await _reassignTask(
            taskId: assignment['taskId'] as String,
            fromPersonelId: deactivatedPersonelId,
            toPersonelId: assignment['toPersonelId'] as String,
            toPersonelName: assignment['toPersonelName'] as String,
            reason: reason,
          );
          reassignedIds.add(assignment['taskId'] as String);
        } catch (e) {
          debugPrint('❌ Görev yeniden atama hatası: ${assignment['taskId']}: $e');
          failedIds.add(assignment['taskId'] as String);
        }
      }

      // 6. Send notifications
      await _sendReassignmentNotifications(
        deactivatedPersonelId: deactivatedPersonelId,
        deactivatedPersonelName: deactivatedPersonelName,
        reassignments: assignments,
        reason: reason,
      );

      // 7. Audit log
      await _auditService.log(
        user: personelProfile,
        action: AuditAction.userUpdated,
        entityType: 'personnel',
        entityId: deactivatedPersonelId,
        metadata: {
          'event': 'task_reassignment',
          'reassigned_count': reassignedIds.length,
          'failed_count': failedIds.length,
          'reason': reason ?? 'Personel pasife alındı',
          'triggered_by': triggeredByUserId,
        },
      );

      debugPrint(
        '✅ Task reassignment tamamlandı: '
        '${reassignedIds.length} başarılı, ${failedIds.length} başarısız',
      );

      return ReassignmentResult.success(
        totalReassigned: reassignedIds.length,
        reassignedTaskIds: reassignedIds,
        totalFailed: failedIds.length,
        failedTaskIds: failedIds,
      );
    } catch (e) {
      debugPrint('❌ Task reassignment hatası: $e');
      return ReassignmentResult.failure(e.toString());
    }
  }

  // =====================================================
  // PRIVATE METHODS
  // =====================================================

  /// Fetch all open (non-completed) tasks for a personnel
  Future<List<Map<String, dynamic>>> _fetchOpenTasks(String personelId) async {
    try {
      final response = await _supabase
          .from('reports')
          .select('id, plaka, marka, model, status, data')
          .eq('data->personel_id', personelId)
          .not('status', 'in', '("published","rejected","cancelled")');

      return response.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Açık görevler alınırken hata: $e');
      return [];
    }
  }

  /// Fetch personnel profile from profiles table
  Future<UserModel?> _fetchPersonelProfile(String personelId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', personelId)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      debugPrint('Personel profili alınırken hata: $e');
      return null;
    }
  }

  /// Find available personnel in the same region
  Future<List<Map<String, dynamic>>> _findAvailablePersonnel({
    required int? ilId,
    required String excludePersonelId,
  }) async {
    try {
      // Find active personnel in same city, excluding the deactivated one
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, il_id, completed_task_count')
          .eq('role', 'field_staff')
          .eq('is_active', true)
          .eq('il_id', ilId ?? 0)
          .neq('id', excludePersonelId);

      return response.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Uygun personel bulunurken hata: $e');
      return [];
    }
  }

  /// Load balance: assign tasks to personnel with fewest current tasks
  Future<List<Map<String, dynamic>>> _loadBalanceAssign({
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> availablePersonnel,
  }) async {
    final assignments = <Map<String, dynamic>>[];

    // Get current task counts for each available personnel
    final taskCounts = <String, int>{};
    for (final personel in availablePersonnel) {
      final personelId = personel['id'] as String;
      final count = await _getOpenTaskCount(personelId);
      taskCounts[personelId] = count;
    }

    // Sort personnel by current task count (ascending)
    availablePersonnel.sort((a, b) {
      final countA = taskCounts[a['id'] as String] ?? 0;
      final countB = taskCounts[b['id'] as String] ?? 0;
      return countA.compareTo(countB);
    });

    // Assign tasks round-robin to least loaded personnel
    int personelIndex = 0;
    for (final task in tasks) {
      final personel = availablePersonnel[personelIndex % availablePersonnel.length];
      assignments.add({
        'taskId': task['id'] as String,
        'toPersonelId': personel['id'] as String,
        'toPersonelName': personel['full_name'] as String,
      });
      personelIndex++;
    }

    return assignments;
  }

  /// Get count of open tasks for a personnel
  Future<int> _getOpenTaskCount(String personelId) async {
    try {
      final response = await _supabase
          .from('reports')
          .select('id')
          .eq('data->personel_id', personelId)
          .not('status', 'in', '("published","rejected","cancelled")');

      return response.length;
    } catch (e) {
      return 0;
    }
  }

  /// Execute single task reassignment
  Future<void> _reassignTask({
    required String taskId,
    required String fromPersonelId,
    required String toPersonelId,
    required String toPersonelName,
    String? reason,
  }) async {
    // Update the report's data->personel_id and data->assigned_personel_id
    // Also update status to indicate reassignment
    await _supabase
        .from('reports')
        .update({
          'data': {
            'personel_id': toPersonelId,
            'assigned_personel_id': toPersonelId,
            'assigned_personel_name': toPersonelName,
            'previous_personel_id': fromPersonelId,
            'reassignment_reason': reason ?? 'Personel pasife alındı',
            'reassigned_at': DateTime.now().toIso8601String(),
          },
          'status_updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', taskId);

    debugPrint('✅ Görev yeniden atandı: $taskId → $toPersonelName');
  }

  /// Escalate to admin when no available personnel found
  Future<void> _escalateToAdmin({
    required String deactivatedPersonelId,
    required String deactivatedPersonelName,
    required int taskCount,
    required List<String> taskIds,
    String? reason,
  }) async {
    // Get all admin user IDs
    final admins = await _supabase
        .from('profiles')
        .select('id')
        .eq('role', 'admin')
        .eq('is_active', true);

    final adminIds = admins.map((a) => a['id'] as String).toList();

    if (adminIds.isEmpty) {
      debugPrint('⚠️ Hiç aktif admin bulunamadı! Görevler sahipsiz kaldı.');
      return;
    }

    // Send notification to all admins
    await NotificationService.sendInAppNotification(
      userId: adminIds.first, // Send to first admin
      type: NotificationType.pendingReview,
      title: '🚨 Personel Pasif — Görevler Sahipsiz',
      message: '$deactivatedPersonelName pasife alındı. '
          'Bölgede uygun personel bulunamadı. '
          '$taskCount görev manuel atama bekliyor.',
      priority: NotificationPriority.urgent,
      metadata: {
        'deactivated_personel_id': deactivatedPersonelId,
        'task_count': taskCount,
        'task_ids': taskIds,
        'reason': reason,
        'type': 'reassignment_escalation',
      },
    );

    debugPrint('📢 Admin\'e bildirim gönderildi: $taskCount görev bekliyor');
  }

  /// Send notifications about reassignments
  Future<void> _sendReassignmentNotifications({
    required String deactivatedPersonelId,
    required String deactivatedPersonelName,
    required List<Map<String, dynamic>> reassignments,
    String? reason,
  }) async {
    // Group assignments by personnel
    final grouped = <String, List<String>>{};
    final personelNames = <String, String>{};
    for (final assignment in reassignments) {
      final personelId = assignment['toPersonelId'] as String;
      final personelName = assignment['toPersonelName'] as String;
      final taskId = assignment['taskId'] as String;
      grouped.putIfAbsent(personelId, () => []);
      grouped[personelId]!.add(taskId);
      personelNames[personelId] = personelName;
    }

    // Send notification to each reassigned personnel
    for (final entry in grouped.entries) {
      await NotificationService.sendInAppNotification(
        userId: entry.key,
        type: NotificationType.reportSubmitted,
        title: '📋 Yeni Görev Ataması',
        message: '$deactivatedPersonelName pasife alındığı için '
            'size ${entry.value.length} yeni görev atandı.',
        priority: NotificationPriority.high,
        metadata: {
          'task_ids': entry.value,
          'from_personel': deactivatedPersonelName,
          'reason': reason ?? 'Personel pasife alındı',
          'type': 'reassignment',
        },
      );
    }
  }
}

