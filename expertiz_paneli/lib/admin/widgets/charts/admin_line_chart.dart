/// ADMIN LINE CHART
/// 
/// FAZ-5.0 / Phase 5 - Visual BI & KPI Cockpit
/// 
/// 🎯 PURPOSE:
/// Forensic-themed line chart with gradient fill, anomaly detection,
/// and interactive tooltips for trend visualization.
/// 
/// 🪨 PRINCIPLE:
/// "Visual hierarchy directs attention to critical deviations."
library;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/chart_data.dart';

/// Admin Line Chart Widget
/// 
/// Displays line charts with:
/// - Gradient area fill
/// - Anomaly detection (red highlight for Y < 70)
/// - Interactive tooltips
/// - Dark mode support
class AdminLineChart extends StatelessWidget {
  final List<ChartData> data;
  final String title;
  final String yAxisLabel;
  final Color primaryColor;
  final bool isDarkMode;
  final ChartConfig config;
  final double? anomalyThreshold;
  final VoidCallback? onTap;

  const AdminLineChart({
    super.key,
    required this.data,
    required this.title,
    this.yAxisLabel = '',
    this.primaryColor = ForensicChartColors.neonCyan,
    this.isDarkMode = true,
    this.config = ChartConfig.defaultConfig,
    this.anomalyThreshold,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    final threshold = anomalyThreshold ?? config.anomalyThreshold;
    final hasAnomalies = data.any((d) => d.y < threshold);

    return Card(
      elevation: 4,
      color: isDarkMode ? ForensicChartColors.backgroundDark : ForensicChartColors.backgroundLight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(hasAnomalies, threshold),
            const SizedBox(height: 20),

            // Chart
            AspectRatio(
              aspectRatio: 2.0,
              child: LineChart(
                _buildLineChartData(threshold),
                duration: config.animate ? config.animationDuration : Duration.zero,
              ),
            ),

            // Legend
            if (hasAnomalies) _buildAnomalyLegend(threshold),
          ],
        ),
      ),
    );
  }

  /// Build header
  Widget _buildHeader(bool hasAnomalies, double threshold) {
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
              if (hasAnomalies)
                Text(
                  '⚠️ Eşik değerin altında (%${threshold.toStringAsFixed(0)})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ForensicChartColors.deepOrange,
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

  /// Build line chart data
  LineChartData _buildLineChartData(double threshold) {
    final spots = data.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.y,
      );
    }).toList();

    final minY = data.map((d) => d.y).reduce((a, b) => a < b ? a : b);
    final maxY = data.map((d) => d.y).reduce((a, b) => a > b ? a : b);
    final yRange = maxY - minY;
    
    return LineChartData(
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
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < data.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    data[index].label,
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                );
              }
              return const Text('');
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: _calculateInterval(minY, maxY),
            getTitlesWidget: (value, meta) {
              return Text(
                value.toStringAsFixed(0),
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 10,
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: false,
      ),
      minX: 0,
      maxX: (data.length - 1).toDouble(),
      minY: (minY - yRange * 0.1).clamp(0, double.infinity),
      maxY: maxY + yRange * 0.1,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          gradient: LinearGradient(
            colors: [
              primaryColor.withValues(alpha: 0.8),
              primaryColor.withValues(alpha: 0.4),
            ],
          ),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: config.showDataPoints,
            getDotPainter: (spot, percent, barData, index) {
              final value = data[index].y;
              final isAnomaly = value < threshold;

              return FlDotCirclePainter(
                radius: isAnomaly ? 6 : 4,
                color: isAnomaly 
                    ? ForensicChartColors.deepOrange 
                    : primaryColor,
                strokeWidth: 2,
                strokeColor: isDarkMode 
                    ? ForensicChartColors.backgroundDark 
                    : Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryColor.withValues(alpha: 0.3),
                primaryColor.withValues(alpha: 0.05),
              ],
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: config.showTooltips,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (touchedSpot) => ForensicChartColors.tooltipBackground,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.toInt();
              if (index >= 0 && index < data.length) {
                final dataPoint = data[index];
                final value = dataPoint.y;
                final isAnomaly = value < threshold;

                return LineTooltipItem(
                  '${dataPoint.label}\n'
                  'Değer: ${value.toStringAsFixed(1)}\n'
                  '${isAnomaly ? '⚠️ Anomali!' : ''}',
                  TextStyle(
                    color: isAnomaly 
                        ? ForensicChartColors.deepOrange 
                        : ForensicChartColors.tooltipText,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }
              return null;
            }).toList();
          },
        ),
      ),
    );
  }

  /// Calculate interval for Y-axis
  double _calculateInterval(double minY, double maxY) {
    final range = maxY - minY;
    if (range <= 10) return 2;
    if (range <= 50) return 10;
    if (range <= 100) return 20;
    return (range / 5).ceilToDouble();
  }

  /// Build anomaly legend
  Widget _buildAnomalyLegend(double threshold) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: ForensicChartColors.deepOrange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Anomali (Eşik: %${threshold.toStringAsFixed(0)})',
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
                Icons.show_chart,
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