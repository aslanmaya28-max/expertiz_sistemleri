import 'package:flutter/material.dart';
import 'package:yerimebak_sistemleri/core/widgets/yerimebak_logo.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yerimebak_sistemleri/tema/renkler.dart';
import 'package:yerimebak_sistemleri/bilesenler/bilesenler.dart';
import '../../core/constants/vehicle_packages.dart';
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
    'Beyaz',
    'Gümüş Gri',
    'Gri',
    'Siyah',
    'Kırmızı',
    'Mavi',
    'Yeşil',
    'Sarı',
    'Turuncu',
    'Bej',
    'Kahverengi',
  ];

  final List<String> _bodyParts = [
    'Kaput',
    'Sol Ön Çamurluk',
    'Sağ Ön Çamurluk',
    'Sol Ön Kapı',
    'Sağ Ön Kapı',
    'Sol Arka Kapı',
    'Sağ Arka Kapı',
    'Sol Arka Çamurluk',
    'Sağ Arka Çamurluk',
    'Bagaj Kapağı',
    'Tavan',
    'Sol Ön Direk',
    'Sağ Ön Direk',
    'Sol Arka Direk',
    'Sağ Arka Direk',
    'Tampon Ön',
    'Tampon Arka',
    'Sol Yan Panel',
    'Sağ Yan Panel',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColoredBox(
        color: context.renkler.zemin,
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
        color: context.renkler.yuzey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.renkler.birincil.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const YerimeBakLogo(height: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI OTO-ANALİZ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: context.renkler.birincil,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Yapay Zeka Destekli Araç Değerleme',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.renkler.metin.withValues(alpha: 0.7),
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
                color: context.renkler.birincil,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.renkler.birincil,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: context.renkler.yuzey,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            widthFactor: progress,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: context.renkler.birincil,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandSelection() {
    return _buildYbKart(
      title: ' Marka Seçimi',
      child: DropdownButtonFormField<String>(
        initialValue: _selectedBrand.isEmpty ? null : _selectedBrand,
        dropdownColor: context.renkler.yuzey,
        decoration: InputDecoration(
          labelText: 'Marka',
          labelStyle: TextStyle(color: context.renkler.birincil),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: context.renkler.birincil),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
                color: context.renkler.birincil.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: context.renkler.birincil, width: 2),
          ),
          prefixIcon: Icon(LucideIcons.car, color: context.renkler.birincil),
        ),
        items: _brandNames
            .map((brand) => DropdownMenuItem(
                  value: brand,
                  child: Text(brand,
                      style: TextStyle(color: context.renkler.metin)),
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
    if (_selectedBrand.isEmpty) return SizedBox.shrink();

    final modelsForBrand =
        VehiclePackagesDatabase.getModelNamesForBrand(_selectedBrand);

    return _buildYbKart(
      title: ' Model Seçimi',
      child: DropdownButtonFormField<String>(
        initialValue: _selectedModel.isEmpty ? null : _selectedModel,
        dropdownColor: context.renkler.yuzey,
        decoration: InputDecoration(
          labelText: 'Model',
          labelStyle: TextStyle(color: context.renkler.birincil),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: context.renkler.birincil),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
                color: context.renkler.birincil.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: context.renkler.birincil, width: 2),
          ),
          prefixIcon: Icon(LucideIcons.wrench, color: context.renkler.birincil),
        ),
        items: modelsForBrand
            .map((model) => DropdownMenuItem(
                  value: model,
                  child: Text(model,
                      style: TextStyle(color: context.renkler.metin)),
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

    return YbKart(
      baslik: 'Paket seçimi',
      child: _availablePackages.isEmpty
        ? const YbBosDurum(mesaj: 'Bu model için paket bulunamadı')
        : Column(children: [
          for (final paket in _availablePackages)
            Semantics(selected: _selectedPackageId == paket.id, child: ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: 52,
              title: Text(paket.name),
              subtitle: paket.description == null ? null : Text(paket.description!),
              trailing: Icon(_selectedPackageId == paket.id ? LucideIcons.circleCheck : LucideIcons.circle,
                color: _selectedPackageId == paket.id ? context.renkler.birincil : context.renkler.ikonPasif),
              onTap: () => setState(() => _selectedPackageId = paket.id),
            )),
        ]),
    );
  }

  Widget _buildYearSelection() {
    if (_selectedPackageId.isEmpty) return SizedBox.shrink();

    return _buildYbKart(
      title: ' Yıl Seçimi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Üretim Yılı: $_selectedYear',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.renkler.birincil,
            ),
          ),
          const SizedBox(height: 12),
          Slider(
            value: _selectedYear.toDouble(),
            min: 2010.0,
            max: DateTime.now().year.toDouble(),
            divisions: DateTime.now().year - 2010,
            label: '$_selectedYear',
            activeColor: context.renkler.birincil,
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
    if (_selectedYear == DateTime.now().year) return SizedBox.shrink();

    return _buildYbKart(
      title: ' KM Bilgisi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kilometre: ${_km.toString()} km',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.renkler.birincil,
            ),
          ),
          const SizedBox(height: 12),
          Slider(
            value: _km.toDouble(),
            min: 0,
            max: 300000,
            divisions: 300,
            label: '${_km.toString()} km',
            activeColor: context.renkler.birincil,
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
    if (_selectedYear == DateTime.now().year) return SizedBox.shrink();

    return _buildYbKart(
      title: ' Renk Seçimi',
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
                    ? context.renkler.birincil.withValues(alpha: 0.3)
                    : context.renkler.yuzey,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? context.renkler.birincil
                      : context.renkler.metin.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(
                color,
                style: TextStyle(
                  color: isSelected
                      ? context.renkler.birincil
                      : context.renkler.metin.withValues(alpha: 0.7),
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
    if (_selectedYear == DateTime.now().year) return SizedBox.shrink();

    return _buildYbKart(
      title: ' Boyalı Parçalar',
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
                    ? context.renkler.uyari.withValues(alpha: 0.3)
                    : context.renkler.yuzey,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? context.renkler.uyari
                      : context.renkler.metin.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(
                part,
                style: TextStyle(
                  color: isSelected
                      ? context.renkler.uyari
                      : context.renkler.metin.withValues(alpha: 0.7),
                  fontSize: 13,
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
    return _buildYbKart(
      title: ' Hasarlı Parçalar',
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
                    ? context.renkler.tehlike.withValues(alpha: 0.3)
                    : context.renkler.yuzey,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? context.renkler.tehlike
                      : context.renkler.metin.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(
                part,
                style: TextStyle(
                  color: isSelected
                      ? context.renkler.tehlike
                      : context.renkler.metin.withValues(alpha: 0.7),
                  fontSize: 13,
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
    const gruplar = <String, List<String>>{
      'Premium': ['Cam Tavan', 'Head-up Display', 'Isıtmalı Koltuk', 'Panoramik Tavan', 'Vakumlu Kapı', 'Soft Close Kapı', 'Adaptif Cruise Control', '360 Kamera'],
      'Orta': ['LED Far', 'Deri Döşeme', 'Navigasyon', 'Bluetooth', 'USB Bağlantı', 'Klima', 'Park Sensörü'],
      'Standart': ['Alarmlı Tekerlek', 'Yol Bilgisayarı', 'Hız Sabitleyici', 'Elektrikli Camlar', 'Merkezi Kilit', 'Radyo'],
    };
    return YbKart(baslik: 'Donanım seçenekleri', child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final grup in gruplar.entries) ...[
        Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(grup.key, style: Theme.of(context).textTheme.titleMedium)),
        for (final ad in grup.value)
          CheckboxListTile(contentPadding: EdgeInsets.zero, title: Text(ad), value: _selectedOptions[ad] ?? false,
            onChanged: (secili) => setState(() => _selectedOptions[ad] = secili ?? false)),
      ]],
    ));
  }

  Widget _buildPaymentWall() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.renkler.yuzey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.renkler.birincil.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            LucideIcons.lock,
            size: 60,
            color: context.renkler.birincil,
          ),
          const SizedBox(height: 16),
          Text(
            'Analizi Kilidini Aç',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: context.renkler.birincil,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '500 TL',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: context.renkler.birincil,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Yapay zeka destekli detaylı araç değerleme raporu',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.renkler.metinIkincil,
            ),
          ),
          const SizedBox(height: 24),
          YbButon(
            metin: 'Analizi Başlat',
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
      return Center(
        child: CircularProgressIndicator(
          color: context.renkler.birincil,
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
        if (result['conflict'] != null)
          _buildConflictWarning(result['conflict']),
        const SizedBox(height: 24),

        // Back button
        YbButon(
          metin: 'Yeni Analiz',
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
        color: context.renkler.birincil,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.renkler.birincil,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${vehicleInfo['year']} ${vehicleInfo['brand']} ${vehicleInfo['model']}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: context.renkler.birincil,
                  ),
                ),
              ),
              if (packageBadge.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSport
                        ? context.renkler.uyari.withValues(alpha: 0.3)
                        : context.renkler.birincil.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSport
                          ? context.renkler.uyari
                          : context.renkler.birincil,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSport)
                        Icon(LucideIcons.gauge,
                            color: context.renkler.uyari, size: 16),
                      if (isSport) const SizedBox(width: 4),
                      Text(
                        packageBadge,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSport
                              ? context.renkler.uyari
                              : context.renkler.birincil,
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
              Icon(LucideIcons.gauge,
                  color: context.renkler.birincil, size: 20),
              const SizedBox(width: 8),
              Text(
                '${vehicleInfo['km'].toString()} km',
                style: TextStyle(
                  fontSize: 16,
                  color: context.renkler.metinIkincil,
                ),
              ),
              const SizedBox(width: 24),
              Icon(LucideIcons.palette,
                  color: context.renkler.birincil, size: 20),
              const SizedBox(width: 8),
              Text(
                vehicleInfo['color'],
                style: TextStyle(
                  fontSize: 16,
                  color: context.renkler.metinIkincil,
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
          child: _buildYbKart(
            title: 'Temel Piyasa Değeri',
            child: Column(
              children: [
                Text(
                  '${(result['basePrice'] as double).toStringAsFixed(0)} TL',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.renkler.metinIkincil,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildYbKart(
            title: 'AI Tahmini Değer',
            child: Column(
              children: [
                Text(
                  '${(result['finalValue'] as double).toStringAsFixed(0)} TL',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: context.renkler.birincil,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${result['adjustmentPercentage']}%',
                  style: TextStyle(
                    fontSize: 16,
                    color: (result['adjustmentPercentage'] as String)
                            .startsWith('-')
                        ? context.renkler.tehlike
                        : context.renkler.birincil,
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

    return _buildYbKart(
      title: ' Ayarlamalar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: adjustments.map((adjustment) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  adjustment.startsWith('-')
                      ? LucideIcons.trendingDown
                      : LucideIcons.trendingUp,
                  color: adjustment.startsWith('-')
                      ? context.renkler.tehlike
                      : context.renkler.birincil,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    adjustment,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.renkler.metinIkincil,
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
        color: context.renkler.uyari.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.renkler.uyari,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.triangleAlert, color: context.renkler.uyari),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              conflict['warning'] ?? 'Paket/Donanım çakışması tespit edildi',
              style: TextStyle(
                fontSize: 14,
                color: context.renkler.uyari,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYbKart({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.renkler.yuzey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.renkler.birincil.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.renkler.birincil,
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
    double packageWeight =
        VehiclePackagesDatabase.getPackageWeight(_selectedPackageId);

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
