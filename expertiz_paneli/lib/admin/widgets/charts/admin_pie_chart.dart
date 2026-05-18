/// ADMIN PIE CHART
/// 
/// FAZ-5.0 / Phase 5 - Visual BI & KPI Cockpit
/// 
/// 🎯 PURPOSE:
/// Interactive pie chart for status distribution and rejection reasons.
/// Shows percentages and raw counts with forensic-themed colors.
/// 
/// 🪨 PRINCIPLE:
/// "Visual hierarchy directs attention to critical items."
library;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/chart_data.dart';

/// Admin Pie Chart Widget
/// 
/// Displays pie charts with:
/// - Interactive segments
/// - Percentage and raw count tooltips
/// - Click-to-filter functionality
/// - Dark mode support
class AdminPieChart extends StatelessWidget {
  final List<ChartData> data;
  final String title;
  final bool isDarkMode;
  final ChartConfig config;
  final void Function(String)? onSectionTap;

  const AdminPieChart({
    super.key,
    required this.data,
    required this.title,
    this.isDarkMode = true,
    this.config = ChartConfig.defaultConfig,
    this.onSectionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    final total = data.fold<double>(0, (sum, d) => sum + d.y);

    return Card(
      elevation: 4,
      color: isDarkMode ? ForensicChartColors.backgroundDark : ForensicChartColors.backgroundLight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(total),
            const SizedBox(height: 20),

            // Chart
            AspectRatio(
              aspectRatio: 1.5,
              child: PieChart(
                _buildPieChartData(total),
                duration: config.animate ? config.animationDuration : Duration.zero,
              ),
            ),

            // Legend
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  /// Build header
  Widget _buildHeader(double total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF111827),
                ),
              ),
              Text(
                'Toplam: ${total.toInt()}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build pie chart data
  PieChartData _buildPieChartData(double total) {
    return PieChartData(
      sectionsSpace: 2,
      centerSpaceRadius: 40,
      sections: List.generate(data.length, (index) {
        final item = data[index];
        final value = item.y;
        final percentage = (value / total * 100);
        final color = _getColor(item);

        return PieChartSectionData(
          color: color,
          value: value,
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _getContrastColor(color),
          ),
          badgeWidget: _showOnlyBigSegments(percentage)
              ? null
              : _buildBadge(percentage),
          showTitle: true,
        );
      }),
      pieTouchData: PieTouchData(
        enabled: config.showTooltips,
        touchCallback: (FlTouchEvent event, pieTouchResponse) {
          if (event is FlTapUpEvent && pieTouchResponse != null) {
            final touchedIndex = pieTouchResponse.touchedSection?.touchedSectionIndex;
            if (touchedIndex != null && touchedIndex >= 0 && touchedIndex < data.length) {
              final item = data[touchedIndex];
              onSectionTap?.call(item.label);
            }
          }
        },
      ),
    );
  }

  /// Get color for data point
  Color _getColor(ChartData item) {
    final colorValue = item.metadata?['color'] as int?;
    if (colorValue != null) {
      return Color(colorValue);
    }

    // Default colors based on index
    final colors = [
      ForensicChartColors.neonCyan,
      ForensicChartColors.securityGreen,
      ForensicChartColors.warningYellow,
      ForensicChartColors.deepOrange,
      ForensicChartColors.criticalRed,
      ForensicChartColors.infoBlue,
    ];
    return colors[item.hashCode % colors.length];
  }

  /// Get contrast color for text
  Color _getContrastColor(Color color) {
    // Calculate luminance
    final luminance = (0.299 * color.r * 255 + 0.587 * color.g * 255 + 0.114 * color.b * 255) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Build badge for small segments
  Widget _buildBadge(double percentage) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        '${percentage.toStringAsFixed(0)}%',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  /// Show only big segments (>= 5%)
  bool _showOnlyBigSegments(double percentage) {
    return percentage >= 5.0;
  }

  /// Build legend
  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: data.map((item) {
        final color = _getColor(item);
        final value = item.y.toInt();
        final percentage = (item.y / data.fold<double>(0, (sum, d) => sum + d.y) * 100);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${item.label}: $value (%${percentage.toStringAsFixed(1)})',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      color: isDarkMode ? ForensicChartColors.backgroundDark : ForensicChartColors.backgroundLight,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.pie_chart,
                size: 64,
                color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Veri bulunamadı',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}