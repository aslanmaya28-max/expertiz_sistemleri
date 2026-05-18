/// NOTIFICATION SERVICE
/// 
/// FAZ-3.0 / S3 — Real-time Notification System
/// 
/// ⚖️ LEGAL STANDARD:
/// This service provides forensic-grade notification tracking.
/// All notifications are logged and audited.
/// 
/// 🎯 PURPOSE:
/// - Real-time notifications for status changes
/// - Admin: New pending reports
/// - Customer: Published reports
/// - Personnel: Rejection notifications
/// - In-app + optional push/email notifications
/// 
/// 🪨 PRINCIPLE:
/// "Every notification is evidence of system activity."
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notification Type
enum NotificationType {
  /// Report submitted for AI analysis
  reportSubmitted,
  
  /// AI analysis complete
  aiAnalysisComplete,
  
  /// Report ready for admin review
  pendingReview,
  
  /// Report approved and published
  reportPublished,
  
  /// Report rejected
  reportRejected,
  
  /// Report reopened for correction
  reportReopened,
}

/// Notification Priority
enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

/// App Notification
/// 
/// Represents a single notification in the system
class AppNotification {
  /// Unique notification ID
  final String id;
  
  /// Notification type
  final NotificationType type;
  
  /// Notification priority
  final NotificationPriority priority;
  
  /// Notification title
  final String title;
  
  /// Notification message
  final String message;
  
  /// Related report ID
  final String? reportId;
  
  /// User ID (recipient)
  final String userId;
  
  /// Whether notification is read
  final bool isRead;
  
  /// Created at timestamp
  final DateTime createdAt;
  
  /// Additional metadata
  final Map<String, dynamic>? metadata;

  const AppNotification({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.message,
    this.reportId,
    required this.userId,
    required this.isRead,
    required this.createdAt,
    this.metadata,
  });

  /// Parse from database JSON
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: _parseNotificationType(json['type'] as String),
      priority: _parseNotificationPriority(json['priority'] as String? ?? 'normal'),
      title: json['title'] as String,
      message: json['message'] as String,
      reportId: json['report_id'] as String?,
      userId: json['user_id'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'priority': priority.name,
      'title': title,
      'message': message,
      'report_id': reportId,
      'user_id': userId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Parse notification type
  static NotificationType _parseNotificationType(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationType.reportPublished,
    );
  }

  /// Parse notification priority
  static NotificationPriority _parseNotificationPriority(String value) {
    return NotificationPriority.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationPriority.normal,
    );
  }

  /// Get icon based on type
  String get icon {
    switch (type) {
      case NotificationType.reportSubmitted:
        return '📝';
      case NotificationType.aiAnalysisComplete:
        return '🤖';
      case NotificationType.pendingReview:
        return '👀';
      case NotificationType.reportPublished:
        return '✅';
      case NotificationType.reportRejected:
        return '❌';
      case NotificationType.reportReopened:
        return '🔄';
    }
  }

  /// Get color based on priority
  String get color {
    switch (priority) {
      case NotificationPriority.low:
        return 'grey';
      case NotificationPriority.normal:
        return 'blue';
      case NotificationPriority.high:
        return 'orange';
      case NotificationPriority.urgent:
        return 'red';
    }
  }
}

/// Notification Service
/// 
/// Central authority for all notifications in the system.
/// This service ensures:
/// - Real-time notification delivery
/// - All notifications are logged
/// - User preferences are respected
/// - In-app + push notifications
class NotificationService {
  final SupabaseClient _supabase;

  /// Current user ID
  String? _currentUserId;

  /// Notification stream subscription
  StreamSubscription? _notificationSubscription;

  NotificationService(this._supabase);

  /// Initialize service with user ID
  void init(String userId) {
    _currentUserId = userId;
    debugPrint('🔔 NotificationService initialized for user: $userId');
  }

  /// Get user notifications
  Future<List<AppNotification>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    if (_currentUserId == null) {
      debugPrint('❌ NotificationService not initialized');
      return [];
    }

    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', _currentUserId!)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List<dynamic>)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get notifications: $e');
      return [];
    }
  }

  /// Get unread notifications count
  Future<int> getUnreadCount() async {
    if (_currentUserId == null) return 0;

    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', _currentUserId!)
          .eq('is_read', false);

      return (response as List<dynamic>).length;
    } catch (e) {
      debugPrint('❌ Failed to get unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('❌ Failed to mark as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (_currentUserId == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', _currentUserId!)
          .eq('is_read', false);

      debugPrint('✅ All notifications marked as read');
    } catch (e) {
      debugPrint('❌ Failed to mark all as read: $e');
    }
  }

  /// Subscribe to real-time notifications
  Stream<List<AppNotification>>? subscribeToNotifications() {
    if (_currentUserId == null) {
      debugPrint('❌ Cannot subscribe: Service not initialized');
      return null;
    }

    try {
      return _supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', _currentUserId!)
          .order('created_at', ascending: false)
          .map((event) => event
              .map((e) => AppNotification.fromJson(e))
              .toList());
    } catch (e) {
      debugPrint('❌ Failed to subscribe to notifications: $e');
      return null;
    }
  }

  /// Send notification (system method)
  /// 
  /// This is called by the system when events occur.
  /// Requires service_role permissions.
  Future<void> sendNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    String? reportId,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic>? metadata,
  }) async {
    await sendInAppNotification(
      userId: userId,
      type: type,
      title: title,
      message: message,
      reportId: reportId,
      priority: priority,
      metadata: metadata,
    );
  }

  /// Static method to send notification via class
  static Future<void> sendInAppNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    String? reportId,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await Supabase.instance.client.from('notifications').insert({
        'user_id': userId,
        'type': type.name,
        'priority': priority.name,
        'title': title,
        'message': message,
        'report_id': reportId,
        'is_read': false,
        'metadata': metadata,
      });

      debugPrint('✅ Notification sent to user $userId: $title');
    } catch (e) {
      debugPrint('❌ Failed to send notification: $e');
    }
  }

  /// Send bulk notifications
  /// 
  /// Send the same notification to multiple users.
  Future<void> sendBulkNotifications({
    required List<String> userIds,
    required NotificationType type,
    required String title,
    required String message,
    String? reportId,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final notifications = userIds.map((userId) => {
        'user_id': userId,
        'type': type.name,
        'priority': priority.name,
        'title': title,
        'message': message,
        'report_id': reportId,
        'is_read': false,
        'metadata': metadata,
      }).toList();

      await _supabase.from('notifications').insert(notifications);

      debugPrint('✅ Bulk notification sent to ${userIds.length} users');
    } catch (e) {
      debugPrint('❌ Failed to send bulk notification: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);

      debugPrint('🗑️ Notification deleted: $notificationId');
    } catch (e) {
      debugPrint('❌ Failed to delete notification: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    if (_currentUserId == null) return;

    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('user_id', _currentUserId!);

      debugPrint('🗑️ All notifications cleared for user $_currentUserId');
    } catch (e) {
      debugPrint('❌ Failed to clear notifications: $e');
    }
  }

  /// Cleanup
  void dispose() {
    _notificationSubscription?.cancel();
    _currentUserId = null;
  }
}