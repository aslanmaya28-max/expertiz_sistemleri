import 'package:flutter/material.dart';
import '../../core/constants/yerimebak_colors.dart';
import 'animation_step.dart';

/// "Nasıl Çalışır?" Animation Widget
/// Shows 4-step animation explaining the system
class HowItWorksAnimation extends StatefulWidget {
  final VoidCallback onFinished;

  const HowItWorksAnimation({
    super.key,
    required this.onFinished,
  });

  @override
  State<HowItWorksAnimation> createState() => _HowItWorksAnimationState();
}

class _HowItWorksAnimationState extends State<HowItWorksAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  int _currentStep = 0;
  bool _isPlaying = true;

  // Animation steps data
  final List<AnimationStepData> _steps = const [
    AnimationStepData(
      icon: Icons.person_add,
      title: 'Müşteri Talep Oluşturur',
      description: 'Araç bilgilerini girip talep oluşturur',
      iconColor: YerimeBakColors.cyberNeonTurquoise,
    ),
    AnimationStepData(
      icon: Icons.psychology,
      title: 'AI Analiz Eder',
      description: 'AI motoru talebi analiz eder ve personel atar',
      iconColor: YerimeBakColors.cyberNeonPurple,
    ),
    AnimationStepData(
      icon: Icons.assignment_turned_in,
      title: 'Personel Raporu Tamamlar',
      description: 'Atanan personel ekspertiz raporunu hazırlar',
      iconColor: YerimeBakColors.cyberNeonMagenta,
    ),
    AnimationStepData(
      icon: Icons.check_circle,
      title: 'Admin Onaylar',
      description: 'Admin raporu onaylar ve finansal işlemler yapılır',
      iconColor: YerimeBakColors.cyberNeonTurquoise,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
      ),
    );

    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    for (int i = 0; i < _steps.length; i++) {
      if (!mounted) return;
      setState(() {
        _currentStep = i;
      });
      await Future.delayed(const Duration(milliseconds: 3000));
    }

    // Animation finished - transition to registration
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      widget.onFinished();
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _controller.forward(from: 0);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              YerimeBakColors.cyberDarkPurple.withValues(alpha: 0.95),
              YerimeBakColors.cyberDarkBlue.withValues(alpha: 0.95),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Nasıl Çalışır?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                // Play/Pause Button
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: YerimeBakColors.cyberNeonTurquoise,
                  ),
                  onPressed: _togglePlayPause,
                ),
                // Close Button
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Progress Indicator
            Row(
              children: List.generate(_steps.length, (index) {
                final isActive = index == _currentStep;
                final isCompleted = index < _currentStep;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: isActive || isCompleted
                          ? const LinearGradient(
                              colors: [
                                YerimeBakColors.cyberNeonTurquoise,
                                YerimeBakColors.cyberNeonPurple,
                              ],
                            )
                          : null,
                      color: isActive || isCompleted
                          ? null
                          : YerimeBakColors.cyberNeonTurquoise
                              .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: YerimeBakColors.cyberNeonTurquoise
                                    .withValues(alpha: 0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            // Animation Step
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: AnimationStep(
                      data: _steps[_currentStep],
                      stepNumber: _currentStep + 1,
                      totalSteps: _steps.length,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            // Step Counter
            Text(
              '${_currentStep + 1} / ${_steps.length}',
              style: TextStyle(
                fontSize: 14,
                color: YerimeBakColors.cyberNeonTurquoise
                    .withValues(alpha: 0.7),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 24),
            // Close Button
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: YerimeBakColors.cyberNeonTurquoise,
                side: BorderSide(
                  color: YerimeBakColors.cyberNeonTurquoise,
                  width: 2,
                ),
              ),
              child: const Text(
                'Kapat',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animation Step Data Model
class AnimationStepData {
  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;

  const AnimationStepData({
    required this.icon,
    required this.title,
    required this.description,
    required this.iconColor,
  });
}
