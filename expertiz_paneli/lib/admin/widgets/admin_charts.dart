import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/ai/ai_analiz_sonucu_model.dart';

/// Admin Dashboard Grafikleri Widget'ı
/// Dashboard üzerindeki grafikleri gösteren widget
class AdminCharts extends StatelessWidget {
  final bool isDarkMode;
  final AIAnalizSonucu? aiAnalizSonucu;

  const AdminCharts({
    super.key,
    required this.isDarkMode,
    this.aiAnalizSonucu,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, color: Colors.blue),
                const SizedBox(width: 10),
                Text(
                  'Grafikler ve Analiz',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // İki grafik yan yana
            Row(
              children: [
                // Alış vs Satış Fiyatı (Kar Marjı) Grafiği
                Expanded(
                  child: _buildKarMarjiGrafigi(isDarkMode),
                ),
                const SizedBox(width: 12),

                // 12 Aylık Enflasyon Projeksiyonu Grafiği
                Expanded(
                  child: _buildEnflasyonGrafigi(isDarkMode),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Grafik Detayları
            _buildGrafikDetaylari(isDarkMode),
            const SizedBox(height: 12),

            // Raporlara Tıklandığında Detaylı Yorum Açılacak
            Center(
              child: TextButton.icon(
                onPressed: () {
                  // Detaylı yorum sayfasına git
                },
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Detaylı AI Yorumlarını Gör'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Alış vs Satış Fiyatı (Kar Marjı) Grafiği
  Widget _buildKarMarjiGrafigi(bool isDarkMode) {
    // AI analiz sonucu varsa, gerçek veriyi kullan
    // Yoksa, mock veri kullan
    bool veriVarMi = aiAnalizSonucu != null && 
                    aiAnalizSonucu!.tamamlandiMi &&
                    aiAnalizSonucu!.raporOzeti.tahminiDeger > 0;
    
    // Alış fiyatları (tahmini değer - %15 kar marjı)
    List<FlSpot> alisFiyatlari = veriVarMi
        ? [
            FlSpot(0, aiAnalizSonucu!.raporOzeti.tahminiDeger * 0.85),
            FlSpot(1, aiAnalizSonucu!.raporOzeti.tahminiDeger * 0.87),
            FlSpot(2, aiAnalizSonucu!.raporOzeti.tahminiDeger * 0.88),
            FlSpot(3, aiAnalizSonucu!.raporOzeti.tahminiDeger * 0.90),
            FlSpot(4, aiAnalizSonucu!.raporOzeti.tahminiDeger * 0.92),
            FlSpot(5, aiAnalizSonucu!.raporOzeti.tahminiDeger * 0.89),
          ]
        : const [
            FlSpot(0, 45),
            FlSpot(1, 52),
            FlSpot(2, 48),
            FlSpot(3, 55),
            FlSpot(4, 60),
            FlSpot(5, 58),
          ];
    
    // Satış fiyatları (tahmini değer)
    List<FlSpot> satisFiyatlari = veriVarMi
        ? [
            FlSpot(0, aiAnalizSonucu!.raporOzeti.tahminiDeger),
            FlSpot(1, aiAnalizSonucu!.raporOzeti.tahminiDeger * 1.03),
            FlSpot(2, aiAnalizSonucu!.raporOzeti.tahminiDeger * 1.05),
            FlSpot(3, aiAnalizSonucu!.raporOzeti.tahminiDeger * 1.08),
            FlSpot(4, aiAnalizSonucu!.raporOzeti.tahminiDeger * 1.10),
            FlSpot(5, aiAnalizSonucu!.raporOzeti.tahminiDeger * 1.12),
          ]
        : const [
            FlSpot(0, 55),
            FlSpot(1, 62),
            FlSpot(2, 58),
            FlSpot(3, 68),
            FlSpot(4, 75),
            FlSpot(5, 72),
          ];
    
    // Y ekseni maksimum değerini hesapla
    double maxY = veriVarMi 
        ? (satisFiyatlari.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.1).ceilToDouble()
        : 100;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alış vs Satış Fiyatı',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.grey[800],
            ),
          ),
          Text(
            'Kar Marjı Analizi',
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          if (!veriVarMi)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Veri Bekleniyor',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        const months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz'];
                        if (value.toInt() >= 0 && value.toInt() < months.length) {
                          return Text(
                            months[value.toInt()],
                            style: TextStyle(
                              fontSize: 10,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}K',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        );
                      },
                      interval: 20,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                minX: 0,
                maxX: 5,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  // Alış Fiyatı
                  LineChartBarData(
                    spots: alisFiyatlari,
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                  // Satış Fiyatı
                  LineChartBarData(
                    spots: satisFiyatlari,
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 12 Aylık Enflasyon Projeksiyonu Grafiği
  Widget _buildEnflasyonGrafigi(bool isDarkMode) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enflasyon Projeksiyonu',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.grey[800],
            ),
          ),
          Text(
            '12 Aylık Tahmin',
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        const months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
                        if (value.toInt() >= 0 && value.toInt() < months.length) {
                          return Text(
                            months[value.toInt()],
                            style: TextStyle(
                              fontSize: 10,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '%${value.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        );
                      },
                      interval: 10,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                minX: 0,
                maxX: 11,
                minY: 40,
                maxY: 80,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 45),
                      FlSpot(1, 48),
                      FlSpot(2, 52),
                      FlSpot(3, 55),
                      FlSpot(4, 58),
                      FlSpot(5, 62),
                      FlSpot(6, 65),
                      FlSpot(7, 68),
                      FlSpot(8, 70),
                      FlSpot(9, 72),
                      FlSpot(10, 74),
                      FlSpot(11, 76),
                    ],
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Grafik Detayları
  Widget _buildGrafikDetaylari(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                'Ortalama Kar Marjı',
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '%18.5',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 40,
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
          Column(
            children: [
              Text(
                'Enflasyon Tahmini',
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '%76',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 40,
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
          Column(
            children: [
              Text(
                'Toplam İşlem',
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '156',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
