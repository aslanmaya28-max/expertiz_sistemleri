import 'package:flutter/material.dart';
import '../core/mappers/location_mapper.dart';
import '../models/personel_model.dart';
import '../services/personel_service.dart';

/// PersonelManagement - Enterprise Grade Personnel Management Dashboard
/// 
/// ARCHITECTURAL RULES:
/// - Uses PersonelService as single data source
/// - Uses LocationMapper for display ONLY
/// - No string-based location fields
/// - No dynamic or loosely typed logic
/// - ADMIN ONLY SCREEN
class PersonelManagement extends StatefulWidget {
  const PersonelManagement({super.key});

  @override
  State<PersonelManagement> createState() => _PersonelManagementState();
}

class _PersonelManagementState extends State<PersonelManagement> {
  // PersonelService as single data source
  final PersonelService _personelService = PersonelService();
  
  // Location mapper for display purposes ONLY
  final LocationMapper _locationMapper = LocationMapper();
  
  // Search keyword
  String _aramaKelimesi = '';
  
  @override
  void initState() {
    super.initState();
    _personelService.loadPersoneller();
    _personelService.addListener(_onPersonelChanged);
  }
  
  @override
  void dispose() {
    _personelService.removeListener(_onPersonelChanged);
    super.dispose();
  }
  
  void _onPersonelChanged() {
    setState(() {});
  }
  
  /// Get filtered personnel based on search
  List<PersonelModel> _getFilteredPersoneller() {
    if (_aramaKelimesi.isEmpty) {
      return _personelService.personeller;
    }
    
    final lowerKeyword = _aramaKelimesi.toLowerCase();
    
    return _personelService.personeller.where((personel) {
      // Search in name
      if (personel.ad.toLowerCase().contains(lowerKeyword) ||
          personel.soyad.toLowerCase().contains(lowerKeyword)) {
        return true;
      }
      
      // Search in title
      if (personel.unvan.toLowerCase().contains(lowerKeyword)) {
        return true;
      }
      
      // Search in city name using LocationMapper
      final ilAdi = _locationMapper.getIlAdi(personel.ilId);
      if (ilAdi.toLowerCase().contains(lowerKeyword)) {
        return true;
      }
      
      // Search in region name using LocationMapper
      final bolgeAdi = _locationMapper.getBolgeAdi(personel.bolgeId);
      if (bolgeAdi.toLowerCase().contains(lowerKeyword)) {
        return true;
      }
      
      return false;
    }).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    final filteredPersoneller = _getFilteredPersoneller();
    final toplamPersonel = _personelService.personelCount;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personel Yönetimi'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) => setState(() => _aramaKelimesi = value),
                decoration: const InputDecoration(
                  hintText: 'Personel ara...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
          ),
          
          // Statistics
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildStatCard('Toplam', toplamPersonel.toString(), Icons.people, Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Filtreli', filteredPersoneller.length.toString(), Icons.filter_list, Colors.orange)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Personnel list
          Expanded(
            child: filteredPersoneller.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'Personel bulunamadı',
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredPersoneller.length,
                    itemBuilder: (context, index) {
                      final personel = filteredPersoneller[index];
                      return _buildPersonelCard(personel);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  /// Build personnel card
  Widget _buildPersonelCard(PersonelModel personel) {
    // Use LocationMapper to get names for display ONLY
    final ilAdi = _locationMapper.getIlAdi(personel.ilId);
    final bolgeAdi = _locationMapper.getBolgeAdi(personel.bolgeId);
    final bolgeRenk = _locationMapper.getBolgeRenk(personel.bolgeId);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bolgeRenk.withValues(alpha: 0.2),
          child: Text(
            personel.ad[0].toUpperCase(),
            style: TextStyle(color: bolgeRenk, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          personel.tamAd,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unvan: ${personel.unvan}'),
            // Display location using LocationMapper - NO string-based logic
            Text('Konum: $ilAdi, $bolgeAdi'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          // Navigate to personnel detail
        },
      ),
    );
  }
  
  /// Build statistics card
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}