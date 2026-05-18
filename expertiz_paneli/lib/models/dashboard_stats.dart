/// DASHBOARD STATS MODELS
/// 
/// FAZ-4.0 / Phase 4 - Real-time Dashboard Data Models
/// 
/// 🎯 PURPOSE:
/// Type-safe data models for dashboard statistics and metrics.
/// All models are immutable and support JSON serialization.
/// 
/// 🪨 PRINCIPLE:
/// "Type safety prevents runtime errors in critical admin operations."
library;

/// Dashboard Statistics
/// 
/// Core metrics for the admin dashboard
class DashboardStats {
  /// Total number of vehicles in the system
  final int totalVehicles;
  
  /// Number of active reports (not archived)
  final int activeReports;
  
  /// Total number of personnel users
  final int personnelCount;
  
  /// Total number of customer users
  final int customerCount;
  
  /// Total number of reports (all statuses)
  final int totalReports;
  
  /// Number of reports published today
  final int todayPublished;
  
  /// Number of reports submitted today
  final int todaySubmitted;

  const DashboardStats({
    required this.totalVehicles,
    required this.activeReports,
    required this.personnelCount,
    required this.customerCount,
    required this.totalReports,
    required this.todayPublished,
    required this.todaySubmitted,
  });

  /// Create empty stats (default state)
  const DashboardStats.empty()
      : totalVehicles = 0,
        activeReports = 0,
        personnelCount = 0,
        customerCount = 0,
        totalReports = 0,
        todayPublished = 0,
        todaySubmitted = 0;

  /// Parse from database response
  factory DashboardStats.fromMap(Map<String, dynamic> data) {
    return DashboardStats(
      totalVehicles: data['total_vehicles'] as int? ?? 0,
      activeReports: data['active_reports'] as int? ?? 0,
      personnelCount: data['personnel_count'] as int? ?? 0,
      customerCount: data['customer_count'] as int? ?? 0,
      totalReports: data['total_reports'] as int? ?? 0,
      todayPublished: data['today_published'] as int? ?? 0,
      todaySubmitted: data['today_submitted'] as int? ?? 0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'total_vehicles': totalVehicles,
      'active_reports': activeReports,
      'personnel_count': personnelCount,
      'customer_count': customerCount,
      'total_reports': totalReports,
      'today_published': todayPublished,
      'today_submitted': todaySubmitted,
    };
  }

  /// Calculate total users (personnel + customers)
  int get totalUsers => personnelCount + customerCount;

  /// Calculate completion rate (published / total)
  double get completionRate {
    if (totalReports == 0) return 0.0;
    return (todayPublished / totalReports * 100);
  }

  @override
  String toString() {
    return 'DashboardStats(vehicles: $totalVehicles, reports: $activeReports, '
           'personnel: $personnelCount, customers: $customerCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DashboardStats &&
           other.totalVehicles == totalVehicles &&
           other.activeReports == activeReports &&
           other.personnelCount == personnelCount &&
           other.customerCount == customerCount;
  }

  @override
  int get hashCode {
    return Object.hash(
      totalVehicles,
      activeReports,
      personnelCount,
      customerCount,
    );
  }
}

/// Status Distribution
/// 
/// Breakdown of reports by their current status
class StatusDistribution {
  /// Number of draft reports
  final int draft;
  
  /// Number of reports pending AI analysis
  final int pendingAi;
  
  /// Number of reports pending admin approval
  final int pendingAdmin;
  
  /// Number of published reports
  final int published;
  
  /// Number of rejected reports
  final int rejected;

  const StatusDistribution({
    required this.draft,
    required this.pendingAi,
    required this.pendingAdmin,
    required this.published,
    required this.rejected,
  });

  /// Create empty distribution (default state)
  const StatusDistribution.empty()
      : draft = 0,
        pendingAi = 0,
        pendingAdmin = 0,
        published = 0,
        rejected = 0;

  /// Parse from database response
  factory StatusDistribution.fromMap(Map<String, dynamic> data) {
    return StatusDistribution(
      draft: data['draft'] as int? ?? 0,
      pendingAi: data['pending_ai'] as int? ?? 0,
      pendingAdmin: data['pending_admin'] as int? ?? 0,
      published: data['published'] as int? ?? 0,
      rejected: data['rejected'] as int? ?? 0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'draft': draft,
      'pending_ai': pendingAi,
      'pending_admin': pendingAdmin,
      'published': published,
      'rejected': rejected,
    };
  }

  /// Calculate total reports
  int get total => draft + pendingAi + pendingAdmin + published + rejected;

  /// Calculate percentage of reports requiring admin attention
  double get adminAttentionRate {
    if (total == 0) return 0.0;
    return (pendingAdmin / total * 100);
  }

