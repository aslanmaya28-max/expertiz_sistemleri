import 'package:flutter/material.dart';
import '../../core/constants/yerimebak_colors.dart';
import 'how_it_works_animation.dart';

/// Individual Animation Step Widget
class AnimationStep extends StatelessWidget {
  final AnimationStepData data;
  final int stepNumber;
  final int totalSteps;

  const AnimationStep({
    super.key,
    required this.data,
    required this.stepNumber,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon Container
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                data.iconColor.withValues(alpha: 0.3),
                data.iconColor.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: data.iconColor.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: data.iconColor.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Icon(
            data.icon,
            size: 48,
            color: data.iconColor,
          ),
        ),
        const SizedBox(height: 24),
        // Step Number
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                YerimeBakColors.cyberNeonTurquoise,
                YerimeBakColors.cyberNeonPurple,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: YerimeBakColors.cyberNeonTurquoise
                    .withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Text(
            'Adım $stepNumber',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Title
        Text(
          data.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        // Description
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            data.description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
