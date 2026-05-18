/// TECHNICAL JUSTIFICATION
/// 
/// FAZ-0.7.1 / A — Technical Justification Domain Model
/// 
/// ⚖️ LEGAL STANDARD:
/// This model captures the TECHNICAL REASONING behind AI decisions.
/// Separates OBSERVATIONS (what was seen) from ASSUMPTIONS (what was inferred).
/// 
/// 🔐 DETERMINISM:
/// - Alphabetical field ordering in toJson()
/// - No null values
/// - Lists are sorted for consistency
library;

import 'package:meta/meta.dart';

/// Technical Justification for AI Decision
/// 
/// Captures the reasoning process:
/// - Observations: What was directly observed in the image
/// - Assumptions: What was inferred or assumed
/// 
/// 🪨 PRINCIPLE:
/// "Separating observation from inference creates legal clarity.
///  Confusion between the two creates liability."
@immutable
class TechnicalJustification {
  /// Direct observations from the image
  /// 
  /// These are statements of what was ACTUALLY seen.
  /// Examples:
  /// - "Görüntüde ön tamponda deformasyon tespit edildi"
  /// - "Sol farın camı çatlamış"
  /// - "Boyada renk farklılığı görülüyor"
  /// 
  /// CRITICAL: These must be OBSERVATIONS, not interpretations
  final List<String> observations;
  
  /// Assumptions made during analysis
  /// 
  /// These are inferences based on observations.
  /// Examples:
  /// - "Hasarın hızı yaklaşık 30-40 km/s olabilir"
  /// - "Tampon değişimi gerekebilir"
  /// - "Boyadan kaynaklı olma ihtimali var"
  /// 
  /// CRITICAL: These must be labeled as assumptions
  final List<String> assumptions;
  
  const TechnicalJustification({
    required this.observations,
    required this.assumptions,
  });
  
  /// Convert to JSON for cryptographic sealing
  /// 
  /// ⚖️ FORENSIC REQUIREMENT:
  /// - Fields sorted alphabetically
  /// - Lists sorted for determinism
  /// - No null values (use empty lists)
  /// - This JSON will be included in SHA256 hash
  Map<String, dynamic> toJson() {
    return {
      'assumptions': List<String>.from(assumptions)..sort(),
      'observations': List<String>.from(observations)..sort(),
    };
  }
  
  /// Create from JSON (for reading from ledger)
  factory TechnicalJustification.fromJson(Map<String, dynamic> json) {
    return TechnicalJustification(
      observations: List<String>.from(json['observations'] as List),
      assumptions: List<String>.from(json['assumptions'] as List),
    );
  }
  
  /// Check if there are any observations
  bool get hasObservations => observations.isNotEmpty;
  
  /// Check if there are any assumptions
  bool get hasAssumptions => assumptions.isNotEmpty;
  
  /// Create with default values
  factory TechnicalJustification.empty() {
    return TechnicalJustification(
      observations: [],
      assumptions: [],
    );
  }
  
  /// Add an observation (returns new instance)
  TechnicalJustification withObservation(String observation) {
    return TechnicalJustification(
      observations: [...observations, observation],
      assumptions: assumptions,
    );
  }
  
  /// Add an assumption (returns new instance)
  TechnicalJustification withAssumption(String assumption) {
    return TechnicalJustification(
      observations: observations,
      assumptions: [...assumptions, assumption],
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TechnicalJustification &&
          runtimeType == other.runtimeType &&
          _listEquals(observations, other.observations) &&
          _listEquals(assumptions, other.assumptions);

  @override
  int get hashCode => observations.hashCode ^ assumptions.hashCode;
  
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}