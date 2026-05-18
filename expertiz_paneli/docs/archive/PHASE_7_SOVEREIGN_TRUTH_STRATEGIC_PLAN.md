# PHASE 7 - The Sovereign Truth (FINAL FORM) - STRATEGIC PLAN

**Date:** February 3, 2026  
**Status:** 📋 **STRATEGIC PLAN COMPLETE**  
**Mission:** Hukuki, adli ve matematiksel olarak inkâr edilemez sistem

---

## ⚠️ EXECUTIVE SUMMARY

Phase 7, YerimeBak sistemini "doğru çalışan" bir sistemden **"hukuken savunulbilir bir gerçeklik makinesi"**ne dönüştüren final fazdır.

**Critical Additions (User-Specified):**
1. **Linearization Point** - Transaction commit anında karar
2. **State Freeze** - Conflict anında operasyonları bloke
3. **Forensic Zaman Ayrımı** - Server vs client timestamps
4. **Conflict'in Kendisi De Audit** - Conflict olayları da kaydedilir

**Status:** Infrastructure ready, implementation requires significant work.

---

## ✅ EXISTING INFRASTRUCTURE (READY)

### 1. OperationIntent Model ✅
**File:** `lib/models/operation_intent.dart` (220+ lines)

**Capabilities:**
- Unique `operation_id` (UUID)
- `baseVersionId` and `baseRevisionHash` tracking
- `conflictsWith()` method
- `canMergeWithServer()` method
- JSON serialization for logging

### 2. AuditLog Model ✅
**File:** `lib/models/audit_log.dart`

**Existing Fields:**
- `action` (AuditAction enum)
- `timestamp`
- `userId`
- `details`

**Required Updates:**
- Add `operation_intent_id`
- Add `previous_hash`
- Add `current_hash`
- Add `server_committed_at`
- Add `event_type` for conflicts

### 3. System Truth Model ✅
**Declared in Phase 6.9:**
- Backend is FINAL authority
- Client operates on versioned snapshots
- Conflict detection via version mismatch

---

## 📋 REQUIRED IMPLEMENTATION WORK

### Step 1: Version Tracking (4-6 hours)

**AracRapor Model Updates:**
```dart
// Add to lib/models/arac_rapor_model.dart
class AracRapor {
  // EXISTING FIELDS...
  
  // NEW FIELDS:
  final String? versionId;           // UUID, server-generated
  final String? revisionHash;        // SHA-256 of canonical JSON
  final DateTime? serverCommittedAt; // UTC, authoritative
  final DateTime? clientObservedAt;  // UTC, informational
}
```

**Database Schema Updates:**
```sql
-- Migration script
ALTER TABLE arac_rapor 
ADD COLUMN version_id UUID DEFAULT gen_random_uuid(),
ADD COLUMN revision_hash TEXT,
ADD COLUMN server_committed_at TIMESTAMPTZ,
ADD COLUMN client_observed_at TIMESTAMPTZ;

-- Backfill existing records
UPDATE arac_rapor 
SET 
  version_id = gen_random_uuid(),
  server_committed_at = created_at,
  client_observed_at = updated_at
WHERE version_id IS NULL;

-- Index for conflict detection
CREATE INDEX idx_arac_rapor_version_id ON arac_rapor(version_id);
```

**Linearization Point Logic:**
```dart
// In ReportStateProvider or Service
Future<void> sealReport({
  required String reportId,
  required String baseVersionId,
}) async {
  // 1. Fetch current server state
  final current = await supabase
    .from('arac_rapor')
    .select()
    .eq('id', reportId)
    .single();
  
  // 2. LINEARIZATION POINT: Check version
  if (current['version_id'] != baseVersionId) {
    // CONFLICT DETECTED
    throw ConflictException(
      currentVersionId: current['version_id'],
      yourVersionId: baseVersionId,
    );
  }
  
  // 3. Only proceed if versions match
  final newVersionId = uuid.v4();
  await supabase
    .from('arac_rapor')
    .update({
      'durum': 'PUBLISHED',
      'version_id': newVersionId,
      'server_committed_at': DateTime.now().toUtc().toIso8601String(),
    })
    .eq('id', reportId);
  
  // 4. State ONLY changed on successful commit
}
```

### Step 2: Concurrency Test Suite (3-4 hours)

**Test File:** `test/integration/concurrency_test.dart`

