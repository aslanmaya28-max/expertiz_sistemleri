/// DAMAGE AREA
/// 
/// FAZ-0.7.1 / A — Damage Area Domain Model
/// 
/// ⚖️ LEGAL STANDARD:
/// This model captures WHERE damage was detected and HOW SEVERE it is.
/// Designed for court-defensible damage assessment.
/// 
/// 🔐 DETERMINISM:
/// - Alphabetical field ordering in toJson()
/// - No null values
/// - Enum-like severity levels for consistency
library;

import 'package:meta/meta.dart';

/// Damage Area detected by AI
/// 
/// Specifies what part of the vehicle was damaged,
/// the severity level, and a description.
/// 
/// 🪨 PRINCIPLE:
/// "Precise damage classification prevents legal ambiguity."
@immutable
class DamageArea {
  /// Name of the damaged area
  /// 
  /// Examples: "Ön Tampon", "Sol Çamurluk", "Kaput", "Tavan"
  /// Standardized terminology is critical for consistency
  final String areaName;
  
  /// Severity level of the damage
  /// 
  /// Standardized severity levels:
  /// - 'low': Minor damage, cosmetic
  /// - 'medium': Moderate damage, functional
  /// - 'high': Severe damage, structural
  final String severity;
  
  /// Detailed description of the damage
  /// 
  /// Free-text description of what was observed
  /// This provides context beyond classification
  final String description;
  
  const DamageArea({
    required this.areaName,
    required this.severity,
    required this.description,
  });
  
  /// Valid severity levels
  static const List<String> validSeverities = ['low', 'medium', 'high'];
  
  /// Convert to JSON for cryptographic sealing
  /// 
  /// ⚖️ FORENSIC REQUIREMENT:
  /// - Fields sorted alphabetically
  /// - Deterministic output
  /// - This JSON will be included in SHA256 hash
  Map<String, dynamic> toJson() {
    return {
      'area_name': areaName,
      'description': description,
      'severity': severity,
    };
  }
  
  /// Create from JSON (for reading from ledger)
  factory DamageArea.fromJson(Map<String, dynamic> json) {
    return DamageArea(
      areaName: json['area_name'] as String,
      severity: json['severity'] as String,
      description: json['description'] as String,
    );
  }
  
  /// Validate severity level
  bool get isValidSeverity => validSeverities.contains(severity);
  
  /// Create with default values if needed
  factory DamageArea.unknown() {
    return DamageArea(
      areaName: 'Bilinmiyor',
      severity: 'low',
      description: 'Hasar alanı belirlenemedi',
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DamageArea &&
          runtimeType == other.runtimeType &&
          areaName == other.areaName &&
          severity == other.severity &&
          description == other.description;

  @override
  int get hashCode => areaName.hashCode ^ severity.hashCode ^ description.hashCode;
}