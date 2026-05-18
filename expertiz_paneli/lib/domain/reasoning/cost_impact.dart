/// COST IMPACT
/// 
/// FAZ-0.7.1 / A — Cost Impact Domain Model
/// 
/// ⚖️ LEGAL STANDARD:
/// This model captures the ESTIMATED financial impact of detected damage.
/// Designed for court-defensible cost assessment with explicit confidence levels.
/// 
/// 🔐 DETERMINISM:
/// - Alphabetical field ordering in toJson()
/// - No null values
/// - Standardized confidence levels
library;

import 'package:meta/meta.dart';

/// Cost Impact of detected damage
/// 
/// Provides estimated repair cost range and confidence level.
/// 
/// 🪨 PRINCIPLE:
/// "Cost estimates must be honest about uncertainty.
///  Overconfident estimates create legal liability."
@immutable
class CostImpact {
  /// Estimated cost range
  /// 
  /// Format: "X - Y TL" or "Belirlenemedi"
  /// Examples:
  /// - "5.000 - 10.000 TL"
  /// - "20.000 - 35.000 TL"
  /// - "Belirlenemedi"
  final String estimatedRange;
  
  /// Confidence level in the estimate
  /// 
  /// Standardized levels:
  /// - 'low': High uncertainty, wide range
  /// - 'medium': Moderate confidence, reasonable range
  /// - 'high': High confidence, narrow range
  final String confidence;
  
  const CostImpact({
    required this.estimatedRange,
    required this.confidence,
  });
  
  /// Valid confidence levels
  static const List<String> validConfidence = ['low', 'medium', 'high'];
  
  /// Convert to JSON for cryptographic sealing
  /// 
  /// ⚖️ FORENSIC REQUIREMENT:
  /// - Fields sorted alphabetically
  /// - Deterministic output
  /// - This JSON will be included in SHA256 hash
  Map<String, dynamic> toJson() {
    return {
      'confidence': confidence,
      'estimated_range': estimatedRange,
    };
  }
  
  /// Create from JSON (for reading from ledger)
  factory CostImpact.fromJson(Map<String, dynamic> json) {
    return CostImpact(
      estimatedRange: json['estimated_range'] as String,
      confidence: json['confidence'] as String,
    );
  }
  
  /// Validate confidence level
  bool get isValidConfidence => validConfidence.contains(confidence);
  
  /// Check if cost is determinable
  bool get isCostDetermined => estimatedRange != 'Belirlenemedi';
  
  /// Create with default values if cost cannot be determined
  factory CostImpact.undetermined() {
    return CostImpact(
      estimatedRange: 'Belirlenemedi',
      confidence: 'low',
    );
  }
  
  /// Create from numeric range
  factory CostImpact.fromRange({
    required double minAmount,
    required double maxAmount,
    required String currency,
    required String confidence,
  }) {
    final range = '$minAmount - $maxAmount $currency';
    return CostImpact(
      estimatedRange: range,
      confidence: confidence,
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CostImpact &&
          runtimeType == other.runtimeType &&
          estimatedRange == other.estimatedRange &&
          confidence == other.confidence;

  @override
  int get hashCode => estimatedRange.hashCode ^ confidence.hashCode;
}