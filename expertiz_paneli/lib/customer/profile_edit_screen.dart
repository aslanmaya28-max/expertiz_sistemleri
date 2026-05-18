/// MÜŞTERİ PROFİL DÜZENLEME EKRANI
///
/// UserProvider üzerinden çalışır - tek kaynak doğruluk
/// Supabase profiles tablosuna yazar
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/user_provider.dart';
import '../core/theme/futuristic_theme.dart';
import '../core/widgets/glass_card.dart';
import '../core/mappers/location_mapper.dart';
import '../core/constants/location_data.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adSoyadController = TextEditingController();
  final _telefonController = TextEditingController();
  final _firmaController = TextEditingController();
  final _vergiDaireController = TextEditingController();
  final _vergiNoController = TextEditingController();
  final _adresController = TextEditingController();
  
  int _selectedIlId = 0;
  String _selectedIlce = '';
  bool _isSaving = false;
  String? _error;

  final LocationMapper _locationMapper = LocationMapper();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;

    _adSoyadController.text = user.fullName;
    _telefonController.text = user.phone ?? '';
    _selectedIlId = user.ilId ?? 0;
    _selectedIlce = user.district ?? '';
    _firmaController.text = ''; // UserModel'de firma alanı yok
    _vergiDaireController.text = ''; // UserModel'de vergiDairesi alanı yok
    _vergiNoController.text = ''; // UserModel'de vergiNo alanı yok
    _adresController.text = user.address ?? '';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final userId = userProvider.userId;
      if (userId == null) throw Exception('Oturum bulunamadı');

      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
        'full_name': _adSoyadController.text.trim(),
        'phone': _telefonController.text.trim(),
        'firma': _firmaController.text.trim(),
        'vergi_dairesi': _vergiDaireController.text.trim(),
        'vergi_no': _vergiNoController.text.trim(),
        'adres': _adresController.text.trim(),
        'il_id': _selectedIlId > 0 ? _selectedIlId : null,
        'ilce': _selectedIlce.isNotEmpty ? _selectedIlce : null,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // UserProvider'ı güncelle
      await userProvider.loadCurrentUser();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil başarıyla güncellendi'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kayıt hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _adSoyadController.dispose();
    _telefonController.dispose();
    _firmaController.dispose();
    _vergiDaireController.dispose();
    _vergiNoController.dispose();
    _adresController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili Düzenle'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kaydet'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KİŞİSEL BİLGİLER
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kişisel Bilgiler',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _adSoyadController,
                      decoration: const InputDecoration(
                        labelText: 'Ad Soyad',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _telefonController,
                      decoration: const InputDecoration(
                        labelText: 'Telefon',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _adresController,
                      decoration: const InputDecoration(
                        labelText: 'Adres',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // KONUM BİLGİLERİ
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Konum Bilgileri',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // İl Seçimi - Dropdown
                    DropdownButtonFormField<int>(
                      initialValue: _selectedIlId > 0 ? _selectedIlId : null,
                      decoration: const InputDecoration(
                        labelText: 'İl',
                        prefixIcon: Icon(Icons.location_city),
                      ),
                      items: LocationData.cities.map((city) {
                        return DropdownMenuItem<int>(
                          value: city.plakaKodu,
                          child: Text(city.ilAdi),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedIlId = value ?? 0;
                          _selectedIlce = '';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // İlçe Seçimi - Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedIlce.isNotEmpty ? _selectedIlce : null,
                      decoration: const InputDecoration(
                        labelText: 'İlçe',
                        prefixIcon: Icon(Icons.map),
                      ),
                      items: _getIlceler().map((ilce) {
                        return DropdownMenuItem<String>(
                          value: ilce,
                          child: Text(ilce),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedIlce = value ?? '');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // FİRMA BİLGİLERİ (Kurumsal Müşteri)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Firma Bilgileri (Opsiyonel)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _firmaController,
                      decoration: const InputDecoration(
                        labelText: 'Firma Adı',
                        prefixIcon: Icon(Icons.business),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _vergiDaireController,
                      decoration: const InputDecoration(
                        labelText: 'Vergi Dairesi',
                        prefixIcon: Icon(Icons.receipt),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _vergiNoController,
                      decoration: const InputDecoration(
                        labelText: 'Vergi Numarası',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Hata: $_error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              // KAYDET BUTONU
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FuturisticTheme.neon,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Profili Kaydet', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _getIlceler() {
    if (_selectedIlId <= 0) return [];
    for (final city in LocationData.cities) {
      if (city.plakaKodu == _selectedIlId) {
        return _locationMapper.getIlceler(city.plakaKodu);
      }
    }
    return [];
  }
}