```dart
void main() {
  testWidgets('Two admins, opposite intents, same version', (tester) async {
    // Setup: Two admin users
    final admin1 = AdminUser(id: 'admin1');
    final admin2 = AdminUser(id: 'admin2');
    
    // Setup: Report with version v1
    final report = Report(id: 'report1', versionId: 'v1', status: 'PENDING');
    
    // Action: Both try to act simultaneously
    final intent1 = OperationIntent.create(
      intentType: IntentType.seal,
      reportId: 'report1',
      baseVersionId: 'v1',
      userId: 'admin1',
    );
    
    final intent2 = OperationIntent.create(
      intentType: IntentType.reject,
      reportId: 'report1',
      baseVersionId: 'v1',
      userId: 'admin2',
    );
    
    // Execute both in same event loop tick
    final results = await Future.wait([
      repo.executeIntent(intent1),
      repo.executeIntent(intent2),
    ]);
    
    // ASSERTIONS:
    // 1. Only one succeeds
    final successCount = results.where((r) => r.isSuccess).length;
    expect(successCount, equals(1));
    
    // 2. One gets 409 Conflict
    final conflictCount = results.where((r) => r.isConflict).length;
    expect(conflictCount, equals(1));
    
    // 3. Server state is consistent
    final finalState = await repo.getReport('report1');
    expect(finalState.versionId, isNotNull);
    expect(finalState.status, isNot('PENDING')); // Sealed OR Rejected
    
    // 4. UI would auto-refresh
    // 5. Conflict UX would trigger for losing user
  });
}
```

### Step 3: Conflict UX - "The Explainer" (4-5 hours)

**Widget:** `lib/widgets/conflict_resolution_dialog.dart`

```dart
class ConflictResolutionDialog extends StatelessWidget {
  final OperationIntent attemptedIntent;
  final AcceptedTruth acceptedTruth;
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Icon(Icons.warning_amber, color: Colors.orange, size: 48),
            SizedBox(height: 16),
            Text('Çakışma Tespit Edildi', style: TextStyle(fontSize: 20)),
            
            SizedBox(height: 24),
            
            // 1. ATTEMPTED STATE
            _buildSection(
              title: 'Sizin İşleminiz',
              icon: Icons.person,
              content: [
                _buildRow('İşlem', _formatIntentType(attemptedIntent.intentType)),
                _buildRow('Sürüm', attemptedIntent.baseVersionId ?? 'Bilinmiyor'),
                _buildRow('Zaman', _formatTime(attemptedIntent.timestamp)),
              ],
            ),
            
            Divider(),
            
            // 2. ACCEPTED TRUTH
            _buildSection(
              title: 'Kabul Edilen İşlem',
              icon: Icons.check_circle,
              content: [
                _buildRow('Kullanıcı', acceptedTruth.actorUserId),
                _buildRow('Rol', acceptedTruth.actorRole),
                _buildRow('İşlem', _formatIntentType(acceptedTruth.intentType)),
                _buildRow('Zaman', _formatTime(acceptedTruth.serverCommittedAt)),
              ],
            ),
            
            SizedBox(height: 24),
            
            // 3. RESOLUTION PATH
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _syncAndRetry(context),
                    child: Text('Senkronize Et & Tekrar Dene'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _cancel(context),
                    child: Text('İptal'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

**State Freeze Logic:**
```dart
// In ReportStateProvider
bool _isConflictFrozen = false;

Future<void> handleConflict() async {
  // 1. Freeze state
  _isConflictFrozen = true;
  state = ConflictFrozenState();
  
  // 2. Block new operations
  // Provider returns error if user tries to act
  
  // 3. Show dialog
  showDialog(
    context: context,
    barrierDismissible: false, // Force user to decide
    builder: (_) => ConflictResolutionDialog(...),
  );
  
  // 4. Unfreeze after resolution
  _isConflictFrozen = false;
}
```

### Step 4: Forensic Audit Chain (3-4 hours)

**Updated AuditLog Model:**
```dart
class AuditLog {
  // EXISTING FIELDS...
  
  // NEW FIELDS:
  final String? operationIntentId;
  final String? previousHash;
  final String? currentHash;
  final DateTime? serverCommittedAt;
  final String? actorUserId;
  final String? actorRole;
  final AuditEventType eventType; // SEAL, REJECT, CONFLICT_DETECTED, etc.
}

