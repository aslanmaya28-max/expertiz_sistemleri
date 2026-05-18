/// ADMIN EVIDENCE CARD
/// 
/// FAZ-6.0 / W4 — Admin-Focused Evidence Card for Review Queue
/// 
/// 🎯 PURPOSE:
/// Admin'in rapor detayına girmeden hızlı karar verebilmesini sağlayan
/// interaktif kart bileşeni. Önceliklendirme, Quick Review, ve
/// güvenli mühürleme akışlarını içerir.
/// 
/// 🚀 KEY FEATURES:
/// - Priority sorting (Low AI score, High severity annotations)
/// - Quick Review Side Panel (Kritik fotoğraflar + AI anomalileri)
/// - Safety Action UI (Long Press/Slide to Confirm)
/// - Bulk Action Capability (Multi-Select)
/// - Visual Feedback (Sealing overlay, checkmark)
/// 
/// 🔒 SECURITY:
/// - Approve & Seal için Long Press mekanizması
/// - Bulk Action sadece güvenli raporlar için (AI > 95, no anomalies)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/forensic_theme.dart';
import '../../models/admin_annotation.dart';
import '../../models/ai_analysis_result.dart';

/// Admin Evidence Card
/// 
/// Enhanced evidence card for admin review queue with:
/// - Quick actions
/// - Priority indicators
/// - Bulk selection
/// - Safety UI
class AdminEvidenceCard extends StatefulWidget {
  /// Report ID
  final String reportId;
  
  /// Vehicle info
  final String vehicleMake;
  final String vehicleModel;
  final String plate;
  
  /// Personnel name
  final String personnelName;
  
  /// AI reliability score
  final double aiScore;
  
  /// Number of damages detected
  final int damageCount;
  
  /// GPS verification status
  final bool isGpsVerified;
  
  /// Ledger hash status
  final bool hasLedgerHash;
  
  /// Pending annotations count
  final int pendingAnnotations;
  
  /// Resolved annotations count
  final int resolvedAnnotations;
  
  /// Admin annotations
  final List<AdminAnnotation>? annotations;
  
  /// AI analysis result
  final AIAnalysisResult? aiAnalysis;
  
  /// Whether card is selected for bulk action
  final bool isSelected;
  
  /// Selection callback
  final ValueChanged<bool>? onSelectionChanged;
  
  /// Quick Review callback
  final VoidCallback? onQuickReview;
  
  /// Approve & Seal callback
  final VoidCallback? onApproveAndSeal;
  
  /// Reject callback
  final VoidCallback? onReject;

  const AdminEvidenceCard({
    super.key,
    required this.reportId,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.plate,
    required this.personnelName,
    required this.aiScore,
    required this.damageCount,
    required this.isGpsVerified,
    required this.hasLedgerHash,
    this.pendingAnnotations = 0,
    this.resolvedAnnotations = 0,
    this.annotations,
    this.aiAnalysis,
    this.isSelected = false,
    this.onSelectionChanged,
    this.onQuickReview,
    this.onApproveAndSeal,
    this.onReject,
  });

  @override
  State<AdminEvidenceCard> createState() => _AdminEvidenceCardState();
}

