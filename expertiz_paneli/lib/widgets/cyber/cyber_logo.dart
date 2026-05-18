import 'package:flutter/material.dart';
import '../../core/constants/yerimebak_colors.dart';

/// Cyber-Themed Logo with Pulsing Neon Glow
class CyberLogo extends StatefulWidget {
  final double size;
  final bool showSubtitle;

  const CyberLogo({
    super.key,
    this.size = 80,
    this.showSubtitle = true,
  });

  @override
  State<CyberLogo> createState() => _CyberLogoState();
}

class _CyberLogoState extends State<CyberLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Column(
          children: [
            // Logo Icon with Circuit Pattern
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    YerimeBakColors.cyberNeonTurquoise,
                    YerimeBakColors.cyberNeonPurple,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: YerimeBakColors.cyberNeonTurquoise
                        .withValues(alpha: 0.5 * _pulseAnimation.value),
                    blurRadius: 30 * _pulseAnimation.value,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: YerimeBakColors.cyberNeonPurple
                        .withValues(alpha: 0.3 * _pulseAnimation.value),
                    blurRadius: 20 * _pulseAnimation.value,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Circuit Lines
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CircuitLinesPainter(),
                    ),
                  ),
                  // Shield Icon
                  Center(
                    child: Icon(
                      Icons.security,
                      size: widget.size * 0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Title Text with Neon Glow
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  YerimeBakColors.cyberNeonTurquoise,
                  YerimeBakColors.cyberNeonPurple,
                ],
              ).createShader(bounds),
              child: Text(
                'YERIMEBAK',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      color: YerimeBakColors.cyberNeonTurquoise
                          .withValues(alpha: 0.8),
                      blurRadius: 15,
                    ),
                    Shadow(
                      color: YerimeBakColors.cyberNeonPurple
                          .withValues(alpha: 0.6),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
            if (widget.showSubtitle) ...[
              const SizedBox(height: 8),
              Text(
                'Güvenli Ekspertiz Sistemi',
                style: TextStyle(
                  fontSize: 14,
                  color: YerimeBakColors.cyberNeonTurquoise
                      .withValues(alpha: 0.8),
                  letterSpacing: 1,
                  shadows: [
                    Shadow(
                      color: YerimeBakColors.cyberNeonTurquoise
                          .withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Circuit Lines Painter for Logo
class _CircuitLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    // Draw circuit lines
    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.1);
    path.lineTo(size.width * 0.4, size.height * 0.1);
    path.lineTo(size.width * 0.4, size.height * 0.3);
    path.lineTo(size.width * 0.2, size.height * 0.3);
    path.close();

    path.moveTo(size.width * 0.6, size.height * 0.7);
    path.lineTo(size.width * 0.8, size.height * 0.7);
    path.lineTo(size.width * 0.8, size.height * 0.9);
    path.lineTo(size.width * 0.6, size.height * 0.9);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
