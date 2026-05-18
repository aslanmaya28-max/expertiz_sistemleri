# MICRO-RISK POLISH — ZERO FRICTION LAYER (FINAL)

**Date:** February 3, 2026  
**Status:** 📋 **STRATEGIC PLAN**  
**Mission:** Sistemi "doğru"dan "zarif, sessiz ve tartışmasız" seviyesine çıkarmak

---

## ⚠️ CONSTRAINTS

**Bu görev:**
- ❌ Yeni faz başlatmaz
- ❌ Yeni feature eklemez
- ❌ Truth modelini değiştirmez
- ✅ Phase 7'den ÖNCE yapılır

**Global Kurallar (Değişmez):**
- Server tek hakikattir
- Client sadece tanıktır
- Conflict = hata değildir
- Audit log okunur, sade ve tek anlamlıdır
- Bulk ≠ kaos

---

## 🔬 MİKRO-RİSKLER & ZORUNLU ÇÖZÜMLER

### 1️⃣ VERSION ID + REVISION COUNTER (ÇİFT MÜHÜR)

**Risk:**
UUID pratikte güvenilir ama deterministik sıralama sağlamaz.

**ZORUNLU AKSİYON:**

**AracRapor Model Updates:**
```dart
// Add to lib/models/arac_rapor_model.dart
class AracRapor {
  // EXISTING FIELDS...
  
  // NEW FIELDS (Double Seal):
  final String? versionId;           // UUID, conflict detection
  final int? revisionCounter;        // BIGINT, monoton artan, linearization
  
  // Other version tracking fields:
  final String? revisionHash;
  final DateTime? serverCommittedAt;
  final DateTime? clientObservedAt;
  
  // Updated toJson()
  Map<String, dynamic> toJson() {
    return {
      // ... existing fields ...
      'version_id': versionId,
      'revision_counter': revisionCounter,
      'revision_hash': revisionHash,
      'server_committed_at': serverCommittedAt?.toIso8601String(),
      'client_observed_at': clientObservedAt?.toIso8601String(),
    };
  }
  
  // Updated fromJson()
  factory AracRapor.fromJson(Map<String, dynamic> json) {
    return AracRapor(
      // ... existing fields ...
      versionId: json['version_id']?.toString(),
      revisionCounter: json['revision_counter'] as int?,
      revisionHash: json['revision_hash']?.toString(),
      serverCommittedAt: json['server_committed_at'] != null 
          ? DateTime.parse(json['server_committed_at']) 
          : null,
      clientObservedAt: json['client_observed_at'] != null 
          ? DateTime.parse(json['client_observed_at']) 
          : null,
    );
  }
}
```

**Database Schema Updates:**
```sql
-- supabase/migrations/20260203_revision_counter.sql

-- Add revision_counter column
ALTER TABLE arac_rapor 
ADD COLUMN revision_counter BIGINT DEFAULT 1;

-- Backfill existing records
UPDATE arac_rapor 
SET revision_counter = 1
WHERE revision_counter IS NULL;

-- Create index for ordering queries
CREATE INDEX idx_arac_rapor_revision_counter 
ON arac_rapor(revision_counter DESC);

-- Trigger: Auto-increment on update
CREATE OR REPLACE FUNCTION increment_revision_counter()
RETURNS TRIGGER AS $$
BEGIN
  NEW.revision_counter = OLD.revision_counter + 1;
  NEW.server_committed_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_arac_rapor_revision_counter
BEFORE UPDATE ON arac_rapor
FOR EACH ROW
EXECUTE FUNCTION increment_revision_counter();
```

**Service Layer Updates:**
```dart
// In ReportStateProvider or Service
Future<void> sealReport({
  required String reportId,
  required String baseVersionId,
  required int baseRevisionCounter,
}) async {
  // 1. Fetch current server state
  final current = await supabase
    .from('arac_rapor')
    .select()
    .eq('id', reportId)
    .single();
  
  // 2. CONFLICT DETECTION: Check version_id
  if (current['version_id'] != baseVersionId) {
    throw ConflictException(
      currentVersionId: current['version_id'],
      yourVersionId: baseVersionId,
      currentRevisionCounter: current['revision_counter'],
    );
  }
  
  // 3. LINEARIZATION: Revision counter auto-increments via trigger
  final newVersionId = uuid.v4();
  await supabase
    .from('arac_rapor')
    .update({
      'durum': 'PUBLISHED',
      'version_id': newVersionId,
      // revision_counter increments via trigger
    })
    .eq('id', reportId);
  
  // 4. Audit log references both
  await auditService.logEvent(
    eventType: AuditEventType.seal,
    reportId: reportId,
    versionId: newVersionId,
    revisionCounter: current['revision_counter'] + 1,
  );
}
```

