/// EVIDENCE CARD
/// 
/// FAZ-1.0 / W1 — Forensic-Grade Evidence Display Widget
/// 
/// ⚖️ PURPOSE:
/// Provides a unified, production-ready card component for displaying
/// immutable ledger evidence across Admin, Personnel, and Customer panels.
/// 
/// 🎨 DESIGN PRINCIPLES:
/// - Clarity: Evidence must be instantly understandable
/// - Forensic focus: Cryptographic verification is primary
/// - Expandable: Details available on demand, not overwhelming
/// - Responsive: Works on mobile, tablet, desktop
/// 
/// 🔐 FORENSIC UX NOTES:
/// - Laser scan animation provides visual confirmation of verification
/// - Glow effects (Emerald/Red) give instant feedback on hash status
/// - Expandable reasoning follows "Black Box Opening" metaphor
/// - All text is selectable for legal proceedings
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme/forensic_theme.dart';
import '../services/ledger_verification_service.dart';
import '../services/evidence_report_service.dart';
import '../domain/ledger/hash_verification_result.dart';

/// Evidence Card State
enum _EvidenceCardState {
  /// Initial state - not yet verified
  initial,
  
  /// Scanning in progress - laser animation running
  scanning,
  
  /// Verified - hash matches, integrity confirmed
  verified,
  
  /// Error - hash mismatch or verification failed
  error,
}

/// Evidence Card
/// 
/// Production-ready widget for displaying immutable ledger evidence
/// with expandable reasoning and cryptographic verification
class EvidenceCard extends StatefulWidget {
  /// Unique identifier for this evidence
  final String evidenceId;
  
  /// UTC timestamp when evidence was sealed
  final DateTime timestamp;
  
  /// SHA256 cryptographic hash
  final String sha256Hash;
  
  /// Whether evidence has been verified (pre-verified state)
  final bool isVerified;
  
  /// Observation from AI (what was seen)
  final String observation;
  
  /// Assumption from AI (what was inferred)
  final String assumption;
  
  /// Limitations from AI (uncertainty expressions)
  final String limitation;
  
  /// Optional report ID for linking
  final String? reportId;
  
  /// Optional analyst ID for attribution
  final String? analystId;
  
  /// Callback when verification completes
  final ValueChanged<HashVerificationResult?>? onVerificationComplete;

  const EvidenceCard({
    super.key,
    required this.evidenceId,
    required this.timestamp,
    required this.sha256Hash,
    required this.isVerified,
    required this.observation,
    required this.assumption,
    required this.limitation,
    this.reportId,
    this.analystId,
    this.onVerificationComplete,
  });

  @override
  State<EvidenceCard> createState() => _EvidenceCardStateWidget();
}

