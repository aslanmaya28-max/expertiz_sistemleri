/// EVIDENCE SHIMMER PLACEHOLDER
/// 
/// FAZ-1.0 / S1 — Forensic-Grade Loading Placeholder
/// 
/// ⚖️ PURPOSE:
/// Provides a loading placeholder that matches EvidenceCard dimensions
/// and forensic theme colors for smooth loading transitions
library;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart'; // FIXED: Added Shimmer import
import '../core/theme/forensic_theme.dart';

/// Evidence Shimmer Placeholder
/// 
/// Displays a shimmer effect matching EvidenceCard layout during data fetch
/// Maintains forensic theme colors and card dimensions
class EvidenceShimmerPlaceholder extends StatelessWidget {
  /// Whether to show compact layout (for ListView)
  final bool isCompact;

  const EvidenceShimmerPlaceholder({
    super.key,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ForensicTheme.getNeutralDecoration(),
      child: Shimmer.fromColors(
        baseColor: ForensicTheme.forensicSlate,
        highlightColor: ForensicTheme.forensicSlate.withValues(alpha: 0.5), // FIXED: Replaced withOpacity
        period: const Duration(milliseconds: 1500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            _buildHeader(),
            
            // Hash section
            _buildHashSection(),
            
            // Status badges section
            _buildStatusSection(),
            
            // Reasoning section (collapsed placeholder)
            if (!isCompact) _buildReasoningSection(),
            
            // Action bar
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  /// Build header shimmer
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      child: Row(
        children: [
          // Status icon placeholder
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(width: ForensicTheme.spaceSm),
          
          // Text placeholders
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 150,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: ForensicTheme.spaceXxs),
                Container(
                  width: 120,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5), // FIXED: Replaced withOpacity
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          
          // UTC badge placeholder
          Container(
            width: 40,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3), // FIXED: Replaced withOpacity
              borderRadius: BorderRadius.circular(ForensicTheme.radiusButton),
            ),
          ),
        ],
      ),
    );
  }

  /// Build hash section shimmer
  Widget _buildHashSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: ForensicTheme.spaceMd),
      padding: const EdgeInsets.all(ForensicTheme.spaceSm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1), // FIXED: Replaced withOpacity
        borderRadius: BorderRadius.circular(ForensicTheme.radiusButton),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2), // FIXED: Replaced withOpacity
        ),
      ),
      child: Row(
        children: [
          // Icon placeholder
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: ForensicTheme.neonCyan.withValues(alpha: 0.5), // FIXED: Replaced withOpacity
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: ForensicTheme.spaceXs),
          
          // Hash placeholder
          Expanded(
            child: Container(
              height: 11,
              decoration: BoxDecoration(
                color: ForensicTheme.neonCyan.withValues(alpha: 0.3), // FIXED: Replaced withOpacity
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          
          // Copy icon placeholder
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3), // FIXED: Replaced withOpacity
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ],
      ),
    );
  }

  /// Build status badges shimmer
  Widget _buildStatusSection() {
    return Padding(
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      child: Row(
        children: [
          // Status badge placeholder
          Container(
            width: 100,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1), // FIXED: Replaced withOpacity
              borderRadius: BorderRadius.circular(ForensicTheme.radiusButton),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2), // FIXED: Replaced withOpacity
              ),
            ),
          ),
          const SizedBox(width: ForensicTheme.spaceXs),
          
          // Limitation badge placeholder
          Container(
            width: 120,
            height: 24,
            decoration: BoxDecoration(
              color: ForensicTheme.atomicRed.withValues(alpha: 0.1), // FIXED: Replaced withOpacity
              borderRadius: BorderRadius.circular(ForensicTheme.radiusButton),
              border: Border.all(
                color: ForensicTheme.atomicRed.withValues(alpha: 0.3), // FIXED: Replaced withOpacity
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build reasoning section shimmer
  Widget _buildReasoningSection() {
    return Container(
      margin: const EdgeInsets.all(ForensicTheme.spaceMd),
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05), // FIXED: Replaced withOpacity
        borderRadius: BorderRadius.circular(ForensicTheme.radiusButton),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label placeholder
          Container(
            width: 100,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3), // FIXED: Replaced withOpacity
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: ForensicTheme.spaceXxs),
          
          // Text line placeholder
          Container(
            width: double.infinity,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1), // FIXED: Replaced withOpacity
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: ForensicTheme.spaceSm),
          
          // Second label placeholder
          Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3), // FIXED: Replaced withOpacity
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: ForensicTheme.spaceXxs),
          
          // Text line placeholder
          Container(
            width: 200,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1), // FIXED: Replaced withOpacity
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  /// Build action bar shimmer
  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1), // FIXED: Replaced withOpacity
          ),
        ),
      ),
      child: Row(
        children: [
          // Expand button placeholder
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: ForensicTheme.neonCyan.withValues(alpha: 0.3), // FIXED: Replaced withOpacity
              shape: BoxShape.circle,
            ),
          ),
          
          const Spacer(),
          
          // Verify button placeholder
          Container(
            width: 80,
            height: 32,
            decoration: BoxDecoration(
              color: ForensicTheme.neonCyan.withValues(alpha: 0.3), // FIXED: Replaced withOpacity
              borderRadius: BorderRadius.circular(ForensicTheme.radiusButton),
            ),
          ),
          
          const SizedBox(width: ForensicTheme.spaceXs),
          
          // PDF button placeholder
          Container(
            width: 60,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1), // FIXED: Replaced withOpacity
              borderRadius: BorderRadius.circular(ForensicTheme.radiusButton),
              border: Border.all(
                color: ForensicTheme.neonCyan.withValues(alpha: 0.3), // FIXED: Replaced withOpacity
              ),
            ),
          ),
        ],
      ),
    );
  }
}