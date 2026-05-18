import 'package:flutter/material.dart';
import '../../core/theme/futuristic_theme.dart';

/// Siber Scanner Animasyonu
/// Rapor yükleme sırasında gösterilen lazer tarayıcı efekti
class SiberScannerAnimation extends StatefulWidget {
  final String statusText;
  final double progress;
  final VoidCallback? onComplete;

  const SiberScannerAnimation({
    super.key,
    this.statusText = 'Rapor Verileri Okunuyor...',
    this.progress = 0.0,
    this.onComplete,
  });

  @override
  State<SiberScannerAnimation> createState() => _SiberScannerAnimationState();
}

class _SiberScannerAnimationState extends State<SiberScannerAnimation>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Scan animation - yukarıdan aşağıya
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _scanAnimation = Tween<double>(begin: -0.2, end: 1.2).animate(
      CurvedAnimation(
        parent: _scanController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Pulse animation - neon glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    
    _scanController.repeat();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: FuturisticTheme.bgSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: FuturisticTheme.neon.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Grid Background
          _buildGridBackground(),
          
          // Scanner Line
          AnimatedBuilder(
            animation: _scanAnimation,
            builder: (context, child) {
              return Positioned(
                top: _scanAnimation.value * 300,
                left: 0,
                right: 0,
                child: _buildScannerLine(),
              );
            },
          ),
          
          // Center Content
          Center(
            child: _buildCenterContent(),
          ),
          
          // Corner Decorations
          _buildCornerDecorations(),
        ],
      ),
    );
  }

  Widget _buildGridBackground() {
    return CustomPaint(
      size: const Size(double.infinity, 300),
      painter: _GridPainter(),
    );
  }

  Widget _buildScannerLine() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          height: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                FuturisticTheme.neon.withValues(alpha: _pulseAnimation.value),
                FuturisticTheme.neon.withValues(alpha: _pulseAnimation.value * 0.5),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: FuturisticTheme.neon.withValues(alpha: _pulseAnimation.value * 0.8),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCenterContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated Icon
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      FuturisticTheme.neon.withValues(alpha: 0.2),
                      FuturisticTheme.neon.withValues(alpha: 0.1),
                    ],
                  ),
                  border: Border.all(
                    color: FuturisticTheme.neon.withValues(alpha: _pulseAnimation.value),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.scanner,
                  size: 40,
                  color: FuturisticTheme.neon,
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 20),
        
        // Status Text
        Text(
          widget.statusText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 10),
        
        // Progress Bar
        SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            value: widget.progress,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(FuturisticTheme.neon),
            minHeight: 4,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Progress Percentage
        Text(
          '${(widget.progress * 100).toInt()}%',
          style: TextStyle(
            fontSize: 14,
            color: FuturisticTheme.neon,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCornerDecorations() {
    return const Stack(
      children: [
        // Top Left
        Positioned(
          top: 10,
          left: 10,
          child: _CornerDecoration(position: 'top-left'),
        ),
        // Top Right
        Positioned(
          top: 10,
          right: 10,
          child: _CornerDecoration(position: 'top-right'),
        ),
        // Bottom Left
        Positioned(
          bottom: 10,
          left: 10,
          child: _CornerDecoration(position: 'bottom-left'),
        ),
        // Bottom Right
        Positioned(
          bottom: 10,
          right: 10,
          child: _CornerDecoration(position: 'bottom-right'),
        ),
      ],
    );
  }
}

/// Corner Decoration Widget
class _CornerDecoration extends StatelessWidget {
  final String position;

  const _CornerDecoration({required this.position});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border.all(
          color: FuturisticTheme.neon.withValues(alpha: 0.6),
          width: 2,
        ),
      ),
      child: _buildCornerLines(),
    );
  }

  Widget _buildCornerLines() {
    switch (position) {
      case 'top-left':
        return const CustomPaint(
          size: Size(30, 30),
          painter: _CornerLinePainter(position: 'top-left'),
        );
      case 'top-right':
        return const CustomPaint(
          size: Size(30, 30),
          painter: _CornerLinePainter(position: 'top-right'),
        );
      case 'bottom-left':
        return const CustomPaint(
          size: Size(30, 30),
          painter: _CornerLinePainter(position: 'bottom-left'),
        );
      case 'bottom-right':
        return const CustomPaint(
          size: Size(30, 30),
          painter: _CornerLinePainter(position: 'bottom-right'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Grid Background Painter
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FuturisticTheme.neon.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    // Draw vertical lines
    for (double x = 0; x <= size.width; x += 20) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (double y = 0; y <= size.height; y += 20) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Corner Line Painter
class _CornerLinePainter extends CustomPainter {
  final String position;

  const _CornerLinePainter({required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FuturisticTheme.neon.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    switch (position) {
      case 'top-left':
        canvas.drawLine(const Offset(0, 0), const Offset(15, 0), paint);
        canvas.drawLine(const Offset(0, 0), const Offset(0, 15), paint);
        break;
      case 'top-right':
        canvas.drawLine(const Offset(15, 0), const Offset(30, 0), paint);
        canvas.drawLine(const Offset(30, 0), const Offset(30, 15), paint);
        break;
      case 'bottom-left':
        canvas.drawLine(const Offset(0, 30), const Offset(15, 30), paint);
        canvas.drawLine(const Offset(0, 15), const Offset(0, 30), paint);
        break;
      case 'bottom-right':
        canvas.drawLine(const Offset(15, 30), const Offset(30, 30), paint);
        canvas.drawLine(const Offset(30, 15), const Offset(30, 30), paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Transformation Effect Widget
/// Eski raporun yeni siber şablona dönüştüğü animasyon
class TransformationEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback? onComplete;

  const TransformationEffect({
    super.key,
    required this.child,
    this.onComplete,
  });

  @override
  State<TransformationEffect> createState() => _TransformationEffectState();
}

class _TransformationEffectState extends State<TransformationEffect>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );
    
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );
    
    _controller.forward();
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: FuturisticTheme.neon.withValues(alpha: _glowAnimation.value * 0.3),
                blurRadius: 30 * _glowAnimation.value,
                spreadRadius: 10 * _glowAnimation.value,
              ),
            ],
          ),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// Seal Stamp Animation Widget
/// "YerimeBak AI Tarafından Doğrulandı" hologramı
class SealStampAnimation extends StatefulWidget {
  final bool isActive;

  const SealStampAnimation({
    super.key,
    this.isActive = true,
  });

  @override
  State<SealStampAnimation> createState() => _SealStampAnimationState();
}

class _SealStampAnimationState extends State<SealStampAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _scaleAnimation = Tween<double>(begin: 3.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );
    
    _rotationAnimation = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );
    
    if (widget.isActive) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(SealStampAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: _buildSeal(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeal() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            FuturisticTheme.neon.withValues(alpha: 0.3),
            FuturisticTheme.neon.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: FuturisticTheme.neon.withValues(alpha: 0.8),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: FuturisticTheme.neon.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified,
            size: 40,
            color: FuturisticTheme.neon,
          ),
          SizedBox(height: 4),
          Text(
            'AI',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: FuturisticTheme.neon,
              letterSpacing: 2.0,
            ),
          ),
          Text(
            'DOĞRULANDI',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
