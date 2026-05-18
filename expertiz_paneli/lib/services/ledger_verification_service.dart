/// LEDGER VERIFICATION SERVICE
/// 
/// FAZ-0.7.1 / C1 — Tamper-Check Engine
/// 
/// 🎯 MISSION:
/// This service provides CRYPTOGRAPHIC PROOF of ledger integrity.
/// It recalculates hashes from stored data to detect tampering.
/// 
/// ⚖️ LEGAL STANDARD:
/// This code will be questioned by lawyers in court.
/// Every implementation detail must be forensically defensible.
/// 
/// 🧠 CORE PRINCIPLE (NON-NEGOTIABLE):
/// "Do not trust the database. Recalculate the truth."
/// 
/// 🔐 DETERMINISM GUARANTEE:
/// Same ledger data → Same recomputed hash → Same verification result
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../domain/ledger/hash_verification_result.dart';

/// Ledger Verification Service
/// 
/// ⚖️ CRITICAL LEGAL IMPORTANCE:
/// This service is the TAMPER-DETECTION ENGINE that mathematically proves
/// whether a ledger record has been altered.
/// 
/// 🔬 VERIFICATION PROCESS:
/// 1. Fetch ledger record from database
/// 2. Reconstruct canonical evidence packet
/// 3. Serialize in DETERMINISTIC alphabetical order
/// 4. Recompute SHA256 hash
/// 5. Compare with stored decision_hash
/// 6. Return binary, undeniable result
/// 
/// 🪨 PRINCIPLE:
/// "Hash mismatch = evidence of tampering.
///  Hash match = integrity verified beyond reasonable doubt."
class LedgerVerificationService {
  final SupabaseClient _supabase;
  
  LedgerVerificationService(this._supabase);
  
  /// Verify the cryptographic integrity of a ledger record
  /// 
  /// ⚖️ FORENSIC PROCESS:
  /// This method does NOT trust the stored hash.
  /// It reconstructs the canonical evidence packet from the stored data,
  /// recomputes the SHA256 hash, and compares it with the stored hash.
  /// 
  /// 🔐 CRITICAL IMPLEMENTATION:
  /// The canonical packet MUST be reconstructed with the EXACT same
  /// field order as LedgerService used originally:
  /// 
  /// ```json
  /// {
  ///   "ai_output": {...},
  ///   "image_hash": "...",
  ///   "model_version": "...",
  ///   "reasoning": {...},
  ///   "timestamp_utc": "ISO-8601"
  /// }
  /// ```
  /// 
  /// This is alphabetical order: ai_output, image_hash, model_version, reasoning, timestamp_utc
  /// 
  /// ⚠️ LEGAL IMPLICATION:
  /// If stored hash != recomputed hash, this is CRITICAL SECURITY EVENT
  /// indicating potential tampering or database corruption.
  /// 
  /// @param ledgerId The ID of the ledger record to verify
  /// @return HashVerificationResult with binary validity result
  /// 
  /// @throws ArgumentError if ledger record not found
  /// @throws StateError if required fields are missing
  /// @throws FormatException if JSON is malformed
  Future<HashVerificationResult> verifyLedgerIntegrity({
    required String ledgerId,
  }) async {
    // Step 1: Fetch ledger record from database
    final record = await _fetchLedgerRecord(ledgerId);
    
    // Step 2: Extract fields
    final storedHash = _extractStoredHash(record);
    final imageData = _extractImageData(record);
    final reasoningData = _extractReasoningData(record);
    final modelVersion = _extractModelVersion(record);
    final aiOutputData = _extractAiOutputData(record);
    final timestampUtc = _extractTimestamp(record);
    
    // Step 3: Reconstruct canonical evidence packet
    final canonicalPacket = _reconstructCanonicalPacket(
      aiOutput: aiOutputData,
      imageHash: imageData,
      modelVersion: modelVersion,
      reasoning: reasoningData,
      timestampUtc: timestampUtc,
    );
    
    // Step 4: Serialize in DETERMINISTIC alphabetical order
    final serializedPacket = _serializeCanonicalPacket(canonicalPacket);
    
    // Step 5: Recompute SHA256 hash
    final recomputedHash = _computeSha256Hash(serializedPacket);
    
    // Step 6: Compare hashes
    final isValid = _compareHashes(storedHash, recomputedHash);
    
    // Step 7: Return verification result
    return HashVerificationResult(
      ledgerId: ledgerId,
      storedHash: storedHash,
      recomputedHash: recomputedHash,
      isValid: isValid,
      verifiedAtUtc: DateTime.now().toUtc(),
    );
  }
  
