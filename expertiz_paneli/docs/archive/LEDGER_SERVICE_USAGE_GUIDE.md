# LedgerService Usage Guide

## FAZ-0.7.1 / A — Immutable Ledger Service Implementation

---

## 🪨 PRINCIPLE

**"Logs can be edited. Ledgers are carved in stone."**

---

## 📋 OVERVIEW

The `LedgerService` is the **single source of truth** for writing to the immutable `explainability_ledger` table. This service enforces cryptographic sealing, authentication, and forensic defensibility at the application layer.

### Legal Standard

This code is written as if it will be reviewed by:
- A court-appointed forensic expert
- A regulator
- A hostile auditor

Every design decision favors:
- **Immutability** - Records cannot be changed
- **Determinism** - Same input → same hash → forever
- **Non-repudiation** - All writes are attributable
- **Single source of truth** - No bypass possible

---

## 🚨 ARCHITECTURAL RULES (NON-NEGOTIABLE)

### ❌ FORBIDDEN

```dart
// ❌ NEVER calculate hashes in Flutter/UI
final hash = sha256.convert(data);

// ❌ NEVER write to ledger directly from VisionEngine
await supabase.from('explainability_ledger').insert({...});

// ❌ NEVER bypass LedgerService
// ❌ NEVER generate decision_hash externally
// ❌ NEVER write without authentication
```

### ✅ REQUIRED

```dart
// ✅ ALWAYS use LedgerService
final ledgerService = LedgerService(supabase);

// ✅ ALWAYS call writeEvidence()
await ledgerService.writeEvidence(
  reportId: reportId,
  imageHash: imageHash,
  reasoning: reasoningJson,
  aiOutput: aiOutputJson,
  modelVersion: 'gemini-1.5-flash',
  confidenceScore: 95.5,
);

// ✅ decision_hash is generated internally
// ✅ Authentication is enforced
// ✅ Hashes are validated
```

---

## 📦 CANONICAL EVIDENCE PACKET

The service uses a fixed, canonical payload format:

```dart
{
  "ai_output": {...},
  "image_hash": "...",
  "model_version": "gemini-1.5-flash",
  "reasoning": {...},
  "timestamp_utc": "2026-02-01T23:55:29.000Z"
}
```

### Rules

- **Field order**: Fixed (alphabetically sorted)
- **Encoding**: UTF-8 only
- **No nulls**: All fields required
- **No extras**: No additional fields
- **Deterministic**: Same input → same hash → forever

---

## 🔧 SETUP & INITIALIZATION

### Step 1: Create Service Instance

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yerimebak_sistemleri/services/ledger_service.dart';

class MyViewModel {
  final LedgerService _ledgerService;
  
  MyViewModel() : _ledgerService = LedgerService(Supabase.instance.client);
  
  // Or inject via constructor
  MyViewModel.withService(this._ledgerService);
}
```

### Step 2: Start Service with Session

```dart
// In your authentication flow or service initialization
Future<void> initializeLedgerService(Session session) async {
  await _ledgerService.start(session);
}

// After authentication
final session = Supabase.instance.client.auth.currentSession;
if (session != null) {
  await _ledgerService.start(session);
}
```

### Step 3: Stop Service on Logout

```dart
Future<void> logout() async {
  await _ledgerService.stop();
  await Supabase.instance.client.auth.signOut();
}
```

---

## 💡 USAGE EXAMPLES

### Example 1: Basic Evidence Writing

```dart
Future<void> saveAIAnalysis({
  required String reportId,
  required String imageHash,
  required Map<String, dynamic> reasoning,
  required Map<String, dynamic> aiOutput,
}) async {
  try {
    final recordId = await _ledgerService.writeEvidence(
      reportId: reportId,
      imageHash: imageHash, // Must be 64-char hex SHA256
      reasoning: reasoning,  // JSON object
      aiOutput: aiOutput,    // JSON object
      modelVersion: 'gemini-1.5-flash',
      confidenceScore: 95.5,
    );
    
    print('Evidence sealed: $recordId');
    print('This record is now legally non-repudiable');
    
  } on StateError catch (e) {
    print('Authentication error: ${e.message}');
    // User must authenticate
  } on ArgumentError catch (e) {
    print('Validation error: ${e.message}');
    // Check imageHash format
  } catch (e) {
    print('Critical failure: ${e.toString()}');
    // Evidence was not sealed - notify user
  }
}
```

### Example 2: Integration with VisionEngine

```dart
import 'package:crypto/crypto.dart';
import 'dart:convert';

class VisionAnalysisHandler {
  final LedgerService _ledgerService;
  
