/// ADMIN BAR CHART
///
/// FAZ-5.0 / Phase 5 - Visual BI & KPI Cockpit
///
///  PURPOSE:
/// Horizontal bar chart for personnel SLA and performance metrics.
/// Shows exact duration and person info with SLA violation highlighting.
///
///  PRINCIPLE:
/// "Performance metrics must be actionable and visible."
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yerimebak_sistemleri/tema/renkler.dart';
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
      return _buildEmptyState(context);
    }

    final threshold = slaThresholdHours ?? config.slaThresholdHours;
    final hasViolations = data.any((d) => d.y > threshold);

    return Card(
      elevation: 0,
      color: context.renkler.yuzey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(context, hasViolations, threshold),
            const SizedBox(height: 20),

            // Chart
            AspectRatio(
              aspectRatio: 1.8,
              child: BarChart(
                _buildBarChartData(context, threshold),
                duration:
                    config.animate ? config.animationDuration : Duration.zero,
              ),
            ),

            // Legend
            if (hasViolations) _buildSLALegend(context, threshold),
          ],
        ),
      ),
    );
  }

  /// Build header
  Widget _buildHeader(
      BuildContext context, bool hasViolations, double threshold) {
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
              if (hasViolations)
                Text(
                  ' SLA ihlali var (${threshold.toInt()} saat üzeri)',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.renkler.metin,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(LucideIcons.info),
          onPressed: onTap,
          color: context.renkler.metinIkincil,
        ),
      ],
    );
  }

  /// Build bar chart data
  BarChartData _buildBarChartData(BuildContext context, double threshold) {
    final maxY = data.map((d) => d.y).reduce((a, b) => a > b ? a : b);

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY * 1.2,
      minY: 0,
      barTouchData: BarTouchData(
        enabled: config.showTooltips,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => context.renkler.yuzey,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final item = data[groupIndex];
            final hours = item.y;
            final isViolation = hours > threshold;
            final personnelId =
                item.metadata?['personnel_id'] as String? ?? item.label;
            final reportCount = item.metadata?['report_count'] as int? ?? 0;

            return BarTooltipItem(
              '$personnelId\n'
              'Ort: ${hours.toStringAsFixed(1)} saat\n'
              'Rapor: $reportCount\n'
              '${isViolation ? ' SLA İhlali!' : ' SLA İçi'}',
              TextStyle(
                color:
                    isViolation ? context.renkler.metin : context.renkler.metin,
                fontWeight: FontWeight.bold,
                fontSize: 13,
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
                    color: context.renkler.metinIkincil,
                    fontSize: 13,
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
            color: isDarkMode ? context.renkler.yuzey : context.renkler.yuzey,
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
              color: isViolation ? context.renkler.uyari : context.renkler.birincil,
              width: 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        );
      }),
    );
  }

  /// Build SLA legend
  Widget _buildSLALegend(BuildContext context, double threshold) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: context.renkler.yuzey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'SLA İçi (≤ ${threshold.toInt()} saat)',
            style: TextStyle(
              color: context.renkler.metinIkincil,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: context.renkler.yuzey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'SLA İhlali (> ${threshold.toInt()} saat)',
            style: TextStyle(
              color: context.renkler.metinIkincil,
              fontSize: 13,
            ),
          ),
        ],
      ),
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
                LucideIcons.chartNoAxesColumn,
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
