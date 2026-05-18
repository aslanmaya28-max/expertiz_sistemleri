/// HASH VERIFICATION RESULT
/// 
/// FAZ-0.7.1 / C1 — Hash Verification Domain Model
/// 
/// ⚖️ LEGAL STANDARD:
/// This model represents the FORENSIC RESULT of cryptographic verification.
/// It provides mathematical proof of whether a ledger record has been tampered with.
/// 
/// 🎯 PURPOSE:
/// - Provide binary, undeniable verification result
/// - Store both stored and recomputed hashes for comparison
/// - Document when verification occurred (UTC)
/// - Enable court-defensible integrity proof
/// 
/// 🔐 DETERMINISM:
/// - UTC timestamps only
/// - No nullable fields
/// - Binary validity result (true/false)
library;

import 'package:meta/meta.dart';

/// Hash Verification Result
/// 
/// ⚖️ CRITICAL LEGAL IMPORTANCE:
/// This object provides MATHEMATICAL PROOF of data integrity.
/// In court, this result can be used to prove whether evidence has been tampered with.
/// 
/// 🪨 PRINCIPLE:
/// "Hash mismatch = evidence of tampering.
///  Hash match = integrity verified beyond reasonable doubt."
@immutable
class HashVerificationResult {
  /// Ledger record ID being verified
  /// 
  /// Unique identifier of the record in explainability_ledger table
  final String ledgerId;
  
  /// Hash stored in the database
  /// 
  /// This is the decision_hash that was stored when the record was created.
  /// If this differs from recomputedHash, the record has been tampered with.
  final String storedHash;
  
  /// Hash recomputed from current data
  /// 
  /// This is recalculated by reconstructing the canonical evidence packet
  /// and computing its SHA256 hash.
  /// 
  /// ⚖️ LEGAL IMPLICATION:
  /// If storedHash != recomputedHash, this is CRITICAL SECURITY EVENT
  /// indicating potential tampering or database corruption.
  final String recomputedHash;
  
  /// Whether the hashes match
  /// 
  /// - true: Integrity verified, record is untampered
  /// - false: TAMPERING DETECTED, record has been modified
  /// 
  /// This is a BINARY, UNDENIABLE result
  final bool isValid;
  
  /// When verification was performed (UTC)
  /// 
  /// CRITICAL: UTC only - no timezone ambiguity
  final DateTime verifiedAtUtc;
  
  /// Optinal error message if verification failed
  final String? errorMessage;
  
  const HashVerificationResult({
    required this.ledgerId,
    required this.storedHash,
    required this.recomputedHash,
    required this.isValid,
    required this.verifiedAtUtc,
    this.errorMessage,
  });
  
  /// Convert to JSON for logging/audit
  /// 
  /// ⚖️ FORENSIC REQUIREMENT:
  /// - Fields sorted alphabetically
  /// - Deterministic output
  /// - This creates an audit trail of verifications
  Map<String, dynamic> toJson() {
    return {
      'is_valid': isValid,
      'ledger_id': ledgerId,
      'recomputed_hash': recomputedHash,
      'stored_hash': storedHash,
      'verified_at_utc': verifiedAtUtc.toIso8601String(),
    };
  }
  
  /// Get verification status message
  String get statusMessage {
    return isValid 
        ? '✅ Integrity Verified'
        : '🔴 TAMPERING DETECTED';
  }
  
  /// Get detailed explanation (for legal/court use)
  String get legalExplanation {
    if (isValid) {
      return '''
Ledger record $ledgerId has been cryptographically verified.

The stored SHA256 hash matches the recomputed hash,
proving that the record has not been altered since creation.

Verification Date: ${verifiedAtUtc.toIso8601String()}

This verification provides mathematical proof of data integrity
beyond reasonable doubt.
''';
    } else {
      return '''
⚠️ CRITICAL SECURITY EVENT ⚠️

Ledger record $ledgerId shows EVIDENCE OF TAMPERING.

The stored SHA256 hash does NOT match the recomputed hash:
- Stored Hash: $storedHash
- Recomputed Hash: $recomputedHash

Verification Date: ${verifiedAtUtc.toIso8601String()}

This discrepancy indicates that either:
1. The record has been modified after creation
2. The database has been corrupted
3. The cryptographic sealing process was compromised

THIS RECORD SHOULD NOT BE USED AS LEGAL EVIDENCE.
''';
    }
  }
  
  /// Check if hashes match exactly
  bool get hashesMatch => storedHash.toLowerCase() == recomputedHash.toLowerCase();
  
  @override
  String toString() {
    return 'HashVerificationResult(ledgerId: $ledgerId, isValid: $isValid, verifiedAt: $verifiedAtUtc)';
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HashVerificationResult &&
          runtimeType == other.runtimeType &&
          ledgerId == other.ledgerId &&
          storedHash == other.storedHash &&
          recomputedHash == other.recomputedHash &&
          isValid == other.isValid;

  @override
  int get hashCode => 
      ledgerId.hashCode ^ 
      storedHash.hashCode ^ 
      recomputedHash.hashCode ^ 
      isValid.hashCode;
}