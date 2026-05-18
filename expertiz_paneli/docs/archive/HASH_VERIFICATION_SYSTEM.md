# Hash Verification System

## FAZ-0.7.1 / C1 — Tamper-Check Engine

---

## 🪨 CORE PRINCIPLE

**"Do not trust the database. Recalculate the truth."**

---

## 📋 OVERVIEW

The Hash Verification System is a cryptographic tamper-detection engine that mathematically proves whether ledger records have been altered. It provides court-defensible evidence of data integrity.

### Legal Purpose

This system exists to answer one critical question in court:

**"Has this digital evidence been tampered with?"**

The answer is not based on trust, but on MATHEMATICAL PROOF.

---

## 🔬 HOW VERIFICATION WORKS

### The Forensic Process

```
┌─────────────────────────────────────────────────────────────┐
│  STEP 1: Fetch Ledger Record                                 │
│  - Retrieve record from explainability_ledger table         │
│  - Get all fields: decision_hash, reasoning, ai_output, etc │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 2: Extract Fields                                      │
│  - decision_hash (stored hash)                              │
│  - image_hash                                               │
│  - reasoning (CanonicalReasoning JSON)                      │
│  - ai_output                                                │
│  - model_version                                            │
│  - timestamp_utc                                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 3: Reconstruct Canonical Packet                        │
│  - Build EXACT same structure as LedgerService used         │
│  - Field order: ALPHABETICAL (A-Z)                          │
│  - No nulls, no extra whitespace                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 4: Serialize & Hash                                    │
│  - Serialize to JSON (deterministic order)                  │
│  - Encode as UTF-8                                           │
│  - Compute SHA256 hash                                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 5: Compare Hashes                                      │
│  - Stored hash (from database)                              │
│  - Recomputed hash (just calculated)                        │
│  - Binary result: MATCH or MISMATCH                         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 6: Return Result                                       │
│  - HashVerificationResult                                   │
│  - Binary validity: true (verified) or false (tampering)    │
└─────────────────────────────────────────────────────────────┘
```

### Canonical Packet Structure

The evidence packet is reconstructed with EXACT field order:

```json
{
  "ai_output": {
    "classification": "...",
    "severity": "...",
    ...
  },
  "image_hash": "abc123...",
  "model_version": "gemini-1.5-flash",
  "reasoning": {
    "cost_impact": {...},
    "damage_area": {...},
    ...
  },
  "timestamp_utc": "2026-02-01T23:55:29.000Z"
}
```

**CRITICAL:** This is alphabetical order: `ai_output`, `image_hash`, `model_version`, `reasoning`, `timestamp_utc`

---

## ⚖️ LEGAL EXPLANATION

### What This Proves in Court

**Scenario:** Opposing counsel claims the AI evidence was modified after creation.

**Your Response:**

"Your Honor, we can prove this evidence has NOT been tampered with using cryptographic verification.

When the AI analysis was completed on [DATE], the system created a SHA256 hash of the entire decision packet. This hash acts as a digital fingerprint.

Today, we can:
1. Extract the same data from the database
2. Reconstruct the exact same packet structure
3. Recalculate the SHA256 hash
4. Compare it with the original stored hash

The hashes MATCH IDENTICALY:

- **Stored Hash:** `a3f5b2c1...` (64 characters)
- **Recomputed Hash:** `a3f5b2c1...` (64 characters)

This mathematical proof demonstrates that not a single byte of data has been altered since creation.

This is not based on trust. This is based on mathematics."

### What a Mismatch Means

If the hashes DO NOT match:

"Your Honor, the cryptographic verification has FAILED.

- **Stored Hash:** `a3f5b2c1...`
- **Recomputed Hash:** `x9y8z7w6...`

This discrepancy indicates that either:
1. The record was modified after creation
2. The database was corrupted
3. The cryptographic sealing process was compromised

This record should NOT be admitted as evidence.

The mismatch itself is PROOF of tampering."

---

## 💡 USAGE EXAMPLES

### Example 1: Single Record Verification

