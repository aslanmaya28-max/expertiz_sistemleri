/// QUICK REVIEW DRAWER
/// 
/// PHASE 6.2 - Admin Quick Review Interface
/// 
/// 🎯 PURPOSE:
/// Provides a fast, efficient way for admins to review report evidence
/// without navigating to full report details. Shows top 3 most critical
/// photos and AI anomaly details in a slide-out drawer.
/// 
/// 🚀 KEY FEATURES:
/// - Shows top 3 riskiest photos
/// - Displays AI anomaly details
/// - Visual feedback during sealing
/// - "Sealed & Published" confirmation
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/forensic_theme.dart';
import '../../models/ai_analysis_result.dart';

/// Quick Review Drawer
/// 
/// Slide-out drawer for quick evidence review
class QuickReviewDrawer extends StatefulWidget {
  /// Report ID
  final String reportId;
  
  /// Vehicle info
  final String vehicleMake;
  final String vehicleModel;
  final String plate;
  
  /// AI analysis result
  final AIAnalysisResult? aiAnalysis;
  
  /// Evidence photos with risk scores
  final List<EvidencePhoto> evidencePhotos;
  
  /// On seal callback
  final VoidCallback? onSeal;
  
  /// On reject callback
  final VoidCallback? onReject;

  const QuickReviewDrawer({
    super.key,
    required this.reportId,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.plate,
    this.aiAnalysis,
    this.evidencePhotos = const [],
    this.onSeal,
    this.onReject,
  });

  @override
  State<QuickReviewDrawer> createState() => _QuickReviewDrawerState();
}

class _QuickReviewDrawerState extends State<QuickReviewDrawer> {
  bool _isSealing = false;
  bool _isSealed = false;