class _EvidenceCardStateWidget extends State<EvidenceCard>
    with TickerProviderStateMixin {
  // =====================================================
  // STATE MANAGEMENT
  // =====================================================
  
  /// Current card state
  _EvidenceCardState _cardState = _EvidenceCardState.initial;
  
  /// Whether reasoning section is expanded
  bool _isReasoningExpanded = false;
  
  // =====================================================
  // ANIMATION CONTROLLERS
  // =====================================================
  
  /// Laser scan animation controller
  late AnimationController _laserController;
  
  /// Expand/collapse animation controller
  late AnimationController _expandController;
  
  /// Error shake animation controller
  late AnimationController _shakeController;
  
  // =====================================================
  // ANIMATIONS
  // =====================================================
  
  /// Laser scan position animation (0.0 to 1.0)
  late Animation<double> _laserAnimation;
  
  /// Expansion animation (collapsed to expanded)
  late Animation<double> _expandAnimation;
  
  /// Error shake offset animation
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize laser scan animation (450ms)
    _laserController = AnimationController(
      duration: ForensicTheme.animSlow,
      vsync: this,
    );
    
    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
    
    // Initialize expand animation (300ms)
    _expandController = AnimationController(
      duration: ForensicTheme.animMedium,
      vsync: this,
    );
    
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    
    // Initialize shake animation (200ms)
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    _expandController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // =====================================================
  // ACTIONS
  // =====================================================
  
  /// Verify cryptographic hash
  /// 
  /// Forensic UX Note: This triggers the laser scan animation,
  /// then calls the verification service, then shows result
  Future<void> _verifyHash() async {
    setState(() {
      _cardState = _EvidenceCardState.scanning;
    });
    
    // FIXED: Capture verification service BEFORE any async operations
    final verificationService = Provider.of<LedgerVerificationService>(context, listen: false);
    
    // Start laser scan animation
    await _laserController.forward();
    
    try {
      // Now safe to use captured service
      final result = await verificationService.verifyLedgerIntegrity(ledgerId: widget.evidenceId);
      
      // Update state based on result
      if (mounted) {
        setState(() {
          _cardState = result.isValid
              ? _EvidenceCardState.verified
              : _EvidenceCardState.error;
        });
      }
      
      // Trigger error shake if failed
      if (!result.isValid) {
        _shakeController.forward().then((_) {
          _shakeController.reverse();
        });
      }
      
      // Notify parent
      widget.onVerificationComplete?.call(result);
    } catch (e) {
      // Handle error
      setState(() {
        _cardState = _EvidenceCardState.error;
      });
      
      // Trigger error shake
      _shakeController.forward().then((_) {
        _shakeController.reverse();
      });
      
      widget.onVerificationComplete?.call(null);
    }
  }
  
  /// Export PDF report
  Future<void> _exportPdf() async {
    // FIXED: Capture scaffold messenger BEFORE async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final reportService = Provider.of<EvidenceReportService>(context, listen: false);
      await reportService.saveReport(widget.evidenceId);
    } catch (e) {
      // Use captured messenger after async gap
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('PDF export failed: $e'),
            backgroundColor: ForensicTheme.atomicRed,
          ),
        );
      }
    }
  }
  
  /// Copy hash to clipboard
  void _copyHash() {
    Clipboard.setData(ClipboardData(text: widget.sha256Hash));
    // FIXED: Capture ScaffoldMessenger before potential async operation
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Hash copied to clipboard'),
        backgroundColor: ForensicTheme.neonCyan,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  /// Toggle reasoning expansion
  void _toggleReasoning() {
    setState(() {
      _isReasoningExpanded = !_isReasoningExpanded;
    });
    
    if (_isReasoningExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  // =====================================================
  // BUILD
  // =====================================================
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value * 0.1, 0),
          child: Container(
            decoration: _getCardDecoration(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ForensicTheme.radiusCard),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Laser scan overlay
                  if (_cardState == _EvidenceCardState.scanning)
                    _buildLaserScan(),
                  
                  // Card header
                  _buildHeader(),
                  
                  // Hash display
                  _buildHashSection(),
                  
                  // Quick status
                  _buildQuickStatus(),
                  
                  // Reasoning (expandable)
                  _buildReasoningSection(),
                  
                  // Action bar
                  _buildActionBar(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // WIDGET BUILDERS
  // =====================================================
  
  /// Get card decoration based on state
  BoxDecoration _getCardDecoration() {
    switch (_cardState) {
      case _EvidenceCardState.verified:
        return ForensicTheme.getVerifiedDecoration(isGlowing: true);
      
      case _EvidenceCardState.error:
        return ForensicTheme.getErrorDecoration(isGlowing: true);
      
      default:
        return ForensicTheme.getNeutralDecoration();
    }
  }
  
  /// Build laser scan overlay
  /// 
  /// Forensic UX Note: CustomPaint draws a cyan laser line
  /// that moves from top to bottom (450ms animation)
  Widget _buildLaserScan() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _laserAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: _LaserScanPainter(
              scanPosition: _laserAnimation.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
  
  /// Build card header
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      child: Row(
        children: [
          // Status icon
          _buildStatusIcon(),
          const SizedBox(width: ForensicTheme.spaceSm),
          
          // Evidence ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Evidence #${widget.evidenceId.substring(0, 8)}',
                  style: ForensicTheme.title,
                ),
                const SizedBox(height: ForensicTheme.spaceXxs),
                Text(
                  DateFormat('dd.MM.yyyy HH:mm:ss').format(widget.timestamp.toUtc()),
                  style: ForensicTheme.caption,
                ),
              ],
            ),
          ),
          
          // UTC badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ForensicTheme.spaceXs,
              vertical: ForensicTheme.spaceXxs,
            ),
            decoration: BoxDecoration(
              // FIXED: Replaced withOpacity with withValues
              color: ForensicTheme.textDim.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(ForensicTheme.radiusButton),
            ),
            child: Text(
              'UTC',
              style: ForensicTheme.caption.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build status icon based on state
  Widget _buildStatusIcon() {
    IconData iconData;
    Color iconColor;
    
    switch (_cardState) {
      case _EvidenceCardState.verified:
        iconData = Icons.verified;
        iconColor = ForensicTheme.obsidianEmerald;
        break;
      
      case _EvidenceCardState.error:
        iconData = Icons.error;
        iconColor = ForensicTheme.atomicRed;
        break;
      
      case _EvidenceCardState.scanning:
        iconData = Icons.scanner;
        iconColor = ForensicTheme.neonCyan;
        break;
      
      default:
        iconData = Icons.lock_clock;
        iconColor = ForensicTheme.textDim;
    }
    
    return Icon(iconData, color: iconColor, size: 32);
  }
  
  /// Build hash section
  Widget _buildHashSection() {
    return InkWell(
      onTap: _copyHash,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: ForensicTheme.spaceMd,
        ),
        padding: const EdgeInsets.all(ForensicTheme.spaceSm),
        decoration: BoxDecoration(
          // FIXED: Replaced withOpacity with withValues
          color: ForensicTheme.deepSpaceBlue.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(ForensicTheme.radiusButton),
          border: Border.all(
            // FIXED: Replaced withOpacity with withValues
            color: ForensicTheme.textDim.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.fingerprint,
              color: ForensicTheme.neonCyan,
              size: 16,
            ),
            const SizedBox(width: ForensicTheme.spaceXs),
            Expanded(
              child: Text(
                _abbreviateHash(widget.sha256Hash),
                style: ForensicTheme.monospace,
              ),
            ),
            Icon(
              Icons.copy,
              color: ForensicTheme.textDim,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build quick status indicator
  Widget _buildQuickStatus() {
    final hasLimitations = widget.limitation.isNotEmpty;
    
    return Padding(
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      child: Wrap(
        spacing: ForensicTheme.spaceXs,
        runSpacing: ForensicTheme.spaceXs,
        children: [
          // Verification badge
          _buildStatusBadge(),
          
          // Limitations warning
          if (hasLimitations)
            _buildLimitationBadge(),
        ],
      ),
    );
  }
  
  /// Build status badge
  Widget _buildStatusBadge() {
    String label;
    Color color;
    
    switch (_cardState) {
      case _EvidenceCardState.verified:
        label = '✓ VERIFIED';
        color = ForensicTheme.obsidianEmerald;
        break;
      
      case _EvidenceCardState.error:
        label = '✗ TAMPERING';
        color = ForensicTheme.atomicRed;
        break;
      
      case _EvidenceCardState.scanning:
        label = '⟳ SCANNING';
        color = ForensicTheme.neonCyan;
        break;
      
      default:
        label = '? UNVERIFIED';
        color = ForensicTheme.textDim;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ForensicTheme.spaceXs,
        vertical: ForensicTheme.spaceXxs,
      ),
      decoration: BoxDecoration(
        // FIXED: Replaced withOpacity with withValues
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ForensicTheme.radiusButton),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: ForensicTheme.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
  
  /// Build limitation badge
  Widget _buildLimitationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ForensicTheme.spaceXs,
        vertical: ForensicTheme.spaceXxs,
      ),
      decoration: BoxDecoration(
        // FIXED: Replaced withOpacity with withValues
        color: ForensicTheme.atomicRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ForensicTheme.radiusButton),
        border: Border.all(color: ForensicTheme.atomicRed),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning, size: 12, color: ForensicTheme.atomicRed),
          const SizedBox(width: 4),
          Text(
            '⚠️ LIMITATIONS',
            style: ForensicTheme.caption.copyWith(
              color: ForensicTheme.atomicRed,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build expandable reasoning section
  Widget _buildReasoningSection() {
    return SizeTransition(
      sizeFactor: _expandAnimation,
      axisAlignment: -1.0,
      child: Container(
        margin: const EdgeInsets.all(ForensicTheme.spaceMd),
        padding: const EdgeInsets.all(ForensicTheme.spaceMd),
        decoration: BoxDecoration(
          // FIXED: Replaced withOpacity with withValues
          color: ForensicTheme.deepSpaceBlue.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(ForensicTheme.radiusButton),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Observation
            if (widget.observation.isNotEmpty) ...[
              _buildReasoningLabel('🔍 Observation', ForensicTheme.neonCyan),
              const SizedBox(height: ForensicTheme.spaceXxs),
              Text(
                widget.observation,
                style: ForensicTheme.body,
              ),
              const SizedBox(height: ForensicTheme.spaceSm),
            ],
            
            // Assumption
            if (widget.assumption.isNotEmpty) ...[
              _buildReasoningLabel('🧠 Assumption', ForensicTheme.textWhite),
              const SizedBox(height: ForensicTheme.spaceXxs),
              Text(
                widget.assumption,
                style: ForensicTheme.body,
              ),
              const SizedBox(height: ForensicTheme.spaceSm),
            ],
            
            // Limitations
            if (widget.limitation.isNotEmpty)
              _buildLimitationSection(),
          ],
        ),
      ),
    );
  }
  
  /// Build reasoning label
  Widget _buildReasoningLabel(String label, Color color) {
    return Text(
      label,
      style: ForensicTheme.caption.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
  
  /// Build limitation section
  Widget _buildLimitationSection() {
    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceSm),
      decoration: BoxDecoration(
        // FIXED: Replaced withOpacity with withValues
        color: ForensicTheme.atomicRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ForensicTheme.radiusButton),
        border: Border.all(
          // FIXED: Replaced withOpacity with withValues
          color: ForensicTheme.atomicRed.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, size: 14, color: ForensicTheme.atomicRed),
              const SizedBox(width: 4),
              Text(
                '⚠️ LIMITATIONS',
                style: ForensicTheme.caption.copyWith(
                  color: ForensicTheme.atomicRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: ForensicTheme.spaceXxs),
          Text(
            widget.limitation,
            style: ForensicTheme.caption.copyWith(
              // FIXED: Replaced withOpacity with withValues
              color: ForensicTheme.atomicRed.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build action bar
  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            // FIXED: Replaced withOpacity with withValues
            color: ForensicTheme.textDim.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Expand/Collapse button
          IconButton(
            icon: Icon(
              _isReasoningExpanded
                  ? Icons.expand_less
                  : Icons.expand_more,
            ),
            onPressed: _toggleReasoning,
            color: ForensicTheme.neonCyan,
            tooltip: _isReasoningExpanded
                ? 'Collapse reasoning'
                : 'Expand reasoning',
          ),
          
          const Spacer(),
          
          // Verify button
          ElevatedButton.icon(
            onPressed: _cardState == _EvidenceCardState.scanning
                ? null
                : _verifyHash,
            icon: _cardState == _EvidenceCardState.scanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.scanner, size: 16),
            label: const Text('Verify', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getVerifyButtonColor(),
              foregroundColor: ForensicTheme.deepSpaceBlue,
            ),
          ),
          
          const SizedBox(width: ForensicTheme.spaceXs),
          
          // Export PDF button
          OutlinedButton.icon(
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('PDF', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
  
  /// Get verify button color based on state
  Color _getVerifyButtonColor() {
    switch (_cardState) {
      case _EvidenceCardState.verified:
        return ForensicTheme.obsidianEmerald;
      case _EvidenceCardState.error:
        return ForensicTheme.atomicRed;
      default:
        return ForensicTheme.neonCyan;
    }
  }
  
  /// Abbreviate hash for display
  String _abbreviateHash(String hash) {
    if (hash.length <= 16) return hash;
    return '${hash.substring(0, 8)}...${hash.substring(hash.length - 8)}';
  }
}

// =====================================================
// CUSTOM PAINTER: LASER SCAN EFFECT
// =====================================================

/// Laser Scan Painter
/// 
/// Draws a cyan laser line that moves from top to bottom
/// 
/// Forensic UX Note: This provides visual feedback during
/// hash verification, creating a "scanning ritual" experience
class _LaserScanPainter extends CustomPainter {
  /// Scan position (0.0 = top, 1.0 = bottom)
  final double scanPosition;
  
  _LaserScanPainter({required this.scanPosition});

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate laser line Y position
    final laserY = size.height * scanPosition;
    
    // Draw laser line
    final laserPaint = Paint()
      // FIXED: Replaced withOpacity with withValues
      ..color = ForensicTheme.neonCyan.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(0, laserY),
      Offset(size.width, laserY),
      laserPaint,
    );
    
    // Draw glow effect
    final glowPaint = Paint()
      // FIXED: Replaced withOpacity with withValues
      ..color = ForensicTheme.neonCyan.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    canvas.drawLine(
      Offset(0, laserY),
      Offset(size.width, laserY),
      glowPaint,
    );
    
    // Draw scan head indicator
    final scanHeadPaint = Paint()
      ..color = ForensicTheme.neonCyan
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size.width / 2, laserY),
      4.0,
      scanHeadPaint,
    );
  }

  @override
  bool shouldRepaint(_LaserScanPainter oldDelegate) {
    return oldDelegate.scanPosition != scanPosition;
  }
}