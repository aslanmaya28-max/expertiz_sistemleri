import 'package:flutter/material.dart';
import '../models/user_model.dart';

class KullaniciDuzenle extends StatefulWidget {
  final UserModel? kullanici;
  final Function(UserModel)? onKaydet;

  const KullaniciDuzenle({
    super.key,
    this.kullanici,
    this.onKaydet,
  });

  @override
  State<KullaniciDuzenle> createState() => _KullaniciDuzenleState();
}

class _KullaniciDuzenleState extends State<KullaniciDuzenle> {
  final _formKey = GlobalKey<FormState>();
  final _adSoyadController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonController = TextEditingController();
  
  String _selectedRol = 'user';
  bool _aktif = true;

  @override
  void initState() {
    super.initState();
    if (widget.kullanici != null) {
      _adSoyadController.text = widget.kullanici!.fullName;
      _emailController.text = widget.kullanici!.email;
      _telefonController.text = '';  // UserModel doesn't have telefon field
      _selectedRol = widget.kullanici!.role.toDatabaseValue;
      _aktif = true;  // UserModel doesn't have aktif field
    }
  }

  @override
  void dispose() {
    _adSoyadController.dispose();
    _emailController.dispose();
    _telefonController.dispose();
    super.dispose();
  }

  void _kaydet() {
    if (_formKey.currentState!.validate()) {
      final yeniKullanici = widget.kullanici?.copyWith(
        fullName: _adSoyadController.text.trim(),
        email: _emailController.text.trim(),
        role: _selectedRol == 'admin' ? UserRole.admin : _selectedRol == 'expert' ? UserRole.fieldStaff : UserRole.customer,
      ) ?? UserModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fullName: _adSoyadController.text.trim(),
        email: _emailController.text.trim(),
        role: _selectedRol == 'admin' ? UserRole.admin : _selectedRol == 'expert' ? UserRole.fieldStaff : UserRole.customer,
        createdAt: DateTime.now(),
      );

      widget.onKaydet?.call(yeniKullanici);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kullanici == null ? 'Yeni Kullanıcı' : 'Kullanıcı Düzenle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _kaydet,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Ad Soyad
              TextFormField(
                controller: _adSoyadController,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ad soyad zorunludur';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // E-posta
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'E-posta zorunludur';
                  }
                  if (!value.contains('@')) {
                    return 'Geçerli bir e-posta adresi girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Telefon
              TextFormField(
                controller: _telefonController,
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Telefon zorunludur';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Rol Seçimi
              DropdownButtonFormField<String>(
                initialValue: _selectedRol,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı Rolü',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'user',
                    child: Text('Standart Kullanıcı'),
                  ),
                  DropdownMenuItem(
                    value: 'expert',
                    child: Text('Expertiz Uzmanı'),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Sistem Yöneticisi'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRol = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Aktif/Pasif
              SwitchListTile(
                title: const Text('Kullanıcı Aktif'),
                value: _aktif,
                onChanged: (value) {
                  setState(() {
                    _aktif = value;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Kaydet Butonu
              ElevatedButton(
                onPressed: _kaydet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  widget.kullanici == null ? 'Kullanıcı Ekle' : 'Güncelle',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
