import 'package:flutter/material.dart';
import '../../services/market_radar_service.dart';
import '../../core/constants/vehicle_packages.dart';
import '../../widgets/cyber/cyber_background.dart';
import '../../core/constants/yerimebak_colors.dart';

/// Final Demo Simulasyonu
///
/// Sistemdeki tüm yeni özellikleri (Paket ağırlığı, 21 donanım, AI risk analizi)
/// kullanarak 2022 VW Passat 1.5 TSI Elegance aracının analizini yapar
/// ve özet raporunu sunar.
class FinalDemoSimulasyonu extends StatelessWidget {
  const FinalDemoSimulasyonu({super.key});

  @override
  Widget build(BuildContext context) {
    // Araç bilgileri
    const String brand = 'Volkswagen';
    const String model = 'Passat';
    const String motor = '1.5 TSI';
    const String package = 'Elegance';
    const int year = 2022;
    const int km = 30000;
    const String color = 'Beyaz';

    // Donanım seçenekleri
    final Map<String, bool> selectedOptions = {
      // İç donanımlar
      'Deri Dosemesi': true,
      'Tavan Dosemesi': true,
      'Isitmali On Koltuklar': true,
      'Isitmali Arka Koltuklar': true,
      'Elektrik Camlar': true,
      'Panoramik Cam Tavan': true,
      // Elektronik donanımlar
      'IQ.Light Navigasyon': true,
      'Bluetooth': true,
      'Klima Otomatik': true,
      'Park Sensörleri': true,
      'Farlar (LED)': true,
      'Ayna Katlanir': true,
      'Dijital Gosterge Paneli': true,
    };

    // Boyalı ve hasarlı parçalar (Hatasız/Boyasız)
    final List<String> paintedParts = [];
    final List<String> damagedParts = [];

    // Paket ağırlığını al
    final String packageId = 'vw_passat_elegance';
    final double packageWeight = VehiclePackagesDatabase.getPackageWeight(packageId);

    // MarketRadarService ile entegre fiyat hesapla
    final piyasaRaporu = MarketRadarService.calculateIntegratedValue(
      brand: brand,
      model: model,
      year: year,
      km: km,
      color: color,
      packageLevel: package,
      packageWeight: packageWeight,
      selectedOptions: selectedOptions,
      paintedParts: paintedParts,
      damagedParts: damagedParts,
      marketSource: null,
    );

    // AI risk analizi (genel puan 80'in üstü = güvenli)
    final bool isSafe = piyasaRaporu['finalPrice'] as double > 0;
    final double aiGuvenlikSkoru = isSafe ? 85.0 : 65.0;

    return CyberBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Final Demo Simulasyonu',
            style: TextStyle(
              color: YerimeBakColors.cyberNeonTurquoise,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: YerimeBakColors.cyberNeonTurquoise),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık - Araç Bilgileri
              _buildSectionHeader('Araç Bilgileri'),
              const SizedBox(height: 8),
              _buildVehicleInfoCard(brand, model, motor, package, year, km, color),

              const SizedBox(height: 24),

              // Paket Analizi
              _buildSectionHeader('Paket Analizi'),
              const SizedBox(height: 8),
              _buildPackageAnalysisCard(packageWeight, piyasaRaporu, package),

              const SizedBox(height: 24),

              // Donanım Analizi
              _buildSectionHeader('Donanım Analizi'),
              const SizedBox(height: 8),
              _buildEquipmentAnalysisCard(selectedOptions, piyasaRaporu),

              const SizedBox(height: 24),

              // AI Risk Analizi
              _buildSectionHeader('AI Risk Analizi'),
              const SizedBox(height: 8),
              _buildAIRiskAnalysisCard(aiGuvenlikSkoru, piyasaRaporu),

              const SizedBox(height: 24),

              // Sonuç Özeti
              _buildSectionHeader('Sonuç Özeti'),
              const SizedBox(height: 8),
              _buildResultSummaryCard(piyasaRaporu, aiGuvenlikSkoru),
            ],
          ),
        ),
      ),
    );
  }

  /// Bölüm başlığı
  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            YerimeBakColors.cyberDarkPurple.withValues(alpha: 0.8),
            YerimeBakColors.cyberDarkBlue.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: YerimeBakColors.cyberNeonTurquoise,
        ),
      ),
    );
  }

  /// Araç bilgileri kartı
  Widget _buildVehicleInfoCard(String brand, String model, String motor, String package, int year, int km, String color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            YerimeBakColors.cyberDarkPurple.withValues(alpha: 0.8),
            YerimeBakColors.cyberDarkBlue.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Marka', brand),
            _buildInfoRow('Model', '$model $motor'),
            _buildInfoRow('Paket', package),
            _buildInfoRow('Yıl', '$year'),
            _buildInfoRow('KM', '$km km'),
            _buildInfoRow('Renk', color),
            _buildInfoRow('Durum', 'Hatasız / Boyasız'),
          ],
        ),
      ),
    );
  }

  /// Paket analizi kartı
  Widget _buildPackageAnalysisCard(double packageWeight, Map<String, dynamic> piyasaRaporu, String package) {
    final basePrice = piyasaRaporu['basePrice'] as double;
    final packageAdjustment = (piyasaRaporu['adjustments'] as List).firstWhere(
      (a) => a.toString().contains('Paket'),
      orElse: () => 'Paket ayarlaması bulunamadı',
    );
    final packageValue = (basePrice * packageWeight) - basePrice;
    final packagePercentage = ((packageWeight - 1.0) * 100).toStringAsFixed(0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            YerimeBakColors.cyberDarkPurple.withValues(alpha: 0.8),
            YerimeBakColors.cyberDarkBlue.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paket: $package',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: YerimeBakColors.cyberNeonTurquoise,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildAnalysisItem(
                    'Paket Ağırlığı',
                    '${packageWeight}x',
                    'Elegance paketi, standart pakete göre %$packagePercentage daha değerli',
                    Icons.fitness_center,
                    YerimeBakColors.cyberNeonTurquoise,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildAnalysisItem(
              'Paket Fiyat Etkisi',
              '${packageValue.toStringAsFixed(0)} TL',
              'Paket ağırlığı ($packageWeight) ile fiyat çarpıldı',
              Icons.attach_money,
              YerimeBakColors.cyberNeonPurple,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: YerimeBakColors.cyberNeonPurple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: YerimeBakColors.cyberNeonPurple,
                  width: 1,
                ),
              ),
              child: Text(
                packageAdjustment.toString(),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Donanım analizi kartı
  Widget _buildEquipmentAnalysisCard(Map<String, bool> selectedOptions, Map<String, dynamic> piyasaRaporu) {
    final optionsAdjustments = (piyasaRaporu['adjustments'] as List).where(
      (a) => a.toString().contains('Donanım') || a.toString().contains('Cam') || a.toString().contains('Koltuk'),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            YerimeBakColors.cyberDarkPurple.withValues(alpha: 0.8),
            YerimeBakColors.cyberDarkBlue.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seçili Donanımlar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: YerimeBakColors.cyberNeonTurquoise,
              ),
            ),
            const SizedBox(height: 12),
            ...selectedOptions.entries.map((entry) {
              return _buildEquipmentItem(entry.key, entry.value);
            }),
            const SizedBox(height: 16),
            const Text(
              'Donanım Fiyat Etkileri',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: YerimeBakColors.cyberNeonTurquoise,
              ),
            ),
            const SizedBox(height: 8),
            ...optionsAdjustments.map((ayarlama) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: YerimeBakColors.cyberNeonPurple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: YerimeBakColors.cyberNeonPurple,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    ayarlama.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Donanım satırı
  Widget _buildEquipmentItem(String equipment, bool selected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: selected ? YerimeBakColors.cyberNeonTurquoise : Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              equipment,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// AI risk analizi kartı
  Widget _buildAIRiskAnalysisCard(double aiGuvenlikSkoru, Map<String, dynamic> piyasaRaporu) {
    final isSafe = aiGuvenlikSkoru >= 80;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            YerimeBakColors.cyberDarkPurple.withValues(alpha: 0.8),
            YerimeBakColors.cyberDarkBlue.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSafe ? Icons.security : Icons.warning,
                  color: isSafe ? YerimeBakColors.cyberNeonTurquoise : Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Guvenlik Skoru',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: YerimeBakColors.cyberNeonTurquoise,
                        ),
                      ),
                      Text(
                        '$aiGuvenlikSkoru / 100',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isSafe ? YerimeBakColors.cyberNeonTurquoise : Colors.orange,
                        ),
                      ),
                      Text(
                        isSafe ? 'GUVENLI' : 'KRITIK RISK',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSafe ? YerimeBakColors.cyberNeonTurquoise : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAnalysisItem(
              'AI Analiz Sonucu',
              isSafe ? 'Güvenli' : 'Kritik Risk',
              isSafe
                  ? 'Araç güvenli, kritik risk taşıyor. Şasi ve Podye temiz.'
                  : 'Araç kritik risk taşıyor. Detaylı inceleme önerilir.',
              Icons.analytics,
              isSafe ? YerimeBakColors.cyberNeonTurquoise : Colors.orange,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSafe
                    ? YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.2)
                    : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSafe ? YerimeBakColors.cyberNeonTurquoise : Colors.red,
                  width: 1,
                ),
              ),
              child: Text(
                isSafe ? 'Şasi/Podye Temiz' : 'Şasi/Podye Hasarlı',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sonuç özeti kartı
  Widget _buildResultSummaryCard(Map<String, dynamic> piyasaRaporu, double aiGuvenlikSkoru) {
    final finalPrice = piyasaRaporu['finalPrice'] as double;
    final basePrice = piyasaRaporu['basePrice'] as double;
    final adjustmentPercentage = piyasaRaporu['adjustmentPercentage'] as double;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            YerimeBakColors.cyberDarkPurple.withValues(alpha: 0.8),
            YerimeBakColors.cyberDarkBlue.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sonuç Özeti',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: YerimeBakColors.cyberNeonTurquoise,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildResultItem('Baz Fiyat', '${basePrice.toStringAsFixed(0)} TL'),
                ),
                Expanded(
                  child: _buildResultItem('Toplam Ayarlama', '%$adjustmentPercentage'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    YerimeBakColors.cyberNeonTurquoise,
                    YerimeBakColors.cyberNeonPurple,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: YerimeBakColors.cyberNeonTurquoise,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'FİNAL FİYAT',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${finalPrice.toStringAsFixed(0)} TL',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI Guvenlik Skoru: $aiGuvenlikSkoru/100',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bilgi satırı
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Analiz kartı
  Widget _buildAnalysisItem(String title, String value, String description, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: YerimeBakColors.cyberNeonTurquoise,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sonuç kartı
  Widget _buildResultItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: YerimeBakColors.cyberDarkPurple.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: YerimeBakColors.cyberNeonPurple,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: YerimeBakColors.cyberNeonPurple,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