**AuditLog Updates:**
```dart
// Add to lib/models/audit_log.dart
class AuditLog {
  // EXISTING FIELDS...
  
  // NEW FIELDS:
  final String? referencedVersionId;
  final int? referencedRevisionCounter;
  
  // Updated toJson()
  Map<String, dynamic> toJson() {
    return {
      // ... existing fields ...
      'referenced_version_id': referencedVersionId,
      'referenced_revision_counter': referencedRevisionCounter,
    };
  }
}
```

**KURAL:**
- Conflict detection → `version_id`
- Linearization & ordering → `revision_counter`
- Audit log → `(version_id + revision_counter)` ile referanslanır

---

### 2️⃣ UTC DRIFT & CLIENT TIME (TANIK STATÜSÜ)

**Risk:**
Client zamanı adli karışıklık yaratabilir.

**ZORUNLU AKSİYON:**

**UI Text Updates:**
```dart
// In widgets displaying timestamps
// ❌ WRONG:
Text('İşlem zamanı: ${formatTimestamp(clientObservedAt)}')

// ✅ CORRECT:
Text('Sunucuya işlendiği an: ${formatTimestamp(serverCommittedAt)}')
Text('Cihazınızda görüldü: ${formatTimestamp(clientObservedAt)}', style: TextStyle(fontSize: 12))
```

**Conflict Resolution Dialog:**
```dart
// In ConflictResolutionDialog
_buildRow('İşlem Zamanı', formatTime(acceptedTruth.serverCommittedAt)), // ONLY server time
_buildRow('Cihazınızda Görüldü', formatTime(attemptedIntent.timestamp)), // Optional, smaller
```

**Service Layer:**
```dart
// NEVER use clientObservedAt for decisions
// ALWAYS use serverCommittedAt for:
// - Conflict detection
// - Ordering
// - Truth determination

// clientObservedAt is ONLY for:
// - Display purposes
// - Debugging
// - UX improvements (showing local time)
```

**KURAL:**
- `client_observed_at`: Saklanır, gösterilebilir, ❌ Karar vermez
- Conflict, sıralama, truth: SADECE `server_committed_at`
- UI metni: "Sunucuya işlendiği an" (NOT "İşlem zamanı")

---

### 3️⃣ CANONICAL JSON HASHING (PLATFORM BAĞIMSIZ HAKİKAT)

**Risk:**
Alan sırası değişirse hash bozulur.

**ZORUNLU AKSİYON:**

**Create Canonical JSON Utility:**
```dart
// lib/utils/canonical_json.dart

import 'dart:convert';

/// Canonical JSON encoder for consistent hashing across platforms
/// 
/// Rules:
/// 1. Sort keys alphabetically
/// 2. Normalize null values
/// 3. Remove whitespace
/// 4. Consistent string encoding
class CanonicalJson {
  /// Encode map to canonical JSON string
  static String encode(Map<String, dynamic> data) {
    // 1. Sort keys alphabetically
    final sortedMap = Map<String, dynamic>.fromEntries(
      data.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
    
    // 2. Normalize null values (remove keys with null values)
    final normalizedMap = _normalizeNulls(sortedMap);
    
    // 3. Encode with JsonEncoder (no whitespace)
    final encoder = JsonEncoder.withIndent(null); // No indentation
    return encoder.convert(normalizedMap);
  }
  
  /// Remove keys with null values (optional, based on requirements)
  static Map<String, dynamic> _normalizeNulls(Map<String, dynamic> data) {
    final normalized = <String, dynamic>{};
    data.forEach((key, value) {
      if (value != null) {
        normalized[key] = value;
      }
    });
    return normalized;
  }
  
  /// Generate SHA-256 hash of canonical JSON
  static String hash(Map<String, dynamic> data) {
    final canonicalJson = encode(data);
    final bytes = utf8.encode(canonicalJson);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
```

**Update AuditChainService:**
```dart
// In lib/services/audit_chain_service.dart
import 'package:crypto/crypto.dart';
import 'lib/utils/canonical_json.dart';

class AuditChainService {
  String _computeHash(Map<String, dynamic> data) {
    // Use canonical JSON encoding
    final canonicalJson = CanonicalJson.encode(data);
    final bytes = utf8.encode(canonicalJson);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
```

