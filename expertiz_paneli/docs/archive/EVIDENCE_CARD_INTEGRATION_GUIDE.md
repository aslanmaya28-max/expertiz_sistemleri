# Evidence Card Integration Guide
## FAZ-1.0 — Panel Integration Documentation

**Status**: ✅ PRODUCTION-READY
**Date**: 2026-02-02

---

## 📋 OVERVIEW

This guide demonstrates how to integrate the **EvidenceCard** widget across Admin, Personnel, and Customer panels with real data from Supabase RPC functions.

**Key Principle**: "Write Once, Display Everywhere" — The same EvidenceCard widget works in all panels with different data sources.

---

## 🎯 COMPONENTS DELIVERED

### 1. ForensicTheme
**File**: `lib/core/theme/forensic_theme.dart`
- Unified color tokens (Deep Space Blue, Neon Cyan, Obsidian Emerald, Atomic Red)
- Typography tokens (Inter + JetBrains Mono)
- Spacing, radius, and effect tokens
- Material ThemeData for dark mode

### 2. EvidenceCard Widget
**File**: `lib/widgets/evidence_card.dart`
- Expandable reasoning section (300ms animation)
- Laser scan verification effect (450ms)
- Status badges (Verified / Tampering / Limitations)
- Hash copy-to-clipboard
- PDF export integration
- Error shake animation

### 3. Supabase RPC Functions
**File**: `supabase/migrations/20260202_evidence_rpc_functions.sql`
- `get_admin_evidence_stats()` — All ledger entries
- `get_personnel_evidence_stats(personnel_id)` — User's entries
- `get_customer_evidence_stats(customer_id)` — Customer's reports
- `get_evidence_summary_stats()` — Dashboard widgets

### 4. Panel Integration Examples
- `lib/screens/admin/evidence_dashboard_screen.dart` — Admin reference implementation
- Personnel panel example (below)
- Customer panel example (below)

---

## 📐 PANEL INTEGRATION PATTERNS

### Admin Panel
**RPC**: `get_admin_evidence_stats`
**Scope**: All ledger entries
**Layout**: Grid (2 columns desktop, 1 column mobile)

### Personnel Panel
**RPC**: `get_personnel_evidence_stats(personnel_id)`
**Scope**: Entries created by current user
**Layout**: Grid (2 columns desktop, 1 column mobile)

### Customer Panel
**RPC**: `get_customer_evidence_stats(customer_id)`
**Scope**: Entries for customer's reports
**Layout**: List view (1 column)

---

## 💻 PERSONNEL PANEL EXAMPLE

```dart
/// EVIDENCE DASHBOARD (PERSONNEL)
/// File: lib/screens/personnel/personnel_evidence_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/forensic_theme.dart';
import '../../widgets/evidence_card.dart';
import '../../models/user_model.dart';
import '../../core/layout/base_scaffold.dart';

class PersonnelEvidenceScreen extends StatefulWidget {
  const PersonnelEvidenceScreen({super.key});

  @override
  State<PersonnelEvidenceScreen> createState() => _PersonnelEvidenceScreenState();
}

class _PersonnelEvidenceScreenState extends State<PersonnelEvidenceScreen> {
  late Future<List<Map<String, dynamic>>> _evidenceFuture;

  @override
  void initState() {
    super.initState();
    _loadEvidence();
  }

  void _loadEvidence() {
    // Get current user ID
    final user = context.read<UserModel>();
    
    // Call Personnel RPC with user ID
    _evidenceFuture = Supabase.instance.client.rpc(
      'get_personnel_evidence_stats',
      params: {
        'personnel_id': user.id,
        'limit_count': 50,
        'offset_count': 0,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      role: UserRole.personel,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildEvidenceGrid()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceLg),
      decoration: BoxDecoration(
        color: ForensicTheme.forensicSlate,
        border: Border(
          bottom: BorderSide(
            color: ForensicTheme.textDim.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: ForensicTheme.neonCyan, size: 32),
          const SizedBox(width: ForensicTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MY EVIDENCE', style: ForensicTheme.headline),
                const SizedBox(height: ForensicTheme.spaceXxs),
                Text('Records I Created', style: ForensicTheme.caption),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: ForensicTheme.neonCyan,
            onPressed: () => setState(() => _loadEvidence()),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _evidenceFuture,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: ForensicTheme.neonCyan),
                const SizedBox(height: ForensicTheme.spaceMd),
                Text('Loading your evidence...', style: ForensicTheme.body),
              ],
            ),
          );
        }
        
        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: ForensicTheme.atomicRed),
                const SizedBox(height: ForensicTheme.spaceMd),
                Text('Failed to load evidence', style: ForensicTheme.title),
                const SizedBox(height: ForensicTheme.spaceSm),
                Text(snapshot.error.toString(), style: ForensicTheme.body),
                const SizedBox(height: ForensicTheme.spaceLg),
                ElevatedButton(
                  onPressed: () => setState(() => _loadEvidence()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        // Empty state
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: ForensicTheme.textDim),
                const SizedBox(height: ForensicTheme.spaceMd),
                Text('No evidence records', style: ForensicTheme.title),
                const SizedBox(height: ForensicTheme.spaceSm),
                Text('Your AI decisions will appear here', style: ForensicTheme.caption),
              ],
            ),
          );
        }
        
        // Success - display evidence
        final evidenceList = snapshot.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 1200 ? 2 : 1;
            
            return GridView.builder(
              padding: const EdgeInsets.all(ForensicTheme.spaceMd),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 1.2,
                crossAxisSpacing: ForensicTheme.spaceMd,
                mainAxisSpacing: ForensicTheme.spaceMd,
              ),
              itemCount: evidenceList.length,
              itemBuilder: (context, index) {
                final e = evidenceList[index];
                return EvidenceCard(
                  evidenceId: e['id']?.toString() ?? '',
                  timestamp: DateTime.parse(e['timestamp']).toUtc(),
                  sha256Hash: e['hash'] ?? '',
                  isVerified: e['is_verified'] ?? false,
                  observation: e['observation'] ?? '',
                  assumption: e['assumption'] ?? '',
                  limitation: e['limitation'] ?? '',
                  reportId: e['report_id']?.toString(),
                );
              },
            );
          },
        );
      },
    );
  }
}
```