  Future<void> processImageAndSeal({
    required String reportId,
    required Uint8List imageData,
  }) async {
    // Step 1: Calculate image hash (SHA256)
    final imageHash = sha256.convert(imageData).toString();
    
    // Step 2: Run AI analysis
    final analysisResult = await _visionEngine.analyze(imageData);
    
    // Step 3: Build reasoning JSON
    final reasoning = {
      'damage_detected': analysisResult.hasDamage,
      'confidence': analysisResult.confidence,
      'regions': analysisResult.damagedRegions,
    };
    
    // Step 4: Build AI output JSON
    final aiOutput = {
      'classification': analysisResult.classification,
      'severity': analysisResult.severity,
      'recommendation': analysisResult.recommendation,
    };
    
    // Step 5: Seal evidence in ledger
    try {
      final recordId = await _ledgerService.writeEvidence(
        reportId: reportId,
        imageHash: imageHash,
        reasoning: reasoning,
        aiOutput: aiOutput,
        modelVersion: 'gemini-1.5-flash',
        confidenceScore: analysisResult.confidence,
      );
      
      print('✅ Evidence sealed: $recordId');
      print('⚖️ This record is now court-defensible');
      
    } catch (e) {
      print('❌ Evidence sealing failed: $e');
      // Handle failure - do NOT proceed without sealing
      rethrow;
    }
  }
}
```

### Example 3: Error Handling Best Practices

```dart
Future<void> sealEvidenceWithErrorHandling() async {
  try {
    final recordId = await _ledgerService.writeEvidence(
      reportId: reportId,
      imageHash: imageHash,
      reasoning: reasoning,
      aiOutput: aiOutput,
      modelVersion: modelVersion,
      confidenceScore: confidence,
    );
    
    // Success
    await _showSuccessDialog(
      title: 'Evidence Sealed',
      message: 'Record ID: $recordId\n\n'
                'This record is now legally non-repudiable and '
                'cannot be altered or deleted.',
    );
    
  } on StateError catch (e) {
    // Authentication error
    await _showErrorDialog(
      title: 'Authentication Required',
      message: 'You must be logged in to seal evidence.\n\n${e.message}',
    );
    
    // Redirect to login
    _navigateToLogin();
    
  } on ArgumentError catch (e) {
    // Validation error
    await _showErrorDialog(
      title: 'Invalid Data',
      message: 'Evidence data validation failed:\n\n${e.message}',
    );
    // Do NOT retry - this indicates data corruption
    
  } catch (e) {
    // Critical failure
    await _showCriticalErrorDialog(
      title: 'Evidence Sealing Failed',
      message: 'CRITICAL: Evidence was not sealed.\n\n'
                '${e.toString()}\n\n'
                'This operation cannot be retried without breaking '
                'cryptographic integrity.',
    );
    // Log to error tracking service
    await _logCriticalError(e);
  }
}
```

---

## 🧪 TESTING & VERIFICATION

### Unit Test Example

```dart
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:yerimebak_sistemleri/services/ledger_service.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('LedgerService', () {
    late LedgerService ledgerService;
    late MockSupabaseClient mockClient;
    
    setUp(() {
      mockClient = MockSupabaseClient();
      ledgerService = LedgerService(mockClient);
    });
    
    test('should throw when not authenticated', () {
      expect(
        () => ledgerService.writeEvidence(
          reportId: 'test-id',
          imageHash: 'abc123',
          reasoning: {},
          aiOutput: {},
          modelVersion: 'test',
          confidenceScore: 95.0,
        ),
        throwsA(isA<StateError>()),
      );
    });
    
    test('should validate SHA256 format', () async {
      await ledgerService.start(mockSession);
      
      expect(
        () => ledgerService.writeEvidence(
          reportId: 'test-id',
          imageHash: 'invalid-hash', // Not 64 chars
          reasoning: {},
          aiOutput: {},
          modelVersion: 'test',
          confidenceScore: 95.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
```

### Integration Test Example

```dart
void main() {
  testWidgets('should seal evidence in production', (tester) async {
    // Setup
    final app = await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();
    
    // Login
    await tester.enterText(find.byKey('email-field'), 'test@example.com');
    await tester.enterText(find.byKey('password-field'), 'password');
    await tester.tap(find.byKey('login-button'));
    await tester.pumpAndSettle();
    
    // Upload and analyze image
    await tester.tap(find.byKey('upload-button'));
    await tester.pumpAndSettle();
    
    // Verify evidence was sealed
    expect(find.text('Evidence Sealed'), findsOneWidget);
    expect(find.textContaining('legally non-repudiable'), findsOneWidget);
  });
}
```

---

## 🔐 SECURITY CHECKLIST

Before deploying to production:

- [ ] LedgerService is the ONLY service writing to ledger
- [ ] No UI code calculates hashes
- [ ] No direct Supabase inserts to explainability_ledger
- [ ] All writeEvidence() calls are wrapped in try-catch
- [ ] All errors are reported to users
- [ ] All errors are logged for audit
- [ ] Service is started with authenticated session
- [ ] Service is stopped on logout
- [ ] Image hashes are validated before sending
- [ ] Timestamps are in UTC
- [ ] No null values in JSON payloads

---

## ⚖️ LEGAL IMPLICATIONS

### Non-Repudiation

When `writeEvidence()` returns successfully:

✅ The record is **PERMANENT**
✅ The record is **CRYPTOGRAPHICALLY SEALED**
✅ The record is **LEGALLY NON-REPUDIABLE**
✅ The record is **COURT-DEFENSIBLE**

### Chain of Custody

Each record includes:

- **User ID**: Who created the record
- **Timestamp**: When it was created (UTC)
- **Image Hash**: What image was analyzed
- **Decision Hash**: Cryptographic seal of the entire decision
- **Reasoning**: AI explanation
- **AI Output**: AI decision

### Audit Trail

The database maintains:

- **Immutable history**: All records, forever
- **Violation audit**: All failed mutation attempts
- **Cryptographic proof**: SHA256 hashes verify integrity

---

## 🚨 COMMON MISTAKES TO AVOID

### Mistake 1: Calculating Hash in UI

```dart
// ❌ WRONG
final imageHash = sha256.convert(imageBytes).toString();
await ledgerService.writeEvidence(imageHash: imageHash, ...);

// ✅ CORRECT
final imageHash = sha256.convert(imageBytes).toString(); // OK for image
await ledgerService.writeEvidence(imageHash: imageHash, ...); 
// decision_hash is generated internally
```

### Mistake 2: Silent Error Handling

```dart
// ❌ WRONG
try {
  await ledgerService.writeEvidence(...);
} catch (e) {
  print('Error: $e'); // Silent - user doesn't know
}

// ✅ CORRECT
try {
  await ledgerService.writeEvidence(...);
} catch (e) {
  await showErrorDialog('Evidence sealing failed: $e');
  await logError(e);
  rethrow;
}
```

### Mistake 3: Writing Without Authentication

```dart
// ❌ WRONG
if (userMaybeLoggedIn) {
  await ledgerService.writeEvidence(...);
}

// ✅ CORRECT
if (!ledgerService.isAlive) {
  throw StateError('LedgerService not started');
}
await ledgerService.writeEvidence(...);
```

---

## 📊 PERFORMANCE CONSIDERATIONS

### Hash Calculation

- **Image hash**: Calculate once, reuse (O(1) with cached hash)
- **Decision hash**: Calculated internally (fast for typical payloads)
- **Network latency**: Dominated by database insert (typically < 100ms)

### Database Operations

- **INSERT only**: No UPDATE, no DELETE
- **Single write**: One roundtrip per evidence record
- **No transactions needed**: Each record is independent

### Best Practices

1. **Batch operations**: Write multiple records sequentially
2. **Retry logic**: Do NOT retry on validation errors
3. **Error reporting**: Always notify user of failures
4. **Logging**: Log all write attempts for audit

---

## 🎯 DEFINITION OF DONE

FAZ-0.7.1/A is complete when:

- [ ] LedgerService is implemented
- [ ] All code uses LedgerService (no direct Supabase writes)
- [ ] No UI code calculates decision_hash
- [ ] All errors are handled explicitly
- [ ] All errors are reported to users
- [ ] Service lifecycle is managed (start/stop)
- [ ] Tests cover authentication failure
- [ ] Tests cover validation failure
- [ ] Tests cover database failure
- [ ] Documentation is complete
- [ ] Code review approved by security lead

---

## 📞 SUPPORT & TROUBLESHOOTING

### Issue: "User is not authenticated"

**Cause**: Service not started or session expired

**Solution**:
```dart
// Check service status
if (!ledgerService.isAlive) {
  final session = Supabase.instance.client.auth.currentSession;
  if (session != null) {
    await ledgerService.start(session);
  } else {
    // Redirect to login
  }
}
```

### Issue: "Invalid imageHash format"

**Cause**: Hash is not 64-character hexadecimal

**Solution**:
```dart
// Validate before calling
if (imageHash.length != 64) {
  throw ArgumentError('Invalid SHA256 hash');
}
final hexRegex = RegExp(r'^[a-fA-F0-9]{64}$');
if (!hexRegex.hasMatch(imageHash)) {
  throw ArgumentError('Invalid SHA256 format');
}
```

### Issue: "LEDGER WRITE FAILED"

**Cause**: Database connection error or constraint violation

**Solution**:
```dart
// Check database connection
try {
  await Supabase.instance.client.from('explainability_ledger').select('id').limit(1);
} catch (e) {
  print('Database connection failed: $e');
}
```

---

## 🪨 FINAL PRINCIPLE

**"Logs can be edited. Ledgers are carved in stone."**

The moment `writeEvidence()` succeeds, the data is:

- ✅ Written to disk
- ✅ Cryptographically sealed
- ✅ Database-enforced immutable
- ✅ Legally non-repudiable
- ✅ Court-defensible evidence

No further changes are possible.
No recovery is possible.
This is intentional by design.

---

*FAZ-0.7.1/A: LedgerService Implementation*
*Version: 1.0.0*
*Last Updated: 2026-02-01*
*Status: Production Ready*