import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/futuristic_theme.dart';

class CyberRadarScan extends StatefulWidget {
  final double size;
  final Color? color;

  const CyberRadarScan({
    super.key,
    this.size = 100,
    this.color,
  });

  @override
  State<CyberRadarScan> createState() => _CyberRadarScanState();
}

class _CyberRadarScanState extends State<CyberRadarScan>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? FuturisticTheme.neon;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _RadarPainter(
                    animationValue: _controller.value,
                    color: color,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "SİBER TARAMA AKTİF",
            style: TextStyle(
              color: color,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.bold
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _RadarPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw concentric circles (Grid)
    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, radius * 0.3, gridPaint);
    canvas.drawCircle(center, radius * 0.6, gridPaint);
    canvas.drawCircle(center, radius * 0.9, gridPaint);
    
    // Crosshairs
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      gridPaint
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      gridPaint
    );

    // 2. Draw rotating sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [
           Colors.transparent,
           color.withValues(alpha: 0.1),
           color.withValues(alpha: 0.5),
        ],
        stops: const [0.0, 0.7, 1.0],
        transform: GradientRotation(animationValue * math.pi * 2 - math.pi / 2)
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);
    
    // 3. Draw Blips (Random appearing dots)
    // We deterministically generate "random" blips based on time to avoid object creation
    final blipTime = (animationValue * 10).toInt();
    if (blipTime % 3 == 0) {
       final blipPaint = Paint()..color = color.withValues(alpha: 0.8)..style = PaintingStyle.fill;
       // Mock blip position
       final angle = animationValue * math.pi * 2;
       final blipX = center.dx + math.cos(angle - 0.5) * radius * 0.7;
       final blipY = center.dy + math.sin(angle - 0.5) * radius * 0.7;
       canvas.drawCircle(Offset(blipX, blipY), 3, blipPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
