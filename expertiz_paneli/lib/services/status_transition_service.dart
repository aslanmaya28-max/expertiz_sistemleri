/// STATUS TRANSITION SERVICE
/// 
/// FAZ-3.0 / S1 — Workflow Orchestration
/// 
/// ⚖️ LEGAL STANDARD:
/// This service enforces forensic-grade status transitions.
/// All transitions are audited and validated against role-based rules.
/// 
/// 🎯 PURPOSE:
/// - Centralized status transition logic
/// - Role-based authorization
/// - Audit trail logging
/// - Database-level enforcement
/// 
/// 🪨 PRINCIPLE:
/// "Every transition is evidence. Every change is accountable."
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report_status.dart';
import '../models/ai_analysis_result.dart';

/// Status Transition Result
class StatusTransitionResult {
  final bool success;
  final String? error;
  final ReportStatus? newStatus;

  const StatusTransitionResult.success(this.newStatus)
      : success = true,
        error = null;

  const StatusTransitionResult.failure(this.error)
      : success = false,
        newStatus = null;
}

/// Status Transition Service
/// 
/// Central authority for all status transitions in the workflow.
/// This service ensures:
/// - Transitions are validated against role-based rules
/// - All transitions are logged to audit trail
/// - Database-level enforcement via triggers
/// - Unauthorized transitions are blocked
class StatusTransitionService {
  final SupabaseClient _supabase;

  StatusTransitionService(this._supabase);

  /// Submit report for AI analysis
  /// 
  /// Transition: draft → pending_ai
  /// 
  /// Only personnel or admin can submit reports.
  /// This queues the report for AI analysis.
  Future<StatusTransitionResult> submitForAIAnalysis({
    required String reportId,
  }) async {
    try {
      debugPrint('🔄 Submitting report $reportId for AI analysis...');

      final response = await _supabase
          .from('reports')
          .update({
            'status': ReportStatus.pendingAi.value,
          })
          .eq('id', reportId)
          .select('id, status')
          .single();

      debugPrint('✅ Report $reportId submitted for AI analysis');
      return StatusTransitionResult.success(
        ReportStatusParser.fromValue(response['status'] as String),
      );
    } catch (e) {
      debugPrint('❌ Failed to submit for AI analysis: $e');
      return StatusTransitionResult.failure(
        'Failed to submit for AI analysis: ${e.toString()}',
      );
    }
  }

  /// Complete AI analysis
  /// 
  /// Transition: pending_ai → pending_admin
  /// 
  /// Only AI service (service_role) or admin can complete analysis.
  /// This marks the report as ready for admin review.
  Future<StatusTransitionResult> completeAIAnalysis({
    required String reportId,
    required AIAnalysisResult analysisResult,
  }) async {
    try {
      debugPrint('🔄 Completing AI analysis for report $reportId...');

      // Store AI analysis result in report
      final response = await _supabase
          .from('reports')
          .update({
            'status': ReportStatus.pendingAdmin.value,
            'ai_analysis_result': analysisResult.toJson(),
          })
          .eq('id', reportId)
          .select('id, status')
          .single();

      debugPrint('✅ AI analysis completed for report $reportId');
      return StatusTransitionResult.success(
        ReportStatusParser.fromValue(response['status'] as String),
      );
    } catch (e) {
      debugPrint('❌ Failed to complete AI analysis: $e');
      return StatusTransitionResult.failure(
        'Failed to complete AI analysis: ${e.toString()}',
      );
    }
  }

  /// Approve and publish report
  /// 
  /// Transition: pending_admin → published
  /// 
  /// ONLY admin can approve reports.
  /// This is a LEGAL REQUIREMENT for publication.
  Future<StatusTransitionResult> approveAndPublish({
    required String reportId,
  }) async {
    try {
      debugPrint('🔄 Approving and publishing report $reportId...');

      final response = await _supabase
          .from('reports')
          .update({
            'status': ReportStatus.published.value,
          })
          .eq('id', reportId)
          .select('id, status')
          .single();

      debugPrint('✅ Report $reportId approved and published');
      return StatusTransitionResult.success(
        ReportStatusParser.fromValue(response['status'] as String),
      );
    } catch (e) {
      debugPrint('❌ Failed to approve and publish: $e');
      return StatusTransitionResult.failure(
        'Failed to approve and publish: ${e.toString()}',
      );
    }
  }

