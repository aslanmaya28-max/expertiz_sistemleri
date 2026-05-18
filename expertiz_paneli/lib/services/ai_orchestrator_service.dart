/// AI ORCHESTRATOR SERVICE
/// 
/// FAZ-3.0 / S2 — AI Analysis Pipeline
/// 
/// ⚖️ LEGAL STANDARD:
/// This service orchestrates AI analysis with forensic-grade integrity.
/// All results are evidence-grade and stored in the immutable ledger.
/// 
/// 🎯 PURPOSE:
/// - Queue reports for AI analysis
/// - Execute AI pipeline with timeout handling
/// - Retry failed analyses (up to 3 times)
/// - Store results in canonical format
/// - Transition status: draft → pending_ai → pending_admin
/// 
/// 🪨 PRINCIPLE:
/// "AI analysis is automated verification, not replacement of human judgment."
/// 
/// ⚠️ CRITICAL:
/// - AI cannot override admin decisions
/// - Timeout: 10 seconds
/// - Retry: Up to 3 times
/// - Manual review flag if AI fails
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report_status.dart';
import '../models/ai_analysis_result.dart';
import 'status_transition_service.dart';
import 'vision_engine_service.dart';

/// AI Orchestrator Service
/// 
/// Central authority for AI analysis pipeline.
/// This service ensures:
/// - All analyses are queued and tracked
/// - Timeout handling prevents hanging
/// - Retry logic handles transient failures
/// - Results are stored in canonical format
/// - Manual review flag for failures
class AIOrchestratorService {
  final SupabaseClient _supabase;
  final StatusTransitionService _statusService;
  final VisionEngineService _visionEngine;

  /// Timeout for AI analysis (default: 10 seconds)
  final Duration analysisTimeout;

  /// Maximum retry attempts (default: 3)
  final int maxRetries;

  /// Currently processing reports
  final Set<String> _processingReports = {};

  AIOrchestratorService({
    required SupabaseClient supabase,
    required StatusTransitionService statusService,
    required VisionEngineService visionEngine,
    this.analysisTimeout = const Duration(seconds: 10),
    this.maxRetries = 3,
  })  : _supabase = supabase,
        _statusService = statusService,
        _visionEngine = visionEngine;

  /// Process AI analysis queue
  /// 
  /// Automatically processes all reports in pending_ai status.
  /// This should be called periodically or triggered by new submissions.
  Future<void> processQueue() async {
    try {
      debugPrint('🔄 Processing AI analysis queue...');

      // Get all pending_ai reports
      final reports = await _statusService.getReportsByStatus(
        status: ReportStatus.pendingAi,
        limit: 100,
      );

      debugPrint('📊 Found ${reports.length} reports pending AI analysis');

      // Process each report
      for (final report in reports) {
        final reportId = report['id'] as String;
        
        // Skip if already processing
        if (_processingReports.contains(reportId)) {
          debugPrint('⏭️ Report $reportId already being processed');
          continue;
        }

        // Add to processing set
        _processingReports.add(reportId);

        // Process report
        try {
          await analyzeReport(reportId: reportId);
        } catch (e) {
          debugPrint('❌ Error processing report $reportId: $e');
        } finally {
          // Remove from processing set
          _processingReports.remove(reportId);
        }
      }

      debugPrint('✅ AI analysis queue processing complete');
    } catch (e) {
      debugPrint('❌ Failed to process AI queue: $e');
    }
  }

