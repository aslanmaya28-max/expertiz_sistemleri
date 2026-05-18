import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/reasoning/reasoning_parser.dart';
import '../domain/reasoning/canonical_reasoning.dart';
import '../domain/ledger/hash_verification_result.dart';
import 'ledger_verification_service.dart';

/// Evidence Report Service
/// 
/// Generates court-admissible PDF reports from immutable ledger records
class EvidenceReportService {
  final LedgerVerificationService _verificationService;
  final ReasoningParser _reasoningParser;

  EvidenceReportService({
    required LedgerVerificationService verificationService,
    required ReasoningParser reasoningParser,
  })  : _verificationService = verificationService,
        _reasoningParser = reasoningParser;

  /// Generate PDF report for a single ledger entry
  Future<pw.Document> generateEntryReport(String entryId) async {
    final pdf = pw.Document();

    // Fetch ledger entry
    final entry = await Supabase.instance.client
        .from('explainability_ledger')
        .select()
        .eq('id', entryId)
        .single();

    // Verify integrity
    final verificationResult = await _verificationService.verifyLedgerIntegrity(ledgerId: entryId);

    // Parse reasoning
    final reasoningData = entry['reasoning'];
    final CanonicalReasoning parsedReasoning;
    if (reasoningData is Map<String, dynamic>) {
      parsedReasoning = CanonicalReasoning.fromJson(reasoningData);
    } else {
      parsedReasoning = _reasoningParser.parseReasoning(reasoningData?.toString() ?? '');
    }

    // Add report page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(entry, verificationResult),
              pw.SizedBox(height: 32),
              _buildCaseInfo(entry),
              pw.SizedBox(height: 24),
              _buildHashSection(entry),
              pw.SizedBox(height: 24),
              _buildDecisionSection(entry),
              pw.SizedBox(height: 24),
              _buildReasoningSection(parsedReasoning),
              pw.SizedBox(height: 24),
              _buildVerificationSection(verificationResult),
              pw.SizedBox(height: 32),
              _buildFooter(entry, verificationResult),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(Map<String, dynamic> entry, HashVerificationResult verification) {
    final sealedAt = DateTime.parse(entry['sealed_at']).toUtc();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Title
        pw.Text(
          'EVIDENCE REPORT',
          style: pw.TextStyle(
            fontSize: 28,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Immutable Ledger Record',
          style: pw.TextStyle(
            fontSize: 14,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 16),
        // Timestamp
        pw.Row(
          children: [
            pw.Icon(const pw.IconData(0xf017), size: 14, color: PdfColors.grey700),
            pw.SizedBox(width: 8),
            pw.Text(
              DateFormat('dd.MM.yyyy HH:mm:ss').format(sealedAt),
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'UTC',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        // Verification Badge
        _buildVerificationBadge(verification),
      ],
    );
  }

  pw.Widget _buildVerificationBadge(HashVerificationResult result) {
    final color = result.isValid ? PdfColors.green700 : PdfColors.red700;
    final text = result.isValid ? '✓ INTEGRITY VERIFIED' : '✗ TAMPERING DETECTED';

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        color: result.isValid ? PdfColors.green100 : PdfColors.red100,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: color, width: 2),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  pw.Widget _buildCaseInfo(Map<String, dynamic> entry) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CASE INFORMATION',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 8),
          _buildInfoRow('Entry ID', entry['id'].toString()),
          _buildInfoRow('Report ID', entry['report_id']?.toString() ?? '---'),
          _buildInfoRow('Analyst', entry['analyst_id']?.toString() ?? '---'),
        ],
      ),
    );
  }

  pw.Widget _buildHashSection(Map<String, dynamic> entry) {
    final decisionHash = entry['decision_hash'] as String? ?? '';
    final imageHash = entry['image_hash'] as String? ?? '';

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CRYPTOGRAPHIC HASHES',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 8),
          _buildHashRow('Decision Hash (SHA256)', decisionHash),
          pw.SizedBox(height: 4),
          _buildHashRow('Image Hash (SHA256)', imageHash),
        ],
      ),
    );
  }

  pw.Widget _buildDecisionSection(Map<String, dynamic> entry) {
    final aiOutput = entry['ai_output'] as String? ?? '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'AI DECISION SUMMARY',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Text(
            aiOutput,
            style: pw.TextStyle(fontSize: 11, color: PdfColors.black),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildReasoningSection(CanonicalReasoning reasoning) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'AI REASONING',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 8),
        if (reasoning.technicalJustification.observations.isNotEmpty) ...[
          _buildReasoningBlock('Observations', reasoning.technicalJustification.observations.join('\n'), PdfColors.purple700),
          pw.SizedBox(height: 8),
        ],
        if (reasoning.technicalJustification.assumptions.isNotEmpty) ...[
          _buildReasoningBlock('Assumptions', reasoning.technicalJustification.assumptions.join('\n'), PdfColors.indigo700),
          pw.SizedBox(height: 8),
        ],
        if (reasoning.limitations.hasLimitations) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.red50,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.red200),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      '⚠️ LIMITATIONS',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red700,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                ...reasoning.limitations.limitationNotes.map((limitation) => pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, top: 2),
                  child: pw.Text(
                    '• $limitation',
                    style: pw.TextStyle(fontSize: 11, color: PdfColors.red900),
                  ),
                )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _buildVerificationSection(HashVerificationResult result) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: result.isValid ? PdfColors.green50 : PdfColors.red50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: result.isValid ? PdfColors.green200 : PdfColors.red200,
          width: 2,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                result.isValid ? '✓ ' : '✗ ',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: result.isValid ? PdfColors.green700 : PdfColors.red700,
                ),
              ),
              pw.Text(
                'HASH VERIFICATION RESULT',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: result.isValid ? PdfColors.green700 : PdfColors.red700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            result.isValid
                ? 'The cryptographic hash has been verified. The data integrity is confirmed.'
                : 'HASH MISMATCH DETECTED! The data may have been tampered with.',
            style: pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
          ),
          if (!result.isValid && result.errorMessage != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Error: ${result.errorMessage}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.red900),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildFooter(Map<String, dynamic> entry, HashVerificationResult verification) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 16),
        pw.Text(
          'LEGAL DISCLAIMER',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'This report is generated from an immutable ledger. All timestamps are in UTC. '
          'The cryptographic hashes provide mathematical proof of data integrity. '
          'This document can be used as evidence in legal proceedings.',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Generated: ${DateFormat('dd.MM.yyyy HH:mm:ss').format(DateTime.now().toUtc())} UTC',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      ],
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 11, color: PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildHashRow(String label, String hash) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
        ),
        pw.SizedBox(height: 2),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.blue300),
          ),
          child: pw.Text(
            hash,
            style: pw.TextStyle(fontSize: 9, font: pw.Font.courier(), color: PdfColors.black),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildReasoningBlock(String label, String content, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Text(
            content,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
          ),
        ),
      ],
    );
  }

  /// Print the PDF report
  Future<void> printReport(String entryId) async {
    final pdf = await generateEntryReport(entryId);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  /// Save the PDF report
  Future<void> saveReport(String entryId) async {
    final pdf = await generateEntryReport(entryId);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'evidence_report_$entryId.pdf',
    );
  }
}