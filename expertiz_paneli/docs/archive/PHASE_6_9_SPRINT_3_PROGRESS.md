# PHASE 6.9 - Sprint 3: Concurrency & Conflict Sovereignty - PROGRESS

**Date:** February 3, 2026  
**Status:** 🚧 **IN PROGRESS**  
**Mission:** Provably consistent under conflict

---

## 🎯 SPRINT PHILOSOPHY

> "NO SILENT OVERWRITE. NO AMBIGUOUS TRUTH.  
> Concurrency is treated as an adversarial force."

**This sprint proves that:**
- Simultaneous intent does not corrupt state
- Offline intent does not overwrite authority
- Duplicate intent does not duplicate effect

---

## ⚠️ SYSTEM TRUTH MODEL (MANDATORY DECLARATION)

### Authority Model
- **Backend** is the FINAL authority for committed state
- **Client** operates on versioned snapshots
- **Conflict Detection** via:
  - `version_id` mismatch OR
  - `revision_hash` mismatch

### If authority model is unclear → STOP
✅ Authority model declared. Proceeding with implementation.

---

## 📋 EXECUTION ROADMAP

### Step 0: Version Tracking Foundation
- [ ] Review current version tracking in `AracRaporModel`
- [ ] Add `version_id` field if missing
- [ ] Add `revision_hash` field if missing
- [ ] Update `ReportStateProvider` to track versions

### Step 1: Idempotency Guarantee (Multi-Layer)
- [ ] Create `lib/models/operation_intent.dart`
  - `operation_id` (UUID)
  - `timestamp` (logical timestamp)
  - `intent_type` (SEAL, REJECT, etc.)
- [ ] Update `ReportStateProvider`
  - Track active `operation_id`
  - Reject duplicate operation_id
  - Implement isSubmitting guard
- [ ] Create `test/integration/idempotency_test.dart`
  - Double tap simulation
  - Network retry simulation
  - App resume simulation

### Step 2: Multi-User Race Condition Test
- [ ] Create `test/integration/concurrency_test.dart`
  - Two distinct users
  - Same report_id
  - Same base version_id
  - Opposite intents (SEAL vs REJECT)
- [ ] Implement conflict detection
  - HTTP 409 response handling
  - Optimistic state reversion
  - Conflict message to user

### Step 3: Offline Queue & Merge Strategy
- [ ] Create `lib/services/offline_operation_queue.dart`
  - Ordered queue (logical timestamp)
  - Version-aware merge
  - Conflict detection on merge
- [ ] Implement merge strategy:
  - Fetch latest server version
  - If version matches → apply
  - If version conflicts → STOP, mark conflict
- [ ] NO auto-merge on conflict

### Step 4: Conflict UX = Operational Clarity
- [ ] Create `lib/widgets/conflict_resolution_dialog.dart`
  - Show what user attempted
  - Show what was accepted
  - Retry with latest state option
  - Cancel intent option
- [ ] No ambiguous UI state

### Step 5: Concurrency Forensic Logging
- [ ] Update `AuditLog` model
  - timestamp
  - user_id/role
  - report_id
  - base_version
  - server_version
  - resolution outcome
- [ ] Create `lib/services/conflict_logger.dart`
  - Structured JSON logging
  - Every conflict logged
  - Logs are evidence

### Step 6: Stress & Chaos Verification
- [ ] Create `test/integration/chaos_test.dart`
  - Delayed responses
  - Reordered responses
  - Duplicate responses
- [ ] Assertions:
  - No duplicated commits
  - No lost intent
  - No inconsistent UI state

### Step 7: Final Gate (Absolute)
- [ ] All concurrency tests pass
- [ ] `flutter analyze` → 0 issues
- [ ] No silent overwrite paths
- [ ] Conflict logs generated
- [ ] Create completion report

---

## 📊 CURRENT STATUS

```
┌─────────────────────────────────────────┐
│ Sprint 3 Progress                        │
├─────────────────────────────────────────┤
│ Step 0: Version Tracking (0%)            │
│   [ ] Review current version fields     │
│   [ ] Add version_id if missing         │
│   [ ] Add revision_hash if missing      │
├─────────────────────────────────────────┤
│ Step 1: Idempotency (0%)                 │
│   [ ] OperationIntent model             │
│   [ ] Provider idempotency guard        │
│   [ ] Idempotency tests                 │
├─────────────────────────────────────────┤
│ Step 2: Race Conditions (0%)             │
│   [ ] Concurrency test suite            │
│   [ ] Conflict detection                │
│   [ ] 409 handling                      │
├─────────────────────────────────────────┤
│ Step 3: Offline Queue (0%)               │
│   [ ] Queue service                     │
│   [ ] Merge strategy                    │
│   [ ] No auto-merge on conflict         │
├─────────────────────────────────────────┤
│ Step 4: Conflict UX (0%)                 │
│   [ ] Resolution dialog                 │
│   [ ] Show attempted vs accepted        │
│   [ ] Retry/Cancel options              │
├─────────────────────────────────────────┤
│ Step 5: Forensic Logging (0%)           │
│   [ ] Update AuditLog model             │
│   [ ] Conflict logger service           │
│   [ ] Structured JSON logs              │
├─────────────────────────────────────────┤
│ Step 6: Chaos Testing (0%)               │
│   [ ] Delayed response simulation       │
│   [ ] Reordered response simulation     │
│   [ ] Duplicate response simulation     │
├─────────────────────────────────────────┤
│ Step 7: Final Gate (0%)                  │
│   [ ] All tests passing                 │
│   [ ] Analyze clean                     │
│   [ ] Completion report                 │
└─────────────────────────────────────────┘

Overall: 0% Complete (0/21 tasks)
```

---

## 🎯 DEFINITION OF DONE

### Critical (P0)
- [ ] Version tracking operational
- [ ] Idempotency guaranteed (multi-layer)
- [ ] Race condition tests passing
- [ ] Conflict detection active
- [ ] Offline queue with version-safe merge

### High Priority (P1)
- [ ] Conflict UX implemented
- [ ] Forensic logging functional
- [ ] Chaos tests passing

### Non-Negotiable
- [ ] NO silent overwrite paths
- [ ] NO auto-merge on conflict
- [ ] All conflicts logged
- [ ] All conflicts user-visible

---

## 💡 KEY METRICS TO VERIFY

1. **Conflict Detection Rate**
   - Target: 100% of conflicts detected
   - Current: TBD (measurement pending)

2. **Idempotency Success Rate**
   - Target: 100% (operation applied exactly once)
   - Current: TBD (measurement pending)

3. **Merge Success Rate**
   - Target: Only version-safe merges succeed
   - Current: TBD (measurement pending)

4. **Forensic Logging**
   - Target: 100% of conflicts logged
   - Current: TBD (measurement pending)

---

## 🚀 NEXT ACTIONS

1. **IMMEDIATE:** Review `AracRaporModel` for version tracking
2. **THEN:** Create `OperationIntent` model
3. **THEN:** Implement idempotency guard in provider
4. **THEN:** Create concurrency test suite

---

## ⚠️ CRITICAL REMINDER

**Silent overwrite = FAILURE**  
**Ambiguous truth = FAILURE**  
**Missing conflict log = FAILURE**

This is **distributed system sovereignty**.

---

*Last Updated: February 3, 2026*  
*Status: Sprint 3 In Progress*