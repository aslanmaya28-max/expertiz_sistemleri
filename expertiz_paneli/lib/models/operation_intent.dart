// PHASE 6.9 - Sprint 3: Concurrency & Conflict Sovereignty
// 
// OPERATION INTENT MODEL
// 
// Purpose: Track and guarantee idempotency of operations
// Each user action gets a unique operation_id to prevent duplicate execution
//
// Use Cases:
// - Double tap prevention
// - Network retry handling
// - App resume after crash
// - Conflict detection

import 'package:uuid/uuid.dart';

/// Operation Intent Types
enum IntentType {
  seal,
  reject,
  assign,
  unassign,
  annotate,
  bulkSeal,
}

/// Operation Intent Model
/// 
/// Represents a single user action with unique identifier
/// Ensures idempotency across UI, Provider, and Network layers
class OperationIntent {
  /// Unique identifier for this operation (UUID)
  /// Generated client-side, used to prevent duplicate execution
  final String operationId;
  
  /// Type of operation being performed
  final IntentType intentType;
  
  /// Logical timestamp (monotonic increasing)
  /// Used for offline queue ordering
  final DateTime timestamp;
  
  /// Report ID this operation targets
  final String reportId;
  
  /// Base version_id of report at operation creation
  /// Used for conflict detection
  final String? baseVersionId;
  
  /// Base revision_hash of report at operation creation
  /// Used for conflict detection (alternative to version_id)
  final String? baseRevisionHash;
  
  /// User ID performing the operation
  final String userId;
  
  /// User role (admin, personnel, customer)
  final String userRole;
  
  /// Additional payload for the operation
  /// E.g., annotation text, seal reason, etc.
  final Map<String, dynamic>? payload;
  
  /// Whether this operation is currently being executed
  final bool isSubmitting;
  
  /// Whether this operation completed successfully
  final bool isCompleted;
  
  /// Error message if operation failed
  final String? errorMessage;

  OperationIntent({
    required this.operationId,
    required this.intentType,
    required this.timestamp,
    required this.reportId,
    this.baseVersionId,
    this.baseRevisionHash,
    required this.userId,
    required this.userRole,
    this.payload,
    this.isSubmitting = false,
    this.isCompleted = false,
    this.errorMessage,
  });

  /// Factory: Create new operation intent with generated UUID
  /// 
  /// Creates a new OperationIntent with:
  /// - Unique UUID operationId
  /// - Current UTC timestamp
  /// - Default state (not submitting, not completed)
  factory OperationIntent.create({
    required IntentType intentType,
    required String reportId,
    String? baseVersionId,
    String? baseRevisionHash,
    required String userId,
    required String userRole,
    Map<String, dynamic>? payload,
  }) {
    return OperationIntent(
      operationId: Uuid().v4(),
      intentType: intentType,
      timestamp: DateTime.now().toUtc(),
      reportId: reportId,
      baseVersionId: baseVersionId,
      baseRevisionHash: baseRevisionHash,
      userId: userId,
      userRole: userRole,
      payload: payload,
    );
  }

  /// Create copy with modified fields
  OperationIntent copyWith({
    String? operationId,
    IntentType? intentType,
    DateTime? timestamp,
    String? reportId,
    String? baseVersionId,
    String? baseRevisionHash,
    String? userId,
    String? userRole,
    Map<String, dynamic>? payload,
    bool? isSubmitting,
    bool? isCompleted,
    String? errorMessage,
  }) {
    return OperationIntent(
      operationId: operationId ?? this.operationId,
      intentType: intentType ?? this.intentType,
      timestamp: timestamp ?? this.timestamp,
      reportId: reportId ?? this.reportId,
      baseVersionId: baseVersionId ?? this.baseVersionId,
      baseRevisionHash: baseRevisionHash ?? this.baseRevisionHash,
      userId: userId ?? this.userId,
      userRole: userRole ?? this.userRole,
      payload: payload ?? this.payload,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isCompleted: isCompleted ?? this.isCompleted,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Convert to JSON for logging/storage
  Map<String, dynamic> toJson() {
    return {
      'operationId': operationId,
      'intentType': intentType.toString(),
      'timestamp': timestamp.toIso8601String(),
      'reportId': reportId,
      'baseVersionId': baseVersionId,
      'baseRevisionHash': baseRevisionHash,
      'userId': userId,
      'userRole': userRole,
      'payload': payload,
      'isSubmitting': isSubmitting,
      'isCompleted': isCompleted,
      'errorMessage': errorMessage,
    };
  }

  /// Create from JSON
  factory OperationIntent.fromJson(Map<String, dynamic> json) {
    return OperationIntent(
      operationId: json['operationId'] as String,
      intentType: _parseIntentType(json['intentType'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      reportId: json['reportId'] as String,
      baseVersionId: json['baseVersionId'] as String?,
      baseRevisionHash: json['baseRevisionHash'] as String?,
      userId: json['userId'] as String,
      userRole: json['userRole'] as String,
      payload: json['payload'] as Map<String, dynamic>?,
      isSubmitting: json['isSubmitting'] as bool? ?? false,
      isCompleted: json['isCompleted'] as bool? ?? false,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  /// Parse IntentType from string
  static IntentType _parseIntentType(String value) {
    return IntentType.values.firstWhere(
      (e) => e.toString() == value,
      orElse: () => IntentType.seal,
    );
  }

  /// Check if this operation conflicts with another
  /// Returns true if operations have different intents on same report
  bool conflictsWith(OperationIntent other) {
    if (reportId != other.reportId) return false;
    if (intentType == other.intentType) return false;
    
    // Same report, different intents = potential conflict
    return true;
  }

  /// Check if this operation can be merged with given server version
  /// Returns false if version mismatch detected (conflict)
  bool canMergeWithServer({
    required String? serverVersionId,
    required String? serverRevisionHash,
  }) {
    // No base version info = assume can merge (legacy support)
    if (baseVersionId == null && baseRevisionHash == null) return true;
    
    // Check version match
    if (baseVersionId != null && serverVersionId != null) {
      return baseVersionId == serverVersionId;
    }
    
    // Check revision hash match
    if (baseRevisionHash != null && serverRevisionHash != null) {
      return baseRevisionHash == serverRevisionHash;
    }
    
    // Mismatch = conflict
    return false;
  }

  @override
  String toString() {
    return 'OperationIntent(operationId: $operationId, type: $intentType, report: $reportId, user: $userId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OperationIntent && other.operationId == operationId;
  }

  @override
  int get hashCode => operationId.hashCode;
}