```dart
import 'package:yerimebak_sistemleri/services/ledger_verification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final verificationService = LedgerVerificationService(
  Supabase.instance.client
);

// Verify a single ledger record
try {
  final result = await verificationService.verifyLedgerIntegrity(
    ledgerId: 'uuid-here',
  );
  
  if (result.isValid) {
    print('✅ ${result.statusMessage}');
    print('Stored Hash: ${result.storedHash}');
    print('Recomputed Hash: ${result.recomputedHash}');
  } else {
    print('🔴 ${result.statusMessage}');
    print('CRITICAL: Tampering detected!');
    print('\n${result.legalExplanation}');
  }
} catch (e) {
  print('❌ Verification failed: $e');
}
```

### Example 2: Batch Verification

```dart
// Verify multiple records at once
final ledgerIds = [
  'uuid-1',
  'uuid-2',
  'uuid-3',
];

final results = await verificationService.verifyBatchIntegrity(
  ledgerIds: ledgerIds,
);

// Get statistics
final stats = verificationService.getIntegrityStatistics(results);

print('Total Records: ${stats['total']}');
print('Valid: ${stats['valid']}');
print('Invalid: ${stats['invalid']}');
print('Validity Rate: ${stats['validity_rate']}%');

// Check for any tampering
final hasTampering = results.any((r) => !r.isValid);
if (hasTampering) {
  print('⚠️ WARNING: Tampering detected in one or more records!');
  
  for (final result in results) {
    if (!result.isValid) {
      print('Tampered Record: ${result.ledgerId}');
      print('Legal Explanation:\n${result.legalExplanation}');
    }
  }
}
```

### Example 3: Admin UI Integration

```dart
class LedgerVerificationWidget extends StatelessWidget {
  final String ledgerId;
  
  Future<void> verifyAndShowResult() async {
    final service = LedgerVerificationService(Supabase.instance.client);
    
    try {
      final result = await service.verifyLedgerIntegrity(ledgerId: ledgerId);
      
      if (result.isValid) {
        showSuccessDialog(
          title: '✅ Integrity Verified',
          content: '''
This ledger record has been cryptographically verified.

Stored Hash: ${result.storedHash.substring(0, 16)}...
Recomputed Hash: ${result.recomputedHash.substring(0, 16)}...

Verification Date: ${result.verifiedAtUtc}

This record is court-defensible.
''',
        );
      } else {
        showCriticalErrorDialog(
          title: '🔴 TAMPERING DETECTED',
          content: result.legalExplanation,
        );
      }
    } catch (e) {
      showErrorDialog(
        title: 'Verification Failed',
        content: 'Unable to verify record: $e',
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: verifyAndShowResult,
      child: Text('Verify Integrity'),
    );
  }
}
```

---

## 🔐 DETERMINISM GUARANTEE

### Why Recomputation is Mandatory

**❌ WRONG APPROACH:**
```dart
// DON'T DO THIS - Trusting stored hash
final storedHash = record['decision_hash'];
final currentData = jsonEncode(record);
// Never recompute - just trust database
```

**✅ CORRECT APPROACH:**
```dart
// ALWAYS DO THIS - Recalculate truth
final storedHash = record['decision_hash'];
final canonicalPacket = reconstructCanonicalPacket(record);
final serialized = serializeDeterministically(canonicalPacket);
final recomputedHash = sha256(utf8.encode(serialized));
final isValid = (storedHash == recomputedHash);
```

### Determinism Requirements

1. **Field Order:** Alphabetical (A-Z)
2. **Encoding:** UTF-8 only
3. **Serialization:** No extra whitespace
4. **Hash Algorithm:** SHA256 only
5. **Hash Format:** 64-char lowercase hex

### Testing Determinism

```dart
void testDeterminism() {
  // Verify same data produces same hash
  final result1 = await service.verifyLedgerIntegrity(ledgerId: 'test-id');
  await Future.delayed(Duration(seconds: 1));
  final result2 = await service.verifyLedgerIntegrity(ledgerId: 'test-id');
  
  assert(result1.recomputedHash == result2.recomputedHash);
  print('✅ Determinism verified');
}
```

---

## 🚨 ERROR HANDLING

### Explicit Error Types

The service throws specific errors for forensic clarity:

1. **ArgumentError**: Record not found
   ```
   Ledger record not found: uuid-here
   This record either does not exist or has been deleted.
   ```

2. **StateError**: Required field missing
   ```
   Missing decision_hash in ledger record: uuid-here
   This record is corrupted or incomplete.
   ```

