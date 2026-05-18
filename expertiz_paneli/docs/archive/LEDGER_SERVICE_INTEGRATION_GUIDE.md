# LedgerService Integration Guide

## FAZ-0.7.1 / A — Integration with Existing Services

---

## 📋 OVERVIEW

This guide explains how to integrate the `LedgerService` into the existing YerimeBak codebase, specifically with the VisionEngine and AI analysis services.

---

## 🎯 INTEGRATION POINTS

### 1. Service Orchestrator Integration

The `LedgerService` should be registered with the `ServiceOrchestrator` to manage its lifecycle.

**File**: `lib/core/services/service_orchestrator.dart`

```dart
import '../services/ledger_service.dart';

class ServiceOrchestrator {
  LedgerService? _ledgerService;
  
  // Initialize LedgerService
  Future<void> initializeServices(Session session) async {
    // ... existing service initialization ...
    
    // Initialize LedgerService
    _ledgerService = LedgerService(Supabase.instance.client);
    await _ledgerService.start(session);
    
    // ... rest of initialization ...
  }
  
  // Stop all services on logout
  Future<void> stopAllServices() async {
    // ... existing service shutdown ...
    
    // Stop LedgerService
    if (_ledgerService != null) {
      await _ledgerService!.stop();
      _ledgerService = null;
    }
    
    // ... rest of shutdown ...
  }
  
  // Getter for LedgerService
  LedgerService? get ledgerService => _ledgerService;
}
```

### 2. AI Analysis Service Integration

The `AIAnalizService` should use `LedgerService` to seal evidence after analysis.

**File**: `lib/services/ai/ai_analiz_service.dart`

```dart
import 'ledger_service.dart';

class AIAnalizService {
  final LedgerService _ledgerService;
  
  AIAnalizService(this._ledgerService);
  
  Future<AIAnalysisResult> analyzeAndSeal({
    required String reportId,
    required Uint8List imageData,
    required Map<String, dynamic> vehicleInfo,
  }) async {
    // Step 1: Calculate image hash
    final imageHash = sha256.convert(imageData).toString();
    
    // Step 2: Perform AI analysis
    final analysisResult = await _performAnalysis(imageData, vehicleInfo);
    
    // Step 3: Build evidence packets
    final reasoning = {
      'analysis_type': 'vehicle_damage_assessment',
      'damage_detected': analysisResult.hasDamage,
      'confidence_level': analysisResult.confidence,
      'analyzed_regions': analysisResult.regions.map((region) => {
        'bounding_box': region.boundingBox,
        'damage_type': region.damageType,
        'severity': region.severity,
      }).toList(),
      'metadata': {
        'image_dimensions': analysisResult.dimensions,
        'processing_time_ms': analysisResult.processingTimeMs,
      },
    };
    
    final aiOutput = {
      'classification': analysisResult.classification,
      'overall_severity': analysisResult.overallSeverity,
      'repair_recommendation': analysisResult.recommendation,
      'estimated_repair_cost': analysisResult.estimatedCost,
      'requires_inspection': analysisResult.requiresInspection,
    };
    
    // Step 4: Seal evidence in ledger
    try {
      final recordId = await _ledgerService.writeEvidence(
        reportId: reportId,
        imageHash: imageHash,
        reasoning: reasoning,
        aiOutput: aiOutput,
        modelVersion: 'gemini-1.5-flash',
        confidenceScore: analysisResult.confidence,
      );
      
      // Attach ledger record ID to result
      analysisResult.ledgerRecordId = recordId;
      
      return analysisResult;
      
    } catch (e) {
      // Critical: Evidence sealing failed
      throw AIAnalysisException(
        'Analysis completed but evidence sealing failed: $e',
        details: {
          'report_id': reportId,
          'image_hash': imageHash,
          'error': e.toString(),
        },
      );
    }
  }
}
```

### 3. VisionEngine Service Integration

The `VisionEngineService` should delegate evidence sealing to `LedgerService`.

**File**: `lib/services/vision_engine_service.dart`