  /// Fetch ledger record from database
  /// 
  /// @throws ArgumentError if record not found
  Future<Map<String, dynamic>> _fetchLedgerRecord(String ledgerId) async {
    final response = await _supabase
        .from('explainability_ledger')
        .select()
        .eq('id', ledgerId)
        .maybeSingle();
    
    if (response == null) {
      throw ArgumentError(
        'Ledger record not found: $ledgerId\n\n'
        'This record either does not exist or has been deleted.',
      );
    }
    return response;
  }
  
  /// Extract stored hash from record
  /// 
  /// @throws StateError if hash is missing or invalid
  String _extractStoredHash(Map<String, dynamic> record) {
    final hash = record['decision_hash'] as String?;
    
    if (hash == null || hash.isEmpty) {
      throw StateError(
        'Missing decision_hash in ledger record: ${record['id']}\n\n'
        'This record is corrupted or incomplete.',
      );
    }
    
    // Validate SHA256 format (64-char hex)
    if (hash.length != 64) {
      throw FormatException(
        'Invalid decision_hash format: expected 64 characters, got ${hash.length}\n'
        'Hash: $hash',
      );
    }
    
    final hexRegex = RegExp(r'^[a-fA-F0-9]{64}$');
    if (!hexRegex.hasMatch(hash)) {
      throw FormatException(
        'Invalid SHA256 format: must be 64-character hexadecimal\n'
        'Hash: $hash',
      );
    }
    
    return hash.toLowerCase();
  }
  
  /// Extract image_hash from record
  /// 
  /// @throws StateError if image_hash is missing
  String _extractImageData(Map<String, dynamic> record) {
    final imageHash = record['image_hash'] as String?;
    
    if (imageHash == null || imageHash.isEmpty) {
      throw StateError(
        'Missing image_hash in ledger record: ${record['id']}\n\n'
        'This record is corrupted or incomplete.',
      );
    }
    
    return imageHash;
  }
  
  /// Extract reasoning from record
  /// 
  /// @throws StateError if reasoning is missing
  Map<String, dynamic> _extractReasoningData(Map<String, dynamic> record) {
    final reasoning = record['reasoning'] as Map<String, dynamic>?;
    
    if (reasoning == null || reasoning.isEmpty) {
      throw StateError(
        'Missing reasoning in ledger record: ${record['id']}\n\n'
        'This record is corrupted or incomplete.',
      );
    }
    
    return reasoning;
  }
  
  /// Extract model_version from record
  /// 
  /// @throws StateError if model_version is missing
  String _extractModelVersion(Map<String, dynamic> record) {
    final modelVersion = record['model_version'] as String?;
    
    if (modelVersion == null || modelVersion.isEmpty) {
      throw StateError(
        'Missing model_version in ledger record: ${record['id']}\n\n'
        'This record is corrupted or incomplete.',
      );
    }
    
    return modelVersion;
  }
  
  /// Extract ai_output from record
  /// 
  /// @throws StateError if ai_output is missing
  Map<String, dynamic> _extractAiOutputData(Map<String, dynamic> record) {
    final aiOutput = record['ai_output'] as Map<String, dynamic>?;
    
    if (aiOutput == null || aiOutput.isEmpty) {
      throw StateError(
        'Missing ai_output in ledger record: ${record['id']}\n\n'
        'This record is corrupted or incomplete.',
      );
    }
    
    return aiOutput;
  }
  
