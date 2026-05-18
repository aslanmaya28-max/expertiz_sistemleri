// PHASE 6.8.3 - Sprint 2B: Mock Repository for Forensic Testing
//
// PURPOSE:
// Controlled chaos for integration testing.
// Simulates network failures, partial failures, and latency.
//
// CAPABILITIES:
// - Mid-operation SocketException
// - Partial 404 (ID-based)
// - Random latency (50ms - 800ms)
// - Call tracking for forensic verification

import 'dart:async';
import 'dart:math';

/// Mock Report Repository for Forensic Testing
class MockReportRepository {
  final Random _random = Random(42); // Deterministic seed
  final List<String> _sealReportCalls = [];
  final List<String> _rollbackCalls = [];
  final List<String> _completedIds = [];
  
  // Configuration
  final Set<String> _notFoundIds;
  final int _failAtOperation; // Fail after this many operations
  int _operationCount = 0;
  final bool _shouldFail;
  final Duration _minLatency;
  final Duration _maxLatency;

  MockReportRepository({
    Set<String> notFoundIds = const {},
    int failAtOperation = -1, // -1 means no failure
    bool shouldFail = false,
    Duration minLatency = Duration.zero,
    Duration maxLatency = const Duration(milliseconds: 1),
  })  : _notFoundIds = notFoundIds,
        _failAtOperation = failAtOperation,
        _shouldFail = shouldFail,
        _minLatency = minLatency,
        _maxLatency = maxLatency;

  /// Call tracking
  List<String> get sealReportCalls => List.unmodifiable(_sealReportCalls);
  List<String> get rollbackCalls => List.unmodifiable(_rollbackCalls);
  List<String> get completedIds => List.unmodifiable(_completedIds);
  int get operationCount => _operationCount;

  /// Reset call tracking
  void reset() {
    _sealReportCalls.clear();
    _rollbackCalls.clear();
    _completedIds.clear();
    _operationCount = 0;
  }

  /// Simulate network latency
  Future<void> _simulateLatency() async {
    final latencyRange = _maxLatency.inMilliseconds - _minLatency.inMilliseconds;
    final latencyMs = _minLatency.inMilliseconds +
        (latencyRange > 0 ? _random.nextInt(latencyRange) : 0);
    await Future.delayed(Duration(milliseconds: latencyMs));
  }

  /// Seal a single report
  Future<void> sealReport(String reportId) async {
    await _simulateLatency();
    
    _operationCount++;
    _sealReportCalls.add(reportId);

    // Check if this ID should return 404
    if (_notFoundIds.contains(reportId)) {
      throw Exception('Report not found: $reportId (404)');
    }

    // Check if we should fail mid-operation
    if (_shouldFail && _operationCount > _failAtOperation) {
      throw SocketException('Connection lost during operation $_operationCount');
    }

    // Success
    _completedIds.add(reportId);
  }

  /// Rollback optimistic updates
  Future<void> rollback(List<String> reportIds) async {
    await _simulateLatency();
    _rollbackCalls.addAll(reportIds);
  }

  /// Bulk seal multiple reports
  /// Throws on first failure for atomic operation testing
  Future<BulkSealResult> bulkSeal(List<String> reportIds) async {
    final succeeded = <String>[];
    final failed = <String>[];

    for (final reportId in reportIds) {
      try {
        await sealReport(reportId);
        succeeded.add(reportId);
      } catch (e) {
        failed.add(reportId);
        continue;
      }
    }

    return BulkSealResult(
      succeeded: succeeded,
      failed: failed,
      completedCount: succeeded.length,
      failedCount: failed.length,
    );
  }
}

/// Bulk Seal Result
class BulkSealResult {
  final List<String> succeeded;
  final List<String> failed;
  final int completedCount;
  final int failedCount;

  BulkSealResult({
    required this.succeeded,
    required this.failed,
    required this.completedCount,
    required this.failedCount,
  });
}

/// Custom SocketException for testing
class SocketException implements Exception {
  final String message;
  SocketException(this.message);

  @override
  String toString() => 'SocketException: $message';
}