**Update AracRapor Model:**
```dart
// In lib/models/arac_rapor_model.dart
import 'lib/utils/canonical_json.dart';

class AracRapor {
  /// Generate revision hash from canonical JSON
  String? generateRevisionHash() {
    final data = toJson();
    return CanonicalJson.hash(data);
  }
}
```

**Tests:**
```dart
// test/utils/canonical_json_test.dart
void main() {
  test('Canonical JSON produces same hash across platforms', () {
    final data1 = {'z': 1, 'a': 2, 'm': 3};
    final data2 = {'a': 2, 'm': 3, 'z': 1};
    
    // Different key order, same hash
    expect(CanonicalJson.hash(data1), equals(CanonicalJson.hash(data2)));
  });
  
  test('Canonical JSON handles null values consistently', () {
    final data1 = {'a': 1, 'b': null, 'c': 3};
    final data2 = {'a': 1, 'c': 3}; // b is null
    
    // Should produce same hash (nulls removed)
    expect(CanonicalJson.hash(data1), equals(CanonicalJson.hash(data2)));
  });
}
```

**KURAL:**
- Mobil, Web, Backend → aynı veri = aynı hash
- Key sırası önemli değil
- Null değerler normalize edilir

---

### 4️⃣ BULK OPERATION DETERMINISM

**Risk:**
Bulk seal/reject sırasında intent sırası belirsiz olabilir.

**ZORUNLU AKSİYON:**

**Update OperationIntent Model:**
```dart
// In lib/models/operation_intent.dart
class OperationIntent {
  // EXISTING FIELDS...
  
  // NEW FIELD:
  final int? bulkSequenceIndex; // 0-based index in bulk operation
  
  const OperationIntent({
    // ... existing parameters ...
    this.bulkSequenceIndex,
  });
  
  factory OperationIntent.create({
    // ... existing parameters ...
    int? bulkSequenceIndex,
  }) {
    return OperationIntent(
      // ... existing fields ...
      bulkSequenceIndex: bulkSequenceIndex,
    );
  }
  
  // Updated toJson()
  Map<String, dynamic> toJson() {
    return {
      // ... existing fields ...
      'bulkSequenceIndex': bulkSequenceIndex,
    };
  }
}
```

**Bulk Operation Service:**
```dart
// In lib/services/bulk_operation_service.dart
class BulkOperationService {
  Future<List<BulkOperationResult>> bulkSeal({
    required List<String> reportIds,
    required String userId,
    required String userRole,
  }) async {
    // 1. Create intents with sequence indices
    final intents = reportIds.asMap().entries.map((entry) {
      return OperationIntent.create(
        intentType: IntentType.seal,
        reportId: entry.value,
        baseVersionId: null, // Will be fetched
        userId: userId,
        userRole: userRole,
        bulkSequenceIndex: entry.key, // 0, 1, 2, ...
      );
    }).toList();
    
    // 2. Execute in order (or parallel, but preserve order in logs)
    final results = <BulkOperationResult>[];
    for (final intent in intents) {
      try {
        await _executeIntent(intent);
        results.add(BulkOperationResult.success(intent));
      } catch (e) {
        results.add(BulkOperationResult.failure(intent, e));
      }
    }
    
    return results;
  }
  
  Future<void> _executeIntent(OperationIntent intent) async {
    // Fetch current version
    final report = await supabase
      .from('arac_rapor')
      .select()
      .eq('id', intent.reportId)
      .single();
    
    // Execute with sequence tracking
    await sealReport(
      reportId: intent.reportId,
      baseVersionId: report['version_id'],
      baseRevisionCounter: report['revision_counter'],
      bulkSequenceIndex: intent.bulkSequenceIndex,
    );
  }
}
```

**Commit Order Rule:**
```dart
// In service layer
// Commit order is determined by:
// 1. revision_counter (global ordering)
// 2. bulk_sequence_index (local ordering within bulk)

// Audit log entry:
{
  'operation_intent_id': intent.operationId,
  'bulk_sequence_index': intent.bulkSequenceIndex,
  'revision_counter': newRevisionCounter,
  'timestamp': serverCommittedAt,
}
```

**KURAL:**
- Bulk içindeki her intent `bulk_sequence_index` ile gönderilir
- Commit sırası: `revision_counter` + `bulk_sequence_index`
- Deterministic ordering guaranteed

---

### 5️⃣ HAPTIC FEEDBACK (UX + WCAG)

**Risk:**
Geç gelen feedback güven hissini bozar.