  /// Analyze single report
  /// 
  /// Executes AI analysis with timeout and retry logic.
  /// Transitions status: pending_ai → pending_admin (or pending_admin with timeout note)
  Future<void> analyzeReport({
    required String reportId,
    int retryCount = 0,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🤖 Analyzing report $reportId (attempt ${retryCount + 1}/$maxRetries)...');

      // Fetch report data
      final report = await _fetchReportData(reportId);
      if (report == null) {
        throw Exception('Report not found: $reportId');
      }

      // Execute AI analysis with timeout
      final analysisResult = await _executeAnalysisWithTimeout(
        reportId: reportId,
        reportData: report,
      );

      // Store AI analysis result and transition status
      final result = await _statusService.completeAIAnalysis(
        reportId: reportId,
        analysisResult: analysisResult,
      );

      if (!result.success) {
        throw Exception(result.error ?? 'Failed to complete AI analysis');
      }

      stopwatch.stop();
      debugPrint(
        '✅ AI analysis complete for $reportId '
        '(${stopwatch.elapsedMilliseconds}ms, '
        'reliability: ${analysisResult.reliabilityScore}%)'
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ AI analysis failed for $reportId: $e');

      // Retry if attempts remain
      if (retryCount < maxRetries) {
        debugPrint('🔄 Retrying report $reportId in 2 seconds...');
        await Future.delayed(const Duration(seconds: 2));
        await analyzeReport(reportId: reportId, retryCount: retryCount + 1);
      } else {
        // Max retries reached, mark for manual review
        debugPrint('⚠️ Max retries reached for $reportId, marking for manual review');
        await _markForManualReview(reportId);
      }
    }
  }

  /// Fetch report data for AI analysis
  Future<Map<String, dynamic>?> _fetchReportData(String reportId) async {
    try {
      final response = await _supabase
          .from('reports')
          .select()
          .eq('id', reportId)
          .single();

      return response as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('❌ Failed to fetch report data: $e');
      return null;
    }
  }

  /// Execute AI analysis with timeout
  Future<AIAnalysisResult> _executeAnalysisWithTimeout({
    required String reportId,
    required Map<String, dynamic> reportData,
  }) async {
    try {
      // Create timeout future
      final timeoutFuture = Future.delayed(analysisTimeout).then((_) {
        throw TimeoutException(
          'AI analysis timed out after ${analysisTimeout.inSeconds}s',
          analysisTimeout,
        );
      });

      // Create analysis future
      final analysisFuture = _visionEngine.analyzeReport(reportData);

      // Race between analysis and timeout
      final AIAnalysisResult result = await Future.any([
        analysisFuture,
        timeoutFuture.then((_) => AIAnalysisResult.timeout(
          modelVersion: 'gemini-1.5-flash',
          timeoutMs: analysisTimeout.inMilliseconds,
        )),
      ]);

      return result;
    } catch (e) {
      if (e is TimeoutException) {
        debugPrint('⏱️ AI analysis timed out');
        return AIAnalysisResult.timeout(
          modelVersion: 'gemini-1.5-flash',
          timeoutMs: analysisTimeout.inMilliseconds,
          message: e.message?.toString() ?? 'Analysis timed out',
        );
      } else {
        debugPrint('❌ AI analysis error: $e');
        return AIAnalysisResult.error(
          errorMessage: e.toString(),
          modelVersion: 'gemini-1.5-flash',
        );
      }
    }
  }

  /// Mark report for manual review
  /// 
  /// Called when AI analysis fails or times out after max retries.
  /// Still transitions to pending_admin but with timeout/error note.
  Future<void> _markForManualReview(String reportId) async {
    try {
      final timeoutResult = AIAnalysisResult.timeout(
        modelVersion: 'gemini-1.5-flash',
        timeoutMs: analysisTimeout.inMilliseconds,
        message: 'AI analysis failed after $maxRetries attempts - Manual review required',
      );

      await _statusService.completeAIAnalysis(
        reportId: reportId,
        analysisResult: timeoutResult,
      );

      debugPrint('✅ Report $reportId marked for manual review');
    } catch (e) {
      debugPrint('❌ Failed to mark for manual review: $e');
      // Last resort: Force transition without AI result
      await _statusService.completeAIAnalysis(
        reportId: reportId,
        analysisResult: AIAnalysisResult(
          reliabilityScore: 0.0,
          observation: 'Manual review required - AI unavailable',
          assumption: 'N/A',
          limitation: 'AI service unavailable',
          inconsistencies: [],
          missingInfo: ['AI analysis incomplete'],
          confidenceScore: 0.0,
          modelVersion: 'manual',
          analyzedAt: DateTime.now().toUtc(),
          processingDurationMs: 0,
          timedOut: true,
        ),
      );
    }
  }

  /// Subscribe to pending_ai queue
  /// 
  /// Returns realtime stream of reports awaiting AI analysis.
  Stream<List<Map<String, dynamic>>>? subscribeToPendingQueue() {
    return _statusService.subscribeToStatusQueue(
      status: ReportStatus.pendingAi,
    );
  }

  /// Get analysis statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final pendingCount = await _statusService.getReportsByStatus(
        status: ReportStatus.pendingAi,
        limit: 1000,
      ).then((reports) => reports.length);

      final processingCount = _processingReports.length;

      return {
        'pending_count': pendingCount,
        'processing_count': processingCount,
        'total_in_queue': pendingCount + processingCount,
        'max_retries': maxRetries,
        'timeout_seconds': analysisTimeout.inSeconds,
      };
    } catch (e) {
      debugPrint('❌ Failed to get AI statistics: $e');
      return {};
    }
  }

  /// Cancel analysis for a report
  /// 
  /// Removes report from processing set.
  /// Useful for manual intervention.
  void cancelAnalysis(String reportId) {
    _processingReports.remove(reportId);
    debugPrint('🚫 Analysis cancelled for report $reportId');
  }

  /// Is report currently being processed?
  bool isProcessing(String reportId) {
    return _processingReports.contains(reportId);
  }

  /// Get currently processing reports
  List<String> getProcessingReports() {
    return _processingReports.toList();
  }

  /// Clear processing set
  /// 
  /// Useful for cleanup or recovery.
  void clearProcessingSet() {
    final count = _processingReports.length;
    _processingReports.clear();
    debugPrint('🧹 Cleared processing set ($count reports)');
  }
}