enum AuditEventType {
  seal,
  reject,
  conflictDetected,
  conflictResolved,
  userAcknowledgedConflict,
}
```

**Hash Chain Implementation:**
```dart
class AuditChainService {
  Future<void> logEvent({
    required AuditEventType eventType,
    required String reportId,
    OperationIntent? intent,
    Map<String, dynamic>? details,
  }) async {
    // 1. Get previous hash
    final previousLog = await _getLatestLog(reportId);
    final previousHash = previousLog?.currentHash ?? _genesisHash();
    
    // 2. Generate current hash
    final currentHash = _computeHash({
      'eventType': eventType.toString(),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'previousHash': previousHash,
      'intent': intent?.toJson(),
      'details': details,
    });
    
    // 3. Create audit log
    final log = AuditLog(
      operationIntentId: intent?.operationId,
      previousHash: previousHash,
      currentHash: currentHash,
      serverCommittedAt: DateTime.now().toUtc(),
      actorUserId: intent?.userId,
      actorRole: intent?.userRole,
      eventType: eventType,
      action: _mapEventTypeToAction(eventType),
      timestamp: DateTime.now(),
      userId: intent?.userId ?? 'system',
      details: details,
    );
    
    // 4. Store in database
    await supabase.from('audit_logs').insert(log.toJson());
  }
  
