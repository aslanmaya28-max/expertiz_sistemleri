# Phase 6.4 - Dashboard Migration Plan

**Status:** 🔄 IN PROGRESS  
**Date:** February 2, 2026  
**Phase:** 6.4 - Dashboard Migration & Legacy Cleanup

---

## 🎯 Migration Objectives

Transform all three dashboards (Admin, Personnel, Customer) from legacy Provider architecture to ReportStateProvider (Riverpod) with enterprise-grade features.

### Key Goals
1. ✅ 100% ReportStateProvider integration
2. ✅ Real-time sync across all panels
3. ✅ Conflict detection and handling
4. ✅ Optimistic updates with rollback
5. ✅ Operational History Panel (Admin only)
6. ✅ Field-level security enforcement
7. ✅ Legacy code cleanup

---

## 📋 Migration Checklist

### Admin Dashboard (lib/admin/admin_dashboard.dart)
- [ ] Convert from StatefulWidget to ConsumerWidget
- [ ] Replace Consumer<AdminProvider> with ref.watch(adminReportsProvider)
- [ ] Replace Consumer<PersonelService> with ref.watch(reportStateProvider)
- [ ] Add Operational History Panel button
- [ ] Implement conflict handling UI (SnackBar/Dialog)
- [ ] Connect seal/reject to ReportStateNotifier
- [ ] Add optimistic feedback with rollback animation
- [ ] Remove mock data (_mockVerileriYukle)
- [ ] Remove manual FutureBuilder for user session
- [ ] Test bulk seal with AI validation

### Personnel Dashboard (lib/personnel/personnel_dashboard.dart)
- [ ] Convert from StatefulWidget to ConsumerWidget
- [ ] Replace Consumer<AdminProvider> with ref.watch(personnelReportsProvider)
- [ ] Remove manual filtering (_getPersonelTalepleri)
- [ ] Add shimmer loading states
- [ ] Implement conflict notification UI
- [ ] Test real-time sync with admin changes
- [ ] Verify field-level filtering

### Customer Dashboard (lib/customer/customer_dashboard.dart)
- [ ] Convert from StatefulWidget to ConsumerWidget
- [ ] Replace manual Supabase stream with ref.watch(customerReportsProvider)
- [ ] Remove _reportsSubscription
- [ ] Test instant updates on admin seal
- [ ] Verify field-level security (no admin_annotations)
- [ ] Test published reports only

### Legacy Cleanup
- [ ] Remove unused DashboardService methods
- [ ] Clean up imports
- [ ] Remove manual Supabase subscriptions
- [ ] Type safety improvements
- [ ] Update documentation

### Testing
- [ ] Real-time sync test (0.5s target)
- [ ] Conflict detection test
- [ ] Offline queue test
- [ ] Bulk seal edge cases test
- [ ] Security (field-level) test
- [ ] Flutter Analyze (0 errors, 0 warnings)

---

## 🏗️ Architecture Changes

### Before (Legacy)
```dart
// Stateful Widget with Provider
class AdminDashboard extends StatefulWidget {
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Manual state
  List<AdminRaporTalepModel> _gelenRaporlar = [];
  
  // Manual loading
  void _mockVerileriYukle() { ... }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        // Manual logic
      },
    );
  }
}
```

### After (Riverpod)
```dart
// Consumer Widget with Riverpod
class AdminDashboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Automatic state management
    final reports = ref.watch(adminReportsProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final state = ref.watch(reportStateProvider);
    
    // Conflict handling
    if (state.hasConflict) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showConflictDialog(context, ref);
      });
    }
    
    // Automatic updates
    return DashboardContent(reports: reports, stats: stats);
  }
}
```

---

## 🔧 Implementation Details

### 1. Admin Dashboard Migration

#### Data Sources
```dart
// OLD: Consumer<AdminProvider>
Consumer<AdminProvider>(
  builder: (context, adminProvider, child) {
    final myTasks = adminProvider.talepler;
  },
)

// NEW: Riverpod Providers
final reports = ref.watch(adminReportsProvider);
final stats = ref.watch(dashboardStatsProvider);
final state = ref.watch(reportStateProvider);
```

#### Actions
```dart
// OLD: Manual setState
setState(() {
  final index = _gelenRaporlar.indexWhere((r) => r.id == rapor.id);
  if (index != -1) {
    _gelenRaporlar[index] = rapor.copyWith(status: 'published');
  }
});

// NEW: ReportStateNotifier (with optimistic update)
final notifier = ref.read(reportStateProvider.notifier);
final success = await notifier.sealReport(reportId);
// Automatic optimistic update + rollback on error
```

#### Conflict Handling
```dart
// Watch for conflicts
if (state.hasConflict) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Veri Güncel Değil'),
        content: Text('Bu rapor başka bir kullanıcı tarafından güncellendi. Yenilemek ister misiniz?'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(reportStateProvider.notifier).clearConflict();
              ref.read(reportStateProvider.notifier).refresh();
              Navigator.pop(context);
            },
            child: Text('Yenile'),
          ),
        ],
      ),
    );
  });
}
```

