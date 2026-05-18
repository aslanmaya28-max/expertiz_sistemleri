import 'package:flutter/material.dart';
import '../core/mappers/location_mapper.dart';
import '../models/personel_model.dart';
import '../services/personel_service.dart';

/// PersonelDashboard - Enterprise Grade Personnel Dashboard
/// 
/// ARCHITECTURAL RULES:
/// - Uses PersonelService as single data source
/// - Uses LocationMapper for display ONLY
/// - No string-based location fields
/// - No dynamic or loosely typed logic
class PersonelDashboard extends StatefulWidget {
  const PersonelDashboard({super.key});

  @override
  State<PersonelDashboard> createState() => _PersonelDashboardState();
}

class _PersonelDashboardState extends State<PersonelDashboard> {
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
        title: Text('Personel Dashboard'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: EdgeInsets.all(16),
            child: Container(
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
              child: TextField(
                onChanged: (value) => setState(() => _aramaKelimesi = value),
                decoration: InputDecoration(
                  hintText: 'Personel ara...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
          ),
          
          // Statistics
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildStatCard('Toplam', toplamPersonel.toString(), Icons.people, Colors.blue)),
                SizedBox(width: 12),
                Expanded(child: _buildStatCard('Filtreli', filteredPersoneller.length.toString(), Icons.filter_list, Colors.orange)),
              ],
            ),
          ),
          SizedBox(height: 16),
          
          // Personnel list
          Expanded(
            child: filteredPersoneller.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Personel bulunamadı',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
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
      margin: EdgeInsets.only(bottom: 12),
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
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unvan: ${personel.unvan}'),
            // Display location using LocationMapper - NO string-based logic
            Text('Konum: $ilAdi, $bolgeAdi'),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () {
          // Navigate to personnel detail
        },
      ),
    );
  }
  
  /// Build statistics card
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