  String _computeHash(Map<String, dynamic> data) {
    final canonicalJson = jsonEncodeCanonical(data);
    final bytes = utf8.encode(canonicalJson);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  Future<bool> verifyChain(String reportId) async {
    final logs = await supabase
      .from('audit_logs')
      .select()
      .eq('report_id', reportId)
      .order('timestamp', ascending: true);
    
    for (int i = 0; i < logs.length; i++) {
      final log = logs[i];
      
      // Verify hash chain
      if (i > 0) {
        final previousLog = logs[i - 1];
        if (log['previous_hash'] != previousLog['current_hash']) {
          // BROKEN CHAIN
          await _reportIntegrityAlarm(reportId, i);
          return false;
        }
      }
      
      // Verify current hash
      final computedHash = _computeHash(log);
      if (computedHash != log['current_hash']) {
        // TAMPERED LOG
        await _reportIntegrityAlarm(reportId, i);
        return false;
      }
    }
    
    return true;
  }
}
```

### Step 5: Final Gate (2-3 hours)

**Requirements:**
1. `flutter analyze` → 0 issues
2. Integration tests → 100% PASS
3. Concurrency tests → deterministic
4. `TRUTH_SOVEREIGNTY_LOG.md` created

**TRUTH_SOVEREIGNTY_LOG.md Structure:**
```markdown
# Truth Sovereignty Log

## Conflict Scenarios

### Scenario 1: Two Admins, Same Version, Opposite Intents
**Input:**
- Admin1: SEAL on report-123, version v1
- Admin2: REJECT on report-123, version v1
- Simultaneous requests

**Decision:**
- Admin1 wins (first commit)
- Admin2 receives 409 Conflict

**Audit Trace:**
- [timestamp] Admin1 initiated SEAL (operation-id-1)
- [timestamp] Admin2 initiated REJECT (operation-id-2)
- [timestamp] Admin1 committed SEAL (version v2)
- [timestamp] CONFLICT_DETECTED for Admin2
- [timestamp] Admin2 acknowledged conflict

**Final State:**
- report-123: PUBLISHED, version v2
- Audit chain: Intact
- Hash verification: Passed

### Scenario 2: Offline Queue Merge Conflict
**Input:**
- Client: SEAL operation queued (version v1)
- Server: Report updated to version v2 by Admin
- Client comes online

**Decision:**
- Merge REJECTED due to version mismatch
- User shown ConflictResolutionDialog
- Operation marked as CONFLICTED

**Audit Trace:**
- [timestamp] Client created SEAL intent (operation-id-3, base version v1)
- [timestamp] Admin committed REJECT (version v2)
- [timestamp] Client detected version mismatch
- [timestamp] CONFLICT_DETECTED for operation-id-3
- [timestamp] User acknowledged and cancelled

**Final State:**
- report-123: REJECTED, version v2
- Operation-id-3: CONFLICTED
- Audit chain: Intact
```

---

## 📊 IMPLEMENTATION ESTIMATE

```
┌─────────────────────────────────────────┐
│ Phase 7 Implementation Estimate         │
├─────────────────────────────────────────┤
│ Step 1: Version Tracking (4-6h)         │
│   - AracRapor model updates             │
│   - Database schema migration           │
│   - Linearization point logic           │
├─────────────────────────────────────────┤
│ Step 2: Concurrency Tests (3-4h)        │
│   - Test suite creation                 │
│   - Two-admin scenario                  │
│   - Deterministic verification          │
├─────────────────────────────────────────┤
│ Step 3: Conflict UX (4-5h)              │
│   - ConflictResolutionDialog            │
│   - State freeze logic                  │
│   - Mandatory disclosure UI             │
├─────────────────────────────────────────┤
│ Step 4: Forensic Audit (3-4h)           │
│   - AuditLog model updates              │
│   - Hash chain implementation           │
│   - Integrity verification              │
├─────────────────────────────────────────┤
│ Step 5: Final Gate (2-3h)               │
│   - flutter analyze                     │
│   - Test verification                   │
│   - Documentation                       │
├─────────────────────────────────────────┤
│ TOTAL: 16-22 hours                      │
└─────────────────────────────────────────┘
```

---

## 🎯 DEFINITION OF DONE - ABSOLUTE

### Non-Negotiable
- [ ] NO feature additions
- [ ] NO silent overwrite paths
- [ ] NO ambiguous truth states
- [ ] Linearization point enforced
- [ ] State freeze on conflict
- [ ] Forensic time separation
- [ ] Conflict as audit event
- [ ] Hash chain integrity verified

### Critical (P0)
- [ ] Version tracking operational
- [ ] Concurrency tests deterministic
- [ ] Conflict UX implemented
- [ ] Forensic audit chain functional

### Final Gate
- [ ] flutter analyze → 0 issues
- [ ] All integration tests pass
- [ ] TRUTH_SOVEREIGNTY_LOG.md complete
- [ ] Every conflict scenario documented

---

## 💡 KEY SUCCESS METRICS

1. **Conflict Detection Rate**
   - Target: 100%
   - Test: Concurrency test suite

2. **Linearization Point Enforcement**
   - Target: 100%
   - Test: Integration tests verify no intermediate states

3. **Audit Chain Integrity**
   - Target: 100%
   - Test: Hash verification tests pass

4. **State Freeze Effectiveness**
   - Target: 100%
   - Test: UX tests verify no operations during conflict

---

## 🚀 NEXT STEPS

### Immediate Actions:
1. **Start with Step 1** - Version tracking implementation
2. **Database migration** - Add version_id, revision_hash, timestamps
3. **Update AracRapor model** - Add new fields, update serialization
4. **Implement linearization point** - Version check before state change
5. **Create concurrency tests** - Verify deterministic behavior

### Recommended Order:
1. Step 1: Version Tracking (foundation)
2. Step 4: Forensic Audit (can proceed in parallel)
3. Step 2: Concurrency Tests (verify Step 1)
4. Step 3: Conflict UX (depends on Step 2)
5. Step 5: Final Gate (all previous steps complete)

---

## ⚠️ CRITICAL REMINDER

**FAILURE IS NOT AN OPTION.**

**YerimeBak artık sadece "doğru çalışan" değil,  
"Hukuken savunulabilir bir gerçeklik makinesi" olur.**

---

## 📁 FILES TO CREATE

1. `lib/widgets/conflict_resolution_dialog.dart` - Conflict UX
2. `test/integration/concurrency_test.dart` - Concurrency tests
3. `lib/services/audit_chain_service.dart` - Hash chain implementation
4. `supabase/migrations/20260203_version_tracking.sql` - DB migration
5. `TRUTH_SOVEREIGNTY_LOG.md` - Documentation

## 📝 FILES TO MODIFY

1. `lib/models/arac_rapor_model.dart` - Add version tracking fields
2. `lib/models/audit_log.dart` - Add hash chain fields
3. `lib/providers/report_state_provider.dart` - Implement linearization point
4. `database_schema.sql` - Update schema documentation

---

## 🏁 STRATEGIC STATUS

**Phase 7:** 📋 **STRATEGIC PLAN COMPLETE**  
**Infrastructure:** Ready (OperationIntent, AuditLog, Truth Model)  
**Implementation:** 16-22 hours estimated  
**Complexity:** High (requires DB migration, comprehensive testing)  
**Critical Success Factors:** Linearization point, state freeze, forensic audit chain  

**Bu faz tamamlandığında:**
- Eventually consistent değil
- **Provably consistent under conflict**
- **Forensically explainable history**
- **Hukuken savunulabilir gerçeklik**

---

*Generated: February 3, 2026*  
*Author: Cline - Principal Distributed Systems & Forensic Engineer*  
*Authority Level: FINAL*  
*Version: 1.0.0 (Strategic Plan)*