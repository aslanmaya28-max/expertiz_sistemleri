import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/futuristic_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/ledger_verification_service.dart';
import '../../services/evidence_report_service.dart';
import '../../domain/ledger/hash_verification_result.dart';
import '../../domain/reasoning/reasoning_parser.dart';
import '../../domain/reasoning/canonical_reasoning.dart';
import '../../core/constants/roles.dart';
import '../../core/layout/base_scaffold.dart';

class EvidenceTimelineScreen extends StatefulWidget {
  const EvidenceTimelineScreen({super.key});

  @override
  State<EvidenceTimelineScreen> createState() => _EvidenceTimelineScreenState();
}

class _EvidenceTimelineScreenState extends State<EvidenceTimelineScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _ledgerEntries = [];
  bool _isLoading = true;
  String? _error;
  final Map<String, HashVerificationResult?> _verificationResults = {};

  @override
  void initState() {
    super.initState();
    _loadLedgerEntries();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLedgerEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('explainability_ledger')
          .select()
          .order('sealed_at', ascending: false)
          .limit(50);

      setState(() {
        _ledgerEntries = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyIntegrity(String entryId) async {
    setState(() {
      _verificationResults[entryId] = null; // Clear previous result to show loading
    });

    final result = await context.read<LedgerVerificationService>().verifyLedgerIntegrity(ledgerId: entryId);

    setState(() {
      _verificationResults[entryId] = result;
    });
  }

  void _copyHash(String hash) {
    Clipboard.setData(ClipboardData(text: hash));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Hash kopyalandı'),
        backgroundColor: FuturisticTheme.neon,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _abbreviateHash(String hash) {
    if (hash.length <= 16) return hash;
    return '${hash.substring(0, 8)}...${hash.substring(hash.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      role: UserRole.admin,
      body: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                    : _ledgerEntries.isEmpty
                        ? _buildEmptyState()
                        : _buildTimeline(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FuturisticTheme.bgSecondary,
        border: Border(
          bottom: BorderSide(
            color: FuturisticTheme.neon.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: FuturisticTheme.neon, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EVIDENCE TIMELINE',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Immutable Ledger Records',
                      style: TextStyle(
                        fontSize: 14,
                        color: FuturisticTheme.neon.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                color: FuturisticTheme.neon,
                onPressed: _loadLedgerEntries,
                tooltip: 'Yenile',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(
              'Veri yüklenemedi: $_error',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLedgerEntries,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.white.withValues(alpha: 0.24)),
          const SizedBox(height: 16),
          Text(
            'Henüz kayıt yok',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _ledgerEntries.length,
      itemBuilder: (context, index) {
        final entry = _ledgerEntries[index];
        return _buildTimelineCard(entry, index);
      },
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic> entry, int index) {
    final imageHash = entry['image_hash'] as String? ?? '';
    final entryId = entry['id'].toString();
    final sealedAt = DateTime.parse(entry['sealed_at']).toUtc();
    final decisionHash = entry['decision_hash'] as String? ?? '';
    final aiOutput = entry['ai_output'] as String? ?? '';

    // Parse reasoning
    final reasoningData = entry['reasoning'];
    final parsedReasoning = reasoningData is Map<String, dynamic>
        ? CanonicalReasoning.fromJson(reasoningData)
        : context.read<ReasoningParser>().parseReasoning(reasoningData?.toString() ?? '');
    
    final hasLimitations = parsedReasoning.limitations.hasLimitations;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          // Timeline indicator
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline line
              Container(
                width: 2,
                height: 80,
                color: FuturisticTheme.neon.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 16),
              // Card
              Expanded(
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with timestamp and hash
                      Row(
                        children: [
                          Icon(
                            Icons.lock_clock,
                            color: FuturisticTheme.neon,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('dd.MM.yyyy HH:mm:ss').format(sealedAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: FuturisticTheme.neon,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            'UTC',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Decision Hash
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _copyHash(decisionHash),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: FuturisticTheme.neon.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: FuturisticTheme.neon.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.fingerprint, color: FuturisticTheme.neon, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _abbreviateHash(decisionHash),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          color: FuturisticTheme.neon,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.copy, color: FuturisticTheme.neon.withValues(alpha: 0.7), size: 14),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Verify Button
                          _buildVerifyButton(entryId),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // AI Decision Summary
                      if (aiOutput.isNotEmpty) ...[
                        const Text(
                          'AI Decision',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          aiOutput,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      // Reasoning Section
                      if (parsedReasoning.technicalJustification.observations.isNotEmpty || 
                          parsedReasoning.technicalJustification.assumptions.isNotEmpty ||
                          hasLimitations) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: FuturisticTheme.bgSecondary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reasoning',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              // Observation
                              if (parsedReasoning.technicalJustification.observations.isNotEmpty) ...[
                                _buildReasoningLabel('🔍 Observations'),
                                const SizedBox(height: 4),
                                Text(
                                  parsedReasoning.technicalJustification.observations.join('\n'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              
                              // Assumption
                              if (parsedReasoning.technicalJustification.assumptions.isNotEmpty) ...[
                                _buildReasoningLabel('🧠 Assumptions'),
                                const SizedBox(height: 4),
                                Text(
                                  parsedReasoning.technicalJustification.assumptions.join('\n'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              
                              // Limitations (RED WARNING)
                              if (hasLimitations) ...[
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.warning, color: Colors.red, size: 16),
                                          const SizedBox(width: 4),
                                          const Text(
                                            '⚠️ LIMITATIONS',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ...parsedReasoning.limitations.limitationNotes.map((limitation) => Padding(
                                        padding: const EdgeInsets.only(left: 20, top: 2),
                                        child: Text(
                                          '• $limitation',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.red.withValues(alpha: 0.9),
                                          ),
                                        ),
                                      )),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      // Image Hash
                      if (imageHash.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.image, color: Colors.white.withValues(alpha: 0.5), size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _abbreviateHash(imageHash),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      // PDF Export Buttons
                      const SizedBox(height: 12),
                      _buildPdfButtons(entryId),
                      
                      // Verification Status (if verified)
                      if (_verificationResults[entryId] != null) ...[
                        const SizedBox(height: 12),
                        _buildVerificationStatus(_verificationResults[entryId]!),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReasoningLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: FuturisticTheme.neon.withValues(alpha: 0.8),
      ),
    );
  }

  Widget _buildVerifyButton(String entryId) {
    final isVerifying = _verificationResults.containsKey(entryId) && _verificationResults[entryId] == null;
    
    return ElevatedButton(
      onPressed: isVerifying ? null : () => _verifyIntegrity(entryId),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: FuturisticTheme.neon.withValues(alpha: 0.2),
        foregroundColor: FuturisticTheme.neon,
      ),
      child: isVerifying
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Verify', style: TextStyle(fontSize: 12)),
    );
  }

  Widget _buildVerificationStatus(HashVerificationResult result) {
    final isVerified = result.isValid;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isVerified 
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isVerified ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.error,
            color: isVerified ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isVerified ? 'INTEGRITY VERIFIED' : 'TAMPERING DETECTED',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isVerified ? Colors.green : Colors.red,
              ),
            ),
          ),
          if (!isVerified)
            IconButton(
              icon: const Icon(Icons.info_outline, size: 18),
              color: Colors.red,
              onPressed: () => _showVerificationError(result),
            ),
        ],
      ),
    );
  }

  void _showVerificationError(HashVerificationResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FuturisticTheme.bgSecondary,
        title: const Text('Verification Error', style: TextStyle(color: Colors.white)),
        content: Text(
          result.errorMessage ?? 'Hash verification failed',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfButtons(String entryId) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _generatePdf(entryId, save: true),
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Save PDF', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: Colors.blue.withValues(alpha: 0.2),
              foregroundColor: Colors.blue,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _generatePdf(entryId, save: false),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: FuturisticTheme.neon.withValues(alpha: 0.2),
              foregroundColor: FuturisticTheme.neon,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _generatePdf(String entryId, {required bool save}) async {
    try {
      final reportService = context.read<EvidenceReportService>();
      
      if (save) {
        await reportService.saveReport(entryId);
      } else {
        await reportService.printReport(entryId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF oluşturma hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}