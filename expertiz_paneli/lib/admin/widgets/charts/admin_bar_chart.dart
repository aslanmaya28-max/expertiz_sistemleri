/// ADMIN BAR CHART
/// 
/// FAZ-5.0 / Phase 5 - Visual BI & KPI Cockpit
/// 
/// 🎯 PURPOSE:
/// Horizontal bar chart for personnel SLA and performance metrics.
/// Shows exact duration and person info with SLA violation highlighting.
/// 
/// 🪨 PRINCIPLE:
/// "Performance metrics must be actionable and visible."
library;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/chart_data.dart';

/// Admin Bar Chart Widget
/// 
/// Displays horizontal bar charts with:
/// - Personnel SLA metrics
/// - Average approval times
/// - SLA violation highlighting (> 48h = orange)
/// - Interactive tooltips
class AdminBarChart extends StatelessWidget {
  final List<ChartData> data;
  final String title;
  final String xAxisLabel;
  final bool isDarkMode;
  final ChartConfig config;
  final double? slaThresholdHours;
  final VoidCallback? onTap;

  const AdminBarChart({
    super.key,
    required this.data,
    required this.title,
    this.xAxisLabel = '',
    this.isDarkMode = true,
    this.config = ChartConfig.defaultConfig,
    this.slaThresholdHours,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    final threshold = slaThresholdHours ?? config.slaThresholdHours;
    final hasViolations = data.any((d) => d.y > threshold);

    return Card(
      elevation: 4,
      color: isDarkMode ? ForensicChartColors.backgroundDark : ForensicChartColors.backgroundLight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(hasViolations, threshold),
            const SizedBox(height: 20),

            // Chart
            AspectRatio(
              aspectRatio: 1.8,
              child: BarChart(
                _buildBarChartData(threshold),
                duration: config.animate ? config.animationDuration : Duration.zero,
              ),
            ),

            // Legend
            if (hasViolations) _buildSLALegend(threshold),
          ],
        ),
      ),
    );
  }

  /// Build header
  Widget _buildHeader(bool hasViolations, double threshold) {
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
              if (hasViolations)
                Text(
                  '⚠️ SLA ihlali var (${threshold.toInt()} saat üzeri)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ForensicChartColors.warningYellow,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: onTap,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ],
    );
  }

  /// Build bar chart data
  BarChartData _buildBarChartData(double threshold) {
    final maxY = data.map((d) => d.y).reduce((a, b) => a > b ? a : b);

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY * 1.2,
      minY: 0,
      barTouchData: BarTouchData(
        enabled: config.showTooltips,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => ForensicChartColors.tooltipBackground,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final item = data[groupIndex];
            final hours = item.y;
            final isViolation = hours > threshold;
            final personnelId = item.metadata?['personnel_id'] as String? ?? item.label;
            final reportCount = item.metadata?['report_count'] as int? ?? 0;

            return BarTooltipItem(
              '$personnelId\n'
              'Ort: ${hours.toStringAsFixed(1)} saat\n'
              'Rapor: $reportCount\n'
              '${isViolation ? '⚠️ SLA İhlali!' : '✅ SLA İçi'}',
              TextStyle(
                color: isViolation 
                    ? ForensicChartColors.warningYellow 
                    : ForensicChartColors.tooltipText,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 60,
            getTitlesWidget: (value, meta) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  '${value.toInt()}s',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 10,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      gridData: FlGridData(
        show: config.showGridLines,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: isDarkMode 
                ? ForensicChartColors.gridLineDark 
                : ForensicChartColors.gridLineLight,
            strokeWidth: 1,
          );
        },
      ),
      borderData: FlBorderData(
        show: false,
      ),
      barGroups: List.generate(data.length, (index) {
        final item = data[index];
        final value = item.y;
        final isViolation = value > threshold;

        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: value,
              color: isViolation 
                  ? ForensicChartColors.warningYellow 
                  : ForensicChartColors.securityGreen,
              width: 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: isViolation
                    ? [
                        ForensicChartColors.warningYellow.withValues(alpha: 0.6),
                        ForensicChartColors.warningYellow,
                      ]
                    : [
                        ForensicChartColors.securityGreen.withValues(alpha: 0.6),
                        ForensicChartColors.securityGreen,
                      ],
              ),
            ),
          ],
        );
      }),
    );
  }

  /// Build SLA legend
  Widget _buildSLALegend(double threshold) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: ForensicChartColors.securityGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'SLA İçi (≤ ${threshold.toInt()} saat)',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: ForensicChartColors.warningYellow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'SLA İhlali (> ${threshold.toInt()} saat)',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
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
                Icons.bar_chart,
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