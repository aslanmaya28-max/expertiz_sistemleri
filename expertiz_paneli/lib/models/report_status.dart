/// REPORT STATUS MODEL
/// 
/// FAZ-3.0 / M2 — Status Workflow Type System
/// 
/// ⚖️ LEGAL STANDARD:
/// This enum represents forensic-grade status transitions.
/// All transitions are enforced at database level via triggers.
/// 
/// 🎯 WORKFLOW:
/// draft → pending_ai → pending_admin → published
///                                 ↘ rejected → draft
/// 
/// 🪨 PRINCIPLE:
/// "Once published, forever immutable."
library;

import 'package:flutter/material.dart';

/// Report Status Enumeration
/// 
/// Forensic-grade status workflow for expertiz reports.
/// All transitions are validated against role-based rules.
enum ReportStatus {
  /// Personnel is working on the report
  draft,
  
  /// Report submitted for AI analysis
  pendingAi,
  
  /// AI analysis complete, awaiting admin approval
  pendingAdmin,
  
  /// Rejected by admin, needs correction
  rejected,
  
  /// Published to customer, immutable
  published,
}

/// Report Status Extension
/// 
/// Provides display properties and validation helpers
extension ReportStatusExtension on ReportStatus {
  /// Database value (snake_case)
  String get value {
    switch (this) {
      case ReportStatus.draft:
        return 'draft';
      case ReportStatus.pendingAi:
        return 'pending_ai';
      case ReportStatus.pendingAdmin:
        return 'pending_admin';
      case ReportStatus.rejected:
        return 'rejected';
      case ReportStatus.published:
        return 'published';
    }
  }

  /// Display label (localized)
  String get label {
    switch (this) {
      case ReportStatus.draft:
        return 'Taslak';
      case ReportStatus.pendingAi:
        return 'AI Analizi Bekleniyor';
      case ReportStatus.pendingAdmin:
        return 'Admin Onayı Bekleniyor';
      case ReportStatus.rejected:
        return 'Reddedildi';
      case ReportStatus.published:
        return 'Yayınlandı';
    }
  }

  /// Display label (English)
  String get labelEn {
    switch (this) {
      case ReportStatus.draft:
        return 'Draft';
      case ReportStatus.pendingAi:
        return 'AI Analysis Pending';
      case ReportStatus.pendingAdmin:
        return 'Admin Approval Pending';
      case ReportStatus.rejected:
        return 'Rejected';
      case ReportStatus.published:
        return 'Published';
    }
  }

  /// Status icon
  IconData get icon {
    switch (this) {
      case ReportStatus.draft:
        return Icons.edit_note;
      case ReportStatus.pendingAi:
        return Icons.psychology;
      case ReportStatus.pendingAdmin:
        return Icons.admin_panel_settings;
      case ReportStatus.rejected:
        return Icons.cancel;
      case ReportStatus.published:
        return Icons.verified;
    }
  }

  /// Status color
  Color get color {
    switch (this) {
      case ReportStatus.draft:
        return Colors.grey;
      case ReportStatus.pendingAi:
        return Colors.blue;
      case ReportStatus.pendingAdmin:
        return Colors.orange;
      case ReportStatus.rejected:
        return Colors.red;
      case ReportStatus.published:
        return Colors.green;
    }
  }

  /// Background color (with opacity)
  Color get backgroundColor {
    switch (this) {
      case ReportStatus.draft:
        return Colors.grey.withValues(alpha: 0.1);
      case ReportStatus.pendingAi:
        return Colors.blue.withValues(alpha: 0.1);
      case ReportStatus.pendingAdmin:
        return Colors.orange.withValues(alpha: 0.1);
      case ReportStatus.rejected:
        return Colors.red.withValues(alpha: 0.1);
      case ReportStatus.published:
        return Colors.green.withValues(alpha: 0.1);
    }
  }

  /// Can this status be edited by personnel?
  bool get isEditableByPersonnel {
    return this == ReportStatus.draft || this == ReportStatus.rejected;
  }

