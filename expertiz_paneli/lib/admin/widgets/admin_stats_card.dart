import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';

/// Admin Dashboard İstatistik Kartı Widget'ı
/// Dashboard üzerindeki istatistikleri gösteren kompakt kartlar
class AdminStatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDarkMode;

  const AdminStatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDarkMode ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.white.withValues(alpha: 0.9), // Dark text on glass might be hard to read if background is dark. 
              // Since background is Deep Space (Dark), standard text should be White.
              // I will force white text since the background is dark now.
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.grey[400] : Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
