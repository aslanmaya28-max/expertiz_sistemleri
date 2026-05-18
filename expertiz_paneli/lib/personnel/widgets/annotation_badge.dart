/// ANNOTATION BADGE
/// 
/// FAZ-6.0 / Step 2 - Smart Annotation System
/// 
/// 🎯 PURPOSE:
/// Saha personelinin reddedilen raporda admin notlarını görsel
/// olarak görmesini sağlayan badge widget'ı.
/// 
/// 🪨 PRINCIPLE:
/// "Visual Hierarchy - Hatalar anında fark edilir"

library;

import 'package:flutter/material.dart';
import '../../models/admin_annotation.dart';

/// Annotation Badge Widget
/// 
/// Displays admin annotations for a specific field with visual
/// indicators (red border, warning icon, popup).
class AnnotationBadge extends StatelessWidget {
  final String fieldKey;
  final String fieldLabel;
  final String message;
  final AnnotationType type;
  final List<AdminAnnotation> annotations;
  final Widget child;
  final VoidCallback onReply;
  final VoidCallback? onResolved;

  const AnnotationBadge({
    super.key,
    required this.fieldKey,
    required this.fieldLabel,
    required this.message,
    required this.type,
    required this.annotations,
    required this.child,
    required this.onReply,
    this.onResolved,
  });

  /// Get active annotations for this field
  List<AdminAnnotation> get activeAnnotations =>
      annotations.where((a) => a.fieldKey == fieldKey && a.isActive).toList();

  /// Check if this field has active annotations
  bool get hasActiveAnnotations => activeAnnotations.isNotEmpty;

  /// Get annotation color based on type
  Color _getAnnotationColor(AnnotationType type) {
    return type.colorHex.toColor();
  }

  @override
  Widget build(BuildContext context) {
    if (!hasActiveAnnotations) {
      return child;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _getAnnotationColor(activeAnnotations.first.type),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              child,
              Positioned(
                top: -8,
                right: -8,
                child: _buildWarningIcon(context),
              ),
            ],
          ),
        ),
        if (activeAnnotations.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${activeAnnotations.length} not',
              style: TextStyle(
                fontSize: 10,
                color: _getAnnotationColor(activeAnnotations.first.type),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWarningIcon(BuildContext context) {
    final type = activeAnnotations.first.type;
    final color = _getAnnotationColor(type);
    
    return GestureDetector(
      onTap: () => _showAnnotationPopup(context),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          _getWarningIcon(type),
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  IconData _getWarningIcon(AnnotationType type) {
    switch (type) {
      case AnnotationType.error:
        return Icons.error;
      case AnnotationType.warning:
        return Icons.warning;
      case AnnotationType.info:
        return Icons.info;
    }
  }

  void _showAnnotationPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AnnotationPopup(
        annotations: activeAnnotations,
        onResolved: onResolved,
      ),
    );
  }
}

/// Annotation Popup Dialog
/// 
/// Shows detailed annotation information with admin details
/// and timestamps.
class AnnotationPopup extends StatelessWidget {
  final List<AdminAnnotation> annotations;
  final VoidCallback? onResolved;

  const AnnotationPopup({
    super.key,
    required this.annotations,
    this.onResolved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            annotations.first.type == AnnotationType.error
                ? Icons.error
                : Icons.warning,
            color: annotations.first.type.colorHex.toColor(),
          ),
          const SizedBox(width: 8),
          const Text('Admin Notları'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: annotations.length,
          itemBuilder: (context, index) {
            final annotation = annotations[index];
            return _buildAnnotationCard(annotation, isDark);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
        if (onResolved != null)
          ElevatedButton(
            onPressed: () {
              onResolved!();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Düzeltildi'),
          ),
      ],
    );
  }

  Widget _buildAnnotationCard(AdminAnnotation annotation, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: annotation.type.colorHex.toColor(),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                annotation.type == AnnotationType.error
                    ? Icons.error
                    : Icons.warning,
                size: 16,
                color: annotation.type.colorHex.toColor(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  annotation.fieldLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              _buildSeverityBadge(annotation.severity),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Message
          Text(
            annotation.message,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Footer
          Row(
            children: [
              Icon(
                Icons.person,
                size: 12,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                annotation.adminName,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.access_time,
                size: 12,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                annotation.ageText,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityBadge(AnnotationSeverity severity) {
    Color color;
    String label;
    
    switch (severity) {
      case AnnotationSeverity.low:
        color = Colors.blue;
        label = 'Düşük';
        break;
      case AnnotationSeverity.medium:
        color = Colors.orange;
        label = 'Orta';
        break;
      case AnnotationSeverity.high:
        color = Colors.red;
        label = 'Yüksek';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Annotation Summary Widget
/// 
/// Shows a summary of all active annotations in the report.
/// Typically displayed at the top of a rejected report.
class AnnotationSummary extends StatelessWidget {
  final List<AdminAnnotation> annotations;
  final VoidCallback? onViewDetails;

  const AnnotationSummary({
    super.key,
    required this.annotations,
    this.onViewDetails,
  });

  List<AdminAnnotation> get activeAnnotations =>
      annotations.where((a) => a.isActive).toList();

  @override
  Widget build(BuildContext context) {
    if (activeAnnotations.isEmpty) {
      return const SizedBox.shrink();
    }

    final errorCount = activeAnnotations
        .where((a) => a.type == AnnotationType.error)
        .length;
    final warningCount = activeAnnotations
        .where((a) => a.type == AnnotationType.warning)
        .length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bu Rapor Admin Tarafından Reddedildi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Aşağıdaki alanları düzelttikten sonra tekrar gönderin:',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (errorCount > 0)
                _buildCountChip('Hata', errorCount, Colors.red),
              if (warningCount > 0)
                _buildCountChip('Uyarı', warningCount, Colors.orange),
            ],
          ),
          if (onViewDetails != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onViewDetails,
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('Tüm Notları Gör'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Extension to convert hex string to Color
extension ColorExtension on String {
  Color toColor() {
    final hex = replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}