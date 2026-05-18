import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/yerimebak_colors.dart';

/// Neon Pulsing Hologram Seal for AI Approval
class NeonHologramSeal extends StatefulWidget {
  final bool isActive;

  const NeonHologramSeal({super.key, this.isActive = true});

  @override
  State<NeonHologramSeal> createState() => _NeonHologramSealState();
}

class _NeonHologramSealState extends State<NeonHologramSeal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(seconds: 4), vsync: this)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 60),
          painter: _HologramSealPainter(
            animationValue: _controller.value,
          ),
        );
      },
    );
  }
}

class _HologramSealPainter extends CustomPainter {
  final double animationValue;

  _HologramSealPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.height / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = LinearGradient(
        colors: [
          YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.8),
          YerimeBakColors.cyberNeonPurple.withValues(alpha: 0.8),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Outer Circle
    canvas.drawCircle(Offset(centerX, centerY), radius, paint);

    // Inner pulsing ring
    final pulseRadius = radius * (0.8 + 0.1 * math.sin(animationValue * 2 * math.pi));
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.5);
    
    canvas.drawCircle(Offset(centerX, centerY), pulseRadius, pulsePaint);

    // Dynamic Scanning Line in background of text
    final scanY = size.height * animationValue;
    final scanPaint = Paint()
      ..shader = LinearGradient(
         colors: [
           Colors.transparent,
           YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
           Colors.transparent
         ],
         stops: const [0.0, 0.5, 1.0],
         begin: Alignment.centerLeft,
         end: Alignment.centerRight // Scanning horizontally across seal
      ).createShader(Rect.fromLTWH(0, scanY, size.width, 10));
    
    // Draw scanning line behind text
    canvas.drawRect(Rect.fromLTWH(0, scanY, size.width, 10), scanPaint);
    
    // Scan effect is subtle behind text
    // We'll draw text manually
    
    // Draw Text "YERİMEBAK AI ONAYLI"
    const textStyle = TextStyle(
      color: YerimeBakColors.cyberNeonTurquoise,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
      fontFamily: 'Inter' // Assuming Inter
    );
    
    final textSpan = TextSpan(
      text: 'YERİMEBAK AI ONAYLI',
      style: textStyle,
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    textPainter.layout(
      minWidth: 0,
      maxWidth: size.width,
    );
    
    final textOffset = Offset(
      centerX - textPainter.width / 2,
      centerY - textPainter.height / 2,
    );
    
    textPainter.paint(canvas, textOffset);
    
    // Add hologram glitch effect lines using deterministic math instead of Random
    // Uses sine wave interference to spuriously generate "glitches"
    final glitchTrigger = math.sin(animationValue * 50 * math.pi); // Fast oscillation
    if (glitchTrigger > 0.95) {
       // Deterministic Y position based on animation value
       final glitchY = (math.cos(animationValue * 30) * 0.5 + 0.5) * size.height;
       
       canvas.drawLine(
         Offset(centerX - 60, glitchY),
         Offset(centerX + 60, glitchY), 
         Paint()..color = YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3)..strokeWidth = 1
       );
    }
  }

  @override
  bool shouldRepaint(covariant _HologramSealPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
