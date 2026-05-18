import 'package:flutter/material.dart';
import '../../core/theme/futuristic_theme.dart';

/// Cyber Error Widget
/// Siber temalı hata gösterimi
class CyberErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? message;

  const CyberErrorWidget({
    super.key,
    this.onRetry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FuturisticTheme.bgSecondary.withValues(alpha: 0.3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.error_outline,
                size: 50,
                color: Colors.red.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            
            // Error Message
            Text(
              message ?? 'Bir hata oluştu',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Veriler yüklenirken bir sorun oluştu',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            // Retry Button
            if (onRetry != null)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      FuturisticTheme.neon.withValues(alpha: 0.2),
                      FuturisticTheme.neon.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FuturisticTheme.neon.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onRetry,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh,
                            color: FuturisticTheme.neon,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tekrar Dene',
                            style: TextStyle(
                              color: FuturisticTheme.neon,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
