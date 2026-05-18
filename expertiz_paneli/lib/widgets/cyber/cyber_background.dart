import 'package:flutter/material.dart';

/// Cyber Background Widget - Static Deep Space Gradient
class CyberBackground extends StatelessWidget {
  final Widget child;
  final bool showParticles; // Kept for API compatibility, but ignored

  const CyberBackground({
    super.key,
    required this.child,
    this.showParticles = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            Color(0xFF1A1F2B), // Lighter Deep Space Center
            Color(0xFF0A0E14), // Dark Deep Space Outer
          ],
          stops: [0.0, 1.0],
        ),
      ),
      child: child,
    );
  }
}



