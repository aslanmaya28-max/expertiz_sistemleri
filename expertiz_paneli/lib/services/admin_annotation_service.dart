/// ADMIN ANNOTATION SERVICE
/// 
/// FAZ-6.0 / Step 2 - Smart Annotation System
/// 
/// 🎯 PURPOSE:
/// Admin annotation'ları yöneten, Supabase ile iletişim kuran
/// merkezi servis.
/// 
/// 🪨 PRINCIPLE:
/// "Audit Trail - Hiçbir not silinmez"

library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_annotation.dart';
import 'notification_service.dart';

/// Admin Annotation Service
/// 
/// Provides CRUD operations for admin annotations with automatic
/// audit trail and notification triggers.
class AdminAnnotationService {
  final SupabaseClient _client;
  AdminAnnotationService({
    required SupabaseClient client,
  }) : _client = client;

  /// Get all annotations for a report
  Future<AdminAnnotationList> getAnnotations(String reportId) async {
    try {
      final response = await _client
          .from('reports')
          .select('admin_annotations')
          .eq('id', reportId)
          .single();

      final annotationsJson = response['admin_annotations'] as List<dynamic>? ?? [];
      return AdminAnnotationList.fromJson(annotationsJson);
    } catch (e) {
      return const AdminAnnotationList([]);
    }
  }

  /// Add annotation to report
  Future<AdminAnnotation?> addAnnotation({
    required String reportId,
    required String fieldKey,
    required String fieldLabel,
    required String message,
    required AnnotationType type,
    required String adminId,
    required String adminName,
    AnnotationSeverity severity = AnnotationSeverity.medium,
  }) async {
    try {
      // Call Supabase RPC function
      final response = await _client.rpc('add_admin_annotation', params: {
        'report_uuid': reportId,
        'field_key': fieldKey,
        'field_label': fieldLabel,
        'annotation_type': type.name,
        'message': message,
        'admin_id': adminId,
        'admin_name': adminName,
        'severity': severity.name,
      });

      if (response != null) {
        final annotationData = response['annotation'] as Map<String, dynamic>;
        final annotation = AdminAnnotation.fromJson(annotationData);

        // Send notification to field personnel
        await _notifyFieldPersonnel(
          reportId: reportId,
          annotation: annotation,
        );

        return annotation;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Add multiple annotations at once (batch)
  Future<List<AdminAnnotation>> addBatchAnnotations({
    required String reportId,
    required List<AnnotationData> annotations,
    required String adminId,
    required String adminName,
  }) async {
    final addedAnnotations = <AdminAnnotation>[];

    for (final annotationData in annotations) {
      final annotation = await addAnnotation(
        reportId: reportId,
        fieldKey: annotationData.fieldKey,
        fieldLabel: annotationData.fieldLabel,
        message: annotationData.message,
        type: annotationData.type,
        adminId: adminId,
        adminName: adminName,
        severity: annotationData.severity,
      );

      if (annotation != null) {
        addedAnnotations.add(annotation);
      }
    }

    return addedAnnotations;
  }

  /// Resolve annotation
  Future<bool> resolveAnnotation({
    required String reportId,
    required String annotationId,
  }) async {
    try {
      // Get current annotations
      final currentList = await getAnnotations(reportId);
      
      // Find and resolve the annotation
      final updatedList = currentList.resolveAnnotation(annotationId);
      
      // Update report
      await _client.from('reports').update({
        'admin_annotations': updatedList.toJson(),
      }).eq('id', reportId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear all annotations (use with caution)
  Future<bool> clearAllAnnotations(String reportId) async {
    try {
      await _client.rpc('clear_admin_annotations', params: {
        'report_uuid': reportId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if report has active annotations
  Future<bool> hasActiveAnnotations(String reportId) async {
    final annotations = await getAnnotations(reportId);
    return annotations.hasActiveAnnotations;
  }

  /// Get active annotations for a specific field
  Future<List<AdminAnnotation>> getFieldAnnotations({
    required String reportId,
    required String fieldKey,
  }) async {
    final allAnnotations = await getAnnotations(reportId);
    return allAnnotations.byFieldKey(fieldKey).where((a) => a.isActive).toList();
  }

  /// Get annotation statistics
  Future<AnnotationStats> getStats(String reportId) async {
    final annotations = await getAnnotations(reportId);
    
    return AnnotationStats(
      total: annotations.count,
      active: annotations.activeCount,
      resolved: annotations.resolvedCount,
      errors: annotations.errors.length,
      warnings: annotations.warnings.length,
      infos: annotations.infos.length,
    );
  }

  /// Send notification to field personnel
  Future<void> _notifyFieldPersonnel({
    required String reportId,
    required AdminAnnotation annotation,
  }) async {
    try {
      // Get report details to find personnel ID
      final reportData = await _client
          .from('reports')
          .select('personnel_id, adim1')
          .eq('id', reportId)
          .single();

      final personnelId = reportData['personnel_id'] as String?;
      final plaka = reportData['adim1']?['plaka'] as String? ?? 'Bilinmeyen Araç';

      if (personnelId != null) {
        await NotificationService.sendInAppNotification(
          userId: personnelId,
          type: NotificationType.reportReopened,
          title: 'Yeni Admin Notu',
          message: '${annotation.fieldLabel}: ${annotation.message}',
          reportId: reportId,
          metadata: {
            'annotation_id': annotation.id,
            'plaka': plaka,
          },
        );
      }
    } catch (e) {
      // Managed silently as per request
    }
  }
}

/// Annotation data for batch operations
class AnnotationData {
  final String fieldKey;
  final String fieldLabel;
  final String message;
  final AnnotationType type;
  final AnnotationSeverity severity;

  const AnnotationData({
    required this.fieldKey,
    required this.fieldLabel,
    required this.message,
    required this.type,
    this.severity = AnnotationSeverity.medium,
  });
}

/// Annotation statistics
class AnnotationStats {
  final int total;
  final int active;
  final int resolved;
  final int errors;
  final int warnings;
  final int infos;

  const AnnotationStats({
    required this.total,
    required this.active,
    required this.resolved,
    required this.errors,
    required this.warnings,
    required this.infos,
  });

  @override
  String toString() {
    return 'AnnotationStats(total: $total, active: $active, resolved: $resolved, errors: $errors)';
  }
}