```dart
import 'ledger_service.dart';

class VisionEngineService {
  final LedgerService _ledgerService;
  
  VisionEngineService(this._ledgerService);
  
  Future<VisionAnalysisResult> analyzeImage({
    required String reportId,
    required String imagePath,
  }) async {
    // Step 1: Read image and calculate hash
    final imageData = await File(imagePath).readAsBytes();
    final imageHash = sha256.convert(imageData).toString();
    
    // Step 2: Send to Vision Engine (Python backend)
    final analysisResult = await _callVisionEngine(imageData);
    
    // Step 3: Build evidence packets
    final reasoning = {
      'engine_version': 'v2.0',
      'analysis_timestamp': DateTime.now().toUtc().toIso8601String(),
      'confidence_scores': analysisResult.confidenceScores,
      'detected_objects': analysisResult.detectedObjects,
      'spatial_analysis': analysisResult.spatialAnalysis,
    };
    
    final aiOutput = {
      'damage_assessment': analysisResult.damageAssessment,
      'severity_rating': analysisResult.severityRating,
      'recommended_actions': analysisResult.recommendedActions,
    };
    
    // Step 4: Seal evidence
    try {
      final recordId = await _ledgerService.writeEvidence(
        reportId: reportId,
        imageHash: imageHash,
        reasoning: reasoning,
        aiOutput: aiOutput,
        modelVersion: 'vision-engine-v2.0',
        confidenceScore: analysisResult.overallConfidence,
      );
      
      analysisResult.ledgerRecordId = recordId;
      return analysisResult;
      
    } catch (e) {
      throw VisionEngineException(
        'Vision analysis completed but evidence sealing failed: $e',
      );
    }
  }
}
```

### 4. Report Service Integration

The `RaporService` should retrieve ledger records for report generation.

**File**: `lib/services/rapor_service.dart`

```dart
class RaporService {
  Future<List<LedgerRecord>> getLedgerRecordsForReport(String reportId) async {
    final response = await Supabase.instance.client
        .from('explainability_ledger')
        .select()
        .eq('report_id', reportId)
        .order('created_at', ascending: true);
    
    return response.map((json) => LedgerRecord.fromJson(json)).toList();
  }
  
  Future<RaporOzeti> generateRaporOzeti(String reportId) async {
    // Get report data
    final report = await getReport(reportId);
    
    // Get ledger records
    final ledgerRecords = await getLedgerRecordsForReport(reportId);
    
    // Include cryptographic proof
    final cryptographicProof = {
      'total_records': ledgerRecords.length,
      'first_record_hash': ledgerRecords.first.decisionHash,
      'last_record_hash': ledgerRecords.last.decisionHash,
      'immutable_ledger': true,
      'forensic_grade': 'court-defensible',
    };
    
    return RaporOzeti(
      report: report,
      ledgerRecords: ledgerRecords,
      cryptographicProof: cryptographicProof,
    );
  }
}
```

---

## 🔧 DEPENDENCY INJECTION

### Using Provider (Recommended)

```dart
// In main.dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ... existing providers ...
        
        // LedgerService provider
        ChangeNotifierProvider<LedgerServiceNotifier>(
          create: (context) => LedgerServiceNotifier(
            LedgerService(Supabase.instance.client),
          ),
        ),
        
        // Services that depend on LedgerService
        ProxyProvider<LedgerServiceNotifier, AIAnalizService>(
          update: (context, ledgerNotifier, previous) {
            return AIAnalizService(ledgerNotifier.service);
          },
        ),
      ],
      child: MaterialApp(...),
    );
  }
}

// Notifier class
class LedgerServiceNotifier extends ChangeNotifier {
  final LedgerService service;
  
  LedgerServiceNotifier(this.service);
  
  Future<void> initialize(Session session) async {
    await service.start(session);
    notifyListeners();
  }
  
  Future<void> disposeService() async {
    await service.stop();
    notifyListeners();
  }
}
```

### Using GetIt (Alternative)

```dart
// In service_locator.dart
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // Register LedgerService
  getIt.registerLazySingleton<LedgerService>(
    () => LedgerService(Supabase.instance.client),
  );
  
  // Register services that depend on LedgerService
  getIt.registerFactory<AIAnalizService>(
    () => AIAnalizService(getIt<LedgerService>()),
  );
}
```

---

## 🧪 TESTING INTEGRATION

