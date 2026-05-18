import 'package:flutter/material.dart';
import '../../core/constants/yerimebak_colors.dart';
import '../../core/constants/vehicle_packages.dart';

/// Neon Paket Seçici Widget
/// 
/// Siber temaya uygun, parlayan neon efektli paket seçimi widget'ı.
/// Dinamik filtreleme ile marka ve modele göre paket seçeneklerini gösterir.
class NeonPackageSelector extends StatefulWidget {
  final String selectedPackage;
  final List<VehiclePackage> packages;
  final Function(VehiclePackage) onPackageSelected;
  final String? brandName;
  final String? modelName;

  const NeonPackageSelector({
    super.key,
    required this.selectedPackage,
    required this.packages,
    required this.onPackageSelected,
    this.brandName,
    this.modelName,
  });

  @override
  State<NeonPackageSelector> createState() => _NeonPackageSelectorState();
}

class _NeonPackageSelectorState extends State<NeonPackageSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.packages.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 20),
          
          // Package grid
          _buildPackageGrid(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.1),
            YerimeBakColors.cyberNeonPurple.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: YerimeBakColors.cyberNeonTurquoise,
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.star,
              color: YerimeBakColors.cyberNeonTurquoise,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⭐ Paket Seçimi',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: YerimeBakColors.cyberNeonTurquoise,
                  ),
                ),
                if (widget.brandName != null && widget.modelName != null)
                  const SizedBox(height: 4),
                if (widget.brandName != null && widget.modelName != null)
                  Text(
                    '${widget.brandName} ${widget.modelName}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageGrid() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: widget.packages.length,
        itemBuilder: (context, index) {
          final package = widget.packages[index];
          final isSelected = widget.selectedPackage == package.id;
          
          return _buildPackageCard(package, isSelected);
        },
      ),
    );
  }

  Widget _buildPackageCard(VehiclePackage package, bool isSelected) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glowIntensity = isSelected ? _glowAnimation.value : 0.0;
        
        return GestureDetector(
          onTap: () => widget.onPackageSelected(package),
          child: Container(
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
                        YerimeBakColors.cyberNeonPurple.withValues(alpha: 0.2),
                      ],
                    )
                  : null,
              color: isSelected
                  ? null
                  : Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.8 + glowIntensity * 0.2)
                    : Colors.white.withValues(alpha: 0.2),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3 * glowIntensity),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                      BoxShadow(
                        color: YerimeBakColors.cyberNeonPurple.withValues(alpha: 0.2 * glowIntensity),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected
                            ? YerimeBakColors.cyberNeonTurquoise
                            : Colors.white.withValues(alpha: 0.5),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          package.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? YerimeBakColors.cyberNeonTurquoise
                                : Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Package weight indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getWeightColor(package.weight).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _getWeightColor(package.weight),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Ağırlık: ${package.weight.toStringAsFixed(1)}x',
                      style: TextStyle(
                        fontSize: 11,
                        color: _getWeightColor(package.weight),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            'Paket Bulunamadı',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lütfen marka ve model seçimini kontrol edin',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          // "Diğer" seçeneği
          _buildOtherPackagesButton(),
        ],
      ),
    );
  }

  Widget _buildOtherPackagesButton() {
    return GestureDetector(
      onTap: () {
        // "Diğer" paketlerini göster
        _showOtherPackagesDialog();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
              YerimeBakColors.cyberNeonPurple.withValues(alpha: 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: YerimeBakColors.cyberNeonTurquoise,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.more_horiz,
              color: YerimeBakColors.cyberNeonTurquoise,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Diğer Paketler',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: YerimeBakColors.cyberNeonTurquoise,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOtherPackagesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.more_horiz,
              color: YerimeBakColors.cyberNeonTurquoise,
            ),
            const SizedBox(width: 12),
            const Text(
              'Diğer Paketler',
              style: TextStyle(
                color: YerimeBakColors.cyberNeonTurquoise,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: VehiclePackagesDatabase.otherPackages.length,
            itemBuilder: (context, index) {
              final package = VehiclePackagesDatabase.otherPackages[index];
              final isSelected = widget.selectedPackage == package.id;
              
              return GestureDetector(
                onTap: () {
                  widget.onPackageSelected(package);
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
                              YerimeBakColors.cyberNeonPurple.withValues(alpha: 0.2),
                            ],
                          )
                        : null,
                    color: isSelected
                        ? null
                        : Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? YerimeBakColors.cyberNeonTurquoise
                          : Colors.white.withValues(alpha: 0.2),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected
                            ? YerimeBakColors.cyberNeonTurquoise
                            : Colors.white.withValues(alpha: 0.5),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          package.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? YerimeBakColors.cyberNeonTurquoise
                                : Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getWeightColor(package.weight).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _getWeightColor(package.weight),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${package.weight.toStringAsFixed(1)}x',
                          style: TextStyle(
                            fontSize: 11,
                            color: _getWeightColor(package.weight),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: YerimeBakColors.cyberNeonTurquoise,
            ),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Color _getWeightColor(double weight) {
    if (weight >= 1.6) {
      return Colors.orange; // Spor/AMG/M paketleri
    } else if (weight >= 1.4) {
      return YerimeBakColors.cyberNeonPurple; // Premium/Lüks paketleri
    } else if (weight >= 1.2) {
      return Colors.blue; // Comfort/Advanced paketleri
    } else {
      return Colors.green; // Standart paketleri
    }
  }
}