**ZORUNLU AKSİYON:**

**Update SlideAction Widget:**
```dart
// In lib/widgets/slide_action.dart
import 'package:flutter/services.dart';

class SlideAction extends StatefulWidget {
  @override
  _SlideActionState createState() => _SlideActionState();
}

class _SlideActionState extends State<SlideAction> {
  // ... existing code ...
  
  void _onDragUpdate(double delta) {
    setState(() {
      _dragPosition += delta;
      
      // HAPTIC FEEDBACK at 90% threshold
      if (_dragPosition >= 0.9 && !_hapticTriggered) {
        _hapticTriggered = true;
        _triggerHaptic();
      }
      
      // Clamp
      _dragPosition = _dragPosition.clamp(0.0, 1.0);
    });
  }
  
  void _triggerHaptic() async {
    // Check if haptic is enabled in settings
    final hapticEnabled = await _isHapticEnabled();
    if (!hapticEnabled) return;
    
    // Light haptic feedback
    await HapticFeedback.lightImpact();
  }
  
  Future<bool> _isHapticEnabled() async {
    // Check user preferences
    // Default: true
    // Can be disabled in settings
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('haptic_enabled') ?? true;
  }
  
  // Reset haptic trigger when slider resets
  void _resetSlider() {
    setState(() {
      _dragPosition = 0;
      _hapticTriggered = false;
    });
  }
}
```

**Settings Page:**
```dart
// In settings page
SwitchListTile(
  title: Text('Haptik Geri Bildirim'),
  subtitle: Text('Kaydırma işlemi sırasında hafif titreşim'),
  value: hapticEnabled,
  onChanged: (value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptic_enabled', value);
    setState(() {
      hapticEnabled = value;
    });
  },
)
```

**WCAG Compliance:**
- Ayarlardan kapatılabilir ✅
- Zorunlu değil (optional) ✅
- Kullanıcı kontrolünde ✅

**KURAL:**
- %90 threshold'ta hafif haptic
- WCAG: Ayarlardan kapatılabilir
- Zorunlu değil

---

### 6️⃣ LOGGING BLOAT (ADLİ ŞİŞME)

**Risk:**
Stacktrace'ler audit log'u kirletir.

**ZORUNLU AKSİYON:**

**Update ErrorBoundary:**
```dart
// In lib/widgets/error_boundary.dart
class ErrorBoundary extends StatefulWidget {
  // ... existing code ...
  
  void _handleError(FlutterErrorDetails details) {
    // 1. Truncate stacktrace to 1024 chars
    final truncatedStacktrace = details.stack?.toString().substring(0, 1024);
    
    // 2. Log structured event (NOT raw text)
    final errorEvent = {
      'error_type': 'widget_error',
      'widget': widget.runtimeType.toString(),
      'message': details.exception.toString(),
      'stacktrace_truncated': truncatedStacktrace,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    
    // 3. Send to audit log (structured)
    auditService.logStructuredEvent(errorEvent);
    
    // 4. Show user-friendly message
    setState(() {
      _errorDetails = details;
    });
  }
}
```

**Audit Service Updates:**
```dart
// In lib/services/audit_service.dart
class AuditService {
  Future<void> logStructuredEvent(Map<String, dynamic> event) async {
    // Validate event structure
    if (!_isValidEvent(event)) {
      throw ArgumentError('Invalid audit event structure');
    }
    
    // Log to database (structured JSON)
    await supabase.from('audit_logs').insert({
      'event_type': event['event_type'],
      'structured_data': event, // JSONB
      'timestamp': DateTime.now().toUtc(),
    });
  }
  
  bool _isValidEvent(Map<String, dynamic> event) {
    // Required fields
    final required = ['event_type', 'timestamp'];
    return required.every((field) => event.containsKey(field));
  }
}
```

**Database Schema:**
```sql
-- Add structured_data column (JSONB)
ALTER TABLE audit_logs
ADD COLUMN structured_data JSONB;

-- Index for querying
CREATE INDEX idx_audit_logs_structured_data
ON audit_logs USING GIN(structured_data);
```

**KURAL:**
- ErrorBoundary: `stacktrace.substring(0, 1024)`
- Audit log: Structured, metin değil olay
- No raw text logging

---

### 7️⃣ PROVIDER LIFECYCLE TEMİZLİĞİ

**Risk:**
Drawer/dialog kapandıktan sonra state sızıntısı.

**ZORUNLU AKSİYON:**