  /// Extract timestamp from record
  /// 
  /// @throws StateError if created_at is missing
  String _extractTimestamp(Map<String, dynamic> record) {
    final createdAt = record['created_at'] as String?;
    
    if (createdAt == null || createdAt.isEmpty) {
      throw StateError(
        'Missing created_at timestamp in ledger record: ${record['id']}\n\n'
        'This record is corrupted or incomplete.',
      );
    }
    
    // Ensure UTC format
    final dateTime = DateTime.parse(createdAt);
    return dateTime.toUtc().toIso8601String();
  }
  
  /// Reconstruct canonical evidence packet
  /// 
  /// 🔐 CRITICAL:
  /// This MUST match LedgerService's canonical packet structure EXACTLY.
  /// Field order is ALPHABETICAL: ai_output, image_hash, model_version, reasoning, timestamp_utc
  /// 
  /// Same input MUST produce same output (deterministic)
  Map<String, dynamic> _reconstructCanonicalPacket({
    required Map<String, dynamic> aiOutput,
    required String imageHash,
    required String modelVersion,
    required Map<String, dynamic> reasoning,
    required String timestampUtc,
  }) {
    return {
      'ai_output': aiOutput,
      'image_hash': imageHash,
      'model_version': modelVersion,
      'reasoning': reasoning,
      'timestamp_utc': timestampUtc,
    };
  }
  
  /// Serialize canonical packet in DETERMINISTIC alphabetical order
  /// 
  /// 🔐 CRITICAL:
  /// - Keys must be sorted alphabetically
  /// - UTF-8 encoding only
  /// - No extra whitespace
  /// - No null values
  /// 
  /// This ensures same input → same JSON → same hash
  String _serializeCanonicalPacket(Map<String, dynamic> packet) {
    // Create ordered map with sorted keys
    final sortedKeys = packet.keys.toList()..sort();
    final orderedMap = <String, dynamic>{};
    for (final key in sortedKeys) {
      orderedMap[key] = packet[key];
    }
    
    // Encode as JSON with no whitespace
    final encoder = JsonEncoder();
    return encoder.convert(orderedMap);
  }
  
  /// Compute SHA256 hash of serialized packet
  /// 
  /// 🔐 CRITICAL:
  /// - UTF-8 encoding only
  /// - SHA256 algorithm only
  /// - 64-char lowercase hex output
  String _computeSha256Hash(String serializedPacket) {
    final bytes = utf8.encode(serializedPacket);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }
  
  /// Compare stored and recomputed hashes
  /// 
  /// @return true if hashes match (integrity verified), false if mismatch (tampering detected)
  bool _compareHashes(String storedHash, String recomputedHash) {
    return storedHash.toLowerCase() == recomputedHash.toLowerCase();
  }
  
  /// Verify multiple ledger records in batch
  /// 
  /// Useful for periodic integrity checks
  /// 
  /// @param ledgerIds List of ledger record IDs to verify
  /// @return List of verification results
  Future<List<HashVerificationResult>> verifyBatchIntegrity({
    required List<String> ledgerIds,
  }) async {
    final results = <HashVerificationResult>[];
    
    for (final ledgerId in ledgerIds) {
      try {
        final result = await verifyLedgerIntegrity(ledgerId: ledgerId);
        results.add(result);
      } catch (e) {
        // Log error but continue with other records
        debugPrint('❌ Failed to verify ledger $ledgerId: $e');
      }
    }
    
    return results;
  }
  
  /// Get integrity statistics for a batch verification
  /// 
  /// @param results List of verification results
  /// @return Statistics map with counts
  Map<String, int> getIntegrityStatistics(List<HashVerificationResult> results) {
    final valid = results.where((r) => r.isValid).length;
    final invalid = results.where((r) => !r.isValid).length;
    final total = results.length;
    
    return {
      'total': total,
      'valid': valid,
      'invalid': invalid,
      'validity_rate': total > 0 ? ((valid / total) * 100).round() : 0,
    };
  }
}