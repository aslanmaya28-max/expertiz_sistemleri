/// REASONING LIMITATIONS
/// 
/// FAZ-0.7.1 / A — Reasoning Limitations Domain Model
/// 
/// ⚖️ LEGAL SHIELD:
/// This model is CRITICAL for legal defensibility.
/// It captures AI UNCERTAINTY explicitly to prevent claims of "AI was falsely confident".
/// 
/// 🎯 PURPOSE:
/// - Capture uncertainty expressions ("not sure", "maybe", "possibly")
/// - Document image quality issues
/// - Record any limitations in the analysis
/// - Create legal transparency about AI capabilities
/// 
/// 🔐 DETERMINISM:
/// - Alphabetical field ordering in toJson()
/// - No null values
/// - Lists sorted for consistency
library;

import 'package:meta/meta.dart';

/// Reasoning Limitations (Legal Shield)
/// 
/// ⚖️ CRITICAL IMPORTANCE:
/// This field is the LEGAL SHIELD against claims of false confidence.
/// If AI expresses ANY uncertainty, it MUST be captured here.
/// 
/// Examples of expressions that MUST be captured:
/// - "Emin değilim" (Not sure)
/// - "Görüntü kalitesi düşük" (Image quality low)
/// - "Tam olarak anlaşılamıyor" (Not fully understood)
/// - "Olabilir" (Could be)
/// - "Muhtemelen" (Probably)
/// - "Belki" (Maybe)
/// - "Sanırım" (I think)
/// - "Herhalde" (Likely)
/// 
/// 🪨 PRINCIPLE:
/// "Honest uncertainty is legally defensible.
///  False confidence creates liability."
@immutable
class ReasoningLimitations {
  /// Whether any limitations were detected
  /// 
  /// - true: AI expressed uncertainty or limitations
  /// - false: AI was confident in the analysis
  final bool hasLimitations;
  
  /// Specific limitation notes
  /// 
  /// Each note is a VERBATIM quote of uncertainty from the AI.
  /// These are NOT paraphrased - they are exact quotes.
  /// 
  /// Examples:
  /// - "Görüntü kalitesi düşük olduğu için detaylı analiz yapılamıyor"
  /// - "Hasarın boyutu tam olarak anlaşılamıyor"
  /// - "Bu hasar yeni olabilir, eski hasar üzerine de olabilir"
  /// - "Işık koşulları nedeniyle kesin yargı yapılamıyor"
  final List<String> limitationNotes;
  
  const ReasoningLimitations({
    required this.hasLimitations,
    required this.limitationNotes,
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
      'has_limitations': hasLimitations,
      'limitation_notes': List<String>.from(limitationNotes)..sort(),
    };
  }
  
  /// Create from JSON (for reading from ledger)
  factory ReasoningLimitations.fromJson(Map<String, dynamic> json) {
    return ReasoningLimitations(
      hasLimitations: json['has_limitations'] as bool,
      limitationNotes: List<String>.from(json['limitation_notes'] as List),
    );
  }
  
  /// Check if there are any limitation notes
  bool get hasNotes => limitationNotes.isNotEmpty;
  
  /// Get the number of limitation notes
  int get noteCount => limitationNotes.length;
  
  /// Create with no limitations
  factory ReasoningLimitations.none() {
    return ReasoningLimitations(
      hasLimitations: false,
      limitationNotes: [],
    );
  }
  
  /// Add a limitation note (returns new instance)
  ReasoningLimitations withNote(String note) {
    return ReasoningLimitations(
      hasLimitations: true,
      limitationNotes: [...limitationNotes, note],
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReasoningLimitations &&
          runtimeType == other.runtimeType &&
          hasLimitations == other.hasLimitations &&
          _listEquals(limitationNotes, other.limitationNotes);

  @override
  int get hashCode => hasLimitations.hashCode ^ limitationNotes.hashCode;
  
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}