**Update QuickReviewDrawer:**
```dart
// In lib/admin/widgets/quick_review_drawer.dart
class QuickReviewDrawer extends ConsumerStatefulWidget {
  @override
  ConsumerState<QuickReviewDrawer> createState() => _QuickReviewDrawerState();
}

class _QuickReviewDrawerState extends ConsumerState<QuickReviewDrawer> {
  @override
  void dispose() {
    // Invalidate provider when drawer closes
    ref.invalidate(reportStateProvider);
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // ... existing code ...
  }
}
```

**Update ConflictResolutionDialog:**
```dart
// In lib/widgets/conflict_resolution_dialog.dart
class ConflictResolutionDialog extends StatefulWidget {
  @override
  _ConflictResolutionDialogState createState() => _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  @override
  void dispose() {
    // Clean up state
    // Invalidate providers if needed
    super.dispose();
  }
}
```

**General Pattern:**
```dart
// For all drawers, dialogs, modals
@override
void dispose() {
  // 1. Invalidate specific provider
  ref.invalidate(specificProvider);
  
  // 2. Cancel active subscriptions
  _subscription?.cancel();
  
  // 3. Close controllers
  _controller.dispose();
  
  super.dispose();
}
```

**KURAL:**
- Tüm drawers/dialogs dispose override gerekir
- Provider invalidation mandatory
- Subscription cancellation mandatory

---

### 8️⃣ RETRY LIMIT & ADLİ İZ

**Risk:**
Kullanıcı conflict'te döngüye girebilir.

**ZORUNLU AKSİYON:**

**Update ConflictResolutionDialog:**
```dart
// In lib/widgets/conflict_resolution_dialog.dart
class ConflictResolutionDialog extends StatefulWidget {
  final OperationIntent attemptedIntent;
  final AcceptedTruth acceptedTruth;
  
  const ConflictResolutionDialog({
    required this.attemptedIntent,
    required this.acceptedTruth,
  });
  
  @override
  _ConflictResolutionDialogState createState() => _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  int _retryCount = 0;
  static const int _maxRetries = 3;
  
  Future<void> _syncAndRetry() async {
    if (_retryCount >= _maxRetries) {
      // Max retries reached
      await _cancelIntent();
      return;
    }
    
    _retryCount++;
    
    try {
      // Sync with server
      final latestState = await ref.read(reportStateProvider.notifier).syncReport(
        widget.attemptedIntent.reportId,
      );
      
      // Retry operation
      await ref.read(reportStateProvider.notifier).executeIntent(
        widget.attemptedIntent.copyWith(
          baseVersionId: latestState.versionId,
          baseRevisionCounter: latestState.revisionCounter,
        ),
      );
      
      // Success - close dialog
      Navigator.of(context).pop(true);
    } catch (e) {
      // Show error, allow retry
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retry failed: ${e.toString()}')),
      );
    }
  }
  
  Future<void> _cancelIntent() async {
    // Mark intent as cancelled
    await ref.read(reportStateProvider.notifier).cancelIntent(
      widget.attemptedIntent,
    );
    
    // Log retry limit reached
    await ref.read(auditServiceProvider).logEvent(
      eventType: AuditEventType.retryLimitReached,
      reportId: widget.attemptedIntent.reportId,
      intent: widget.attemptedIntent,
      details: {
        'retry_count': _retryCount,
        'max_retries': _maxRetries,
        'reason': 'Max retries exceeded',
      },
    );
    
    // Close dialog
    Navigator.of(context).pop(false);
  }
  
  @override
  Widget build(BuildContext context) {
    // Show retry count if > 0
    return Dialog(
      child: Column(
        children: [
          // ... existing UI ...
          if (_retryCount > 0)
            Text('Deneme $_retryCount/$_maxRetries', style: TextStyle(fontSize: 12)),
          
          // Update button text
          ElevatedButton(
            onPressed: _syncAndRetry,
            child: Text(_retryCount >= _maxRetries 
              ? 'Maksimum Deneme Sayısına Ulaşıldı' 
              : 'Senkronize Et & Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}
```

**Add AuditEventType:**
```dart
// In lib/models/audit_log.dart
enum AuditEventType {
  seal,
  reject,
  conflictDetected,
  conflictResolved,
  userAcknowledgedConflict,
  retryLimitReached, // NEW
  userCancelledIntent, // NEW
}
```

**KURAL:**
- Max retry: 3
- 3 denemeden sonra intent → cancelled
- Audit: RETRY_LIMIT_REACHED

---

### 9️⃣ ROLE-AWARE DİL (SON KATMAN)