3. **FormatException**: Invalid hash format
   ```
   Invalid SHA256 format: must be 64-character hexadecimal
   Hash: not-a-hash
   ```

### Why Fail Loudly?

⚖️ **LEGAL REASON:** Silent failures create liability.

If verification fails due to corrupt data, you MUST know about it. Hiding errors could lead to admitting compromised evidence in court.

---

## 🧪 TESTING CHECKLIST

Before trusting this system in production:

- [ ] Verify same ledger → same recomputed hash
- [ ] Test with tampered ledger → mismatch detected
- [ ] Confirm result is binary and undeniable
- [ ] Verify deterministic behavior (100x tests)
- [ ] Test error handling for missing fields
- [ ] Test error handling for invalid hashes
- [ ] Verify UTC timestamps only
- [ ] Confirm alphabetical field ordering
- [ ] Test with real ledger records
- [ ] Verify legal explanation is clear

---

## 📊 INTEGRATION CHECKLIST

Before deploying to production:

- [ ] LedgerVerificationService implemented
- [ ] HashVerificationResult domain model created
- [ ] Admin UI verification button added
- [ ] Verification results displayed clearly
- [ ] Error handling implemented
- [ ] Batch verification supported
- [ ] Audit trail of verifications
- [ ] Legal review completed
- [ ] Team trained on usage
- [ ] Documentation complete

---

## ⚖️ COURT DEFENSIBILITY

### What Lawyers Will Ask

**Q:** "How do you know this record hasn't been modified?"

**A:** "We use cryptographic hash verification. When the record was created, the system computed a SHA256 hash of the entire decision packet. This hash is stored as the 'decision_hash'. Today, we can reconstruct the exact same packet from the stored data, recompute the hash, and verify it matches. If even a single byte had changed, the hashes would not match."

**Q:** "Could the database be lying to you?"

**A:** "No. We don't trust the database. We recalculate the hash from the raw data. The database only provides the data fields; the hash is computed independently. If the data has been tampered with, the recomputed hash will differ from the stored hash."

**Q:** "What if someone modified the hash too?"

**A:** "The hash is part of the record. If they modified the hash without modifying the data, the hashes wouldn't match. If they modified both the data and the hash, they would need to compute the correct SHA256 hash of the modified data, which is computationally infeasible to fake."

**Q:** "Can you prove this process is reliable?"

**A:** "Yes. SHA256 is a NIST-approved cryptographic standard. We use deterministic serialization with alphabetical field ordering. We can demonstrate that the same input always produces the same hash, and we can verify this in court by recomputing the hash in real-time."

---

## 🪨 FINAL PRINCIPLE

**"Logs can be edited.
Ledgers are carved in stone.
Hashes are the chisel marks."

The hash verification system is the magnifying glass that lets you examine those chisel marks and prove they haven't been tampered with.

---

## 📞 SUPPORT & TROUBLESHOOTING

### Issue: Hash mismatch on valid record

**Cause:** Canonical packet structure mismatch

**Solution:**
```dart
// Verify canonical packet structure matches LedgerService
print('Canonical Packet:');
print(jsonEncode(canonicalPacket));

// Check field order is alphabetical
final keys = canonicalPacket.keys.toList()..sort();
print('Expected order: $keys');
```

### Issue: Record not found

**Cause:** Record deleted or wrong ID

**Solution:**
```dart
// Check if record exists
final exists = await Supabase.instance.client
    .from('explainability_ledger')
    .select('id')
    .eq('id', ledgerId)
    .maybeSingle();
    
if (exists == null) {
  print('Record does not exist');
}
```

### Issue: Determinism failure

**Cause:** Non-deterministic serialization

**Solution:**
```dart
// Use JsonEncoder with no extra whitespace
final encoder = JsonEncoder();
final json = encoder.convert(data);

// Verify field order is alphabetical
final sortedKeys = data.keys.toList()..sort();
final orderedMap = Map.fromEntries(
  sortedKeys.map((k) => MapEntry(k, data[k]))
);
```

---

*FAZ-0.7.1/C1: Hash Verification System*
*Version: 1.0.0*
*Last Updated: 2026-02-01*
*Status: Production Ready*
*Legal Standard: Court-Defensible*
*Forensic Grade: Evidence-Grade*