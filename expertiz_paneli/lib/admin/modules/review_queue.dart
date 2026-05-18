/// ADMIN REVIEW CONSOLE
/// 
/// FAZ-3.0 / W1 — Admin Review & Ledger Sealing UI
/// 
/// ⚖️ LEGAL STANDARD:
/// This console enforces forensic-grade admin review before publication.
/// Only admin can approve (seal to ledger) or reject reports.
/// 
/// 🎯 PURPOSE:
/// - Display pending_admin reports for review
/// - Show AI analysis + Personnel data side-by-side
/// - Approve & Seal → LedgerService.writeEvidence()
/// - Reject with Reason → Personnel correction workflow
/// - Real-time updates via Supabase streams
/// 
/// 🪨 PRINCIPLE:
/// "Admin approval is the gateway to legal publication."
/// 
/// ⚠️ CRITICAL:
/// - Only admin role can access this console
/// - Approve triggers immutable ledger write
/// - Reject requires mandatory reason
/// - All actions are audited
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/report_status.dart';
import '../../models/ai_analysis_result.dart';
import '../../services/status_transition_service.dart';
import '../../services/ledger_service.dart';
import '../../widgets/evidence_card.dart';
import '../../core/theme/forensic_theme.dart';

/// Admin Review Queue
/// 
/// Main console for reviewing and approving/rejecting reports.
/// Shows all pending_admin reports with AI analysis and personnel data.
class ReviewQueue extends StatefulWidget {
  const ReviewQueue({super.key});

  @override
  State<ReviewQueue> createState() => _ReviewQueueState();
}

class _ReviewQueueState extends State<ReviewQueue> {
  // =====================================================
  // STATE
  // =====================================================

  /// Pending reports list
  List<Map<String, dynamic>> _pendingReports = [];

  /// Currently selected report
  Map<String, dynamic>? _selectedReport;

  /// Loading state
  bool _isLoading = true;

  /// Processing state
  bool _isProcessing = false;

  /// Stream subscription
  StreamSubscription? _queueSubscription;

  // =====================================================
  // SERVICES
  // =====================================================

  late final StatusTransitionService _statusService;
  late final LedgerService _ledgerService;

  // =====================================================
  // INITIALIZATION
  // =====================================================

  @override
  void initState() {
    super.initState();
    _initServices();
    _loadPendingReports();
    _subscribeToQueue();
  }

  void _initServices() {
    final supabase = Supabase.instance.client;
    _statusService = StatusTransitionService(supabase);
    _ledgerService = LedgerService(supabase);
  }

  // =====================================================
  // DATA LOADING
  // =====================================================