**Risk:**
Tek metin tüm roller için uygun olmayabilir.

**ZORUNLU AKSİYON:**

**Create Role-Aware Text Service:**
```dart
// lib/services/role_aware_text_service.dart

enum UserRole { admin, personnel, customer }

class RoleAwareTextService {
  static String getOperationCompleteMessage({
    required UserRole role,
    required String operationType,
  }) {
    switch (role) {
      case UserRole.admin:
        return 'İşlemi siz tamamladınız';
      case UserRole.personnel:
        return 'Yetkili tarafından tamamlandı';
      case UserRole.customer:
        return 'Rapor sonuçlandı';
    }
  }
  
  static String getConflictMessage({
    required UserRole role,
  }) {
    switch (role) {
      case UserRole.admin:
        return 'Başka bir yönetici tarafından değiştirildi';
      case UserRole.personnel:
        return 'Yetkili tarafından değiştirildi';
      case UserRole.customer:
        return 'Rapor güncellendi';
    }
  }
}
```

**Update UI Components:**
```dart
// In widgets
class ReportStatusCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final role = _mapToUserRole(user.role);
    
    final message = RoleAwareTextService.getOperationCompleteMessage(
      role: role,
      operationType: 'seal',
    );
    
    return Text(message);
  }
}
```

**Conflict Resolution Dialog:**
```dart
// In ConflictResolutionDialog
Text(
  RoleAwareTextService.getConflictMessage(role: userRole),
  style: TextStyle(fontSize: 14),
)
```

**Translation Table:**
```
Rol | Metin
----|------
Admin | "İşlemi siz tamamladınız"
Personnel | "Yetkili tarafından tamamlandı"
Customer | "Rapor sonuçlandı"

Hakikat aynı, anlatım rol bazlı.
```

**KURAL:**
- Hakikat aynı
- Anlatım rol bazlı
- Role-aware text service kullan

---

## ✅ DEFINITION OF DONE (MICRO)

Bu görev bitmiş sayılır ancak:

- [ ] UUID + revision_counter birlikte çalışıyorsa
- [ ] Hash her platformda aynıysa
- [ ] Bulk işlemler deterministikse
- [ ] Conflict UX sakin ve tek mesajlıysa
- [ ] Audit log sade ve şişmemişse
- [ ] Personnel & Customer paneli "sessiz güven" hissi veriyorsa

---

## 📊 IMPLEMENTATION ESTIMATE

```
┌─────────────────────────────────────────┐
│ Micro-Risk Polish Estimate               │
├─────────────────────────────────────────┤
│ 1. Revision Counter (2-3h)              │
│ 2. UTC Drift Fixes (1h)                 │
│ 3. Canonical JSON (2-3h)                │
│ 4. Bulk Determinism (2h)                │
│ 5. Haptic Feedback (1h)                 │
│ 6. Logging Bloat Fix (1h)               │
│ 7. Provider Lifecycle (1h)              │
│ 8. Retry Limit (2h)                     │
│ 9. Role-Aware Text (1h)                 │
├─────────────────────────────────────────┤
│ TOTAL: 13-16 hours                      │
└─────────────────────────────────────────┘
```

---

## 🧭 STRATEJİK NOT

**Bu görevden sonra sistem:**
- Teknik olarak tamam ✅
- Hukuki olarak yorumsuz ✅
- UX olarak yorucu değil ✅

---

## 📁 FILES TO CREATE

1. `lib/utils/canonical_json.dart` - Canonical JSON utility
2. `lib/services/role_aware_text_service.dart` - Role-aware text
3. `lib/services/bulk_operation_service.dart` - Bulk operations
4. `test/utils/canonical_json_test.dart` - Tests

## 📝 FILES TO MODIFY

1. `lib/models/arac_rapor_model.dart` - Add revision_counter
2. `lib/models/audit_log.dart` - Add referenced fields
3. `lib/models/operation_intent.dart` - Add bulk_sequence_index
4. `lib/widgets/slide_action.dart` - Add haptic feedback
5. `lib/widgets/error_boundary.dart` - Truncate stacktrace
6. `lib/widgets/conflict_resolution_dialog.dart` - Retry limit
7. `lib/admin/widgets/quick_review_drawer.dart` - Lifecycle cleanup
8. `database_schema.sql` - Add revision_counter column

---

*Generated: February 3, 2026*  
*Author: Cline - Principal Systems Engineer & Forensic Consistency Specialist*  
*Version: 1.0.0 (Micro-Risk Polish Strategic Plan)*