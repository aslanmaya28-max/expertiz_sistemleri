import 'package:flutter/material.dart';
import '../../core/mappers/location_mapper.dart';
import '../../models/personel_model.dart';
import '../../core/constants/roles.dart';

/// PersonelDuzenle - Enterprise Grade Personnel Edit Screen
/// 
/// ARCHITECTURAL RULES:
/// - Uses PersonelModel with ID-based relationships
/// - Uses LocationMapper for display ONLY
/// - No string-based location fields
/// - No dynamic or loosely typed logic
class PersonelDuzenle extends StatefulWidget {
  final PersonelModel? personel;
  final Function(PersonelModel) onKaydet;

  const PersonelDuzenle({
    super.key,
    this.personel,
    required this.onKaydet,
  });

  @override
  State<PersonelDuzenle> createState() => _PersonelDuzenleState();
}

class _PersonelDuzenleState extends State<PersonelDuzenle> {
  // Location mapper for display purposes ONLY
  final LocationMapper _locationMapper = LocationMapper();
  
  // Form controllers
  final _adController = TextEditingController();
  final _soyadController = TextEditingController();
  final _unvanController = TextEditingController();
  final _ilIdController = TextEditingController();
  final _bolgeIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPersonelData();
  }

  void _loadPersonelData() {
    if (widget.personel != null) {
      final personel = widget.personel!;
      _adController.text = personel.ad;
      _soyadController.text = personel.soyad;
      _unvanController.text = personel.unvan;
      _ilIdController.text = personel.ilId.toString();
      _bolgeIdController.text = personel.bolgeId.toString();
    }
  }

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    _unvanController.dispose();
    _ilIdController.dispose();
    _bolgeIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get city and region names using LocationMapper for display ONLY
    final ilAdi = _locationMapper.getIlAdi(widget.personel?.ilId ?? 0);
    final bolgeId = widget.personel?.bolgeId ?? 0;
    final bolgeAdi = _locationMapper.getBolgeAdi(bolgeId);
    final bolgeRenk = _locationMapper.getBolgeRenk(bolgeId);

    return Scaffold(
      appBar: AppBar(
        title: Text('Personel Düzenle'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Personel info card
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personel Bilgileri',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Ad
                  TextFormField(
                    controller: _adController,
                    decoration: InputDecoration(
                      labelText: 'Ad',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    readOnly: true,
                  ),
                  SizedBox(height: 12),
                  
                  // Soyad
                  TextFormField(
                    controller: _soyadController,
                    decoration: InputDecoration(
                      labelText: 'Soyad',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    readOnly: true,
                  ),
                  SizedBox(height: 12),
                  
                  // Unvan
                  TextFormField(
                    controller: _unvanController,
                    decoration: InputDecoration(
                      labelText: 'Unvan',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
                    ),
                    readOnly: true,
                  ),
                  SizedBox(height: 12),
                  
                  // Location info - Display using LocationMapper
                  Text(
                    'Konum',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  
                  // City
                  Row(
                    children: [
                      Icon(Icons.location_city, color: bolgeRenk, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'İl: $ilAdi',
                              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                            ),
                            Text(
                              'Bölge: $bolgeAdi',
                              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  
                  // ID info
                  Text(
                    'ID Bilgileri',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'İl ID: ${widget.personel?.ilId ?? 0}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Bölge ID: ${widget.personel?.bolgeId ?? 0}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                        ),
                      ),
                    ],
                  ),
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _kaydet(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          ),
                          child: Text('Kaydet'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          ),
                          child: Text('İptal'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _kaydet() {
    // Validate form
    if (_adController.text.isEmpty ||
        _soyadController.text.isEmpty ||
        _unvanController.text.isEmpty ||
        _ilIdController.text.isEmpty ||
        _bolgeIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tüm alanlar doldurulmalı'), backgroundColor: Colors.red),
      );
      return;
    }

    // Create updated PersonelModel
    final updatedPersonel = PersonelModel(
      id: widget.personel?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      ad: _adController.text.trim(),
      soyad: _soyadController.text.trim(),
      unvan: _unvanController.text.trim(),
      ilId: int.tryParse(_ilIdController.text.trim()) ?? 0,
      bolgeId: int.tryParse(_bolgeIdController.text.trim()) ?? 0,
      rol: widget.personel?.rol ?? UserRole.fieldStaff,
    );

    widget.onKaydet(updatedPersonel);
    Navigator.pop(context);
  }
}
