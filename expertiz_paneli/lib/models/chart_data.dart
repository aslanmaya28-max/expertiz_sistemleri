/// CHART DATA MODELS
/// 
/// FAZ-5.0 / Phase 5 - Visual BI & KPI Cockpit
/// 
/// 🎯 PURPOSE:
/// Type-safe data models for chart visualization.
/// Supports line, pie, and bar charts with forensic-themed colors.
/// 
/// 🪨 PRINCIPLE:
/// "Type safety prevents runtime errors in critical visualizations."
library;

import 'package:flutter/material.dart';

/// Chart Data Point
/// 
/// Represents a single data point for charts
class ChartData {
  /// X-axis value (typically date/time)
  final DateTime x;
  
  /// Y-axis value (metric value)
  final double y;
  
  /// Label for the data point
  final String label;
  
  /// Additional metadata (optional)
  final Map<String, dynamic>? metadata;

  const ChartData({
    required this.x,
    required this.y,
    required this.label,
    this.metadata,
  });

  /// Create chart data from map
  factory ChartData.fromMap(Map<String, dynamic> data) {
    return ChartData(
      x: DateTime.parse(data['x'] as String),
      y: (data['y'] as num).toDouble(),
      label: data['label'] as String,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'x': x.toIso8601String(),
      'y': y,
      'label': label,
      'metadata': metadata,
    };
  }

  /// Get formatted date string
  String get formattedDate => '${x.day}/${x.month}';

  /// Get formatted time string
  String get formattedTime => '${x.hour}:${x.minute.toString().padLeft(2, '0')}';

  @override
  String toString() => 'ChartData($formattedDate, y: $y, label: $label)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChartData && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}

/// Chart Series
/// 
/// Represents a collection of data points for a chart
class ChartSeries {
  /// Series name
  final String name;
  
  /// Data points
  final List<ChartData> data;
  
  /// Series color
  final Color color;
  
  /// Series display name
  final String displayName;

  const ChartSeries({
    required this.name,
    required this.data,
    required this.color,
    required this.displayName,
  });

  /// Create empty series
  const ChartSeries.empty()
      : name = '',
        data = const [],
        color = Colors.blue,
        displayName = '';

  /// Get maximum Y value
  double get maxY {
    if (data.isEmpty) return 0.0;
    return data.map((d) => d.y).reduce((a, b) => a > b ? a : b);
  }

  /// Get minimum Y value
  double get minY {
    if (data.isEmpty) return 0.0;
    return data.map((d) => d.y).reduce((a, b) => a < b ? a : b);
  }

  /// Get average Y value
  double get averageY {
    if (data.isEmpty) return 0.0;
    final sum = data.map((d) => d.y).reduce((a, b) => a + b);
    return sum / data.length;
  }

  /// Check if all values are above threshold
  bool isAllAbove(double threshold) {
    return data.every((d) => d.y >= threshold);
  }

  /// Check if any value is below threshold
  bool hasAnyBelow(double threshold) {
    return data.any((d) => d.y < threshold);
  }

  @override
  String toString() => 'ChartSeries($displayName, ${data.length} points)';
}

/// Anomaly Detection Result
/// 
/// Represents detected anomalies in chart data
class AnomalyResult {
  /// Data point with anomaly
  final ChartData dataPoint;
  
  /// Anomaly type
  final AnomalyType type;
  
  /// Severity level (0-1)
  final double severity;
  
  /// Description
  final String description;

  const AnomalyResult({
    required this.dataPoint,
    required this.type,
    required this.severity,
    required this.description,
  });

  @override
  String toString() => 'AnomalyResult(${type.name}: $description)';
}

/// Anomaly Type Enum
enum AnomalyType {
  /// Value too low
  lowValue,
  
  /// Value too high
  highValue,
  
  /// Sudden drop
  suddenDrop,
  
  /// Sudden spike
  suddenSpike,
  
  /// Below threshold
  belowThreshold,
}

/// Chart Type Enum
enum ChartType {
  line,
  pie,
  bar,
}

/// Forensic Theme Colors for Charts
class ForensicChartColors {
  /// Neon Cyan for primary data
  static const Color neonCyan = Color(0xFF00FFFF);
  
  /// Deep Orange for anomalies
  static const Color deepOrange = Color(0xFFFF4500);
  
  /// Security Green for success
  static const Color securityGreen = Color(0xFF228B22);
  
  /// Warning Yellow
  static const Color warningYellow = Color(0xFFFFD700);
  
  /// Critical Red
  static const Color criticalRed = Color(0xFFDC143C);
  
  /// Info Blue
  static const Color infoBlue = Color(0xFF4169E1);
  
  /// Neutral Grey
  static const Color neutralGrey = Color(0xFF808080);
  
  /// Background dark
  static const Color backgroundDark = Color(0xFF1E1E1E);
  
  /// Background light
  static const Color backgroundLight = Color(0xFFF5F5F5);
  
  /// Grid line color (dark mode)
  static const Color gridLineDark = Color(0xFF333333);
  
  /// Grid line color (light mode)
  static const Color gridLineLight = Color(0xFFE0E0E0);
  
  /// Tooltip background
  static const Color tooltipBackground = Color(0xDD000000);
  
  /// Tooltip text
  static const Color tooltipText = Colors.white;
}

/// Chart Configuration
/// 
/// Centralized configuration for all charts
class ChartConfig {
  /// Enable animation
  final bool animate;
  
  /// Animation duration
  final Duration animationDuration;
  
  /// Show tooltips
  final bool showTooltips;
  
  /// Show grid lines
  final bool showGridLines;
  
  /// Show data points
  final bool showDataPoints;
  
  /// Enable pinch to zoom
  final bool enableZoom;
  
  /// Anomaly threshold for line charts
  final double anomalyThreshold;
  
  /// SLA threshold for bar charts (in hours)
  final double slaThresholdHours;

  const ChartConfig({
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 800),
    this.showTooltips = true,
    this.showGridLines = true,
    this.showDataPoints = true,
    this.enableZoom = false,
    this.anomalyThreshold = 70.0,
    this.slaThresholdHours = 48.0,
  });

  /// Default configuration
  static const defaultConfig = ChartConfig();

  /// High performance configuration (no animations)
  static const highPerformance = ChartConfig(
    animate: false,
    showTooltips: false,
    showGridLines: false,
  );
}