  Future<void> _loadPendingReports() async {
    setState(() => _isLoading = true);

    try {
      final reports = await _statusService.getReportsByStatus(
        status: ReportStatus.pendingAdmin,
        limit: 100,
      );

      if (mounted) {
        setState(() {
          _pendingReports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load pending reports: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showErrorSnackBar('Failed to load reports: $e');
    }
  }

  void _subscribeToQueue() {
    final stream = _statusService.subscribeToStatusQueue(
      status: ReportStatus.pendingAdmin,
    );

    if (stream != null) {
      _queueSubscription = stream.listen((reports) {
        if (mounted) {
          setState(() => _pendingReports = reports);
        }
      });
    }
  }

  // =====================================================
  // ACTIONS: APPROVE & SEAL
  // =====================================================

  Future<void> _approveAndSeal() async {
    if (_selectedReport == null) return;

    final reportId = _selectedReport!['id'] as String;
    final reportData = _selectedReport!;

    setState(() => _isProcessing = true);

    try {
      debugPrint('🔐 Approving and sealing report: $reportId');

      // Step 1: Get AI analysis result
      final aiAnalysisResult = _getAIAnalysisResult(reportData);

      // Step 2: Seal to immutable ledger
      final ledgerId = await _ledgerService.writeEvidence(
        reportId: reportId,
        imageHash: _extractImageHash(reportData),
        reasoning: aiAnalysisResult.toCanonicalReasoning(),
        aiOutput: {
          'reliability_score': aiAnalysisResult.reliabilityScore,
          'confidence_score': aiAnalysisResult.confidenceScore,
          'model_version': aiAnalysisResult.modelVersion,
        },
        modelVersion: aiAnalysisResult.modelVersion,
        confidenceScore: aiAnalysisResult.confidenceScore,
      );

      // Step 3: Transition to published
      final result = await _statusService.approveAndPublish(
        reportId: reportId,
      );

      if (!result.success) {
        throw Exception(result.error ?? 'Failed to publish');
      }

      if (!mounted) return;

      // Success feedback
      HapticFeedback.heavyImpact();
      _showSuccessSnackBar(
        '✅ Report approved and sealed to ledger\n'
        'Ledger ID: ${ledgerId.substring(0, 8)}...'
      );

      // Clear selection and reload
      setState(() {
        _selectedReport = null;
        _isProcessing = false;
      });

      await _loadPendingReports();
    } catch (e) {
      debugPrint('❌ Failed to approve and seal: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
      }
      _showErrorSnackBar('Failed to approve: ${e.toString()}');
    }
  }

  // =====================================================
  // ACTIONS: REJECT
  // =====================================================

  Future<void> _rejectReport() async {
    if (_selectedReport == null) return;

    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => RejectDialog(controller: reasonController),
    );

    if (reason == null || reason.trim().isEmpty) {
      _showErrorSnackBar('Rejection reason is required');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      debugPrint('🚫 Rejecting report: ${_selectedReport!['id']}');

      final result = await _statusService.reject(
        reportId: _selectedReport!['id'] as String,
        rejectionReason: reason.trim(),
      );

      if (!result.success) {
        throw Exception(result.error ?? 'Failed to reject');
      }

      if (!mounted) return;

      HapticFeedback.heavyImpact();
      _showSuccessSnackBar('✅ Report rejected and returned to personnel');

      // Clear selection and reload
      setState(() {
        _selectedReport = null;
        _isProcessing = false;
      });

      await _loadPendingReports();
    } catch (e) {
      debugPrint('❌ Failed to reject: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
      }
      _showErrorSnackBar('Failed to reject: ${e.toString()}');
    }
  }

  // =====================================================
  // HELPERS
  // =====================================================

  AIAnalysisResult _getAIAnalysisResult(Map<String, dynamic> reportData) {
    final analysisData = reportData['ai_analysis_result'] as Map<String, dynamic>?;
    if (analysisData != null) {
      return AIAnalysisResult.fromJson(analysisData);
    }

    // Fallback for reports without AI analysis
    return AIAnalysisResult(
      reliabilityScore: 0.0,
      observation: 'No AI analysis available',
      assumption: 'Manual review required',
      limitation: 'AI analysis was not performed',
      inconsistencies: [],
      missingInfo: ['AI analysis missing'],
      confidenceScore: 0.0,
      modelVersion: 'manual',
      analyzedAt: DateTime.now().toUtc(),
      processingDurationMs: 0,
      timedOut: true,
    );
  }

  String _extractImageHash(Map<String, dynamic> reportData) {
    // Extract image hash from report data
    // This is a placeholder - actual implementation depends on data structure
    final imageData = reportData['image_data'] as Map<String, dynamic>?;
    return imageData?['hash'] as String? ?? 
           '0000000000000000000000000000000000000000000000000000000000000000';
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ForensicTheme.obsidianEmerald,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ForensicTheme.atomicRed,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    _queueSubscription?.cancel();
    super.dispose();
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ForensicTheme.deepSpaceBlue,
      appBar: AppBar(
        title: const Text('Review Queue'),
        backgroundColor: ForensicTheme.deepSpaceBlue,
        elevation: 0,
      ),
      body: Row(
        children: [
          // Report list (left side)
          Expanded(
            flex: 2,
            child: _buildReportList(),
          ),

          const VerticalDivider(width: 1),

          // Report detail (right side)
          Expanded(
            flex: 3,
            child: _buildReportDetail(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingReports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: ForensicTheme.obsidianEmerald),
            const SizedBox(height: 16),
            Text(
              'All caught up!',
              style: TextStyle(fontSize: 18, color: ForensicTheme.textWhite),
            ),
            const SizedBox(height: 8),
            Text(
              'No reports pending review',
              style: TextStyle(fontSize: 14, color: ForensicTheme.textDim),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _pendingReports.length,
      itemBuilder: (context, index) {
        final report = _pendingReports[index];
        final isSelected = _selectedReport?['id'] == report['id'];

        return ReportListTile(
          report: report,
          isSelected: isSelected,
          onTap: () => setState(() => _selectedReport = report),
        );
      },
    );
  }

  Widget _buildReportDetail() {
    if (_selectedReport == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description, size: 64, color: ForensicTheme.textDim),
            const SizedBox(height: 16),
            Text(
              'Select a report to review',
              style: TextStyle(fontSize: 18, color: ForensicTheme.textWhite),
            ),
          ],
        ),
      );
    }

    final aiResult = _getAIAnalysisResult(_selectedReport!);

    return Column(
      children: [
        // Report header
        _buildDetailHeader(),

        // Scrollable content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(ForensicTheme.spaceMd),
            children: [
              // AI Analysis Section
              _buildAIAnalysisSection(aiResult),

              const SizedBox(height: ForensicTheme.spaceMd),

              // Personnel Data Section
              _buildPersonnelDataSection(),

              const SizedBox(height: ForensicTheme.spaceMd),

              // Evidence Card Preview
              _buildEvidenceCardPreview(aiResult),
            ],
          ),
        ),

        // Action bar
        _buildActionBar(aiResult),
      ],
    );
  }

  Widget _buildDetailHeader() {
    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ForensicTheme.textDim.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report #${(_selectedReport!['id'] as String).substring(0, 8)}',
                  style: ForensicTheme.title.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submitted: ${_selectedReport!['status_updated_at'] ?? 'N/A'}',
                  style: ForensicTheme.caption,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ForensicTheme.spaceSm,
              vertical: ForensicTheme.spaceXs,
            ),
            decoration: BoxDecoration(
              color: ForensicTheme.obsidianEmerald.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(ForensicTheme.radiusButton),
              border: Border.all(color: ForensicTheme.obsidianEmerald),
            ),
            child: Text(
              'PENDING REVIEW',
              style: ForensicTheme.caption.copyWith(
                color: ForensicTheme.obsidianEmerald,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAnalysisSection(AIAnalysisResult aiResult) {
    final hasIssues = aiResult.hasCriticalIssues;

    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      decoration: BoxDecoration(
        color: hasIssues 
            ? ForensicTheme.atomicRed.withValues(alpha: 0.1)
            : ForensicTheme.deepSpaceBlue.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(ForensicTheme.radiusCard),
        border: Border.all(
          color: hasIssues ? ForensicTheme.atomicRed : ForensicTheme.neonCyan,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasIssues ? Icons.warning : Icons.psychology,
                color: hasIssues ? ForensicTheme.atomicRed : ForensicTheme.neonCyan,
              ),
              const SizedBox(width: 8),
              Text(
                'AI Analysis',
                style: ForensicTheme.title.copyWith(
                  color: hasIssues ? ForensicTheme.atomicRed : ForensicTheme.neonCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: ForensicTheme.spaceSm),
          Text('Reliability: ${aiResult.reliabilityRating} (${aiResult.reliabilityScore}%)'),
          if (aiResult.timedOut) ...[
            const SizedBox(height: 4),
            Text('⚠️ Analysis timed out - Manual review required',
                style: TextStyle(color: ForensicTheme.atomicRed)),
          ],
          if (aiResult.inconsistencies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Inconsistencies:', style: ForensicTheme.caption),
            ...aiResult.inconsistencies.map((issue) => Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Text('• $issue', style: ForensicTheme.body),
            )),
          ],
          if (aiResult.missingInfo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Missing Information:', style: ForensicTheme.caption),
            ...aiResult.missingInfo.map((info) => Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Text('• $info', style: ForensicTheme.body),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonnelDataSection() {
    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      decoration: BoxDecoration(
        color: ForensicTheme.deepSpaceBlue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(ForensicTheme.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: ForensicTheme.textWhite),
              const SizedBox(width: 8),
              Text('Personnel Data', style: ForensicTheme.title),
            ],
          ),
          const SizedBox(height: ForensicTheme.spaceSm),
          // Display personnel data here
          Text('Person: ${_selectedReport!['user_id'] ?? 'N/A'}'),
          Text('Created: ${_selectedReport!['created_at'] ?? 'N/A'}'),
        ],
      ),
    );
  }

  Widget _buildEvidenceCardPreview(AIAnalysisResult aiResult) {
    return EvidenceCard(
      evidenceId: _selectedReport!['id'] as String,
      timestamp: DateTime.parse(_selectedReport!['created_at'] as String? ?? DateTime.now().toIso8601String()),
      sha256Hash: 'placeholder_hash_64_characters_long_for_preview_only',
      isVerified: false,
      observation: aiResult.observation,
      assumption: aiResult.assumption,
      limitation: aiResult.limitation,
    );
  }

  Widget _buildActionBar(AIAnalysisResult aiResult) {
    final canApprove = !aiResult.hasCriticalIssues;

    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: ForensicTheme.textDim.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _rejectReport,
              icon: const Icon(Icons.cancel, size: 20),
              label: const Text('Reject'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ForensicTheme.atomicRed,
                foregroundColor: ForensicTheme.textWhite,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: ForensicTheme.spaceMd),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : (canApprove ? _approveAndSeal : null),
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.verified, size: 20),
              label: Text(_isProcessing ? 'Sealing...' : 'Approve & Seal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: canApprove ? ForensicTheme.obsidianEmerald : Colors.grey,
                foregroundColor: ForensicTheme.textWhite,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// WIDGET: REPORT LIST TILE
// =====================================================

class ReportListTile extends StatelessWidget {
  final Map<String, dynamic> report;
  final bool isSelected;
  final VoidCallback onTap;

  const ReportListTile({
    super.key,
    required this.report,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final analysisData = report['ai_analysis_result'] as Map<String, dynamic>?;
    final hasIssues = analysisData != null && 
        (analysisData['timed_out'] == true || 
         (analysisData['reliability_score'] as num) < 60);

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(ForensicTheme.spaceXs),
        padding: const EdgeInsets.all(ForensicTheme.spaceMd),
        decoration: BoxDecoration(
          color: isSelected 
              ? ForensicTheme.neonCyan.withValues(alpha: 0.1)
              : ForensicTheme.deepSpaceBlue.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(ForensicTheme.radiusCard),
          border: Border.all(
            color: isSelected 
                ? ForensicTheme.neonCyan 
                : (hasIssues ? ForensicTheme.atomicRed : Colors.transparent),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${(report['id'] as String).substring(0, 8)}',
                    style: ForensicTheme.title.copyWith(
                      color: isSelected ? ForensicTheme.neonCyan : ForensicTheme.textWhite,
                    ),
                  ),
                ),
                if (hasIssues)
                  Icon(Icons.warning, color: ForensicTheme.atomicRed, size: 16),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              report['status_updated_at'] ?? 'N/A',
              style: ForensicTheme.caption,
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// WIDGET: REJECT DIALOG
// =====================================================

class RejectDialog extends StatefulWidget {
  final TextEditingController controller;

  const RejectDialog({super.key, required this.controller});

  @override
  State<RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<RejectDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Report'),
      content: TextField(
        controller: widget.controller,
        maxLines: 5,
        decoration: const InputDecoration(
          hintText: 'Enter rejection reason...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(widget.controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: ForensicTheme.atomicRed,
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}