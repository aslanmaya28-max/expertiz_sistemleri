import 'package:flutter/material.dart';
import '../../core/constants/yerimebak_colors.dart';
import '../../core/constants/vehicle_packages.dart';
import '../../widgets/cyber/index.dart';
import '../../services/market_radar_service.dart';

/// Müşteri Paneli - AI Oto-Analiz Modülü
/// Akıllı form hiyerarşisi: Marka → Model → Paket → KM → Boya/Hasar → Donanımlar
class OtoAnalizMerkezi extends StatefulWidget {
  const OtoAnalizMerkezi({super.key});

  @override
  State<OtoAnalizMerkezi> createState() => _OtoAnalizMerkeziState();
}

class _OtoAnalizMerkeziState extends State<OtoAnalizMerkezi> {
  // Form state
  String _selectedBrand = '';
  String _selectedModel = '';
  String _selectedPackageId = '';
  int _selectedYear = DateTime.now().year;
  int _km = 0;
  String _color = '';
  List<String> _paintedParts = [];
  List<String> _damagedParts = [];
  Map<String, bool> _selectedOptions = {};
  
  // Payment state
  bool _isPaymentUnlocked = false;
  
  // Analysis result
  Map<String, dynamic>? _analysisResult;
  
  // Dynamic packages
  List<VehiclePackage> _availablePackages = [];
  
  // Brand data
  final List<String> _brandNames = VehiclePackagesDatabase.getAllBrandNames();
  
  final List<String> _colors = [
    'Beyaz', 'Gümüş Gri', 'Gri', 'Siyah', 'Kırmızı', 'Mavi', 'Yeşil', 'Sarı', 'Turuncu', 'Bej', 'Kahverengi',
  ];
  
  final List<String> _bodyParts = [
    'Kaput', 'Sol Ön Çamurluk', 'Sağ Ön Çamurluk', 'Sol Ön Kapı', 'Sağ Ön Kapı',
    'Sol Arka Kapı', 'Sağ Arka Kapı', 'Sol Arka Çamurluk', 'Sağ Arka Çamurluk',
    'Bagaj Kapağı', 'Tavan', 'Sol Ön Direk', 'Sağ Ön Direk', 'Sol Arka Direk', 'Sağ Arka Direk',
    'Tampon Ön', 'Tampon Arka', 'Sol Yan Panel', 'Sağ Yan Panel',
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CyberBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 24),
                 
                // Progress indicator
                _buildProgressIndicator(),
                const SizedBox(height: 24),
                 
