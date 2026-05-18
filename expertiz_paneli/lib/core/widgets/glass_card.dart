import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/futuristic_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: width,
            height: height,
            padding: padding ?? const EdgeInsets.all(24),
            decoration: BoxDecoration(
            color: FuturisticTheme.loginBgStart.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                width: 1,
                color: FuturisticTheme.accentCyan.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: FuturisticTheme.accentCyan.withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
