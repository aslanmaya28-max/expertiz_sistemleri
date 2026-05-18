import 'package:flutter/material.dart';
import '../../core/constants/yerimebak_colors.dart';

/// Neon Onay Mührü
/// 
/// RaporDetaySayfasi ve AI Oto-Analiz ekranının sağ üst köşesine,
/// parlayan turkuaz-neon renklerde 'YERİMEBAK AI ONAYLIDIR' ibaresini
/// içeren dairesel bir siber mühür (Badge).
/// 
/// Bu mühür, araç 'Kritik Risk' taşıyorsa (Şasi/Podye temizse) görünür.
class NeonApprovalBadge extends StatefulWidget {
  /// Araç kritik risk taşıyor mu? (Şasi/Podye temizse)
  final bool hasCriticalRisk;

  /// Animasyon süresi (varsayılan: 2 saniye)
  final Duration animationDuration;

  const NeonApprovalBadge({
    super.key,
    this.hasCriticalRisk = false,
    this.animationDuration = const Duration(seconds: 2),
  });

  @override
  State<NeonApprovalBadge> createState() => _NeonApprovalBadgeState();
}

class _NeonApprovalBadgeState extends State<NeonApprovalBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulse animasyonu (parlama)
    _pulseController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    )..repeat(reverse: true);
    
    // Glow animasyonu (parıltı)
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Kritik risk yoksa badge'i gösterme
    if (!widget.hasCriticalRisk) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            final scale = _pulseAnimation.value;
            final glowOpacity = _glowAnimation.value;
            
            return Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      YerimeBakColors.cyberNeonTurquoise.withValues(alpha: glowOpacity),
                      YerimeBakColors.cyberNeonPurple.withValues(alpha: glowOpacity * 0.5),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                  boxShadow: [
                    // İç glow
                    BoxShadow(
                      color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: glowOpacity * 0.8),
                      blurRadius: 20 * glowOpacity,
                      spreadRadius: 5 * glowOpacity,
                    ),
                    // Dış glow
                    BoxShadow(
                      color: YerimeBakColors.cyberNeonPurple.withValues(alpha: glowOpacity * 0.6),
                      blurRadius: 30 * glowOpacity,
                      spreadRadius: 10 * glowOpacity,
                    ),
                  ],
                ),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        YerimeBakColors.cyberNeonTurquoise,
                        YerimeBakColors.cyberNeonPurple,
                      ],
                      stops: const [0.3, 0.7],
                    ),
                    border: Border.all(
                      color: YerimeBakColors.cyberNeonTurquoise,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // AI ikonu
                        Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        // Metin
                        Text(
                          'YERİMEBAK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'AI ONAYLIDIR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