---

## 💳 CUSTOMER PANEL EXAMPLE

```dart
/// EVIDENCE DASHBOARD (CUSTOMER)
/// File: lib/screens/customer/customer_evidence_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/forensic_theme.dart';
import '../../widgets/evidence_card.dart';
import '../../models/user_model.dart';
import '../../core/layout/base_scaffold.dart';

class CustomerEvidenceScreen extends StatefulWidget {
  const CustomerEvidenceScreen({super.key});

  @override
  State<CustomerEvidenceScreen> createState() => _CustomerEvidenceScreenState();
}

class _CustomerEvidenceScreenState extends State<CustomerEvidenceScreen> {
  late Future<List<Map<String, dynamic>>> _evidenceFuture;

  @override
  void initState() {
    super.initState();
    _loadEvidence();
  }

  void _loadEvidence() {
    // Get current customer ID
    final user = context.read<UserModel>();
    
    // Call Customer RPC with customer ID
    _evidenceFuture = Supabase.instance.client.rpc(
      'get_customer_evidence_stats',
      params: {
        'customer_id': user.id,
        'limit_count': 50,
        'offset_count': 0,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      role: UserRole.musteri,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildEvidenceList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceLg),
      decoration: BoxDecoration(
        color: ForensicTheme.forensicSlate,
        border: Border(
          bottom: BorderSide(
            color: ForensicTheme.textDim.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_special, color: ForensicTheme.neonCyan, size: 32),
          const SizedBox(width: ForensicTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('REPORT EVIDENCE', style: ForensicTheme.headline),
                const SizedBox(height: ForensicTheme.spaceXxs),
                Text('Evidence for My Reports', style: ForensicTheme.caption),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: ForensicTheme.neonCyan,
            onPressed: () => setState(() => _loadEvidence()),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _evidenceFuture,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: ForensicTheme.neonCyan),
                const SizedBox(height: ForensicTheme.spaceMd),
                Text('Loading report evidence...', style: ForensicTheme.body),
              ],
            ),
          );
        }
        
        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: ForensicTheme.atomicRed),
                const SizedBox(height: ForensicTheme.spaceMd),
                Text('Failed to load evidence', style: ForensicTheme.title),
                const SizedBox(height: ForensicTheme.spaceSm),
                Text(snapshot.error.toString(), style: ForensicTheme.body),
                const SizedBox(height: ForensicTheme.spaceLg),
                ElevatedButton(
                  onPressed: () => setState(() => _loadEvidence()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        // Empty state
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: ForensicTheme.textDim),
                const SizedBox(height: ForensicTheme.spaceMd),
                Text('No evidence records', style: ForensicTheme.title),
                const SizedBox(height: ForensicTheme.spaceSm),
                Text('Evidence will appear when reports are analyzed', style: ForensicTheme.caption),
              ],
            ),
          );
        }
        
        // Success - list view for customer
        final evidenceList = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(ForensicTheme.spaceMd),
          itemCount: evidenceList.length,
          itemBuilder: (context, index) {
            final e = evidenceList[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: ForensicTheme.spaceMd),
              child: EvidenceCard(
                evidenceId: e['id']?.toString() ?? '',
                timestamp: DateTime.parse(e['timestamp']).toUtc(),
                sha256Hash: e['hash'] ?? '',
                isVerified: e['is_verified'] ?? false,
                observation: e['observation'] ?? '',
                assumption: e['assumption'] ?? '',
                limitation: e['limitation'] ?? '',
                reportId: e['report_id']?.toString(),
              ),
            );
          },
        );
      },
    );
  }
}
```

