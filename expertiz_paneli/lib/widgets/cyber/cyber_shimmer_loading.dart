import 'package:flutter/material.dart';
import '../../core/theme/futuristic_theme.dart';

/// Cyber Shimmer Loading Widget
/// Siber temalı shimmer loading efekti
class CyberShimmerLoading extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const CyberShimmerLoading({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: FuturisticTheme.bgSecondary,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: FuturisticTheme.neon.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: _buildShimmerContent(),
    );
  }

  Widget _buildShimmerContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Base gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    FuturisticTheme.bgSecondary.withValues(alpha: 0.3),
                    FuturisticTheme.bgSecondary.withValues(alpha: 0.1),
                    FuturisticTheme.bgSecondary.withValues(alpha: 0.3),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            // Animated shimmer line
            AnimatedContainer(
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    FuturisticTheme.neon.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