### Unit Test with Mock LedgerService

```dart
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';

class MockLedgerService extends Mock implements LedgerService {}

void main() {
  group('AIAnalizService Integration', () {
    late AIAnalizService aiService;
    late MockLedgerService mockLedgerService;
    
    setUp(() {
      mockLedgerService = MockLedgerService();
      aiService = AIAnalizService(mockLedgerService);
    });
    
    test('should seal evidence after analysis', () async {
      // Setup
      final reportId = 'test-report-id';
      final imageData = Uint8List.fromList([1, 2, 3, 4, 5]);
      
      // Mock ledger service
      when(mockLedgerService.writeEvidence(
        reportId: anyNamed('reportId'),
        imageHash: anyNamed('imageHash'),
        reasoning: anyNamed('reasoning'),
        aiOutput: anyNamed('aiOutput'),
        modelVersion: anyNamed('modelVersion'),
        confidenceScore: anyNamed('confidenceScore'),
      )).thenAnswer((_) async => 'ledger-record-id');
      
      // Execute
      final result = await aiService.analyzeAndSeal(
        reportId: reportId,
        imageData: imageData,
        vehicleInfo: {},
      );
      
      // Verify
      expect(result.ledgerRecordId, 'ledger-record-id');
      verify(mockLedgerService.writeEvidence(
        reportId: reportId,
        imageHash: anyNamed('imageHash'),
        reasoning: anyNamed('reasoning'),
        aiOutput: anyNamed('aiOutput'),
        modelVersion: anyNamed('modelVersion'),
        confidenceScore: anyNamed('confidenceScore'),
      )).called(1);
    });
  });
}
```

### Integration Test with Real Ledger

```dart
void main() {
  testWidgets('end-to-end evidence sealing', (tester) async {
    // Setup app
    await tester.pumpWidget(MyApp());
    
    // Login
    await tester.enterText(find.byKey('email'), 'test@example.com');
    await tester.enterText(find.byKey('password'), 'password');
    await tester.tap(find.byKey('login-button'));
    await tester.pumpAndSettle();
    
    // Navigate to report creation
    await tester.tap(find.byKey('create-report-button'));
    await tester.pumpAndSettle();
    
    // Upload image
    await tester.tap(find.byKey('upload-image-button'));
    await tester.pumpAndSettle();
    
    // Trigger AI analysis
    await tester.tap(find.byKey('analyze-button'));
    await tester.pumpAndSettle();
    
    // Verify evidence was sealed
    expect(find.text('Evidence Sealed'), findsOneWidget);
    expect(find.textContaining('legally non-repudiable'), findsOneWidget);
    
    // Verify in database
    final records = await Supabase.instance.client
        .from('explainability_ledger')
        .select();
    expect(records.length, greaterThan(0));
  });
}
```

---

## 📊 MONITORING & LOGGING

### Logging Evidence Sealing Events

```dart
import 'package:logger/logger.dart';

class LedgerServiceLogger {
  final Logger _logger = Logger();
  
  void logEvidenceSealingAttempt({
    required String reportId,
    required String imageHash,
  }) {
    _logger.i(
      'Attempting to seal evidence',
      error: null,
      time: DateTime.now(),
      stackTrace: StackTrace.current,
    );
  }
  
  void logEvidenceSealingSuccess({
    required String reportId,
    required String recordId,
    required String decisionHash,
  }) {
    _logger.i(
      'Evidence sealed successfully',
      error: null,
      time: DateTime.now(),
      stackTrace: StackTrace.current,
    );
  }
  
  void logEvidenceSealingFailure({
    required String reportId,
    required String error,
    required dynamic exception,
  }) {
    _logger.e(
      'Evidence sealing failed',
      error: error,
      time: DateTime.now(),
      stackTrace: StackTrace.current,
      exception: exception,
    );
  }
}
```

### Monitoring Dashboard Integration

