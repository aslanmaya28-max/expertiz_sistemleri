/// STATUS DISTRIBUTION CARD
/// 
/// FAZ-4.0 / Phase 4 - Real-time Status Distribution Widget
/// 
/// 🎯 PURPOSE:
/// Display the breakdown of reports by status in real-time.
/// Highlights pending_admin status for immediate admin attention.
/// 
/// 🪨 PRINCIPLE:
/// "Visual hierarchy directs attention to critical items."
library;

import 'package:flutter/material.dart';
import '../../models/dashboard_stats.dart';

/// Status Distribution Card
/// 
/// Shows the distribution of reports across all FAZ-3.0 statuses.
/// Emphasizes pending_admin with visual highlighting.
class StatusDistributionCard extends StatelessWidget {
  final StatusDistribution distribution;
  final bool isDarkMode;
  final VoidCallback? onStatusTap;

  const StatusDistributionCard({
    super.key,
    required this.distribution,
    required this.isDarkMode,
    this.onStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.pie_chart, color: Colors.blue),
                const SizedBox(width: 10),
                Text(
                  'Rapor Durum Dağılımı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                _buildTotalBadge(),
              ],
            ),
            const SizedBox(height: 20),

            // Status items (horizontal layout)
            LayoutBuilder(
              builder: (context, constraints) {
                // Use horizontal layout for wider screens
                if (constraints.maxWidth > 600) {
                  return _buildHorizontalLayout();
                }
                // Vertical layout for smaller screens
                return _buildVerticalLayout();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build total badge
  Widget _buildTotalBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue, width: 1),
      ),
      child: Text(
        'Toplam: ${distribution.total}',
        style: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  /// Build horizontal layout (desktop/tablet)
  Widget _buildHorizontalLayout() {
    return Row(
      children: Status.values.map((status) {
        final count = _getCountForStatus(status);
        final isPendingAdmin = status == Status.pendingAdmin;
        
        return Expanded(
          child: _buildStatusItem(
            status: status,
            count: count,
            isHighlighted: isPendingAdmin && count > 0,
          ),
        );
      }).toList(),
    );
  }

  /// Build vertical layout (mobile)
  Widget _buildVerticalLayout() {
    return Column(
      children: Status.values.map((status) {
        final count = _getCountForStatus(status);
        final isPendingAdmin = status == Status.pendingAdmin;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildStatusItem(
            status: status,
            count: count,
            isHighlighted: isPendingAdmin && count > 0,
            isVertical: true,
          ),
        );
      }).toList(),
    );
  }

  /// Build single status item
  Widget _buildStatusItem({
    required Status status,
    required int count,
    required bool isHighlighted,
    bool isVertical = false,
  }) {
    final color = _getStatusColor(status);
    final percentage = distribution.total > 0 ? (count / distribution.total * 100) : 0.0;

    return GestureDetector(
      onTap: () => onStatusTap?.call(),
      child: Container(
        margin: isVertical ? null : const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isHighlighted
              ? Colors.orange.withValues(alpha: 0.1)
              : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isHighlighted ? Colors.orange : color.withValues(alpha: 0.3),
            width: isHighlighted ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and name
            Row(
              children: [
                Text(
                  status.icon,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                      color: isDarkMode
                          ? Colors.white
                          : (isHighlighted ? Colors.orange : const Color(0xFF111827)),
                    ),
                  ),
                ),
                if (isHighlighted && count > 0)
                  _buildBlinkingDot(),
              ],
            ),
            const SizedBox(height: 8),

            // Count and percentage
            Row(
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isHighlighted ? Colors.orange : color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(%${percentage.toStringAsFixed(1)})',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),

            // Progress bar
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: distribution.total > 0 ? count / distribution.total : 0.0,
                backgroundColor: (isHighlighted ? Colors.orange : color).withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isHighlighted ? Colors.orange : color,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build blinking dot for pending admin
  Widget _buildBlinkingDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.orange,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  /// Get count for status
  int _getCountForStatus(Status status) {
    switch (status) {
      case Status.draft:
        return distribution.draft;
      case Status.pendingAi:
        return distribution.pendingAi;
      case Status.pendingAdmin:
        return distribution.pendingAdmin;
      case Status.published:
        return distribution.published;
      case Status.rejected:
        return distribution.rejected;
    }
  }

  /// Get color for status
  Color _getStatusColor(Status status) {
    switch (status) {
      case Status.draft:
        return Colors.grey;
      case Status.pendingAi:
        return Colors.blue;
      case Status.pendingAdmin:
        return Colors.orange;
      case Status.published:
        return Colors.green;
      case Status.rejected:
        return Colors.red;
    }
  }

}
