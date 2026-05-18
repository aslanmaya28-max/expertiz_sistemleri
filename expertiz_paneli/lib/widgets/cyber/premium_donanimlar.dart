import 'package:flutter/material.dart';
import '../../core/constants/yerimebak_colors.dart';

/// Premium Donanımlar Widget - Displays all 21 equipment options with cyber icons
class PremiumDonanimlarWidget extends StatelessWidget {
  final Map<String, bool> selectedOptions;
  final Function(String, bool)? onOptionChanged;

  const PremiumDonanimlarWidget({
    super.key,
    required this.selectedOptions,
    this.onOptionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final premiumOptions = _getPremiumOptions();
    final mediumOptions = _getMediumOptions();
    final standardOptions = _getStandardOptions();

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
          color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.diamond,
                  color: YerimeBakColors.cyberNeonTurquoise,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'Premium Donanımlar',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: YerimeBakColors.cyberNeonTurquoise,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildOptionCategory('Premium', premiumOptions, YerimeBakColors.cyberNeonTurquoise),
            const SizedBox(height: 16),
            _buildOptionCategory('Medium', mediumOptions, YerimeBakColors.cyberNeonPurple),
            const SizedBox(height: 16),
            _buildOptionCategory('Standard', standardOptions, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCategory(String title, List<OptionItem> options, Color categoryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                categoryColor.withValues(alpha: 0.3),
                categoryColor.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: categoryColor.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: categoryColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((option) => _buildOptionChip(option, categoryColor)).toList(),
        ),
      ],
    );
  }

  Widget _buildOptionChip(OptionItem option, Color categoryColor) {
    final isSelected = selectedOptions[option.name] ?? false;
    
    return GestureDetector(
      onTap: () {
        if (onOptionChanged != null) {
          onOptionChanged!(option.name, !isSelected);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    categoryColor.withValues(alpha: 0.4),
                    categoryColor.withValues(alpha: 0.2),
                  ],
                )
              : LinearGradient(
                  colors: [
                    categoryColor.withValues(alpha: 0.1),
                    categoryColor.withValues(alpha: 0.05),
                  ],
                ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? categoryColor : categoryColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: categoryColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              option.icon,
              color: isSelected ? categoryColor : categoryColor.withValues(alpha: 0.6),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              option.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? categoryColor : categoryColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<OptionItem> _getPremiumOptions() {
    return [
      OptionItem(name: 'Cam Tavan', icon: Icons.roofing),
      OptionItem(name: 'Head-up Display', icon: Icons.dashboard),
      OptionItem(name: 'Isıtmalı Koltuk', icon: Icons.chair),
      OptionItem(name: 'Panoramik Tavan', icon: Icons.panorama_horizontal),
      OptionItem(name: 'Vakumlu Kapı', icon: Icons.sensor_door),
      OptionItem(name: 'Soft Close Kapı', icon: Icons.sensor_door),
      OptionItem(name: 'Adaptif Cruise Control', icon: Icons.speed),
      OptionItem(name: '360 Kamera', icon: Icons.videocam),
    ];
  }

  List<OptionItem> _getMediumOptions() {
    return [
      OptionItem(name: 'LED Far', icon: Icons.highlight),
      OptionItem(name: 'Deri Döşeme', icon: Icons.weekend),
      OptionItem(name: 'Navigasyon', icon: Icons.map),
      OptionItem(name: 'Bluetooth', icon: Icons.bluetooth),
      OptionItem(name: 'USB Bağlantı', icon: Icons.usb),
      OptionItem(name: 'Klima', icon: Icons.ac_unit),
      OptionItem(name: 'Park Sensörü', icon: Icons.sensors),
    ];
  }

  List<OptionItem> _getStandardOptions() {
    return [
      OptionItem(name: 'Alarmlı Tekerlek', icon: Icons.notifications),
      OptionItem(name: 'Yol Bilgisayarı', icon: Icons.info),
      OptionItem(name: 'Hız Sabitleyici', icon: Icons.speed),
      OptionItem(name: 'Elektrikli Camlar', icon: Icons.window),
      OptionItem(name: 'Merkezi Kilit', icon: Icons.lock),
      OptionItem(name: 'Radyo', icon: Icons.radio),
    ];
  }
}

class OptionItem {
  final String name;
  final IconData icon;

  OptionItem({required this.name, required this.icon});
}
