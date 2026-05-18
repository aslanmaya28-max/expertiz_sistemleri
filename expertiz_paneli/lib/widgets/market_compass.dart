import 'package:flutter/material.dart';
import 'dart:math' as math;

/// MarketCompass Widget
/// Aracın fiyatını piyasa ortalamasıyla kıyaslayan 'Fiyat Pusulası' (Gauge) gösterir
class MarketCompass extends StatelessWidget {
  final double currentPrice;
  final double marketAveragePrice;
  final String? title;

  const MarketCompass({
    super.key,
    required this.currentPrice,
    required this.marketAveragePrice,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    // Fiyat farkını hesapla
    final priceDifference = currentPrice - marketAveragePrice;
    final percentageDifference = (priceDifference / marketAveragePrice) * 100;
    
    // Renk ve durum belirle
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (percentageDifference.abs() < 5) {
      // Piyasa ortalamasına yakın
      statusColor = Colors.green;
      statusText = 'Piyasa Ortalaması';
      statusIcon = Icons.check_circle;
    } else if (percentageDifference > 5) {
      // Piyasa ortalamasının üzerinde
      statusColor = Colors.orange;
      statusText = 'Piyasa Üzerinde';
      statusIcon = Icons.trending_up;
    } else {
      // Piyasa ortalamasının altında
      statusColor = Colors.red;
      statusText = 'Piyasa Altında';
      statusIcon = Icons.trending_down;
    }

    // Gauge değerini hesapla (0-100 arası)
    final gaugeValue = ((currentPrice / marketAveragePrice) * 50).clamp(0, 100).toDouble();

    return Card(
      elevation: 4,
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                // Fiyat Pusulası (Gauge)
                Expanded(
                  child: Column(
                    children: [
                      // Custom Gauge
                      SizedBox(
                        height: 150,
                        child: CustomPaint(
                          painter: _GaugePainter(
                            value: gaugeValue,
                            isDarkMode: isDarkMode,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '%${percentageDifference.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 14,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Fiyat Detayları
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPriceDetail(
                        'Mevcut Fiyat',
                        currentPrice,
                        Colors.blue,
                        isDarkMode,
                      ),
                      const SizedBox(height: 12),
                      _buildPriceDetail(
                        'Piyasa Ortalaması',
                        marketAveragePrice,
                        Colors.green,
                        isDarkMode,
                      ),
                      const SizedBox(height: 12),
                      _buildPriceDetail(
                        'Fark',
                        priceDifference.abs(),
                        statusColor,
                        isDarkMode,
                        isDifference: true,
                        isPositive: priceDifference >= 0,
                      ),
                      const SizedBox(height: 16),
                      // Durum İkonu
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor),
                        ),
                        child: Row(
                          children: [
                            Icon(statusIcon, color: statusColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceDetail(
    String label,
    double value,
    Color color,
    bool isDarkMode, {
    bool isDifference = false,
    bool isPositive = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${value.toStringAsFixed(0)} TL',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (isDifference) ...[
              const SizedBox(width: 8),
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: color,
                size: 20,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Custom Gauge Painter
class _GaugePainter extends CustomPainter {
  final double value;
  final bool isDarkMode;

  _GaugePainter({
    required this.value,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.8);
    final radius = size.width * 0.4;

    // Arka plan yayı
    final backgroundPaint = Paint()
      ..color = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14, // 180 derece
      0,
      false,
      backgroundPaint,
    );

    // Renkli yay (yeşil - sarı - kırmızı)
    final greenPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final yellowPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final redPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    // Yeşil bölüm (0-50)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14,
      1.57,
      false,
      greenPaint,
    );

    // Sarı bölüm (50-75)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      4.71,
      0.785,
      false,
      yellowPaint,
    );

    // Kırmızı bölüm (75-100)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      5.495,
      0.785,
      false,
      redPaint,
    );

    // İbre (needle)
    final angle = math.pi + (value / 100) * math.pi;
    final needlePaint = Paint()
      ..color = isDarkMode ? Colors.white : Colors.black87
      ..style = PaintingStyle.fill;

    final needlePath = Path();
    needlePath.moveTo(center.dx, center.dy);
    needlePath.lineTo(
      center.dx + radius * 0.9 * math.cos(angle - 1.57),
      center.dy + radius * 0.9 * math.sin(angle - 1.57),
    );
    canvas.drawPath(needlePath, needlePaint);

    // Merkez noktası
    final centerPaint = Paint()
      ..color = isDarkMode ? Colors.white : Colors.black87
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 8, centerPaint);
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.isDarkMode != isDarkMode;
  }
}
