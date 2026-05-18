import 'package:flutter/material.dart';
import '../../core/constants/yerimebak_colors.dart';

/// Neon Motor Gauge - Displays motor status with neon glow effect
class NeonMotorGauge extends StatelessWidget {
  final String status;
  final double score;
  final String description;

  const NeonMotorGauge({
    super.key,
    required this.status,
    required this.score,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(status);
    
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
          color: statusColor.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: statusColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'Motor Durumu',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: YerimeBakColors.cyberNeonTurquoise,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Neon Score Display
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    statusColor.withValues(alpha: 0.3),
                    statusColor.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
                border: Border.all(
                  color: statusColor,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${score.toInt()}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              status,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'mükemmel':
      case 'excellent':
        return YerimeBakColors.cyberNeonTurquoise;
      case 'iyi':
      case 'good':
        return Colors.green;
      case 'orta':
      case 'average':
        return Colors.orange;
      case 'kötü':
      case 'poor':
        return YerimeBakColors.cyberNeonMagenta;
      default:
        return Colors.grey;
    }
  }
}

/// Neon Car Body Gauge - Displays paint/body condition with neon glow
class NeonCarBodyGauge extends StatelessWidget {
  final String condition;
  final double score;
  final List<String> paintedParts;
  final List<String> damagedParts;

  const NeonCarBodyGauge({
    super.key,
    required this.condition,
    required this.score,
    required this.paintedParts,
    required this.damagedParts,
  });

  @override
  Widget build(BuildContext context) {
    final conditionColor = _getConditionColor(condition);
    
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
          color: conditionColor.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: conditionColor.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_car,
                  color: conditionColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'Kaporta / Boya',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: YerimeBakColors.cyberNeonTurquoise,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Neon Score Display
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    conditionColor.withValues(alpha: 0.3),
                    conditionColor.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
                border: Border.all(
                  color: conditionColor,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: conditionColor.withValues(alpha: 0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${score.toInt()}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: conditionColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              condition,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: conditionColor,
              ),
            ),
            const SizedBox(height: 16),
            if (paintedParts.isNotEmpty) ...[
              _buildPartList('Boyalı Parçalar', paintedParts, YerimeBakColors.cyberNeonPurple),
              const SizedBox(height: 12),
            ],
            if (damagedParts.isNotEmpty)
              _buildPartList('Hasarlı Parçalar', damagedParts, YerimeBakColors.cyberNeonMagenta),
          ],
        ),
      ),
    );
  }

  Widget _buildPartList(String title, List<String> parts, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: parts.map((part) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Text(
                part,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Color _getConditionColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'orijinal':
      case 'original':
        return YerimeBakColors.cyberNeonTurquoise;
      case 'kısmi boya':
      case 'partial paint':
        return Colors.orange;
      case 'tam boya':
      case 'full paint':
        return YerimeBakColors.cyberNeonMagenta;
      default:
        return Colors.grey;
    }
  }
}

/// Neon Battery Gauge - Displays EV battery health with neon glow
class NeonBatteryGauge extends StatelessWidget {
  final double healthPercentage;
  final int estimatedRange;
  final String chargingPortCondition;
  final String softwareVersion;

  const NeonBatteryGauge({
    super.key,
    required this.healthPercentage,
    required this.estimatedRange,
    required this.chargingPortCondition,
    required this.softwareVersion,
  });

  @override
  Widget build(BuildContext context) {
    final healthColor = _getHealthColor(healthPercentage);
    
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
          color: healthColor.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: healthColor.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.battery_charging_full,
                  color: healthColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'EV Batarya Sağlığı',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: YerimeBakColors.cyberNeonTurquoise,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Neon Battery Display
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    healthColor.withValues(alpha: 0.3),
                    healthColor.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
                border: Border.all(
                  color: healthColor,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: healthColor.withValues(alpha: 0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${healthPercentage.toInt()}%',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: healthColor,
                      ),
                    ),
                    Icon(
                      Icons.bolt,
                      color: healthColor,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Tahmini Menzil', '$estimatedRange km', Icons.route),
            const SizedBox(height: 12),
            _buildInfoRow('Şarj Portu', chargingPortCondition, Icons.power),
            const SizedBox(height: 12),
            _buildInfoRow('Yazılım Sürümü', softwareVersion, Icons.system_update),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.15),
            YerimeBakColors.cyberNeonPurple.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: YerimeBakColors.cyberNeonTurquoise,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getHealthColor(double healthPercentage) {
    if (healthPercentage >= 90) {
      return YerimeBakColors.cyberNeonTurquoise;
    } else if (healthPercentage >= 70) {
      return Colors.green;
    } else if (healthPercentage >= 50) {
      return Colors.orange;
    } else {
      return YerimeBakColors.cyberNeonMagenta;
    }
  }
}
