/// DASHBOARD MODULE - REAL-TIME COMMAND CENTER
/// 
/// FAZ-4.0 / Phase 4 - Live Dashboard with Real-time Updates
/// 
/// 🎯 PURPOSE:
/// Admin command center with real-time data updates, status distribution,
/// and instant notifications for pending approvals.
/// 
/// 🪨 PRINCIPLE:
/// "Event-driven refresh prevents unnecessary database queries."
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/user_provider.dart';
import '../../../models/dashboard_stats.dart';
import '../../../models/chart_data.dart';
import '../../../services/dashboard_service.dart';
import '../widgets/admin_stats_card.dart';
import '../widgets/status_distribution_card.dart';
import '../widgets/charts/admin_line_chart.dart';
import '../widgets/charts/admin_pie_chart.dart';
import '../widgets/charts/admin_bar_chart.dart';
import 'package:intl/intl.dart';

/// Dashboard Module - Real-time Command Center
class DashboardModule extends StatefulWidget {
  const DashboardModule({super.key});

  @override
  State<DashboardModule> createState() => _DashboardModuleState();
}

class _DashboardModuleState extends State<DashboardModule> {
  late DashboardService _dashboardService;
  StreamSubscription<DashboardUpdateEvent>? _updatesSubscription;

  // Data states
  DashboardStats _stats = DashboardStats.empty();
  StatusDistribution _statusDistribution = StatusDistribution.empty();
  List<RecentActivity> _activities = [];
  List<Map<String, dynamic>> _pendingReports = [];
  
  // Chart data states
  List<ChartData> _weeklyTrend = [];
  List<ChartData> _aiReliabilityTrend = [];
  List<ChartData> _statusDistributionData = [];
  List<ChartData> _personnelSLA = [];

  // Loading states
  bool _isLoadingStats = true;
  bool _isLoadingDistribution = true;
  bool _isLoadingActivities = true;
  bool _isLoadingPending = true;
  bool _isLoadingCharts = true;

  // Error states
  String? _statsError;
  String? _distributionError;
  String? _activitiesError;
  String? _pendingError;
  String? _chartsError;

  @override
  void initState() {
    super.initState();
    _dashboardService = DashboardService(Supabase.instance.client);
    _loadAllData();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _updatesSubscription?.cancel();
    super.dispose();
  }

  /// Load all dashboard data in parallel
  Future<void> _loadAllData() async {
    setState(() {
      _isLoadingStats = true;
      _isLoadingDistribution = true;
      _isLoadingActivities = true;
      _isLoadingPending = true;
      _isLoadingCharts = true;
      _statsError = null;
      _distributionError = null;
      _activitiesError = null;
      _pendingError = null;
      _chartsError = null;
    });

    try {
      await Future.wait([
        _dashboardService.getStats().then((stats) {
          if (mounted) setState(() => _stats = stats);
          return stats;
        }).catchError((error) {
          if (mounted) {
            setState(() => _statsError = error.toString());
          }
          return DashboardStats.empty();
        }),

        _dashboardService.getStatusDistribution().then((dist) {
          if (mounted) setState(() => _statusDistribution = dist);
          return dist;
        }).catchError((error) {
          if (mounted) {
            setState(() => _distributionError = error.toString());
          }
          return StatusDistribution.empty();
        }),

        _dashboardService.getRecentActivities(limit: 5).then((activities) {
          if (mounted) setState(() => _activities = activities);
          return activities;
        }).catchError((error) {
          if (mounted) {
            setState(() => _activitiesError = error.toString());
          }
          return <RecentActivity>[];
        }),

        _dashboardService.getPendingAdminReports(limit: 5).then((reports) {
          if (mounted) setState(() => _pendingReports = reports);
          return reports;
        }).catchError((error) {
          if (mounted) {
            setState(() => _pendingError = error.toString());
          }
          return <Map<String, dynamic>>[];
        }),

        _dashboardService.getWeeklyTrend().then((data) {
          if (mounted) setState(() => _weeklyTrend = data);
          return data;
        }).catchError((error) {
          if (mounted) {
            setState(() => _chartsError = error.toString());
          }
          return <ChartData>[];
        }),

        _dashboardService.getAIReliabilityTrend().then((data) {
          if (mounted) setState(() => _aiReliabilityTrend = data);
          return data;
        }).catchError((error) {
          debugPrint('AI reliability trend error: $error');
          return <ChartData>[];
        }),

        _dashboardService.getStatusDistributionData().then((data) {
          if (mounted) setState(() => _statusDistributionData = data);
          return data;
        }).catchError((error) {
          debugPrint('Status distribution data error: $error');
          return <ChartData>[];
        }),

        _dashboardService.getPersonnelSLA().then((data) {
          if (mounted) setState(() => _personnelSLA = data);
          return data;
        }).catchError((error) {
          debugPrint('Personnel SLA error: $error');
          return <ChartData>[];
        }),
      ]);

      setState(() {
        _isLoadingStats = false;
        _isLoadingDistribution = false;
        _isLoadingActivities = false;
        _isLoadingPending = false;
        _isLoadingCharts = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStats = false;
        _isLoadingDistribution = false;
        _isLoadingActivities = false;
        _isLoadingPending = false;
        _isLoadingCharts = false;
        _statsError = e.toString();
      });
    }
  }

