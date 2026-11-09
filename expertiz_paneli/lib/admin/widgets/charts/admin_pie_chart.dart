/// ADMIN PIE CHART
///
/// FAZ-5.0 / Phase 5 - Visual BI & KPI Cockpit
///
///  PURPOSE:
/// Interactive pie chart for status distribution and rejection reasons.
/// Shows percentages and raw counts with forensic-themed colors.
///
///  PRINCIPLE:
/// "Visual hierarchy directs attention to critical items."
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yerimebak_sistemleri/tema/renkler.dart';
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
    if (data.isEmpty || data.every((item) => item.y <= 0)) {
      return _buildEmptyState(context);
    }

    final total = data.fold<double>(0, (sum, d) => sum + d.y);

    return Card(
      elevation: 0,
      color: context.renkler.yuzey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(context, total),
            const SizedBox(height: 20),

            // Chart
            AspectRatio(
              aspectRatio: 1.5,
              child: PieChart(
                _buildPieChartData(context, total),
                duration:
                    config.animate ? config.animationDuration : Duration.zero,
              ),
            ),

            // Legend
            _buildLegend(context),
          ],
        ),
      ),
    );
  }

  /// Build header
  Widget _buildHeader(BuildContext context, double total) {
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
                  color: context.renkler.metin,
                ),
              ),
              Text(
                'Toplam: ${total.toInt()}',
                style: TextStyle(
                  fontSize: 14,
                  color: context.renkler.metinIkincil,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build pie chart data
  PieChartData _buildPieChartData(BuildContext context, double total) {
    return PieChartData(
      sectionsSpace: 2,
      centerSpaceRadius: 40,
      sections: List.generate(data.length, (index) {
        final item = data[index];
        final value = item.y;
        final percentage = (value / total * 100);
        final color = _getColor(context, item);

        return PieChartSectionData(
          color: color,
          value: value,
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _getContrastColor(context, color),
          ),
          badgeWidget: _showOnlyBigSegments(percentage)
              ? null
              : _buildBadge(context, percentage),
          showTitle: true,
        );
      }),
      pieTouchData: PieTouchData(
        enabled: config.showTooltips,
        touchCallback: (FlTouchEvent event, pieTouchResponse) {
          if (event is FlTapUpEvent && pieTouchResponse != null) {
            final touchedIndex =
                pieTouchResponse.touchedSection?.touchedSectionIndex;
            if (touchedIndex != null &&
                touchedIndex >= 0 &&
                touchedIndex < data.length) {
              final item = data[touchedIndex];
              onSectionTap?.call(item.label);
            }
          }
        },
      ),
    );
  }

  /// Get color for data point
  Color _getColor(BuildContext context, ChartData item) {
    final colorValue = item.metadata?['color'] as int?;
    if (colorValue != null) {
      return Color(colorValue);
    }

    // Default colors based on index
    final colors = [
      context.renkler.birincil,
      context.renkler.birincilMetin,
      context.renkler.uyari,
      context.renkler.vurgu,
      context.renkler.tehlike,
      context.renkler.bilgi,
    ];
    return colors[item.hashCode % colors.length];
  }

  /// Get contrast color for text
  Color _getContrastColor(BuildContext context, Color color) {
    // Calculate luminance
    final luminance = (0.299 * color.r * 255 +
            0.587 * color.g * 255 +
            0.114 * color.b * 255) /
        255;
    return luminance > 0.5 ? context.renkler.yuzey : context.renkler.metin;
  }

  /// Build badge for small segments
  Widget _buildBadge(BuildContext context, double percentage) {
    return Container(
      decoration: BoxDecoration(
        color: context.renkler.metin.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        '${percentage.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: context.renkler.metin,
        ),
      ),
    );
  }

  /// Show only big segments (>= 5%)
  bool _showOnlyBigSegments(double percentage) {
    return percentage >= 5.0;
  }

  /// Build legend
  Widget _buildLegend(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: data.map((item) {
        final color = _getColor(context, item);
        final value = item.y.toInt();
        final percentage =
            (item.y / data.fold<double>(0, (sum, d) => sum + d.y) * 100);

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
                color: context.renkler.metinIkincil,
                fontSize: 13,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  /// Build empty state
  Widget _buildEmptyState(BuildContext context) {
    return Card(
      elevation: 0,
      color: context.renkler.yuzey,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(
                LucideIcons.chartPie,
                size: 64,
                color: context.renkler.metinIkincil,
              ),
              const SizedBox(height: 16),
              Text(
                'Veri bulunamadı',
                style: TextStyle(
                  color: context.renkler.metinIkincil,
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
