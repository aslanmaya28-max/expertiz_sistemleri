import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/location_data.dart';
import '../../core/constants/expertiz_packages.dart';
import '../../models/talep_model.dart';
import '../../services/yerimebak_expertiz_api_service.dart';
import '../../providers/user_provider.dart';

/// Müşteri Talep Oluşturma Ekranı
/// Step-by-Step yapı ile talep oluşturma sürecini yönetir
class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  // Stepper State
  int _currentStep = 0;
  String _userName = 'Müşteri';
  String? _userId;
  
  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadCatalog();
  }

  /// Firma/paket fiyatları ve hizmet bedeli admin panelinden yönetilir; merkezi API'den okunur.
  Future<void> _loadCatalog() async {
    try {
      final data = await _api.getExpertizPackages();
      final firms = (data['firms'] as List? ?? const [])
          .whereType<Map>()
          .map((f) => ExpertizFirm(
                id: f['id'].toString(),
                name: f['name']?.toString() ?? '',
                logoUrl: '',
                packages: (f['packages'] as List? ?? const [])
                    .whereType<Map>()
                    .map((p) => ExpertizPackage(
                          id: p['id'].toString(),
                          name: p['name']?.toString() ?? '',
                          price: (p['price'] as num?)?.toDouble() ?? 0,
                          features: (p['features'] as List? ?? const []).map((e) => e.toString()).toList(),
                        ))
                    .toList(),
              ))
          .toList();
      if (!mounted) return;
      setState(() {
        _firmalar = firms;
        _hizmetBedeli = (data['service_fee_tl'] as num?)?.toDouble() ?? _hizmetBedeli;
        _kdvOrani = (data['vat_rate'] as num?)?.toDouble() ?? _kdvOrani;
        _katalogHatasi = null;
      });
    } catch (e) {
      if (mounted) setState(() => _katalogHatasi = 'Ekspertiz paketleri yüklenemedi: $e');
    }
  }
  
  Future<void> _loadUserName() async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.fullName.isNotEmpty ? user.fullName : user.email;
        _userId = user.id;
      });
    }
  }

  // Adım 1: Araç Bilgileri
  final _ilanLinkController = TextEditingController();
  final _plakaController = TextEditingController();
  String? _secilenSehir;

  // Adım 2: Kurumsal Ekspertiz Seçimi
  ExpertizFirm? _secilenFirma;
  ExpertizPackage? _secilenPaket;

  // Katalog (merkezi API) ve ödeme
  final YerimebakExpertizApiService _api = YerimebakExpertizApiService();
  List<ExpertizFirm> _firmalar = const [];
  String? _katalogHatasi;
  double _hizmetBedeli = 0;
  double _kdvOrani = 0.20;

  // Loading State
  bool _isLoading = false;

  @override
  void dispose() {
    _ilanLinkController.dispose();
    _plakaController.dispose();
    super.dispose();
  }

  // Getters
  double get _paketFiyati => _secilenPaket?.price ?? 0.0;
  double get _altToplam => _hizmetBedeli + _paketFiyati;
  double get _kdv => _altToplam * _kdvOrani;
  double get _toplamTutar => _altToplam + _kdv;

  bool get _adim1Valid =>
      _plakaController.text.isNotEmpty && _secilenSehir != null;

  bool get _adim2Valid => _secilenFirma != null && _secilenPaket != null;

  // Kart bilgisi uygulamada alınmaz; ödeme PayTR güvenli sayfasında yapılır.
  bool get _adim3Valid => true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Yeni Ekspertiz Talebi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Progress Indicator
          _buildProgressIndicator(),
          
          // Stepper Content
          Expanded(
            child: Stepper(
              type: StepperType.horizontal,
              currentStep: _currentStep,
              onStepContinue: _nextStep,
              onStepCancel: _prevStep,
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : details.onStepContinue,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF1976D2),
                            disabledBackgroundColor: Colors.grey[300],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  _currentStep == 2 ? 'ÖDEMEYİ TAMAMLA' : 'DEVAM ET',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      if (_currentStep > 0) ...[
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: _isLoading ? null : details.onStepCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            side: const BorderSide(color: Color(0xFF1976D2)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'GERİ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
              steps: [
                _buildAdim1(),
                _buildAdim2(),
                _buildAdim3(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Progress Indicator
  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              3,
              (index) => _buildProgressStep(index),
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            backgroundColor: const Color(0xFFE0E0E0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int index) {
    final isActive = index == _currentStep;
    final isCompleted = index < _currentStep;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? const Color(0xFF1976D2)
                : isCompleted
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFE0E0E0),
            border: Border.all(
              color: isActive ? const Color(0xFF1976D2) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _getStepTitle(index),
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? const Color(0xFF1976D2) : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getStepTitle(int index) {
    switch (index) {
      case 0:
        return 'Araç';
      case 1:
        return 'Firma';
      case 2:
        return 'Ödeme';
      default:
        return '';
    }
  }

  // Adım 1: Araç Bilgileri
  Step _buildAdim1() {
    return Step(
      title: const Text('Araç Bilgileri'),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İlan Linki
            _buildInfoCard(
              'İlan Linki ile Hızlı Giriş',
              'Sahibinden veya Arabam.com linkini yapıştırın, biz sizin için inceleyelim.',
              Icons.link,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ilanLinkController,
              decoration: InputDecoration(
                labelText: 'İlan Linki (Opsiyonel)',
                hintText: 'https://...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.link, color: Color(0xFF1976D2)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            
            // Manuel Giriş
            const Text(
              'Veya Manuel Giriş',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1976D2),
              ),
            ),
            const SizedBox(height: 16),
            
            // Plaka
            TextFormField(
              controller: _plakaController,
              decoration: InputDecoration(
                labelText: 'Araç Plakası *',
                hintText: '34 ABC 123',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.directions_car, color: Color(0xFF1976D2)),
                filled: true,
                fillColor: Colors.white,
              ),
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            
            // Şehir Seçimi
            DropdownButtonFormField<String>(
              initialValue: _secilenSehir,
              decoration: InputDecoration(
                labelText: 'Şehir Seçiniz *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.location_city, color: Color(0xFF1976D2)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: LocationData.cities.map((city) {
                return DropdownMenuItem(
                  value: city.ilAdi,
                  child: Text(
                    '${city.plakaKodu.toString().padLeft(2, '0')} - ${city.ilAdi}',
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _secilenSehir = value;
                  // Şehir değişince firma ve paket seçimini sıfırla
                  _secilenFirma = null;
                  _secilenPaket = null;
                });
              },
            ),
          ],
        ),
      ),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
    );
  }

  // Adım 2: Kurumsal Ekspertiz Seçimi
  Step _buildAdim2() {
    return Step(
      title: const Text('Kurumsal Ekspertiz'),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_secilenSehir == null) ...[
              _buildWarningCard(
                'Lütfen önce bir şehir seçiniz.',
                Icons.warning,
              ),
              const SizedBox(height: 16),
            ],
            
            if (_secilenSehir != null) ...[
              const Text(
                'Anlaşmalı Kurumsal Firmalar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
              const SizedBox(height: 16),
              
              // Firma Listesi
              if (_katalogHatasi != null)
                _buildWarningCard(_katalogHatasi!, Icons.error_outline)
              else if (_firmalar.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              ..._firmalar.map((firma) {
                final isSelected = _secilenFirma?.id == firma.id;
                return _buildFirmaCard(firma, isSelected);
              }),
              
              // Paket Seçimi (Firma seçildiyse göster)
              if (_secilenFirma != null) ...[
                const SizedBox(height: 24),
                const Text(
                  'Paket Seçimi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 16),
                ..._secilenFirma!.packages.map((paket) {
                  final isSelected = _secilenPaket?.id == paket.id;
                  return _buildPaketCard(paket, isSelected);
                }),
              ],
            ],
          ],
        ),
      ),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
    );
  }

  // Adım 3: Özet ve Ödeme
  Step _buildAdim3() {
    return Step(
      title: const Text('Özet ve Ödeme'),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Özet Kartı
              _buildSummaryCard(),
              const SizedBox(height: 24),
              
              const Text(
                'Ödeme',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '"Ödemeyi Tamamla" ile talebiniz oluşturulur ve PayTR güvenli ödeme sayfası açılır. '
                'Kart bilgileriniz uygulamaya girilmez. Talebiniz ödeme onaylandığında işleme alınır.',
                style: TextStyle(color: Colors.grey[800], fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Güvenlik Notu
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1976D2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.security,
                      color: Color(0xFF1976D2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ödeme, PayTR altyapısında 3D Secure ile alınır.',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      isActive: _currentStep >= 2,
      state: _currentStep > 2 ? StepState.complete : StepState.indexed,
    );
  }

  // Helper Widgets
  Widget _buildInfoCard(String title, String description, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1976D2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1976D2)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF9800)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF9800)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFF9800),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirmaCard(ExpertizFirm firma, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _secilenFirma = firma;
          _secilenPaket = null; // Firma değişince paketi sıfırla
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3F2FD) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1976D2) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1976D2).withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Logo Placeholder
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.business,
                size: 32,
                color: Color(0xFF1976D2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firma.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF1976D2) : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${firma.packages.length} paket seçeneği',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4CAF50),
                size: 28,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaketCard(ExpertizPackage paket, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _secilenPaket = paket;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    paket.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[800],
                    ),
                  ),
                ),
                Text(
                  '${paket.price.toStringAsFixed(0)} TL',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFF1976D2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: paket.features.map((feature) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                        : const Color(0xFF1976D2).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF1976D2),
                    ),
                  ),
                  child: Text(
                    feature,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF1976D2),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Seçildi',
                      style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.bold,
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

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Talep Özeti',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 20),
          
          // Araç Bilgileri
          _buildSummaryItem(
            'Araç Plakası',
            _plakaController.text.toUpperCase(),
            Icons.directions_car,
          ),
          const Divider(height: 24),
          _buildSummaryItem(
            'Şehir',
            _secilenSehir ?? '-',
            Icons.location_city,
          ),
          const Divider(height: 24),
          
          // Firma ve Paket
          _buildSummaryItem(
            'Firma',
            _secilenFirma?.name ?? '-',
            Icons.business,
          ),
          const Divider(height: 24),
          _buildSummaryItem(
            'Paket',
            _secilenPaket?.name ?? '-',
            Icons.inventory_2,
          ),
          const Divider(height: 24),
          
          // Fiyatlandırma
          _buildPriceItem(
            'Hizmet Bedeli',
            '$_hizmetBedeli TL',
            false,
          ),
          const SizedBox(height: 8),
          _buildPriceItem(
            'Paket Ücreti',
            '${_paketFiyati.toStringAsFixed(0)} TL',
            false,
          ),
          const SizedBox(height: 8),
          _buildPriceItem(
            'Ara Toplam',
            '${_altToplam.toStringAsFixed(0)} TL',
            true,
          ),
          const SizedBox(height: 12),
          _buildPriceItem(
            'KDV (%20)',
            '${_kdv.toStringAsFixed(0)} TL',
            false,
          ),
          const SizedBox(height: 16),
          
          // Toplam Tutar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4CAF50)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOPLAM TUTAR',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                Text(
                  '${_toplamTutar.toStringAsFixed(0)} TL',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1976D2), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1976D2),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceItem(String label, String value, bool isBold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? const Color(0xFF1976D2) : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  // Step Navigation
  void _nextStep() {
    if (_currentStep == 0 && !_adim1Valid) {
      _showErrorSnackBar('Lütfen plaka ve şehir seçiniz.');
      return;
    }
    
    if (_currentStep == 1 && !_adim2Valid) {
      _showErrorSnackBar('Lütfen bir firma ve paket seçiniz.');
      return;
    }
    
    if (_currentStep == 2 && !_adim3Valid) {
      return;
    }
    
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    } else {
      _talepOlustur();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Talep Oluşturma + PayTR ödemesi
  Future<void> _talepOlustur() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _api.createExpertizRequest(
        firmId: _secilenFirma!.id,
        packageId: _secilenPaket!.id,
        plate: _plakaController.text.trim().toUpperCase(),
        city: _secilenSehir,
        listingUrl: _ilanLinkController.text.trim(),
        note: 'Mobil uygulama talebi',
      );
      if (!mounted) return;
      final paid = await _odemeyiTamamla(response);
      if (!mounted || paid == null) return;

      final talep = TalepModel(
        id: paid['request_id']?.toString() ?? response['request_id']?.toString() ?? const Uuid().v4(),
        musteriAdi: _userName,
        musteriId: _userId ?? _userName,
        telefon: '',
        aracPlaka: _plakaController.text.toUpperCase(),
        aracMarka: 'Belirtilmedi',
        aracModel: 'Belirtilmedi',
        durum: 'Beklemede',
        olusturulma: DateTime.now(),
        aciklama: 'Mobil uygulama talebi. İlan: ${_ilanLinkController.text}',
        sehir: _secilenSehir!,
        expertizFirmasi: _secilenFirma!.name,
        expertizPaketi: _secilenPaket!.name,
        paketFiyati: _secilenPaket!.price,
        hizmetBedeli: _hizmetBedeli,
        toplamTutar: (paid['amount_tl'] as num?)?.toDouble() ?? _toplamTutar,
        isPaid: true,
      );
      _showSuccessDialog(talep);
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e is ApiException ? e.message : 'Bir hata oluştu: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// PayTR sayfasını açar ve onayı bekler. Ödendiyse sipariş durumunu, vazgeçildiyse null döner.
  Future<Map<String, dynamic>?> _odemeyiTamamla(Map<String, dynamic> checkout) async {
    final orderId = checkout['order_id'].toString();
    final iframeUrl = checkout['iframe_url']?.toString();
    final simulation = checkout['provider'] == 'simulation';
    if (!simulation && iframeUrl != null && iframeUrl.isNotEmpty) {
      await launchUrl(Uri.parse(iframeUrl), mode: LaunchMode.externalApplication);
    }
    if (!mounted) return null;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? info;
        bool busy = false;
        return StatefulBuilder(
          builder: (ctx, setDialog) {
            Future<void> check({bool? simulate}) async {
              setDialog(() {
                busy = true;
                info = null;
              });
              try {
                final status = simulate == null
                    ? await _api.getCheckoutStatus(orderId)
                    : await _api.simulateCheckout(orderId, success: simulate);
                if (status['status'] == 'paid') {
                  if (dialogContext.mounted) Navigator.pop(dialogContext, status);
                  return;
                }
                setDialog(() => info = status['status'] == 'failed'
                    ? 'Ödeme başarısız oldu; kartınızdan çekim yapılmadı.'
                    : 'Ödeme onayı henüz gelmedi. Ödemeyi tamamladıysanız birkaç saniye sonra tekrar kontrol edin.');
              } catch (e) {
                setDialog(() => info = e is ApiException ? e.message : '$e');
              } finally {
                setDialog(() => busy = false);
              }
            }

            return AlertDialog(
              title: const Text('Ödeme'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tutar: ${((checkout['amount_tl'] as num?) ?? _toplamTutar).toStringAsFixed(2)} TL'),
                  const SizedBox(height: 8),
                  Text(simulation
                      ? 'Sunucu test ödeme modunda; gerçek çekim yapılmaz.'
                      : 'Ödemeyi açılan PayTR sayfasında tamamlayın, ardından "Ödemeyi Kontrol Et"e basın.'),
                  if (info != null) ...[
                    const SizedBox(height: 12),
                    Text(info!, style: const TextStyle(color: Color(0xFFD32F2F))),
                  ],
                ],
              ),
              actions: [
                TextButton(onPressed: busy ? null : () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
                if (simulation)
                  FilledButton(onPressed: busy ? null : () => check(simulate: true), child: const Text('Ödemeyi Onayla (test)'))
                else ...[
                  if (iframeUrl != null)
                    TextButton(
                      onPressed: busy ? null : () => launchUrl(Uri.parse(iframeUrl), mode: LaunchMode.externalApplication),
                      child: const Text('Ödeme Sayfasını Aç'),
                    ),
                  FilledButton(onPressed: busy ? null : () => check(), child: const Text('Ödemeyi Kontrol Et')),
                ],
              ],
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog(TalepModel talep) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Color(0xFF4CAF50),
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              'Ödemeniz Başarılı!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Talep No: ${talep.id}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Talebiniz oluşturuldu ve uzman ekibimize iletildi.\nEn kısa sürede sizinle iletişime geçilecektir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // Dialog kapat
                Navigator.pop(context); // Sayfayı kapat
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'TAMAM',
                style: TextStyle(
                  fontSize: 16,
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
}