  /// Is this status visible to customer?
  bool get isVisibleToCustomer {
    return this == ReportStatus.published;
  }

  /// Can this status transition to pending_ai?
  bool canTransitionToPendingAi() {
    return this == ReportStatus.draft;
  }

  /// Can this status transition to pending_admin?
  bool canTransitionToPendingAdmin() {
    return this == ReportStatus.pendingAi;
  }

  /// Can this status transition to published?
  bool canTransitionToPublished() {
    return this == ReportStatus.pendingAdmin;
  }

  /// Can this status transition to rejected?
  bool canTransitionToRejected() {
    return this == ReportStatus.pendingAdmin;
  }

  /// Can this status transition to draft?
  bool canTransitionToDraft() {
    return this == ReportStatus.rejected;
  }

  /// Is this a final status?
  bool get isFinal {
    return this == ReportStatus.published || this == ReportStatus.rejected;
  }
}

/// Report Status Parser
/// 
/// Converts database string to ReportStatus enum
class ReportStatusParser {
  /// Parse from database value
  static ReportStatus fromValue(String value) {
    switch (value.toLowerCase()) {
      case 'draft':
        return ReportStatus.draft;
      case 'pending_ai':
        return ReportStatus.pendingAi;
      case 'pending_admin':
        return ReportStatus.pendingAdmin;
      case 'rejected':
        return ReportStatus.rejected;
      case 'published':
        return ReportStatus.published;
      default:
        throw ArgumentError('Invalid report status: $value');
    }
  }

  /// Parse from nullable database value
  static ReportStatus? fromValueOrNull(String? value) {
    if (value == null) return null;
    try {
      return fromValue(value);
    } catch (e) {
      return null;
    }
  }

  /// Get all valid status values
  static List<String> get allValues {
    return ReportStatus.values.map((s) => s.value).toList();
  }

  /// Get all valid statuses
  static List<ReportStatus> get allStatuses {
    return ReportStatus.values;
  }
}

/// Status Transition
/// 
/// Represents a valid status transition
class StatusTransition {
  /// From status
  final ReportStatus from;
  
  /// To status
  final ReportStatus to;
  
  /// Allowed roles for this transition
  final List<String> allowedRoles;
  
  /// Requires rejection reason?
  final bool requiresReason;

  const StatusTransition({
    required this.from,
    required this.to,
    required this.allowedRoles,
    this.requiresReason = false,
  });

  /// All valid status transitions
  static const List<StatusTransition> all = [
    // draft → pending_ai (Submit for Review)
    StatusTransition(
      from: ReportStatus.draft,
      to: ReportStatus.pendingAi,
      allowedRoles: ['personnel', 'admin'],
    ),
    
    // pending_ai → pending_admin (AI Analysis Complete)
    StatusTransition(
      from: ReportStatus.pendingAi,
      to: ReportStatus.pendingAdmin,
      allowedRoles: ['service_role', 'admin'],
    ),
    
    // pending_admin → published (Approve & Seal)
    StatusTransition(
      from: ReportStatus.pendingAdmin,
      to: ReportStatus.published,
      allowedRoles: ['admin'],
    ),
    
    // pending_admin → rejected (Reject with Reason)
    StatusTransition(
      from: ReportStatus.pendingAdmin,
      to: ReportStatus.rejected,
      allowedRoles: ['admin'],
      requiresReason: true,
    ),
    
    // rejected → draft (Correct & Resubmit)
    StatusTransition(
      from: ReportStatus.rejected,
      to: ReportStatus.draft,
      allowedRoles: ['personnel', 'admin'],
    ),
  ];

  /// Find transition by from/to status
  static StatusTransition? find(ReportStatus from, ReportStatus to) {
    for (final transition in all) {
      if (transition.from == from && transition.to == to) {
        return transition;
      }
    }
    return null;
  }

  /// Check if transition is valid
  static bool isValid(ReportStatus from, ReportStatus to) {
    return find(from, to) != null;
  }

  /// Check if user role is allowed for this transition
  bool isRoleAllowed(String userRole) {
    return allowedRoles.contains(userRole);
  }
}