```dart
class LedgerServiceMonitor {
  Future<void> reportMetrics() async {
    final totalRecords = await Supabase.instance.client
        .from('explainability_ledger')
        .select('*', count: CountOption.exact);
    
    final todayRecords = await Supabase.instance.client
        .from('explainability_ledger')
        .select('*', count: CountOption.exact)
        .gte('created_at', DateTime.now().toUtc().subtract(Duration(days: 1)).toIso8601String());
    
    // Send to monitoring service
    await MonitoringService.reportMetrics({
      'ledger.total_records': totalRecords,
      'ledger.today_records': todayRecords,
      'ledger.immutable': true,
      'ledger.court_defensible': true,
    });
  }
}
```

---

## 🚨 ERROR HANDLING STRATEGY

### Centralized Error Handler

```dart
class LedgerErrorHandler {
  static Future<void> handleError({
    required dynamic error,
    required StackTrace stackTrace,
    required String context,
  }) async {
    // Log error
    Logger().e(
      context,
      error: error,
      stackTrace: stackTrace,
    );
    
    // Send to error tracking service
    await ErrorTrackingService.captureException(
      error,
      stackTrace: stackTrace,
      context: {
        'context': context,
        'service': 'LedgerService',
      },
    );
    
    // Show user-friendly message
    if (error is StateError) {
      await _showAuthenticationError();
    } else if (error is ArgumentError) {
      await _showValidationError(error.message);
    } else {
      await _showCriticalError();
    }
  }
  
  static Future<void> _showAuthenticationError() async {
    // Show dialog and redirect to login
  }
  
  static Future<void> _showValidationError(String message) async {
    // Show validation error dialog
  }
  
  static Future<void> _showCriticalError() async {
    // Show critical error dialog
    // Suggest user contact support
  }
}
```

---

## 🎯 MIGRATION CHECKLIST

### Phase 1: Preparation
- [ ] Review all existing services that write to explainability_ledger
- [ ] Identify all direct Supabase inserts to ledger
- [ ] Document current evidence sealing process
- [ ] Create integration test suite

### Phase 2: Implementation
- [ ] Integrate LedgerService with ServiceOrchestrator
- [ ] Update AIAnalizService to use LedgerService
- [ ] Update VisionEngineService to use LedgerService
- [ ] Update RaporService to read ledger records
- [ ] Add error handling wrappers

### Phase 3: Testing
- [ ] Run unit tests for LedgerService
- [ ] Run integration tests with mock services
- [ ] Run end-to-end tests with real ledger
- [ ] Verify cryptographic integrity
- [ ] Test authentication flows
- [ ] Test error scenarios

### Phase 4: Deployment
- [ ] Deploy database migration (FAZ-0.7.0)
- [ ] Deploy LedgerService code
- [ ] Update all service integrations
- [ ] Monitor for errors
- [ ] Verify evidence sealing in production

### Phase 5: Verification
- [ ] Confirm no direct Supabase inserts remain
- [ ] Confirm all evidence is sealed
- [ ] Confirm all records have valid hashes
- [ ] Confirm audit trail is complete
- [ ] Confirm legal defensibility

---

## 📞 ROLLBACK PROCEDURE

If issues occur after deployment:

1. **Stop new evidence sealing**
   ```dart
   // Feature flag
   const bool LEDGER_ENABLED = false;
   
   if (LEDGER_ENABLED) {
     await ledgerService.writeEvidence(...);
   }
   ```

2. **Revert to previous implementation**
   ```dart
   // Fallback to direct inserts (temporary)
   await Supabase.instance.client
       .from('explainability_ledger')
       .insert({...});
   ```

3. **Investigate and fix issues**
   - Review error logs
   - Check database constraints
   - Verify service lifecycle
   - Test in staging environment

4. **Re-deploy when ready**
   - Enable feature flag
   - Monitor closely
   - Verify all operations

---

## 🪨 FINAL INTEGRATION CHECK

Before considering integration complete:

- [ ] LedgerService is initialized with authentication
- [ ] All services use LedgerService for writes
- [ ] No direct Supabase inserts remain
- [ ] All errors are handled explicitly
- [ ] All errors are logged
- [ ] All errors are reported to users
- [ ] Tests pass (unit, integration, e2e)
- [ ] Documentation is updated
- [ ] Team is trained on usage
- [ ] Monitoring is configured

---

*FAZ-0.7.1/A: LedgerService Integration Guide*
*Version: 1.0.0*
*Last Updated: 2026-02-01*
*Status: Ready for Integration*