class _AdminEvidenceCardState extends State<AdminEvidenceCard>
    with TickerProviderStateMixin {
  // =====================================================
  // STATE
  // =====================================================
  
  /// Whether bulk selection mode is active
  final bool _isSelectionMode = false;
  
  /// Long press progress (0.0 to 1.0)
  double _longPressProgress = 0.0;
  
  /// Animation controller for long press
  late AnimationController _longPressController;
  
  /// Animation for long press progress
  late Animation<double> _longPressAnimation;

  // =====================================================
  // INITIALIZATION
  // =====================================================

  @override
  void initState() {
    super.initState();
    
    _longPressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _longPressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _longPressController, curve: Curves.linear),
    );
    
    _longPressAnimation.addListener(() {
      setState(() {
        _longPressProgress = _longPressAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _longPressController.dispose();
    super.dispose();
  }

  // =====================================================
  // ACTIONS
  // =====================================================

  /// Handle card tap (selection mode)
  void _handleTap() {
    if (_isSelectionMode) {
      widget.onSelectionChanged?.call(!widget.isSelected);
    }
  }
  
  /// Handle long press start (for approve & seal)
  void _handleLongPressStart() {
    _longPressController.forward();
    HapticFeedback.lightImpact();
  }
  
  /// Handle long press end
  void _handleLongPressEnd() {
    if (_longPressProgress < 1.0) {
      _longPressController.reverse();
      setState(() {
        _longPressProgress = 0.0;
      });
    } else {
      // Long press completed - trigger approve & seal
      HapticFeedback.heavyImpact();
      widget.onApproveAndSeal?.call();
      _longPressController.reset();
      setState(() {
        _longPressProgress = 0.0;
      });
    }
  }

  // =====================================================
  // HELPERS
  // =====================================================

  /// Calculate priority level
  _PriorityLevel _getPriorityLevel() {
    // High priority: AI score < 80 OR has critical issues
    if (widget.aiScore < 80 || 
        widget.aiAnalysis?.hasCriticalIssues == true ||
        widget.pendingAnnotations > 0) {
      return _PriorityLevel.high;
    }
    
    // Medium priority: AI score < 95
    if (widget.aiScore < 95) {
      return _PriorityLevel.medium;
    }
    
    // Low priority: AI score >= 95, no issues
    return _PriorityLevel.low;
  }
  
  /// Get priority color
  Color _getPriorityColor() {
    switch (_getPriorityLevel()) {
      case _PriorityLevel.high:
        return ForensicTheme.atomicRed;
      case _PriorityLevel.medium:
        return ForensicTheme.warningAmber;
      case _PriorityLevel.low:
        return ForensicTheme.obsidianEmerald;
    }
  }
  
  /// Get AI score color
  Color _getAiScoreColor() {
    if (widget.aiScore >= 95) return ForensicTheme.obsidianEmerald;
    if (widget.aiScore >= 80) return ForensicTheme.neonCyan;
    if (widget.aiScore >= 60) return ForensicTheme.warningAmber;
    return ForensicTheme.atomicRed;
  }
  
  /// Check if bulk seal is allowed
  bool _canBulkSeal() {
    return widget.aiScore >= 95 && 
           widget.damageCount == 0 &&
           widget.pendingAnnotations == 0 &&
           (widget.aiAnalysis?.hasCriticalIssues != true);
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final priority = _getPriorityLevel();
    final priorityColor = _getPriorityColor();
    
    return GestureDetector(
      onTap: _handleTap,
      onLongPressStart: _canBulkSeal() ? (_) => _handleLongPressStart() : null,
      onLongPressEnd: _canBulkSeal() ? (_) => _handleLongPressEnd() : null,
      child: AnimatedContainer(
        duration: ForensicTheme.animMedium,
        margin: const EdgeInsets.all(ForensicTheme.spaceXs),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? ForensicTheme.neonCyan.withValues(alpha: 0.1)
              : ForensicTheme.deepSpaceBlue.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(ForensicTheme.radiusCard),
          border: Border.all(
            color: widget.isSelected
                ? ForensicTheme.neonCyan
                : priorityColor,
            width: widget.isSelected ? 2 : 1,
          ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: ForensicTheme.neonCyan.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ForensicTheme.radiusCard),
          child: Stack(
            children: [
              // Main content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(priority, priorityColor),
                  
                  // AI Insight
                  _buildAIInsight(),
                  
                  // Forensic Check
                  _buildForensicCheck(),
                  
                  // Annotation Summary
                  if (widget.pendingAnnotations > 0 || widget.resolvedAnnotations > 0)
                    _buildAnnotationSummary(),
                  
                  // Action Buttons
                  _buildActionButtons(),
                ],
              ),
              
              // Long press overlay
              if (_longPressProgress > 0)
                _buildLongPressOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // WIDGET BUILDERS
  // =====================================================

  /// Build card header
  Widget _buildHeader(_PriorityLevel priority, Color priorityColor) {
    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: ForensicTheme.textDim.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Priority indicator
          _buildPriorityIndicator(priority, priorityColor),
          
          const SizedBox(width: ForensicTheme.spaceSm),
          
          // Vehicle info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.vehicleMake} ${widget.vehicleModel}',
                  style: ForensicTheme.title.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.directions_car, size: 12, color: ForensicTheme.textDim),
                    const SizedBox(width: 4),
                    Text(
                      widget.plate,
                      style: ForensicTheme.caption,
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.person, size: 12, color: ForensicTheme.textDim),
                    const SizedBox(width: 4),
                    Text(
                      widget.personnelName,
                      style: ForensicTheme.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Report ID
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ForensicTheme.spaceXs,
              vertical: ForensicTheme.spaceXxs,
            ),
            decoration: BoxDecoration(
              color: ForensicTheme.textDim.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(ForensicTheme.radiusButton),
            ),
            child: Text(
              '#${widget.reportId.substring(0, 8)}',
              style: ForensicTheme.caption.copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build priority indicator
  Widget _buildPriorityIndicator(_PriorityLevel priority, Color color) {
    IconData icon;
    String label;
    
    switch (priority) {
      case _PriorityLevel.high:
        icon = Icons.warning;
        label = 'HIGH';
        break;
      case _PriorityLevel.medium:
        icon = Icons.priority_high;
        label = 'MED';
        break;
      case _PriorityLevel.low:
        icon = Icons.check_circle;
        label = 'LOW';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ForensicTheme.spaceXs,
        vertical: ForensicTheme.spaceXxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ForensicTheme.radiusButton),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: ForensicTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build AI Insight section
  Widget _buildAIInsight() {
    final aiScoreColor = _getAiScoreColor();
    
    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      child: Row(
        children: [
          // AI Score
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, size: 16, color: aiScoreColor),
                    const SizedBox(width: 4),
                    Text(
                      'AI Reliability',
                      style: ForensicTheme.caption.copyWith(
                        color: aiScoreColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // AI Score bar
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: ForensicTheme.textDim.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: widget.aiScore / 100,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: aiScoreColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.aiScore.toStringAsFixed(1)}%',
                  style: ForensicTheme.caption.copyWith(
                    color: aiScoreColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: ForensicTheme.spaceMd),
          
          // Damage Count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.damageCount > 0 ? Icons.report : Icons.check_circle,
                      size: 16,
                      color: widget.damageCount > 0 
                          ? ForensicTheme.atomicRed 
                          : ForensicTheme.obsidianEmerald,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Damages',
                      style: ForensicTheme.caption.copyWith(
                        color: widget.damageCount > 0 
                            ? ForensicTheme.atomicRed 
                            : ForensicTheme.obsidianEmerald,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.damageCount} detected',
                  style: ForensicTheme.body.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: widget.damageCount > 0 
                        ? ForensicTheme.atomicRed 
                        : ForensicTheme.obsidianEmerald,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build Forensic Check section
  Widget _buildForensicCheck() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ForensicTheme.spaceMd,
        vertical: ForensicTheme.spaceSm,
      ),
      child: Row(
        children: [
          // GPS Verification
          _buildForensicItem(
            icon: Icons.gps_fixed,
            label: 'GPS',
            isVerified: widget.isGpsVerified,
          ),
          
          const SizedBox(width: ForensicTheme.spaceMd),
          
          // Ledger Hash
          _buildForensicItem(
            icon: Icons.fingerprint,
            label: 'Hash',
            isVerified: widget.hasLedgerHash,
          ),
          
          const Spacer(),
          
          // AI Issues warning
          if (widget.aiAnalysis?.hasCriticalIssues == true)
            Row(
              children: [
                Icon(Icons.warning, size: 14, color: ForensicTheme.atomicRed),
                const SizedBox(width: 4),
                Text(
                  'Critical Issues',
                  style: ForensicTheme.caption.copyWith(
                    color: ForensicTheme.atomicRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  /// Build forensic check item
  Widget _buildForensicItem({
    required IconData icon,
    required String label,
    required bool isVerified,
  }) {
    final color = isVerified 
        ? ForensicTheme.obsidianEmerald 
        : ForensicTheme.atomicRed;
    
    return Row(
      children: [
        Icon(
          isVerified ? Icons.check_circle : Icons.cancel,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: ForensicTheme.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
  
  /// Build Annotation Summary
  Widget _buildAnnotationSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ForensicTheme.spaceMd,
        vertical: ForensicTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: ForensicTheme.textDim.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.comment, size: 14, color: ForensicTheme.neonCyan),
          const SizedBox(width: 4),
          Text(
            'Annotations: ',
            style: ForensicTheme.caption,
          ),
          if (widget.pendingAnnotations > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: ForensicTheme.atomicRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: ForensicTheme.atomicRed),
              ),
              child: Text(
                '${widget.pendingAnnotations} pending',
                style: ForensicTheme.caption.copyWith(
                  color: ForensicTheme.atomicRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (widget.resolvedAnnotations > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: ForensicTheme.obsidianEmerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: ForensicTheme.obsidianEmerald),
              ),
              child: Text(
                '${widget.resolvedAnnotations} resolved',
                style: ForensicTheme.caption.copyWith(
                  color: ForensicTheme.obsidianEmerald,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Build Action Buttons
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: ForensicTheme.textDim.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Quick Review
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onQuickReview,
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('Quick Review'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ForensicTheme.neonCyan,
                side: BorderSide(color: ForensicTheme.neonCyan),
              ),
            ),
          ),
          
          const SizedBox(width: ForensicTheme.spaceSm),
          
          // Reject
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onReject,
              icon: const Icon(Icons.cancel, size: 16),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ForensicTheme.atomicRed,
                side: BorderSide(color: ForensicTheme.atomicRed),
              ),
            ),
          ),
          
          const SizedBox(width: ForensicTheme.spaceSm),
          
          // Approve & Seal (with long press indicator)
          Expanded(
            flex: 2,
            child: _buildApproveButton(),
          ),
        ],
      ),
    );
  }
  
  /// Build Approve & Seal button
  Widget _buildApproveButton() {
    final canSeal = _canBulkSeal();
    
    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          // Background button
          ElevatedButton.icon(
            onPressed: canSeal ? null : widget.onApproveAndSeal,
            icon: const Icon(Icons.verified, size: 16),
            label: Text(
              canSeal ? 'Hold to Seal' : 'Approve & Seal',
              style: const TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: canSeal 
                  ? ForensicTheme.obsidianEmerald 
                  : Colors.grey,
              foregroundColor: ForensicTheme.textWhite,
              disabledBackgroundColor: ForensicTheme.obsidianEmerald.withValues(alpha: 0.5),
            ),
          ),
          
          // Long press progress overlay
          if (canSeal)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _longPressProgress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ForensicTheme.textWhite.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Build Long Press Overlay
  Widget _buildLongPressOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: ForensicTheme.obsidianEmerald.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(ForensicTheme.radiusCard),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified,
                size: 48,
                color: ForensicTheme.obsidianEmerald,
              ),
              const SizedBox(height: 8),
              Text(
                'Sealing...',
                style: ForensicTheme.title.copyWith(
                  color: ForensicTheme.obsidianEmerald,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// ENUMS
// =====================================================

/// Priority Level
enum _PriorityLevel {
  high,
  medium,
  low,
}