---

## 🔧 ROUTE INTEGRATION

Add these routes to your routing configuration:

```dart
// lib/routing/route_paths.dart
class RoutePaths {
  // ... existing routes ...
  
  static const String adminEvidenceDashboard = '/admin/evidence-dashboard';
  static const String personnelEvidence = '/personnel/evidence';
  static const String customerEvidence = '/customer/evidence';
}
```

---

## 📊 DATA FLOW DIAGRAM

```
┌─────────────────────────────────────────────────────────────┐
│                     SUPABASE (Database)                      │
│                                                               │
│  explainability_ledger table                                │
│  - id, sealed_at, decision_hash, reasoning, report_id...     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   RPC FUNCTIONS                              │
│                                                               │
│  • get_admin_evidence_stats()                                │
│  • get_personnel_evidence_stats(personnel_id)                │
│  • get_customer_evidence_stats(customer_id)                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   FLUTTER PANELS                             │
│                                                               │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   ADMIN     │  │  PERSONNEL   │  │   CUSTOMER   │       │
│  │   Panel     │  │    Panel     │  │    Panel     │       │
│  └─────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
│        │                  │                  │                │
│        │ FutureBuilder    │ FutureBuilder    │ FutureBuilder │
│        │ RPC call         │ RPC call         │ RPC call       │
│        │                  │                  │                │
│        ▼                  ▼                  ▼                │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                  EvidenceCard                        │    │
│  │                                                      │    │
│  │  • Expandable reasoning                              │    │
│  │  • Laser scan verification                           │    │
│  │  • Status badges                                     │    │
│  │  • Hash copy / PDF export                            │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## ✅ CHECKLIST

### Before Using EvidenceCard

- [ ] Run Supabase migration: `20260202_evidence_rpc_functions.sql`
- [ ] Add route paths to routing configuration
- [ ] Ensure fonts (Inter, JetBrains Mono) are available
- [ ] Test RPC functions in Supabase SQL Editor

### Integration Steps

1. **Import dependencies**
   ```dart
   import '../../widgets/evidence_card.dart';
   import '../../core/theme/forensic_theme.dart';
   ```

2. **Call appropriate RPC function**
   - Admin: `get_admin_evidence_stats`
   - Personnel: `get_personnel_evidence_stats(personnel_id)`
   - Customer: `get_customer_evidence_stats(customer_id)`

3. **Use FutureBuilder pattern**
   - Handle loading, error, empty, and success states
   - Map RPC result to EvidenceCard parameters

4. **Layout (Grid vs List)**
   - Grid: Admin, Personnel (2 columns desktop)
   - List: Customer (1 column)

---

## 🎨 CUSTOMIZATION

### Change Grid Columns

```dart
final crossAxisCount = constraints.maxWidth > 1200 ? 3 : 
                       constraints.maxWidth > 600 ? 2 : 1;
```

### Change Card Aspect Ratio

```dart
childAspectRatio: 1.2, // Taller cards
childAspectRatio: 1.5, // Wider cards
```

### Add Pagination

```dart
// Store page state
int _currentPage = 0;
static const int _pageSize = 20;

// Update RPC call
_evidenceFuture = Supabase.instance.client.rpc(
  'get_admin_evidence_stats',
  params: {
    'limit_count': _pageSize,
    'offset_count': _currentPage * _pageSize,
  },
);
```

---

## 🔍 TROUBLESHOOTING

### RPC Function Not Found
**Error**: `function get_admin_evidence_stats() does not exist`
**Solution**: Run the migration file in Supabase SQL Editor

### Empty Results
**Check**: 
- Is there data in `explainability_ledger`?
- Does user have permissions via RLS?
- Are you passing correct user ID?

### EvidenceCard Shows Wrong Colors
**Cause**: Not using ForensicTheme
**Solution**: Wrap in `Theme(data: ForensicTheme.themeData, child: ...)`

---

## 📚 ADDITIONAL RESOURCES

- Forensic Theme: `lib/core/theme/forensic_theme.dart`
- Evidence Card: `lib/widgets/evidence_card.dart`
- Admin Example: `lib/screens/admin/evidence_dashboard_screen.dart`
- RPC Functions: `supabase/migrations/20260202_evidence_rpc_functions.sql`

---

**FAZ-1.0 Evidence Card System — Production Ready ✅**