#### Operational History Panel
```dart
// Add to header actions
IconButton(
  icon: Icon(Icons.history),
  onPressed: () {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: OperationalHistoryPanel(
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  },
)
```

---

### 2. Personnel Dashboard Migration

#### Data Filtering
```dart
// OLD: Manual filtering
List<TalepModel> _getPersonelTalepleri(List<TalepModel> tumTalepler) {
  return tumTalepler.where((t) => 
    t.atananPersonel == _currentUser!.id
  ).toList();
}

// NEW: Provider-level filtering
final reports = ref.watch(personnelReportsProvider);
// Already filtered by personnel_id in provider
```

#### Real-time Sync
```dart
// Automatic via ReportStateProvider
final state = ref.watch(reportStateProvider);

// Admin changes trigger automatic updates
// No manual subscription needed
```

#### Conflict Notification
```dart
if (state.hasConflict) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Admin raporu güncelledi. Yenileniyor...'),
      backgroundColor: Colors.orange,
      action: SnackBarAction(
        label: 'Yenile',
        textColor: Colors.white,
        onPressed: () {
          ref.read(reportStateProvider.notifier).clearConflict();
          ref.read(reportStateProvider.notifier).refresh();
        },
      ),
    ),
  );
}
```

---

### 3. Customer Dashboard Migration

#### Data Source
```dart
// OLD: Manual Supabase stream
_reportsSubscription = Supabase.instance.client
    .from('reports')
    .stream(primaryKey: ['id'])
    .eq('status', 'published')
    .listen((event) { ... });

// NEW: Provider (with automatic filtering)
final reports = ref.watch(customerReportsProvider);
// Already filtered by:
// - status = published
// - customer_id = current user
// - Field-level security
```

#### Instant Updates
```dart
// When admin seals a report:
// 1. ReportStateProvider detects change via Supabase Realtime
// 2. State updates automatically
// 3. Customer dashboard rebuilds
// 4. UI shows "İndirilebilir" immediately

// No manual refresh needed!
```

---

## 🧪 Testing Strategy

### Test 1: Real-Time Sync
```dart
// 1. Open Personnel Dashboard in browser A
// 2. Open Customer Dashboard in browser B
// 3. Admin seals report
// 4. Both dashboards update within 0.5s
```

### Test 2: Conflict Detection
```dart
// 1. Open Admin Dashboard in browser A
// 2. Open same report in Admin Dashboard in browser B
// 3. Browser A seals report
// 4. Browser B tries to reject
// 5. Conflict dialog appears
// 6. Rollback happens automatically
```

### Test 3: Field-Level Security
```dart
// Personnel should NOT see:
// - admin_annotations
// - internal_notes
// - admin_metadata

// Customer should NOT see:
// - admin_annotations
// - internal_notes
// - admin_metadata
// - personnel_id
// - rejection_reason
// - ai_analysis (detailed)
```

### Test 4: Bulk Seal AI Validation
```dart
// 1. Select 10 reports
// 2. 3 reports have AI score < 95%
// 3. Try bulk seal
// 4. Warning appears: "3 reports have AI score < 95%"
// 5. User can cancel or proceed
```

---

## 📊 Success Metrics

| Metric | Target | Status |
|--------|--------|--------|
| Real-time sync | <0.5s | ⏳ TBD |
| Conflict detection | 100% | ⏳ TBD |
| Field-level security | 100% | ⏳ TBD |
| Flutter Analyze errors | 0 | ⏳ TBD |
| Flutter Analyze warnings | 0 (offline reserved) | ⏳ TBD |
| Legacy code removed | 100% | ⏳ TBD |

---

## 🚀 Rollback Plan

If migration fails:
1. Keep old dashboard files as backup
2. Gradual rollout (one dashboard at a time)
3. Feature flags for enabling/disabling
4. Monitor error rates closely
5. Quick revert capability

---

## 📝 Migration Order

1. **Admin Dashboard** (Most complex)
   - Phase 1: Convert to ConsumerWidget
   - Phase 2: Add ReportStateProvider
   - Phase 3: Add Operational History Panel
   - Phase 4: Add conflict handling
   - Phase 5: Test and verify

2. **Personnel Dashboard** (Medium complexity)
   - Phase 1: Convert to ConsumerWidget
   - Phase 2: Add personnelReportsProvider
   - Phase 3: Test real-time sync
   - Phase 4: Verify filtering

3. **Customer Dashboard** (Least complex)
   - Phase 1: Convert to ConsumerWidget
   - Phase 2: Add customerReportsProvider
   - Phase 3: Test instant updates
   - Phase 4: Verify security

4. **Legacy Cleanup**
   - Phase 1: Remove unused services
   - Phase 2: Clean imports
   - Phase 3: Update documentation

5. **Final Testing**
   - Phase 1: Cross-panel sync
   - Phase 2: Conflict scenarios
   - Phase 3: Security verification
   - Phase 4: Performance testing

---

**Next Step:** Begin Admin Dashboard migration