  Future<void> _handleSeal() async {
    if (_isSealing) return;
    
    setState(() => _isSealing = true);
    HapticFeedback.mediumImpact();
    
    // Simulate sealing delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Trigger seal callback
    widget.onSeal?.call();
    
    setState(() {
      _isSealing = false;
      _isSealed = true;
    });
    
    HapticFeedback.heavyImpact();
    
    // Auto-close after showing success
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleReject() {
    HapticFeedback.lightImpact();
    widget.onReject?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final topRiskPhotos = _getTopRiskPhotos(widget.evidencePhotos);
    
    return Container(
      width: MediaQuery.of(context).size.width * 0.7,
      constraints: const BoxConstraints(maxWidth: 600, minWidth: 400),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ForensicTheme.deepSpaceBlue.withValues(alpha: 0.98),
            ForensicTheme.deepSpaceBlue.withValues(alpha: 0.95),
          ],
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(ForensicTheme.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vehicle Info
                  _buildVehicleInfo(),
                  
                  const SizedBox(height: ForensicTheme.spaceMd),
                  
                  // AI Analysis Summary
                  if (widget.aiAnalysis != null) ...[
                    _buildAIAnalysisSummary(),
                    const SizedBox(height: ForensicTheme.spaceMd),
                  ],
                  
                  // Top Risk Photos
                  _buildRiskPhotosSection(topRiskPhotos),
                  
                  const SizedBox(height: ForensicTheme.spaceMd),
                  
                  // Inconsistencies
                  if (widget.aiAnalysis?.inconsistencies.isNotEmpty == true)
                    _buildInconsistenciesSection(),
                  
                  // Missing Info
                  if (widget.aiAnalysis?.missingInfo.isNotEmpty == true)
                    _buildMissingInfoSection(),
                ],
              ),
            ),
          ),
          
          // Actions
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
          Icon(Icons.speed, color: ForensicTheme.neonCyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QUICK REVIEW',
                  style: ForensicTheme.title.copyWith(
                    fontSize: 16,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  '#${widget.reportId.substring(0, 8)}',
                  style: ForensicTheme.caption.copyWith(
                    color: ForensicTheme.textDim,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            color: ForensicTheme.textDim,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfo() {
    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      decoration: BoxDecoration(
        color: ForensicTheme.textDim.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ForensicTheme.radiusCard),
        border: Border.all(
          color: ForensicTheme.neonCyan.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.directions_car,
            color: ForensicTheme.neonCyan,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${widget.vehicleMake} ${widget.vehicleModel} - ${widget.plate}',
              style: ForensicTheme.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAnalysisSummary() {
    final aiAnalysis = widget.aiAnalysis!;
    final reliabilityColor = aiAnalysis.reliabilityScore >= 95
        ? ForensicTheme.obsidianEmerald
        : aiAnalysis.reliabilityScore >= 80
            ? ForensicTheme.neonCyan
            : ForensicTheme.warningAmber;
    
    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            reliabilityColor.withValues(alpha: 0.1),
            reliabilityColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(ForensicTheme.radiusCard),
        border: Border.all(color: reliabilityColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, color: reliabilityColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'AI RELIABILITY',
                style: ForensicTheme.caption.copyWith(
                  color: reliabilityColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${aiAnalysis.reliabilityScore.toStringAsFixed(1)}%',
                style: ForensicTheme.title.copyWith(
                  color: reliabilityColor,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          if (aiAnalysis.hasCriticalIssues) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.warning, color: ForensicTheme.atomicRed, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Critical issues detected',
                    style: ForensicTheme.caption.copyWith(
                      color: ForensicTheme.atomicRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRiskPhotosSection(List<EvidencePhoto> photos) {
    if (photos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(ForensicTheme.spaceLg),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.check_circle,
                size: 48,
                color: ForensicTheme.obsidianEmerald.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'No critical issues detected',
                style: ForensicTheme.body.copyWith(
                  color: ForensicTheme.obsidianEmerald,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning, color: ForensicTheme.atomicRed, size: 18),
            const SizedBox(width: 8),
            Text(
              'TOP ${photos.length} CRITICAL PHOTOS',
              style: ForensicTheme.caption.copyWith(
                color: ForensicTheme.atomicRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...photos.map((photo) => _buildPhotoCard(photo)),
      ],
    );
  }

  Widget _buildPhotoCard(EvidencePhoto photo) {
    final riskColor = photo.riskScore >= 0.7
        ? ForensicTheme.atomicRed
        : photo.riskScore >= 0.5
            ? ForensicTheme.warningAmber
            : ForensicTheme.neonCyan;
    
    return Container(
      margin: const EdgeInsets.only(bottom: ForensicTheme.spaceSm),
      padding: const EdgeInsets.all(ForensicTheme.spaceSm),
      decoration: BoxDecoration(
        color: ForensicTheme.textDim.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ForensicTheme.radiusCard),
        border: Border.all(color: riskColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Photo thumbnail placeholder
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              color: ForensicTheme.textDim.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.image,
              color: ForensicTheme.textDim.withValues(alpha: 0.5),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Photo info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photo.label,
                  style: ForensicTheme.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: riskColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning,
                            size: 12,
                            color: riskColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(photo.riskScore * 100).toInt()}% RISK',
                            style: ForensicTheme.caption.copyWith(
                              color: riskColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (photo.damageType != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          photo.damageType!,
                          style: ForensicTheme.caption.copyWith(
                            color: ForensicTheme.textDim,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInconsistenciesSection() {
    final inconsistencies = widget.aiAnalysis!.inconsistencies.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: ForensicTheme.warningAmber, size: 18),
            const SizedBox(width: 8),
            Text(
              'INCONSISTENCIES',
              style: ForensicTheme.caption.copyWith(
                color: ForensicTheme.warningAmber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...inconsistencies.map((inconsistency) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ForensicTheme.warningAmber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: ForensicTheme.warningAmber.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.warning, color: ForensicTheme.warningAmber, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  inconsistency,
                  style: ForensicTheme.body.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
  
  Widget _buildMissingInfoSection() {
    final missingInfo = widget.aiAnalysis!.missingInfo.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline, color: ForensicTheme.neonCyan, size: 18),
            const SizedBox(width: 8),
            Text(
              'MISSING INFORMATION',
              style: ForensicTheme.caption.copyWith(
                color: ForensicTheme.neonCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...missingInfo.map((info) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ForensicTheme.neonCyan.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: ForensicTheme.neonCyan.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.help_outline, color: ForensicTheme.neonCyan, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  info,
                  style: ForensicTheme.body.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildActions() {
    if (_isSealed) {
      return Container(
        padding: const EdgeInsets.all(ForensicTheme.spaceMd),
        decoration: BoxDecoration(
          color: ForensicTheme.obsidianEmerald.withValues(alpha: 0.2),
          border: Border(
            top: BorderSide(
              color: ForensicTheme.obsidianEmerald.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              color: ForensicTheme.obsidianEmerald,
              size: 32,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SEALED & PUBLISHED',
                  style: ForensicTheme.title.copyWith(
                    color: ForensicTheme.obsidianEmerald,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Report is now visible to customer',
                  style: ForensicTheme.caption.copyWith(
                    color: ForensicTheme.obsidianEmerald,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
    if (_isSealing) {
      return Container(
        padding: const EdgeInsets.all(ForensicTheme.spaceMd),
        decoration: BoxDecoration(
          color: ForensicTheme.textDim.withValues(alpha: 0.1),
          border: Border(
            top: BorderSide(
              color: ForensicTheme.neonCyan.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                backgroundColor: ForensicTheme.textDim.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  ForensicTheme.neonCyan,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ForensicTheme.neonCyan,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'SEALING FORENSIC DATA...',
                  style: ForensicTheme.body.copyWith(
                    color: ForensicTheme.neonCyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
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
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _handleReject,
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text('REJECT'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ForensicTheme.atomicRed,
                side: BorderSide(color: ForensicTheme.atomicRed),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: ForensicTheme.spaceSm),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _handleSeal,
              icon: const Icon(Icons.verified, size: 18),
              label: const Text('APPROVE & SEAL'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ForensicTheme.obsidianEmerald,
                foregroundColor: ForensicTheme.textWhite,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<EvidencePhoto> _getTopRiskPhotos(List<EvidencePhoto> photos) {
    final sorted = List<EvidencePhoto>.from(photos);
    sorted.sort((a, b) => b.riskScore.compareTo(a.riskScore));
    return sorted.take(3).toList();
  }
}

// =====================================================
// MODELS
// =====================================================

/// Evidence Photo
/// 
/// Represents a photo with risk assessment
class EvidencePhoto {
  final String id;
  final String url;
  final String label;
  final double riskScore;
  final String? damageType;
  final String? description;
  
  EvidencePhoto({
    required this.id,
    required this.url,
    required this.label,
    required this.riskScore,
    this.damageType,
    this.description,
  });
}