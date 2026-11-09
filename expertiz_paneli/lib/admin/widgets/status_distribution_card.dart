/// STATUS DISTRIBUTION CARD
///
/// FAZ-4.0 / Phase 4 - Real-time Status Distribution Widget
///
///  PURPOSE:
/// Display the breakdown of reports by status in real-time.
/// Highlights pending_admin status for immediate admin attention.
///
///  PRINCIPLE:
/// "Visual hierarchy directs attention to critical items."
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yerimebak_sistemleri/tema/renkler.dart';
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
      elevation: 0,
      color: context.renkler.yuzey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(LucideIcons.chartPie, color: context.renkler.birincil),
                const SizedBox(width: 10),
                Text(
                  'Rapor Durum Dağılımı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.renkler.metin,
                  ),
                ),
                const Spacer(),
                _buildTotalBadge(context),
              ],
            ),
            const SizedBox(height: 20),

            // Status items (horizontal layout)
            LayoutBuilder(
              builder: (context, constraints) {
                // Use horizontal layout for wider screens
                if (constraints.maxWidth > 600) {
                  return _buildHorizontalLayout(context);
                }
                // Vertical layout for smaller screens
                return _buildVerticalLayout(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build total badge
  Widget _buildTotalBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.renkler.birincil.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.renkler.birincil, width: 1),
      ),
      child: Text(
        'Toplam: ${distribution.total}',
        style: TextStyle(
          color: context.renkler.birincil,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  /// Build horizontal layout (desktop/tablet)
  Widget _buildHorizontalLayout(BuildContext context) {
    return Row(
      children: Status.values.map((status) {
        final count = _getCountForStatus(status);
        final isPendingAdmin = status == Status.pendingAdmin;

        return Expanded(
          child: _buildStatusItem(
            context,
            status: status,
            count: count,
            isHighlighted: isPendingAdmin && count > 0,
          ),
        );
      }).toList(),
    );
  }

  /// Build vertical layout (mobile)
  Widget _buildVerticalLayout(BuildContext context) {
    return Column(
      children: Status.values.map((status) {
        final count = _getCountForStatus(status);
        final isPendingAdmin = status == Status.pendingAdmin;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildStatusItem(
            context,
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
  Widget _buildStatusItem(
    BuildContext context, {
    required Status status,
    required int count,
    required bool isHighlighted,
    bool isVertical = false,
  }) {
    final color = _getStatusColor(context, status);
    final percentage =
        distribution.total > 0 ? (count / distribution.total * 100) : 0.0;

    return GestureDetector(
      onTap: () => onStatusTap?.call(),
      child: Container(
        margin: isVertical ? null : const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isHighlighted
              ? context.renkler.uyari.withValues(alpha: 0.1)
              : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isHighlighted
                ? context.renkler.uyari
                : color.withValues(alpha: 0.3),
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
                      fontSize: 13,
                      fontWeight:
                          isHighlighted ? FontWeight.bold : FontWeight.normal,
                      color: isDarkMode
                          ? context.renkler.metin
                          : (isHighlighted
                              ? context.renkler.uyari
                              : context.renkler.metin),
                    ),
                  ),
                ),
                if (isHighlighted && count > 0) _buildBlinkingDot(context),
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
                    color: isHighlighted ? context.renkler.uyari : color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(%${percentage.toStringAsFixed(1)})',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.renkler.metinIkincil,
                  ),
                ),
              ],
            ),

            // Progress bar
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:
                    distribution.total > 0 ? count / distribution.total : 0.0,
                backgroundColor: (isHighlighted ? context.renkler.uyari : color)
                    .withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isHighlighted ? context.renkler.uyari : color,
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
  Widget _buildBlinkingDot(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: context.renkler.uyari,
        shape: BoxShape.circle,
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
  Color _getStatusColor(BuildContext context, Status status) {
    switch (status) {
      case Status.draft:
        return context.renkler.metinIkincil;
      case Status.pendingAi:
        return context.renkler.birincil;
      case Status.pendingAdmin:
        return context.renkler.uyari;
      case Status.published:
        return context.renkler.birincilMetin;
      case Status.rejected:
        return context.renkler.tehlike;
    }
  }
}
