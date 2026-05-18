/// ADMIN ANNOTATION MODEL
/// 
/// FAZ-6.0 / Step 2 - Smart Annotation System
/// 
/// 🎯 PURPOSE:
/// Admin tarafından eklenen, reddedilen raporlardaki spesifik hataları
/// yöneten izlenebilir not sistemi.
/// 
/// 🪨 PRINCIPLE:
/// "Adli Şeffaflık - Her not kanıttır"

library;

import 'package:equatable/equatable.dart';

/// Annotation type
enum AnnotationType {
  error,
  warning,
  info;

  String get displayName {
    switch (this) {
      case AnnotationType.error:
        return 'Hata';
      case AnnotationType.warning:
        return 'Uyarı';
      case AnnotationType.info:
        return 'Bilgi';
    }
  }

  String get colorHex {
    switch (this) {
      case AnnotationType.error:
        return '#FF4500'; // Forensic Red
      case AnnotationType.warning:
        return '#FFC107'; // Warning Yellow
      case AnnotationType.info:
        return '#2196F3'; // Info Blue
    }
  }
}

/// Annotation severity
enum AnnotationSeverity {
  low,
  medium,
  high;

  String get displayName {
    switch (this) {
      case AnnotationSeverity.low:
        return 'Düşük';
      case AnnotationSeverity.medium:
        return 'Orta';
      case AnnotationSeverity.high:
        return 'Yüksek';
    }
  }
}

/// Admin Annotation Model
/// 
/// Represents a single annotation on a specific field of a report.
/// Used for communication between admin and field personnel.
class AdminAnnotation extends Equatable {
  /// Unique identifier
  final String id;
  
  /// Report identifier
  final String reportId;
  
  /// Field key (e.g., 'adim2.onTampon', 'adim3.klima')
  final String fieldKey;
  
  /// Human-readable field label (e.g., 'Ön Tampon', 'Klima')
  final String fieldLabel;
  
  /// Annotation message (Admin's note)
  final String adminNote;
  
  /// Annotation type
  final AnnotationType annotationType;
  
  /// Admin ID who created this annotation
  final String adminId;
  
  /// Admin name who created this annotation
  final String adminName;
  
  /// Creation timestamp
  final DateTime createdAt;
  
  /// Resolution status
  final bool isResolved;
  
  /// Resolution timestamp (null if not resolved)
  final DateTime? resolvedAt;

  /// Personnel's reply to the annotation
  final String? personnelReply;

  /// Counter reply timestamp
  final DateTime? repliedAt;
  
  /// Severity level
  final AnnotationSeverity severity;

  const AdminAnnotation({
    required this.id,
    required this.reportId,
    required this.fieldKey,
    required this.fieldLabel,
    required this.adminNote,
    required this.annotationType,
    required this.adminId,
    required this.adminName,
    required this.createdAt,
    this.isResolved = false,
    this.resolvedAt,
    this.personnelReply,
    this.repliedAt,
    this.severity = AnnotationSeverity.medium,
  });

  /// Legacy compatibility
  String get message => adminNote;
  AnnotationType get type => annotationType;

  /// Create from JSON
  factory AdminAnnotation.fromJson(Map<String, dynamic> json) {
    return AdminAnnotation(
      id: json['id'] as String,
      reportId: json['reportId'] as String? ?? json['report_id'] as String? ?? '',
      fieldKey: json['fieldKey'] as String? ?? json['field_key'] as String? ?? '',
      fieldLabel: json['fieldLabel'] as String? ?? json['field_label'] as String? ?? '',
      adminNote: json['adminNote'] as String? ?? json['message'] as String? ?? '',
      annotationType: AnnotationType.values.firstWhere(
        (e) => e.name == json['annotationType'] || e.name == json['type'],
        orElse: () => AnnotationType.info,
      ),
      adminId: json['adminId'] as String? ?? json['admin_id'] as String? ?? '',
      adminName: json['adminName'] as String? ?? json['admin_name'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String? ?? json['created_at'] as String),
      isResolved: json['isResolved'] as bool? ?? json['is_resolved'] as bool? ?? false,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : (json['resolved_at'] != null ? DateTime.parse(json['resolved_at'] as String) : null),
      personnelReply: json['personnelReply'] as String? ?? json['personnel_reply'] as String?,
      repliedAt: json['repliedAt'] != null
          ? DateTime.parse(json['repliedAt'] as String)
          : (json['replied_at'] != null ? DateTime.parse(json['replied_at'] as String) : null),
      severity: AnnotationSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => AnnotationSeverity.medium,
      ),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reportId': reportId,
      'fieldKey': fieldKey,
      'fieldLabel': fieldLabel,
      'adminNote': adminNote,
      'message': adminNote, // Compatibility
      'annotationType': annotationType.name,
      'type': annotationType.name, // Compatibility
      'adminId': adminId,
      'adminName': adminName,
      'createdAt': createdAt.toIso8601String(),
      'isResolved': isResolved,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'personnelReply': personnelReply,
      'repliedAt': repliedAt?.toIso8601String(),
      'severity': severity.name,
    };
  }

  /// Create a copy with modified fields
  AdminAnnotation copyWith({
    String? id,
    String? reportId,
    String? fieldKey,
    String? fieldLabel,
    String? adminNote,
    AnnotationType? annotationType,
    String? adminId,
    String? adminName,
    DateTime? createdAt,
    bool? isResolved,
    DateTime? resolvedAt,
    String? personnelReply,
    DateTime? repliedAt,
    AnnotationSeverity? severity,
  }) {
    return AdminAnnotation(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      fieldKey: fieldKey ?? this.fieldKey,
      fieldLabel: fieldLabel ?? this.fieldLabel,
      adminNote: adminNote ?? this.adminNote,
      annotationType: annotationType ?? this.annotationType,
      adminId: adminId ?? this.adminId,
      adminName: adminName ?? this.adminName,
      createdAt: createdAt ?? this.createdAt,
      isResolved: isResolved ?? this.isResolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      personnelReply: personnelReply ?? this.personnelReply,
      repliedAt: repliedAt ?? this.repliedAt,
      severity: severity ?? this.severity,
    );
  }

  /// Mark as resolved
  AdminAnnotation resolve() {
    return copyWith(
      isResolved: true,
      resolvedAt: DateTime.now(),
    );
  }

  /// Reopen (mark as unresolved)
  AdminAnnotation reopen() {
    return copyWith(
      isResolved: false,
      resolvedAt: null,
    );
  }

  /// Check if annotation is still valid (not resolved or recently resolved)
  bool get isActive => !isResolved;

  /// Get age of annotation
  Duration get age {
    final now = DateTime.now();
    if (isResolved && resolvedAt != null) {
      return now.difference(resolvedAt!);
    }
    return now.difference(createdAt);
  }

  /// Get age in human-readable format
  String get ageText {
    final a = age;
    if (a.inDays > 0) {
      return '${a.inDays} gün önce';
    } else if (a.inHours > 0) {
      return '${a.inHours} saat önce';
    } else if (a.inMinutes > 0) {
      return '${a.inMinutes} dakika önce';
    }
    return 'Az önce';
  }

  /// Get display color as hex string
  String get color => type.colorHex;

  @override
  List<Object?> get props => [
        id,
        reportId,
        fieldKey,
        fieldLabel,
        adminNote,
        annotationType,
        adminId,
        adminName,
        createdAt,
        isResolved,
        resolvedAt,
        personnelReply,
        repliedAt,
        severity,
      ];

  @override
  String toString() {
    return 'AdminAnnotation(id: $id, report: $reportId, field: $fieldLabel, type: ${annotationType.name}, resolved: $isResolved)';
  }
}

