import 'package:flutter/material.dart';
import '../theme/futuristic_theme.dart';

class NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color? color;
  final double? width;
  final double? height;
  final bool isLoading;

  const NeonButton({
    super.key,
    required this.text,
    this.onTap,
    this.color,
    this.width,
    this.height,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? FuturisticTheme.neon;
    
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: width,
        height: height ?? 50,
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: effectiveColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: effectiveColor.withValues(alpha: 0.4),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(0, 0),
            ),
            BoxShadow(
              color: effectiveColor.withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 5,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Center(
          child: isLoading 
              ? SizedBox(
                  width: 24, 
                  height: 24, 
                  child: CircularProgressIndicator(color: effectiveColor, strokeWidth: 2)
                )
              : Text(
                  text,
                  style: TextStyle(
                    color: effectiveColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    shadows: [
                      Shadow(
                        color: effectiveColor.withValues(alpha: 0.8),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
