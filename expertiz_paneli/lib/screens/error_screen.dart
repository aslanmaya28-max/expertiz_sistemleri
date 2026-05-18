/// ERROR SCREEN
/// 
/// Tüm sistem hataları için merkezi hata ekranı
/// GoRouter ile entegre çalışır
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Error Screen
class ErrorScreen extends StatelessWidget {
  final String error;
  final String? details;

  const ErrorScreen({
    super.key,
    required this.error,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27), // Neon dark blue
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Neon Icon with glow
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 32),
              
              // Neon title
              Text(
                'Bir Hata Oluştu',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.red.withValues(alpha: 0.8),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Error message
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                ),
              ),
              
              // Error details (if any)
              if (details != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F3A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      details!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.orangeAccent,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              
              // Neon back button
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade700],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home),
                  label: const Text('Ana Sayfaya Dön'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}