  /// Reject report
  /// 
  /// Transition: pending_admin → rejected
  /// 
  /// ONLY admin can reject reports.
  /// Requires a rejection reason for personnel to address.
  Future<StatusTransitionResult> reject({
    required String reportId,
    required String rejectionReason,
  }) async {
    try {
      debugPrint('🔄 Rejecting report $reportId...');

      final response = await _supabase
          .from('reports')
          .update({
            'status': ReportStatus.rejected.value,
            'rejection_reason': rejectionReason,
          })
          .eq('id', reportId)
          .select('id, status, rejection_reason')
          .single();

      debugPrint('✅ Report $reportId rejected with reason');
      return StatusTransitionResult.success(
        ReportStatusParser.fromValue(response['status'] as String),
      );
    } catch (e) {
      debugPrint('❌ Failed to reject report: $e');
      return StatusTransitionResult.failure(
        'Failed to reject report: ${e.toString()}',
      );
    }
  }

  /// Reopen rejected report for correction
  /// 
  /// Transition: rejected → draft
  /// 
  /// Only personnel or admin can reopen rejected reports.
  /// This clears the rejection reason and allows resubmission.
  Future<StatusTransitionResult> reopenForCorrection({
    required String reportId,
  }) async {
    try {
      debugPrint('🔄 Reopening report $reportId for correction...');

      final response = await _supabase
          .from('reports')
          .update({
            'status': ReportStatus.draft.value,
            'rejection_reason': null,
          })
          .eq('id', reportId)
          .select('id, status')
          .single();

      debugPrint('✅ Report $reportId reopened for correction');
      return StatusTransitionResult.success(
        ReportStatusParser.fromValue(response['status'] as String),
      );
    } catch (e) {
      debugPrint('❌ Failed to reopen report: $e');
      return StatusTransitionResult.failure(
        'Failed to reopen report: ${e.toString()}',
      );
    }
  }

  /// Get reports by status
  /// 
  /// Retrieves paginated list of reports by status.
  /// Useful for admin review queue and AI processing queue.
  Future<List<Map<String, dynamic>>> getReportsByStatus({
    required ReportStatus status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      debugPrint('🔄 Fetching reports with status: ${status.value}');

      final response = await _supabase
          .from('reports')
          .select()
          .eq('status', status.value)
          .order('status_updated_at', ascending: false)
          .range(offset, offset + limit - 1);

      debugPrint('✅ Retrieved ${response.length} reports');
      return (response as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ Failed to fetch reports by status: $e');
      return [];
    }
  }

  /// Get report status
  /// 
  /// Retrieves current status of a report.
  Future<ReportStatus?> getReportStatus(String reportId) async {
    try {
      final response = await _supabase
          .from('reports')
          .select('status')
          .eq('id', reportId)
          .single();

      final statusValue = response['status'] as String?;
      if (statusValue == null) return null;

      return ReportStatusParser.fromValue(statusValue);
    } catch (e) {
      debugPrint('❌ Failed to get report status: $e');
      return null;
    }
  }

  /// Subscribe to status updates
  /// 
  /// Returns a realtime stream of status updates for a specific report.
  Stream<Map<String, dynamic>>? subscribeToStatusUpdates(String reportId) {
    try {
      return _supabase
          .from('reports')
          .stream(primaryKey: ['id'])
          .eq('id', reportId)
          .map((event) => event.first);
    } catch (e) {
      debugPrint('❌ Failed to subscribe to status updates: $e');
      return null;
    }
  }

  /// Subscribe to status queue
  /// 
  /// Returns a realtime stream of reports with a specific status.
  /// Useful for admin review queue and AI processing queue.
  Stream<List<Map<String, dynamic>>>? subscribeToStatusQueue({
    required ReportStatus status,
  }) {
    try {
      return _supabase
          .from('reports')
          .stream(primaryKey: ['id'])
          .eq('status', status.value)
          .order('status_updated_at', ascending: false);
    } catch (e) {
      debugPrint('❌ Failed to subscribe to status queue: $e');
      return null;
    }
  }
}