/// AI ANALYSIS RESULT MODEL
/// 
/// FAZ-3.0 / M3 — AI Analysis Output Structure
/// 
/// ⚖️ LEGAL STANDARD:
/// This model represents AI-generated analysis results that will be
/// stored in the immutable ledger as forensic evidence.
/// 
/// 🎯 PURPOSE:
/// - Structured AI output for admin review
/// - Canonical format for hash generation
/// - Evidence-grade data for legal defensibility
/// 
/// 🪨 PRINCIPLE:
/// "AI analysis is evidence, not opinion."
library;
 
/// AI Analysis Result
/// 
/// Contains the complete output of AI analysis on a report.
/// This data is cryptographically sealed in the immutable ledger.
class AIAnalysisResult {
  /// Reliability score (0.0 to 100.0)
  final double reliabilityScore;
  
  /// Primary observation from AI
  final String observation;
  
  /// Assumptions made by AI
  final String assumption;
  
  /// Limitations and uncertainties
  final String limitation;
  
  /// Detected inconsistencies
  final List<String> inconsistencies;
  
  /// Missing information
  final List<String> missingInfo;
  
  /// Confidence score (0.0 to 1.0)
  final double confidenceScore;
  
  /// Model version used
  final String modelVersion;
  
  /// Analysis timestamp (UTC)
  final DateTime analyzedAt;
  
  /// Processing duration in milliseconds
  final int processingDurationMs;
  
  /// Whether analysis timed out
  final bool timedOut;
  
  /// Timeout message (if timed out)
  final String? timeoutMessage;

  /// Additional engine metadata
  final Map<String, dynamic>? metadata;

  const AIAnalysisResult({
    required this.reliabilityScore,
    required this.observation,
    required this.assumption,
    required this.limitation,
    required this.inconsistencies,
    required this.missingInfo,
    required this.confidenceScore,
    required this.modelVersion,
    required this.analyzedAt,
    required this.processingDurationMs,
    this.timedOut = false,
    this.timeoutMessage,
    this.metadata,
  });

  /// Create timeout result
  factory AIAnalysisResult.timeout({
    required String modelVersion,
    required int timeoutMs,
    String? message,
  }) {
    return AIAnalysisResult(
      reliabilityScore: 0.0,
      observation: 'AI analysis timed out after ${timeoutMs}ms',
      assumption: 'Manual review required',
      limitation: 'AI service unavailable or timed out',
      inconsistencies: [],
      missingInfo: ['AI analysis incomplete'],
      confidenceScore: 0.0,
      modelVersion: modelVersion,
      analyzedAt: DateTime.now().toUtc(),
      processingDurationMs: timeoutMs,
      timedOut: true,
      timeoutMessage: message ?? 'AI analysis timed out',
    );
  }

  /// Create error result
  factory AIAnalysisResult.error({
    required String errorMessage,
    required String modelVersion,
  }) {
    return AIAnalysisResult(
      reliabilityScore: 0.0,
      observation: 'AI analysis failed',
      assumption: 'Manual review required',
      limitation: 'AI service error: $errorMessage',
      inconsistencies: [],
      missingInfo: ['AI analysis incomplete'],
      confidenceScore: 0.0,
      modelVersion: modelVersion,
      analyzedAt: DateTime.now().toUtc(),
      processingDurationMs: 0,
      timedOut: false,
      timeoutMessage: errorMessage,
    );
  }

  /// Convert to JSON (canonical format)
  Map<String, dynamic> toJson() {
    return {
      'reliability_score': reliabilityScore,
      'observation': observation,
      'assumption': assumption,
      'limitation': limitation,
      'inconsistencies': inconsistencies,
      'missing_info': missingInfo,
      'confidence_score': confidenceScore,
      'model_version': modelVersion,
      'analyzed_at': analyzedAt.toIso8601String(),
      'processing_duration_ms': processingDurationMs,
      'timed_out': timedOut,
      'timeout_message': timeoutMessage,
      'metadata': metadata,
    };
  }

  /// Parse from JSON
  factory AIAnalysisResult.fromJson(Map<String, dynamic> json) {
    return AIAnalysisResult(
      reliabilityScore: (json['reliability_score'] as num).toDouble(),
      observation: json['observation'] as String,
      assumption: json['assumption'] as String,
      limitation: json['limitation'] as String,
      inconsistencies: (json['inconsistencies'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      missingInfo: (json['missing_info'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      modelVersion: json['model_version'] as String,
      analyzedAt: DateTime.parse(json['analyzed_at'] as String),
      processingDurationMs: json['processing_duration_ms'] as int,
      timedOut: json['timed_out'] as bool? ?? false,
      timeoutMessage: json['timeout_message'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to canonical reasoning format for ledger
  Map<String, dynamic> toCanonicalReasoning() {
    return {
      'observation': observation,
      'assumption': assumption,
      'limitation': limitation,
      'reliability_score': reliabilityScore,
      'confidence_score': confidenceScore,
      'inconsistencies': inconsistencies,
      'missing_info': missingInfo,
    };
  }

  /// Get reliability rating
  String get reliabilityRating {
    if (timedOut) return 'N/A (Timeout)';
    if (reliabilityScore >= 90) return 'Excellent';
    if (reliabilityScore >= 75) return 'Good';
    if (reliabilityScore >= 60) return 'Fair';
    return 'Poor';
  }

  /// Get reliability color
  String get reliabilityColor {
    if (timedOut) return 'grey';
    if (reliabilityScore >= 90) return 'green';
    if (reliabilityScore >= 75) return 'blue';
    if (reliabilityScore >= 60) return 'orange';
    return 'red';
  }

  /// Has critical issues?
  bool get hasCriticalIssues {
    return timedOut || 
           reliabilityScore < 60 || 
           inconsistencies.isNotEmpty ||
           missingInfo.isNotEmpty;
  }

  /// Get summary for admin review
  String get summary {
    if (timedOut) {
      return '⚠️ AI Analysis Timed Out - Manual Review Required';
    }
    
    final buffer = StringBuffer();
    buffer.write('Reliability: $reliabilityRating ($reliabilityScore%)');
    
    if (inconsistencies.isNotEmpty) {
      buffer.write('\n⚠️ ${inconsistencies.length} Inconsistencies Detected');
    }
    
    if (missingInfo.isNotEmpty) {
      buffer.write('\n❓ ${missingInfo.length} Missing Fields');
    }
    
    return buffer.toString();
  }

  @override
  String toString() {
    return 'AIAnalysisResult(reliability: $reliabilityScore%, '
        'confidence: ${(confidenceScore * 100).toStringAsFixed(1)}%, '
        'duration: ${processingDurationMs}ms, '
        'timedOut: $timedOut)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIAnalysisResult &&
        other.reliabilityScore == reliabilityScore &&
        other.observation == observation &&
        other.assumption == assumption &&
        other.limitation == limitation &&
        other.confidenceScore == confidenceScore &&
        other.modelVersion == modelVersion &&
        other.timedOut == timedOut;
  }

  @override
  int get hashCode {
    return reliabilityScore.hashCode ^
        observation.hashCode ^
        assumption.hashCode ^
        limitation.hashCode ^
        confidenceScore.hashCode ^
        modelVersion.hashCode ^
        timedOut.hashCode;
  }
}