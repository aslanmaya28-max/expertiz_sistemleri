import 'package:flutter/material.dart';

/// StatusChip - Enterprise Grade Task Status Widget
/// 
/// STATUS VALUES:
/// - Beklemede (Pending) - Gray/Blue
/// - Atandı (Assigned) - Orange
/// - İşlemde (In Progress) - Yellow
/// - Tamamlandı (Completed) - Green
/// - Reddedildi (Rejected) - Red
class StatusChip extends StatelessWidget {
  final String durum;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const StatusChip({
    super.key,
    required this.durum,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    final (color, backgroundColor, icon) = _getStatusInfo();

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 4, color: color),
          SizedBox(width: 6),
          Text(
            durum,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, IconData) _getStatusInfo() {
    switch (durum.toLowerCase()) {
      case 'beklemede':
        return (Colors.blue, Colors.blue.withValues(alpha: 0.1), Icons.pending);
      case 'atanmış':
      case 'atandı':
        return (Colors.orange, Colors.orange.withValues(alpha: 0.1), Icons.person_add);
      case 'işlemde':
        return (Colors.amber, Colors.amber.withValues(alpha: 0.1), Icons.autorenew);
      case 'tamamlandı':
        return (Colors.green, Colors.green.withValues(alpha: 0.1), Icons.check_circle);
      case 'reddedildi':
        return (Colors.red, Colors.red.withValues(alpha: 0.1), Icons.cancel);
      case 'incelemede':
        return (Colors.cyan, Colors.cyan.withValues(alpha: 0.1), Icons.search);
      case 'gönderim bekliyor':
        return (Colors.purple, Colors.purple.withValues(alpha: 0.1), Icons.send);
      case 'gönderildi':
        return (Colors.teal, Colors.teal.withValues(alpha: 0.1), Icons.done_all);
      default:
        return (Colors.grey, Colors.grey.withValues(alpha: 0.1), Icons.help);
    }
  }

  /// Get status color only
  static Color getStatusColor(String durum) {
    switch (durum.toLowerCase()) {
      case 'beklemede':
        return Colors.blue;
      case 'atanmış':
      case 'atandı':
        return Colors.orange;
      case 'işlemde':
        return Colors.amber;
      case 'tamamlandı':
        return Colors.green;
      case 'reddedildi':
        return Colors.red;
      case 'incelemede':
        return Colors.cyan;
      case 'gönderim bekliyor':
        return Colors.purple;
      case 'gönderildi':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}