/// Admin Annotation List Model
/// 
/// Manages a collection of annotations with helper methods
/// for filtering and sorting.
class AdminAnnotationList extends Equatable {
  final List<AdminAnnotation> annotations;

  const AdminAnnotationList([this.annotations = const []]);

  /// Create from JSON array
  factory AdminAnnotationList.fromJson(List<dynamic> json) {
    return AdminAnnotationList(
      json
          .map((item) => AdminAnnotation.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convert to JSON array
  List<Map<String, dynamic>> toJson() {
    return annotations.map((a) => a.toJson()).toList();
  }

  /// Get all annotations
  List<AdminAnnotation> get all => annotations;

  /// Get only active (unresolved) annotations
  List<AdminAnnotation> get active =>
      annotations.where((a) => a.isActive).toList();

  /// Get only resolved annotations
  List<AdminAnnotation> get resolved =>
      annotations.where((a) => a.isResolved).toList();

  /// Get annotations by field key
  List<AdminAnnotation> byFieldKey(String fieldKey) =>
      annotations.where((a) => a.fieldKey == fieldKey).toList();

  /// Get annotations by type
  List<AdminAnnotation> byType(AnnotationType type) =>
      annotations.where((a) => a.type == type).toList();

  /// Get annotations by severity
  List<AdminAnnotation> bySeverity(AnnotationSeverity severity) =>
      annotations.where((a) => a.severity == severity).toList();

  /// Get error annotations only
  List<AdminAnnotation> get errors => byType(AnnotationType.error);

  /// Get warning annotations only
  List<AdminAnnotation> get warnings => byType(AnnotationType.warning);

  /// Get info annotations only
  List<AdminAnnotation> get infos => byType(AnnotationType.info);

  /// Get high severity annotations
  List<AdminAnnotation> get highSeverity =>
      bySeverity(AnnotationSeverity.high);

  /// Check if there are any active annotations
  bool get hasActiveAnnotations => active.isNotEmpty;

  /// Check if there are any error annotations
  bool get hasErrors => errors.isNotEmpty;

  /// Get total count
  int get count => annotations.length;

  /// Get active count
  int get activeCount => active.length;

  /// Get resolved count
  int get resolvedCount => resolved.length;

  /// Create copy with modified list
  AdminAnnotationList copyWith(List<AdminAnnotation> annotations) {
    return AdminAnnotationList(annotations);
  }

  /// Add annotation
  AdminAnnotationList add(AdminAnnotation annotation) {
    return AdminAnnotationList([...annotations, annotation]);
  }

  /// Remove annotation by ID
  AdminAnnotationList remove(String id) {
    return AdminAnnotationList(
      annotations.where((a) => a.id != id).toList(),
    );
  }

  /// Update annotation
  AdminAnnotationList update(AdminAnnotation updated) {
    return AdminAnnotationList(
      annotations.map((a) => a.id == updated.id ? updated : a).toList(),
    );
  }

  /// Resolve annotation by ID
  AdminAnnotationList resolveAnnotation(String id) {
    return AdminAnnotationList(
      annotations.map((a) => a.id == id ? a.resolve() : a).toList(),
    );
  }

  @override
  List<Object?> get props => [annotations];
}