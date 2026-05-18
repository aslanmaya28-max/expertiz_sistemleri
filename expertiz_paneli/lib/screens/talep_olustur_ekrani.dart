import 'package:flutter/material.dart';

class YeniTalepEkrani extends StatefulWidget {
  const YeniTalepEkrani({super.key});

  @override
  State<YeniTalepEkrani> createState() => _YeniTalepEkraniState();
}

class _YeniTalepEkraniState extends State<YeniTalepEkrani> {
  int _currentStep = 0;
  
  // Form Kontrolcüleri
  final _linkController = TextEditingController();
  final _markaController = TextEditingController();
  final _modelController = TextEditingController();
  
  // Seçimler
  String? _secilenSehir;
  String? _secilenFirma;
  double _firmaFiyati = 0;
  final double _hizmetBedeli = 6500;

  // Mock Veriler (Gerçekte API'den gelecek)
  final List<String> _sehirler = ['İstanbul', 'Ankara', 'İzmir', 'Bursa', 'Antalya'];
  
  final Map<String, List<Map<String, dynamic>>> _firmalar = {
    'İstanbul': [
      {'ad': 'Tarcanlar Ekspertiz', 'fiyat': 4500.0},
      {'ad': 'Pilot Garage', 'fiyat': 3500.0},
      {'ad': 'Oto Rapor', 'fiyat': 3000.0},
    ],
    'Ankara': [
      {'ad': 'Tarcanlar Ekspertiz', 'fiyat': 4000.0},
      {'ad': 'Pilot Garage', 'fiyat': 3200.0},
    ],
    // Diğer şehirler için varsayılan
    'default': [
      {'ad': 'Kurumsal Ekspertiz A.Ş.', 'fiyat': 3000.0},
    ]
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Ekspertiz Talebi'),
        elevation: 0,
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: _nextStep,
        onStepCancel: _prevStep,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue[800],
                    ),
                    child: Text(_currentStep == 2 ? 'ÖDEMEYİ TAMAMLA' : 'DEVAM ET'),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: details.onStepCancel,
                    child: const Text('GERİ'),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          _buildAracBilgileriStep(),
          _buildLokasyonFirmaStep(),
          _buildOdemeStep(),
        ],
      ),
    );
  }

  Step _buildAracBilgileriStep() {
    return Step(
      title: const Text('Araç'),
      content: Column(
        children: [
          _buildInfoCard(
            'İlan Linki ile Hızlı Giriş',
            'Sahibinden veya Arabam.com linkini yapıştırın, biz sizin için inceleyelim.',
            Icons.link,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _linkController,
            decoration: InputDecoration(
              labelText: 'İlan Linki (Opsiyonel)',
              hintText: 'https://...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Veya Manuel Giriş', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _markaController,
                  decoration: const InputDecoration(labelText: 'Marka', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(labelText: 'Model', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
        ],
      ),
      isActive: _currentStep >= 0,
    );
  }

  Step _buildLokasyonFirmaStep() {
    return Step(
      title: const Text('Firma'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _secilenSehir,
            decoration: const InputDecoration(
              labelText: 'Şehir Seçiniz',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_city),
            ),
            items: _sehirler.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (val) {
              setState(() {
                _secilenSehir = val;
                _secilenFirma = null;
                _firmaFiyati = 0;
              });
            },
          ),
          const SizedBox(height: 24),
          if (_secilenSehir != null) ...[
            const Text('Anlaşmalı Kurumsal Firmalar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...(_firmalar[_secilenSehir] ?? _firmalar['default']!).map((firma) {
              final isSelected = _secilenFirma == firma['ad'];
              return Card(
                elevation: isSelected ? 4 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isSelected ? Colors.blue : Colors.transparent, width: 2),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(Icons.business, color: isSelected ? Colors.blue : Colors.grey),
                  title: Text(firma['ad'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Full Ekspertiz Paketi'),
                  trailing: Text(
                    '${firma['fiyat']} TL',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.blue : Colors.black,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _secilenFirma = firma['ad'];
                      _firmaFiyati = firma['fiyat'];
                    });
                  },
                ),
              );
            }),
          ],
        ],
      ),
      isActive: _currentStep >= 1,
    );
  }

  Step _buildOdemeStep() {
    final toplam = _hizmetBedeli + _firmaFiyati;
    
    return Step(
      title: const Text('Ödeme'),
      content: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                _buildFiyatSatiri('Şirket Hizmet Bedeli', '$_hizmetBedeli TL', isBold: true),
                const Divider(height: 24),
                _buildFiyatSatiri('Seçilen Firma', _secilenFirma ?? '-'),
                const SizedBox(height: 8),
                _buildFiyatSatiri('Ekspertiz Ücreti', '$_firmaFiyati TL'),
                const Divider(height: 24, thickness: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOPLAM TUTAR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      '$toplam TL',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Kart Üzerindeki İsim',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Kart Numarası',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.credit_card),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: const TextField(
                  decoration: InputDecoration(
                    labelText: 'SKT (AA/YY)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: const TextField(
                  decoration: InputDecoration(
                    labelText: 'CVV',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      isActive: _currentStep >= 2,
    );
  }

  Widget _buildFiyatSatiri(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildInfoCard(String title, String desc, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[800]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900])),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.blue[800])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < 2) {
      if (_currentStep == 1 && _secilenFirma == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen bir ekspertiz firması seçiniz')),
        );
        return;
      }
      setState(() => _currentStep++);
    } else {
      // Ödeme Tamamlandı - Kaydet ve Çık
      _talepOlustur();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _talepOlustur() {
    // Burada normalde servise istek atılır
    // Biz şimdilik başarılı mesajı gösterip ana sayfaya dönelim
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: const Text(
          'Ödemeniz başarıyla alındı!\n\nTalebiniz oluşturuldu ve uzman ekiplerimize iletildi. En kısa sürede sizinle iletişime geçilecektir.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Dialog kapat
              Navigator.pop(context); // Sayfayı kapat
            },
            child: const Text('TAMAM'),
          ),
        ],
      ),
    );
  }
}