                // Form sections
                if (!_isPaymentUnlocked) ...[
                  _buildBrandSelection(),
                  const SizedBox(height: 16),
                  _buildModelSelection(),
                  const SizedBox(height: 16),
                  _buildPackageSelection(),
                  const SizedBox(height: 16),
                  _buildYearSelection(),
                  const SizedBox(height: 16),
                  _buildKmSelection(),
                  const SizedBox(height: 16),
                  _buildColorSelection(),
                  const SizedBox(height: 16),
                  _buildPaintedParts(),
                  const SizedBox(height: 16),
                  _buildDamagedParts(),
                  const SizedBox(height: 16),
                  _buildEquipmentOptions(),
                  const SizedBox(height: 24),
                   
                  // Payment wall
                  _buildPaymentWall(),
                ] else ...[
                  // Analysis results
                  _buildAnalysisResults(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CyberLogo(size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI OTO-ANALİZ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: YerimeBakColors.cyberNeonTurquoise,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Yapay Zeka Destekli Araç Değerleme',
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
        ],
      ),
    );
  }
  
  Widget _buildProgressIndicator() {
    int completedSteps = 0;
    if (_selectedBrand.isNotEmpty) completedSteps++;
    if (_selectedModel.isNotEmpty) completedSteps++;
    if (_selectedPackageId.isNotEmpty) completedSteps++;
    if (_km > 0) completedSteps++;
    if (_color.isNotEmpty) completedSteps++;
    if (_selectedOptions.isNotEmpty) completedSteps++;
    
    double progress = completedSteps / 6;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'İlerleme',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: YerimeBakColors.cyberNeonTurquoise,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: YerimeBakColors.cyberNeonPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            widthFactor: progress,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    YerimeBakColors.cyberNeonTurquoise,
                    YerimeBakColors.cyberNeonPurple,
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildBrandSelection() {
    return _buildGlassCard(
      title: '🚗 Marka Seçimi',
      child: DropdownButtonFormField<String>(
        initialValue: _selectedBrand.isEmpty ? null : _selectedBrand,
        dropdownColor: Colors.black.withValues(alpha: 0.9),
        decoration: InputDecoration(
          labelText: 'Marka',
          labelStyle: const TextStyle(color: YerimeBakColors.cyberNeonTurquoise),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: YerimeBakColors.cyberNeonTurquoise),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: YerimeBakColors.cyberNeonTurquoise, width: 2),
          ),
          prefixIcon: const Icon(Icons.directions_car, color: YerimeBakColors.cyberNeonTurquoise),
        ),
        items: _brandNames
            .map((brand) => DropdownMenuItem(
                  value: brand,
                  child: Text(brand, style: const TextStyle(color: Colors.white)),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedBrand = value ?? '';
            _selectedModel = '';
            _selectedPackageId = '';
            _availablePackages = [];
          });
        },
      ),
    );
  }
  
  Widget _buildModelSelection() {
    if (_selectedBrand.isEmpty) return const SizedBox.shrink();
    
    final modelsForBrand = VehiclePackagesDatabase.getModelNamesForBrand(_selectedBrand);
    
    return _buildGlassCard(
      title: '🚙 Model Seçimi',
      child: DropdownButtonFormField<String>(
        initialValue: _selectedModel.isEmpty ? null : _selectedModel,
        dropdownColor: Colors.black.withValues(alpha: 0.9),
        decoration: InputDecoration(
          labelText: 'Model',
          labelStyle: const TextStyle(color: YerimeBakColors.cyberNeonTurquoise),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: YerimeBakColors.cyberNeonTurquoise),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: YerimeBakColors.cyberNeonTurquoise, width: 2),
          ),
          prefixIcon: const Icon(Icons.car_repair, color: YerimeBakColors.cyberNeonTurquoise),
        ),
        items: modelsForBrand
            .map((model) => DropdownMenuItem(
                  value: model,
                  child: Text(model, style: const TextStyle(color: Colors.white)),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedModel = value ?? '';
            _selectedPackageId = '';
            // Load dynamic packages for selected brand and model
            if (_selectedBrand.isNotEmpty && _selectedModel.isNotEmpty) {
              _availablePackages = VehiclePackagesDatabase.getPackages(
                _selectedBrand,
                _selectedModel,
                _selectedYear,
              );
              // If no packages found, show "Diğer" packages
              if (_availablePackages.isEmpty) {
                _availablePackages = VehiclePackagesDatabase.otherPackages;
              }
            }
          });
        },
      ),
    );
  }
  
  Widget _buildPackageSelection() {
    if (_selectedModel.isEmpty) return const SizedBox.shrink();
    
    return NeonPackageSelector(
      selectedPackage: _selectedPackageId,
      packages: _availablePackages,
      brandName: _selectedBrand,
      modelName: _selectedModel,
      onPackageSelected: (package) {
        setState(() {
          _selectedPackageId = package.id;
        });
      },
    );
  }
  
  Widget _buildYearSelection() {
    if (_selectedPackageId.isEmpty) return const SizedBox.shrink();
    
    return _buildGlassCard(
      title: '📅 Yıl Seçimi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Üretim Yılı: $_selectedYear',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: YerimeBakColors.cyberNeonTurquoise,
            ),
          ),
          const SizedBox(height: 12),
          Slider(
            value: _selectedYear.toDouble(),
            min: 2010.0,
            max: DateTime.now().year.toDouble(),
            divisions: DateTime.now().year - 2010,
            label: '$_selectedYear',
            activeColor: YerimeBakColors.cyberNeonTurquoise,
            onChanged: (value) {
              setState(() {
                _selectedYear = value.toInt();
              });
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildKmSelection() {
    if (_selectedYear == DateTime.now().year) return const SizedBox.shrink();
    
    return _buildGlassCard(
      title: '📊 KM Bilgisi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kilometre: ${_km.toString()} km',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: YerimeBakColors.cyberNeonTurquoise,
            ),
          ),
          const SizedBox(height: 12),
          Slider(
            value: _km.toDouble(),
            min: 0,
            max: 300000,
            divisions: 300,
            label: '${_km.toString()} km',
            activeColor: YerimeBakColors.cyberNeonTurquoise,
            onChanged: (value) {
              setState(() {
                _km = value.toInt();
              });
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildColorSelection() {
    if (_selectedYear == DateTime.now().year) return const SizedBox.shrink();
    
    return _buildGlassCard(
      title: '🎨 Renk Seçimi',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _colors.map((color) {
          bool isSelected = _color == color;
          return GestureDetector(
            onTap: () {
              setState(() {
                _color = color;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                        ? YerimeBakColors.cyberNeonTurquoise
                        : Colors.white.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(
                color,
                style: TextStyle(
                  color: isSelected
                        ? YerimeBakColors.cyberNeonTurquoise
                        : Colors.white.withValues(alpha: 0.7),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildPaintedParts() {
    if (_selectedYear == DateTime.now().year) return const SizedBox.shrink();
    
    return _buildGlassCard(
      title: '🖌️ Boyalı Parçalar',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _bodyParts.map((part) {
          bool isSelected = _paintedParts.contains(part);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _paintedParts.remove(part);
                } else {
                  _paintedParts.add(part);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.orange.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                        ? Colors.orange
                        : Colors.white.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(
                part,
                style: TextStyle(
                  color: isSelected
                        ? Colors.orange
                        : Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildDamagedParts() {
    return _buildGlassCard(
      title: '⚠️ Hasarlı Parçalar',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _bodyParts.map((part) {
          bool isSelected = _damagedParts.contains(part);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _damagedParts.remove(part);
                } else {
                  _damagedParts.add(part);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                        ? Colors.red
                        : Colors.white.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(
                part,
                style: TextStyle(
                  color: isSelected
                        ? Colors.red
                        : Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildEquipmentOptions() {
    return _buildGlassCard(
      title: '🔧 Donanım Seçenekleri',
      child: PremiumDonanimlarWidget(
        selectedOptions: _selectedOptions,
        onOptionChanged: (option, isSelected) {
          setState(() {
            _selectedOptions[option] = isSelected;
          });
        },
      ),
    );
  }
  
  Widget _buildPaymentWall() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
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
        children: [
          Icon(
            Icons.lock,
            size: 60,
            color: YerimeBakColors.cyberNeonTurquoise,
          ),
          const SizedBox(height: 16),
          const Text(
            'Analizi Kilidini Aç',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: YerimeBakColors.cyberNeonTurquoise,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '500 TL',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: YerimeBakColors.cyberNeonPurple,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Yapay zeka destekli detaylı araç değerleme raporu',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          NeonButton(
            text: 'Analizi Başlat',
            onPressed: () {
              setState(() {
                _isPaymentUnlocked = true;
                _runAnalysis();
              });
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnalysisResults() {
    if (_analysisResult == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: YerimeBakColors.cyberNeonTurquoise,
        ),
      );
    }
    
    final result = _analysisResult!;
    final vehicleInfo = result['vehicleInfo'] as Map<String, dynamic>;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vehicle identity header
        _buildVehicleIdentityHeader(vehicleInfo),
        const SizedBox(height: 24),
        
        // Value cards
        _buildValueCards(result),
        const SizedBox(height: 24),
        
        // Adjustments
        _buildAdjustmentsList(result),
        const SizedBox(height: 24),
        
        // Conflict warning
        if (result['conflict'] != null) _buildConflictWarning(result['conflict']),
        const SizedBox(height: 24),
        
        // Back button
        NeonButton(
          text: 'Yeni Analiz',
          onPressed: () {
            setState(() {
              _isPaymentUnlocked = false;
              _analysisResult = null;
              _resetForm();
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildVehicleIdentityHeader(Map<String, dynamic> vehicleInfo) {
    String packageBadge = vehicleInfo['packageLevel'] ?? '';
    bool isSport = vehicleInfo['isSportPackage'] ?? false;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.2),
            YerimeBakColors.cyberNeonPurple.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: YerimeBakColors.cyberNeonTurquoise,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${vehicleInfo['year']} ${vehicleInfo['brand']} ${vehicleInfo['model']}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: YerimeBakColors.cyberNeonTurquoise,
                  ),
                ),
              ),
              if (packageBadge.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSport
                        ? Colors.orange.withValues(alpha: 0.3)
                        : YerimeBakColors.cyberNeonPurple.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSport ? Colors.orange : YerimeBakColors.cyberNeonPurple,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSport)
                        const Icon(Icons.sports_motorsports, color: Colors.orange, size: 16),
                      if (isSport) const SizedBox(width: 4),
                      Text(
                        packageBadge,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSport ? Colors.orange : YerimeBakColors.cyberNeonPurple,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.speed, color: YerimeBakColors.cyberNeonPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                '${vehicleInfo['km'].toString()} km',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 24),
              Icon(Icons.palette, color: YerimeBakColors.cyberNeonPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                vehicleInfo['color'],
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildValueCards(Map<String, dynamic> result) {
    return Row(
      children: [
        Expanded(
          child: _buildGlassCard(
            title: 'Temel Piyasa Değeri',
            child: Column(
              children: [
                Text(
                  '${(result['basePrice'] as double).toStringAsFixed(0)} TL',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildGlassCard(
            title: 'AI Tahmini Değer',
            child: Column(
              children: [
                Text(
                  '${(result['finalValue'] as double).toStringAsFixed(0)} TL',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: YerimeBakColors.cyberNeonTurquoise,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${result['adjustmentPercentage']}%',
                  style: TextStyle(
                    fontSize: 16,
                    color: (result['adjustmentPercentage'] as String).startsWith('-')
                        ? Colors.red
                        : YerimeBakColors.cyberNeonPurple,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildAdjustmentsList(Map<String, dynamic> result) {
    final adjustments = result['adjustments'] as List<String>;
    
    return _buildGlassCard(
      title: '📊 Ayarlamalar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: adjustments.map((adjustment) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  adjustment.startsWith('-') ? Icons.trending_down : Icons.trending_up,
                  color: adjustment.startsWith('-') ? Colors.red : YerimeBakColors.cyberNeonTurquoise,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    adjustment,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildConflictWarning(dynamic conflict) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              conflict['warning'] ?? 'Paket/Donanım çakışması tespit edildi',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGlassCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: YerimeBakColors.cyberNeonTurquoise,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
  
  void _runAnalysis() {
    // Get package weight from database
    double packageWeight = VehiclePackagesDatabase.getPackageWeight(_selectedPackageId);
    
    final result = MarketRadarService.calculateIntegratedValue(
      brand: _selectedBrand,
      model: _selectedModel,
      year: _selectedYear,
      km: _km,
      color: _color,
      packageLevel: _selectedPackageId,
      packageWeight: packageWeight,
      selectedOptions: _selectedOptions,
      paintedParts: _paintedParts,
      damagedParts: _damagedParts,
      marketSource: null,
    );
    
    setState(() {
      _analysisResult = result;
    });
  }
  
  void _resetForm() {
    setState(() {
      _selectedBrand = '';
      _selectedModel = '';
      _selectedPackageId = '';
      _selectedYear = DateTime.now().year;
      _km = 0;
      _color = '';
      _paintedParts = [];
      _damagedParts = [];
      _selectedOptions = {};
      _availablePackages = [];
    });
  }
}