  /// Get most critical status (highest priority)
  Status get mostCriticalStatus {
    if (pendingAdmin > 0) return Status.pendingAdmin;
    if (pendingAi > 0) return Status.pendingAi;
    if (draft > 0) return Status.draft;
    return Status.published;
  }

  @override
  String toString() {
    return 'StatusDistribution(draft: $draft, pendingAI: $pendingAi, '
           'pendingAdmin: $pendingAdmin, published: $published, rejected: $rejected)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StatusDistribution &&
           other.draft == draft &&
           other.pendingAi == pendingAi &&
           other.pendingAdmin == pendingAdmin &&
           other.published == published &&
           other.rejected == rejected;
  }

  @override
  int get hashCode {
    return Object.hash(draft, pendingAi, pendingAdmin, published, rejected);
  }
}

/// Report Status Enum
/// 
/// MUST match FAZ-3.0 ReportStatus enum exactly
enum Status {
  draft,
  pendingAi,
  pendingAdmin,
  published,
  rejected;

  /// Get status from string
  static Status fromString(String value) {
    return Status.values.firstWhere(
      (status) => status.name == value,
      orElse: () => Status.draft,
    );
  }

  /// Get display name (Turkish)
  String get displayName {
    switch (this) {
      case Status.draft:
        return 'Taslak';
      case Status.pendingAi:
        return 'AI Bekliyor';
      case Status.pendingAdmin:
        return 'Onay Bekliyor';
      case Status.published:
        return 'Yayınlandı';
      case Status.rejected:
        return 'Reddedildi';
    }
  }

  /// Get icon for status
  String get icon {
    switch (this) {
      case Status.draft:
        return '📝';
      case Status.pendingAi:
        return '🤖';
      case Status.pendingAdmin:
        return '⏳';
      case Status.published:
        return '✅';
      case Status.rejected:
        return '❌';
    }
  }
}

/// Recent Activity
/// 
/// Represents a single activity in the dashboard timeline
class RecentActivity {
  /// Unique identifier
  final String id;
  
  /// Activity type (report_created, status_changed, etc.)
  final ActivityType type;
  
  /// Activity title
  final String title;
  
  /// Activity description
  final String description;
  
  /// User who performed the action
  final String? userId;
  
  /// User's display name
  final String? userName;
  
  /// Related report ID (if applicable)
  final String? reportId;
  
  /// Timestamp when activity occurred
  final DateTime timestamp;

  const RecentActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.userId,
    this.userName,
    this.reportId,
    required this.timestamp,
  });

  /// Parse from database response
  factory RecentActivity.fromMap(Map<String, dynamic> data) {
    return RecentActivity(
      id: data['id'] as String,
      type: ActivityType.fromString(data['type'] as String? ?? 'other'),
      title: data['title'] as String,
      description: data['description'] as String,
      userId: data['user_id'] as String?,
      userName: data['user_name'] as String?,
      reportId: data['report_id'] as String?,
      timestamp: DateTime.parse(data['timestamp'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'description': description,
      'user_id': userId,
      'user_name': userName,
      'report_id': reportId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Get time ago string (e.g., "2 dakika önce")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  String toString() {
    return 'RecentActivity($type: $title, $timeAgo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecentActivity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Activity Type Enum
enum ActivityType {
  reportCreated,
  statusChanged,
  aiAnalysisComplete,
  reportPublished,
  reportRejected,
  reportApproved,
  userCreated,
  other;

  /// Get activity type from string
  static ActivityType fromString(String value) {
    return ActivityType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ActivityType.other,
    );
  }

  /// Get icon for activity type
  String get icon {
    switch (this) {
      case ActivityType.reportCreated:
        return '📝';
      case ActivityType.statusChanged:
        return '🔄';
      case ActivityType.aiAnalysisComplete:
        return '🤖';
      case ActivityType.reportPublished:
        return '✅';
      case ActivityType.reportRejected:
        return '❌';
      case ActivityType.reportApproved:
        return '👍';
      case ActivityType.userCreated:
        return '👤';
      case ActivityType.other:
        return '📌';
    }
  }

  /// Get display name (Turkish)
  String get displayName {
    switch (this) {
      case ActivityType.reportCreated:
        return 'Rapor Oluşturuldu';
      case ActivityType.statusChanged:
        return 'Durum Değişti';
      case ActivityType.aiAnalysisComplete:
        return 'AI Analizi Tamamlandı';
      case ActivityType.reportPublished:
        return 'Rapor Yayınlandı';
      case ActivityType.reportRejected:
        return 'Rapor Reddedildi';
      case ActivityType.reportApproved:
        return 'Rapor Onaylandı';
      case ActivityType.userCreated:
        return 'Kullanıcı Oluşturuldu';
      case ActivityType.other:
        return 'Diğer';
    }
  }
}