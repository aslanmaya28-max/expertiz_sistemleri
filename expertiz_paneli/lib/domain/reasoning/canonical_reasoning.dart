/// CANONICAL REASONING
/// 
/// FAZ-0.7.1 / A — Canonical Reasoning Domain Model
/// 
/// ⚖️ LEGAL STANDARD:
/// This structure represents the FORENSIC-GRADE interpretation of AI reasoning.
/// Every field is designed to be court-defensible and legally non-repudiable.
/// 
/// 🎯 PURPOSE:
/// - Convert free-text AI output into structured, hash-safe data
/// - Capture AI uncertainty explicitly (legal defense)
/// - Provide deterministic JSON for cryptographic sealing
/// - Enable forensic audit trails
/// 
/// 🔐 DETERMINISM:
/// - Same input → same JSON → same hash → forever
/// - Alphabetical field ordering in toJson()
/// - No null values (use empty collections)
/// - UTC timestamps only
library;

import 'package:meta/meta.dart';
import 'damage_area.dart';
import 'cost_impact.dart';
import 'technical_justification.dart';
import 'reasoning_limitations.dart';

/// Canonical Reasoning v1.0
/// 
/// This is the ONLY structure that should be written to the immutable ledger.
/// Raw Gemini text is NEVER written directly - it must be parsed into this format.
/// 
/// 🪨 PRINCIPLE:
/// "AI explanations can be vague. Legal evidence must be precise."
@immutable
class CanonicalReasoning {
  /// Schema version for future compatibility
  /// 
  /// CRITICAL: Changing this version breaks hash verification
  /// All changes require new schema version
  final String schemaVersion;
  
  /// Damage area detected by AI
  /// 
  /// Specifies what was damaged, where, and how severe
  final DamageArea damageArea;
  
  /// Cost impact of the damage
  /// 
  /// Estimated repair cost range with confidence level
  final CostImpact costImpact;
  
  /// Technical justification for the decision
  /// 
  /// AI's reasoning: observations and assumptions
  final TechnicalJustification technicalJustification;
  
  /// Known limitations of the analysis
  /// 
  /// ⚖️ LEGAL SHIELD:
  /// This field captures AI uncertainty explicitly.
  /// If AI says "not sure", "maybe", "possibly", it goes here.
  /// This prevents claims of "AI was falsely confident"
  final ReasoningLimitations limitations;
  
  /// When this reasoning was generated (UTC)
  /// 
  /// CRITICAL: UTC only - no timezone ambiguity
  final DateTime generatedAtUtc;
  
  const CanonicalReasoning({
    required this.damageArea,
    required this.costImpact,
    required this.technicalJustification,
    required this.limitations,
    required this.generatedAtUtc,
  }) : schemaVersion = '1.0';
  
  /// Convert to JSON for cryptographic sealing
  /// 
  /// ⚖️ FORENSIC REQUIREMENT:
  /// - Fields sorted alphabetically
  /// - No null values
  /// - Deterministic output (same input → same hash)
  /// - This JSON will be SHA256 hashed for ledger sealing
  /// 
  /// WARNING: Changing field order breaks historical hash verification
  Map<String, dynamic> toJson() {
    return {
      'cost_impact': costImpact.toJson(),
      'damage_area': damageArea.toJson(),
      'generated_at_utc': generatedAtUtc.toIso8601String(),
      'limitations': limitations.toJson(),
      'schema_version': schemaVersion,
      'technical_justification': technicalJustification.toJson(),
    };
  }
  
  /// Create from JSON (for reading from ledger)
  factory CanonicalReasoning.fromJson(Map<String, dynamic> json) {
    return CanonicalReasoning(
      damageArea: DamageArea.fromJson(json['damage_area'] as Map<String, dynamic>),
      costImpact: CostImpact.fromJson(json['cost_impact'] as Map<String, dynamic>),
      technicalJustification: TechnicalJustification.fromJson(
        json['technical_justification'] as Map<String, dynamic>
      ),
      limitations: ReasoningLimitations.fromJson(
        json['limitations'] as Map<String, dynamic>
      ),
      generatedAtUtc: DateTime.parse(json['generated_at_utc'] as String),
    );
  }
  
  /// Check if reasoning has significant limitations
  /// 
  /// Returns true if AI expressed uncertainty
  /// This is a legal safety indicator
  bool get hasSignificantLimitations => limitations.hasLimitations;
  
  /// Get confidence level based on limitations
  /// 
  /// - 'high': No limitations detected
  /// - 'medium': Minor limitations noted
  /// - 'low': Significant uncertainty expressed
  String get overallConfidence {
    if (!limitations.hasLimitations) return 'high';
    if (limitations.limitationNotes.length <= 2) return 'medium';
    return 'low';
  }
}