  /// Subscribe to real-time updates
  void _subscribeToUpdates() {
    _updatesSubscription = _dashboardService.subscribeToDashboardUpdates().listen(
      (event) {
        debugPrint('📡 Dashboard update received: ${event.type}');
        _loadAllData();

        // Haptic feedback for pending admin status
        if (event.newStatus == 'pending_admin') {
          _triggerHapticFeedback();
          _showPendingAdminNotification();
        }
      },
      onError: (error) {
        debugPrint('❌ Dashboard update error: $error');
      },
    );
  }

  /// Trigger haptic feedback
  void _triggerHapticFeedback() {
    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Haptic feedback not available: $e');
    }
  }

  /// Show notification for pending admin
  void _showPendingAdminNotification() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notification_important, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Yeni rapor onay bekliyor!',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () => _navigateToReviewQueue(),
              child: const Text(
                'İNCELE',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'GİT',
          textColor: Colors.white,
          onPressed: () => _navigateToReviewQueue(),
        ),
      ),
    );
  }

  void _navigateToReviewQueue() {
    // TODO: Navigate to review queue module
    debugPrint('📋 Navigating to review queue...');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HOŞ GELDİNİZ
            _buildWelcomeSection(currentUser, isDarkMode),
            const SizedBox(height: 30),

            // İSTATİSTİK KARTLARI
            _buildStatsSection(isDarkMode),
            const SizedBox(height: 30),

            // STATUS DISTRIBUTION
            _buildStatusDistributionSection(isDarkMode),
            const SizedBox(height: 30),

            // PENDING ADMIN REPORTS (Review Queue Preview)
            _buildPendingReportsSection(isDarkMode),
            const SizedBox(height: 30),

            // CHARTS SECTION (NEW)
            _buildChartsSection(isDarkMode),
            const SizedBox(height: 30),

            // SON AKTİVİTELER
            _buildActivitiesSection(isDarkMode),
          ],
        ),
      ),
    );
  }

  /// Build charts section
  Widget _buildChartsSection(bool isDarkMode) {
    if (_chartsError != null) {
      return _buildErrorCard('Grafikler', _chartsError!, _loadAllData);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analiz & Trendler',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Weekly Trend & AI Reliability (Row)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _isLoadingCharts
                  ? _buildShimmerCard(isDarkMode)
                  : AdminLineChart(
                      data: _weeklyTrend,
                      title: 'Haftalık Rapor Trendi',
                      isDarkMode: isDarkMode,
                      primaryColor: ForensicChartColors.neonCyan,
                    ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _isLoadingCharts
                  ? _buildShimmerCard(isDarkMode)
                  : AdminLineChart(
                      data: _aiReliabilityTrend,
                      title: 'AI Güven Skoru Trendi',
                      yAxisLabel: '%',
                      isDarkMode: isDarkMode,
                      primaryColor: ForensicChartColors.securityGreen,
                      anomalyThreshold: 70.0,
                    ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Status Distribution & Personnel SLA (Row)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _isLoadingCharts
                  ? _buildShimmerCard(isDarkMode)
                  : AdminPieChart(
                      data: _statusDistributionData,
                      title: 'Rapor Durum Dağılımı',
                      isDarkMode: isDarkMode,
                      onSectionTap: (label) {
                        debugPrint('📊 Filter by: $label');
                        // TODO: Navigate to filtered reports
                      },
                    ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _isLoadingCharts
                  ? _buildShimmerCard(isDarkMode)
                  : AdminBarChart(
                      data: _personnelSLA,
                      title: 'Personel SLA Performansı',
                      isDarkMode: isDarkMode,
                      slaThresholdHours: 48.0,
                      onTap: () {
                        debugPrint('📊 Personnel SLA info');
                      },
                    ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build welcome section
  Widget _buildWelcomeSection(dynamic currentUser, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hoş Geldiniz, ${currentUser?.fullName ?? 'Admin'}!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(DateTime.now()),
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _loadAllData,
          icon: _isLoadingStats
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.refresh),
          label: const Text('Yenile'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  /// Build stats section
  Widget _buildStatsSection(bool isDarkMode) {
    if (_statsError != null) {
      return _buildErrorCard('İstatistikler', _statsError!, _loadAllData);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İstatistikler',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _isLoadingStats
            ? _buildStatsShimmer(isDarkMode)
            : GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
                children: [
                  AdminStatsCard(
                    title: 'Toplam Araç',
                    value: _stats.totalVehicles.toString(),
                    icon: Icons.directions_car,
                    color: Colors.blue,
                    isDarkMode: isDarkMode,
                  ),
                  AdminStatsCard(
                    title: 'Aktif Rapor',
                    value: _stats.activeReports.toString(),
                    icon: Icons.description,
                    color: Colors.orange,
                    isDarkMode: isDarkMode,
                  ),
                  AdminStatsCard(
                    title: 'Personel',
                    value: _stats.personnelCount.toString(),
                    icon: Icons.people,
                    color: Colors.green,
                    isDarkMode: isDarkMode,
                  ),
                  AdminStatsCard(
                    title: 'Müşteri',
                    value: _stats.customerCount.toString(),
                    icon: Icons.person,
                    color: Colors.purple,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
      ],
    );
  }

  /// Build status distribution section
  Widget _buildStatusDistributionSection(bool isDarkMode) {
    if (_distributionError != null) {
      return _buildErrorCard('Durum Dağılımı', _distributionError!, _loadAllData);
    }

    return _isLoadingDistribution
        ? _buildShimmerCard(isDarkMode)
        : StatusDistributionCard(
            distribution: _statusDistribution,
            isDarkMode: isDarkMode,
            onStatusTap: () => _navigateToReviewQueue(),
          );
  }

  /// Build pending reports section
  Widget _buildPendingReportsSection(bool isDarkMode) {
    if (_pendingError != null) {
      return _buildErrorCard('Bekleyen Raporlar', _pendingError!, _loadAllData);
    }

    return Card(
      elevation: 4,
      color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pending_actions, color: Colors.orange),
                const SizedBox(width: 10),
                Text(
                  'Onay Bekleyen Raporlar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _navigateToReviewQueue(),
                  child: const Text('Tümünü Gör'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _isLoadingPending
                ? _buildListShimmer(isDarkMode)
                : _pendingReports.isEmpty
                    ? _buildEmptyState('Onay bekleyen rapor yok', Icons.check_circle)
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _pendingReports.length,
                        itemBuilder: (context, index) {
                          final report = _pendingReports[index];
                          return _buildPendingReportItem(report, isDarkMode);
                        },
                      ),
          ],
        ),
      ),
    );
  }

  /// Build activities section
  Widget _buildActivitiesSection(bool isDarkMode) {
    if (_activitiesError != null) {
      return _buildErrorCard('Son Aktiviteler', _activitiesError!, _loadAllData);
    }

    return Card(
      elevation: 4,
      color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.blue),
                const SizedBox(width: 10),
                Text(
                  'Son Aktiviteler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _isLoadingActivities
                ? _buildListShimmer(isDarkMode)
                : _activities.isEmpty
                    ? _buildEmptyState('Henüz aktivite yok', Icons.history)
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _activities.length,
                        itemBuilder: (context, index) {
                          final activity = _activities[index];
                          return _buildActivityItem(activity, isDarkMode);
                        },
                      ),
          ],
        ),
      ),
    );
  }

  /// Build pending report item
  Widget _buildPendingReportItem(Map<String, dynamic> report, bool isDarkMode) {
    final plaka = report['plaka'] as String? ?? 'Belirsiz';
    final aiResult = report['ai_analysis_result'] as Map<String, dynamic>?;
    final reliability = aiResult?['reliability_score'] as double? ?? 0.0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.orange.withValues(alpha: 0.1),
        child: const Icon(Icons.pending, color: Colors.orange),
      ),
      title: Text(
        plaka,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : const Color(0xFF111827),
        ),
      ),
      subtitle: Row(
        children: [
          const Icon(Icons.psychology, size: 16, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            'Güven Skoru: %${reliability.toStringAsFixed(1)}',
            style: TextStyle(
              color: reliability >= 80 ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _navigateToReviewQueue(),
    );
  }

  /// Build activity item
  Widget _buildActivityItem(RecentActivity activity, bool isDarkMode) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.withValues(alpha: 0.1),
        child: Text(
          activity.type.icon,
          style: const TextStyle(fontSize: 20),
        ),
      ),
      title: Text(
        activity.title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : const Color(0xFF111827),
        ),
      ),
      subtitle: Text(activity.timeAgo),
      trailing: activity.userName != null
          ? Text(
              activity.userName!,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            )
          : null,
    );
  }

  /// Build shimmer loading effect
  Widget _buildStatsShimmer(bool isDarkMode) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.0,
      children: List.generate(
        4,
        (index) => Card(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 80,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build list shimmer
  Widget _buildListShimmer(bool isDarkMode) {
    return Column(
      children: List.generate(
        3,
        (index) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 150,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build shimmer card
  Widget _buildShimmerCard(bool isDarkMode) {
    return Card(
      elevation: 4,
      color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 200,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState(String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// Build error card
  Widget _buildErrorCard(String title, String error, VoidCallback onRetry) {
    return Card(
      elevation: 4,
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(error, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden Dene'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}