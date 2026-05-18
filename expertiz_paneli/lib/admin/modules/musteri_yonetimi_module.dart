/// MÜŞTERİ YÖNETİMİ MODULE
/// 
/// Müşteri yönetim ekranı
library;

import 'package:flutter/material.dart';

/// Müşteri Yönetimi Module
class MusteriYonetimiModule extends StatelessWidget {
  const MusteriYonetimiModule({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people,
            size: 64,
            color: isDarkMode ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            'Müşteri Yönetimi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Müşteri verileri Supabase\'den çekilecek',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}