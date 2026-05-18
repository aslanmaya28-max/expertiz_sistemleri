/// AUDIT LOG MODEL - Audit Log Database Record
/// 
/// Supabase audit_logs tablosu için model
library;

import 'package:equatable/equatable.dart';
import 'audit_action.dart';

/// Audit Log Model
/// 
/// Tüm sistem işlemlerinin kaydı
class AuditLog extends Equatable {
  /// Unique identifier
  final String id;
  
  /// User who performed the action
  final String userId;
  
  /// User email (denormalized for query performance)
  final String userEmail;
  
  /// User full name (denormalized for query performance)
  final String userName;
  
  /// Action performed
  final AuditAction action;
  
  /// Entity type (e.g., 'report', 'user', 'payment')
  final String entityType;
  
  /// Entity ID
  final String? entityId;
  
  /// Old value (before change)
  final Map<String, dynamic>? oldValue;
  
  /// New value (after change)
  final Map<String, dynamic>? newValue;
  
  /// IP address
  final String? ipAddress;
  
  /// User agent
  final String? userAgent;
  
  /// Additional metadata
  final Map<String, dynamic>? metadata;
  
  /// Timestamp
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.action,
    required this.entityType,
    this.entityId,
    this.oldValue,
    this.newValue,
    this.ipAddress,
    this.userAgent,
    this.metadata,
    required this.createdAt,
  });

  /// Create AuditLog from Supabase JSON
  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userEmail: json['user_email']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
      action: AuditActionExtension.fromDatabaseValue(
        json['action']?.toString() ?? 'SYSTEM_SETTING_CHANGED'
      ),
      entityType: json['entity_type']?.toString() ?? '',
      entityId: json['entity_id']?.toString(),
      oldValue: json['old_value'] as Map<String, dynamic>?,
      newValue: json['new_value'] as Map<String, dynamic>?,
      ipAddress: json['ip_address']?.toString(),
      userAgent: json['user_agent']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_email': userEmail,
      'user_name': userName,
      'action': action.toDatabaseValue,
      'entity_type': entityType,
      'entity_id': entityId,
      'old_value': oldValue,
      'new_value': newValue,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// CopyWith for immutability
  AuditLog copyWith({
    String? id,
    String? userId,
    String? userEmail,
    String? userName,
    AuditAction? action,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    String? ipAddress,
    String? userAgent,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return AuditLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      action: action ?? this.action,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      oldValue: oldValue ?? this.oldValue,
      newValue: newValue ?? this.newValue,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // =====================================================
  // CONVENIENCE METHODS
  // =====================================================

  /// Get description
  String get description {
    final entityName = entityId ?? entityType;
    return '${action.displayName}: $entityName';
  }

  /// Get category
  String get category => action.category;

  /// Get icon name
  String get iconName => action.iconName;

  /// Check if this is a critical action
  bool get isCritical {
    return [
      AuditAction.reportDeleted,
      AuditAction.reportApproved,
      AuditAction.userDeleted,
      AuditAction.userRoleChanged,
      AuditAction.paymentRefunded,
      AuditAction.systemSettingChanged,
    ].contains(action);
  }

  /// Check if this is a financial action
  bool get isFinancial {
    return action.category == 'FINANCIAL';
  }

  /// Check if this is an AI action
  bool get isAIAction {
    return action.category == 'AI';
  }

  /// Check if this is a user management action
  bool get isUserManagement {
    return action.category == 'USER';
  }

  /// Check if this is a report action
  bool get isReportAction {
    return action.category == 'REPORT';
  }

  @override
  String toString() {
    return 'AuditLog(id: $id, action: $action, user: $userName, entity: $entityType)';
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        userEmail,
        userName,
        action,
        entityType,
        entityId,
        oldValue,
        newValue,
        ipAddress,
        userAgent,
        metadata,
        createdAt,
      ];
}

/// Audit Log Filter
class AuditLogFilter {
  final AuditAction? action;
  final String? entityType;
  final String? entityId;
  final String? userId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? category;

  const AuditLogFilter({
    this.action,
    this.entityType,
    this.entityId,
    this.userId,
    this.startDate,
    this.endDate,
    this.category,
  });

  /// Convert to Supabase filter
  Map<String, dynamic> toSupabaseFilter() {
    final filters = <String, dynamic>{};
    
    if (action != null) {
      filters['action'] = action!.toDatabaseValue;
    }
    
    if (entityType != null) {
      filters['entity_type'] = entityType;
    }
    
    if (entityId != null) {
      filters['entity_id'] = entityId;
    }
    
    if (userId != null) {
      filters['user_id'] = userId;
    }
    
    if (startDate != null) {
      filters['created_at'] = {'gte': startDate!.toIso8601String()};
    }
    
    if (endDate != null) {
      filters['created_at'] = {'lte': endDate!.toIso8601String()};
    }
    
    return filters;
  }

  /// Check if filter is empty
  bool get isEmpty =>
      action == null &&
      entityType == null &&
      entityId == null &&
      userId == null &&
      startDate == null &&
      endDate == null &&
      category == null;
}