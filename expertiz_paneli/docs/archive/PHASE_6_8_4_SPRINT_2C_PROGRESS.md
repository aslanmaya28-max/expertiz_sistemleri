# PHASE 6.8.4 - Sprint 2C: Performance = Truth - PROGRESS

**Date:** February 3, 2026  
**Status:** 🚧 **IN PROGRESS**  
**Mission:** Convert performance into truth preservation infrastructure

---

## 🎯 SPRINT PHILOSOPHY

> "Performance failure is NOT a UI issue.  
> Performance failure is a **silent truth corruption risk**."

In this system:
- Frame drops = forensic anomalies
- Excess rebuilds = truth-risk vectors
- Accessibility = legal & ethical compliance

---

## 📋 EXECUTION ROADMAP

### Step 1: Performance Instrumentation Setup
- [ ] Create `lib/utils/performance_monitor.dart`
  - Frame timing capture (60 FPS target)
  - Rebuild count tracking
  - Jank detection (<30 FPS = anomaly)
- [ ] Create `test/utils/performance_monitor_test.dart`
  - Verify frame timing capture
  - Verify rebuild counting

### Step 2: Rebuild Budget Enforcement
- [ ] Instrument widgets:
  - AdminDashboard (Riverpod)
  - PersonnelDashboard (Riverpod)
  - QuickReviewDrawer
  - SlideAction
- [ ] Identify static UI zones
- [ ] Apply `const` constructors aggressively
- [ ] Apply `RepaintBoundary` strategically
- [ ] Narrow `Consumer` scopes
- [ ] **Budget Rule:** Max 3 rebuilds per interaction

### Step 3: Frame Timing & Jank Forensics
- [ ] Implement `SchedulerBinding.instance.addTimingsCallback`
- [ ] Capture frame timing during:
  - SlideAction drag
  - QuickReviewDrawer open/close
  - Bulk selection toggle
- [ ] Log performance anomalies to OperationalHistory
- [ ] **Threshold:** <30 FPS = PERFORMANCE_ANOMALY

### Step 4: GPU & Paint Isolation
- [ ] Apply `RepaintBoundary` to:
  - SlideAction draggable thumb
  - Progress indicators
  - Drawer animation container
- [ ] Verify paint isolation via DevTools
- [ ] **Assertion:** Sliding gesture must NOT repaint parent

### Step 5: Accessibility Compliance (WCAG 2.1 AA)
- [ ] SlideAction semantics:
  - Role: Adjustable action (NOT button)
  - Label: "Mühürleme işlemi"
  - Hint: "Onaylamak için sağa kaydırın"
- [ ] Bulk Seal checkbox semantics
- [ ] Logical focus order
- [ ] No focus trap during loading
- [ ] Widget tests with `tester.getSemantics`
- [ ] Font scaling (200%) verification
- [ ] Contrast AA compliance

### Step 6: Stress Verification
- [ ] Simulate low FPS / heavy rebuild
- [ ] Verify ErrorBoundary still isolates
- [ ] Verify no stuck loading states
- [ ] Verify retry functions deterministically

### Step 7: Final Verification Gate
- [ ] `flutter analyze` → 0 issues
- [ ] All widget tests pass
- [ ] Performance logs generated for:
  - SlideAction interaction
  - Drawer animation
- [ ] Create completion report

---

## 📊 CURRENT STATUS

```
┌─────────────────────────────────────────┐
│ Sprint 2C Progress                       │
├─────────────────────────────────────────┤
│ Step 1: Performance Setup (0%)          │
│   [ ] Performance monitor created       │
│   [ ] Performance tests created         │
├─────────────────────────────────────────┤
│ Step 2: Rebuild Budget (0%)             │
│   [ ] Widgets instrumented              │
│   [ ] Const constructors applied        │
│   [ ] RepaintBoundary applied           │
│   [ ] Consumer scopes narrowed          │
├─────────────────────────────────────────┤
│ Step 3: Frame Timing (0%)               │
│   [ ] SchedulerBinding implemented      │
│   [ ] Jank detection active             │
│   [ ] Anomalies logged                  │
├─────────────────────────────────────────┤
│ Step 4: GPU Isolation (0%)              │
│   [ ] RepaintBoundary zones marked      │
│   [ ] Paint isolation verified          │
├─────────────────────────────────────────┤
│ Step 5: Accessibility (0%)              │
│   [ ] SlideAction semantics             │
│   [ ] Bulk Seal semantics               │
│   [ ] Focus order verified              │
│   [ ] Widget tests passing              │
├─────────────────────────────────────────┤
│ Step 6: Stress Testing (0%)             │
│   [ ] Low FPS simulation                │
│   [ ] ErrorBoundary verified            │
│   [ ] Retry determinism verified        │
├─────────────────────────────────────────┤
│ Step 7: Final Gate (0%)                 │
│   [ ] Analyze clean                     │
│   [ ] Tests passing                     │
│   [ ] Performance logs generated        │
└─────────────────────────────────────────┘

Overall: 0% Complete (0/21 tasks)
```

---

## 🎯 DEFINITION OF DONE

### Critical (P0)
- [ ] Performance monitor operational
- [ ] Rebuild budget ≤3 per interaction
- [ ] Frame timing capture active
- [ ] Jank detection (<30 FPS)
- [ ] RepaintBoundary zones isolated

### High Priority (P1)
- [ ] SlideAction semantics (WCAG 2.1 AA)
- [ ] Bulk Seal semantics
- [ ] Focus order verified
- [ ] Font scaling (200%) no layout break

### Non-Negotiable
- [ ] Performance anomalies logged to OperationalHistory
- [ ] Sliding gesture doesn't repaint parent
- [ ] No focus traps
- [ ] ErrorBoundary works under stress

---

## 💡 KEY METRICS TO CAPTURE

1. **Rebuild Count**
   - Max allowed: 3 per interaction
   - Current: TBD (measurement pending)

2. **Frame Rate**
   - Target: 60 FPS ±5
   - Anomaly threshold: <30 FPS

3. **Paint Isolation**
   - SlideAction: Must not repaint parent
   - Drawer: Must not repaint dashboard

4. **Accessibility**
   - WCAG 2.1 AA compliance
   - Screen reader support
   - Keyboard navigation

---

## 🚀 NEXT ACTIONS

1. **IMMEDIATE:** Create `lib/utils/performance_monitor.dart`
2. **THEN:** Instrument widgets with rebuild tracking
3. **THEN:** Apply RepaintBoundary strategically
4. **THEN:** Implement accessibility semantics

---

*Last Updated: February 3, 2026*  
*Status: Sprint 2C In Progress*