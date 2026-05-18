import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/yerimebak_colors.dart';

/// Neon Smart Gauge - Displays market radar price analysis with animated neon arc
class NeonSmartGauge extends StatefulWidget {
  final double fairValue;
  final double adjustmentPercentage;
  final bool isAnalyzing;

  const NeonSmartGauge({
    super.key,
    required this.fairValue,
    required this.adjustmentPercentage,
    this.isAnalyzing = false,
  });

  @override
  State<NeonSmartGauge> createState() => _NeonSmartGaugeState();
}

class _NeonSmartGaugeState extends State<NeonSmartGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: widget.adjustmentPercentage).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    if (!widget.isAnalyzing) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(NeonSmartGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAnalyzing && !widget.isAnalyzing) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            YerimeBakColors.cyberDarkPurple.withValues(alpha: 0.8),
            YerimeBakColors.cyberDarkBlue.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: YerimeBakColors.cyberNeonTurquoise,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'Fiyat Pusulası',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: YerimeBakColors.cyberNeonTurquoise,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (widget.isAnalyzing)
              _buildAnalyzingAnimation()
            else
              _buildGauge(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzingAnimation() {
    return Column(
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomPaint(
                painter: _AnalyzingGaugePainter(
                  animation: _animationController.value,
                  color: YerimeBakColors.cyberNeonTurquoise,
                ),
                child: child,
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: _textAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _textAnimation.value,
              child: Text(
                'Fiyat Analizi Yapılıyor...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: YerimeBakColors.cyberNeonTurquoise,
                  letterSpacing: 1.2,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGauge() {
    return Column(
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                painter: _NeonGaugePainter(
                  value: _animation.value,
                  color: _getGaugeColor(_animation.value),
                ),
                child: child,
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: _textAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _textAnimation.value,
              child: Column(
                children: [
                  Text(
                    '${widget.fairValue.toStringAsFixed(0)} TL',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getGaugeColor(widget.adjustmentPercentage).withValues(alpha: 0.3),
                          _getGaugeColor(widget.adjustmentPercentage).withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getGaugeColor(widget.adjustmentPercentage),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '${widget.adjustmentPercentage > 0 ? '+' : ''}${widget.adjustmentPercentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getGaugeColor(widget.adjustmentPercentage),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Color _getGaugeColor(double value) {
    if (value > 10) {
      return YerimeBakColors.cyberNeonTurquoise;
    } else if (value > -10) {
      return YerimeBakColors.cyberNeonPurple;
    } else {
      return YerimeBakColors.cyberNeonMagenta;
    }
  }
}

/// Neon Gauge Painter - Draws the gauge arc with neon glow
class _NeonGaugePainter extends CustomPainter {
  final double value;
  final Color color;

  _NeonGaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Background arc
    final backgroundPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      backgroundPaint,
    );

    // Value arc
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final sweepAngle = (value / 100) * math.pi * 1.5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      sweepAngle,
      false,
      valuePaint,
    );

    // Inner glow arc
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      sweepAngle,
      false,
      innerPaint,
    );

    // Center indicator
    final indicatorPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final indicatorAngle = math.pi * 0.75 + sweepAngle;
    final indicatorX = center.dx + radius * math.cos(indicatorAngle);
    final indicatorY = center.dy + radius * math.sin(indicatorAngle);

    canvas.drawCircle(
      Offset(indicatorX, indicatorY),
      12,
      indicatorPaint,
    );
  }

  @override
  bool shouldRepaint(_NeonGaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}

/// Analyzing Gauge Painter - Draws animated scanning arc
class _AnalyzingGaugePainter extends CustomPainter {
  final double animation;
  final Color color;

  _AnalyzingGaugePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Background arc
    final backgroundPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      backgroundPaint,
    );

    // Scanning arc
    final scanPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final scanAngle = math.pi * 0.75 + (animation * math.pi * 1.5);
    final scanSweep = math.pi * 0.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      scanAngle,
      scanSweep,
      false,
      scanPaint,
    );

    // Inner glow arc
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      scanAngle,
      scanSweep,
      false,
      innerPaint,
    );
  }

  @override
  bool shouldRepaint(_AnalyzingGaugePainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.color != color;
  }
}
