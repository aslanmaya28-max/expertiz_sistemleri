import 'package:flutter/material.dart';
import '../models/personel_model.dart';
import '../core/constants/roles.dart';

class PersonelDuzenle extends StatefulWidget {
  final PersonelModel? personel;
  final Function(PersonelModel)? onKaydet;

  const PersonelDuzenle({
    super.key,
    this.personel,
    this.onKaydet,
  });

  @override
  State<PersonelDuzenle> createState() => _PersonelDuzenleState();
}

class _PersonelDuzenleState extends State<PersonelDuzenle> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _adController = TextEditingController();
  final _soyadController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonController = TextEditingController();
  final _unvanController = TextEditingController();
  final _ilIdController = TextEditingController();
  final _bolgeIdController = TextEditingController();
  final _departmanController = TextEditingController();
  final _pozisyonController = TextEditingController();
  final _maasController = TextEditingController();
  final _adresController = TextEditingController();
  final _ilController = TextEditingController();
  final _ilceController = TextEditingController();
  final _egitimController = TextEditingController();
  final _acilKontakController = TextEditingController();
  final _acilTelefonController = TextEditingController();
  final _notlarController = TextEditingController();
  final _uzmanlikAlaniController = TextEditingController();
  final _bolgeController = TextEditingController();

  UserRole _selectedRol = UserRole.fieldStaff;
  bool _aktif = true;
  DateTime? _iseBaslamaTarihi;
  int? _tamamlananGorevSayisi;
  double? _ortalamaPuan;

  @override
  void initState() {
    super.initState();
    _loadPersonelData();
  }

  void _loadPersonelData() {
    if (widget.personel != null) {
      final p = widget.personel!;
      _adController.text = p.ad;
      _soyadController.text = p.soyad;
      _emailController.text = p.email ?? '';
      _telefonController.text = p.telefon ?? '';
      _unvanController.text = p.unvan;
      _ilIdController.text = p.ilId.toString();
      _bolgeIdController.text = p.bolgeId.toString();
      _departmanController.text = p.departman ?? '';
      _pozisyonController.text = p.pozisyon ?? '';
      _maasController.text = p.maas?.toString() ?? '0';
      _adresController.text = p.adres ?? '';
      _ilController.text = p.il ?? '';
      _ilceController.text = p.ilce ?? '';
      _egitimController.text = p.egitimDurumu ?? '';
      _acilKontakController.text = p.acilDurumKontagi ?? '';
      _acilTelefonController.text = p.acilDurumTelefonu ?? '';
      _notlarController.text = p.notlar ?? '';
      _uzmanlikAlaniController.text = p.uzmanlikAlani ?? '';
      _bolgeController.text = p.bolge ?? '';

      _selectedRol = p.rol;
      _aktif = p.aktif;
      _iseBaslamaTarihi = p.iseBaslamaTarihi;
      _tamamlananGorevSayisi = p.tamamlananGorevSayisi;
      _ortalamaPuan = p.ortalamaPuan;
    }
  }

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    _emailController.dispose();
    _telefonController.dispose();
    _unvanController.dispose();
    _ilIdController.dispose();
    _bolgeIdController.dispose();
    _departmanController.dispose();
    _pozisyonController.dispose();
    _maasController.dispose();
    _adresController.dispose();
    _ilController.dispose();
    _ilceController.dispose();
    _egitimController.dispose();
    _acilKontakController.dispose();
    _acilTelefonController.dispose();
    _notlarController.dispose();
    _uzmanlikAlaniController.dispose();
    _bolgeController.dispose();
    super.dispose();
  }

  void _kaydet() {
    if (_formKey.currentState!.validate()) {
      final yeniPersonel = PersonelModel(
        id: widget.personel?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        ad: _adController.text.trim(),
        soyad: _soyadController.text.trim(),
        unvan: _unvanController.text.trim(),
        ilId: int.tryParse(_ilIdController.text.trim()) ?? 0,
        bolgeId: int.tryParse(_bolgeIdController.text.trim()) ?? 0,
        email: _emailController.text.trim(),
        telefon: _telefonController.text.trim(),
        rol: _selectedRol,
        kayitTarihi: widget.personel?.kayitTarihi ?? DateTime.now(),
        aktif: _aktif,
        departman: _departmanController.text.trim().isEmpty ? null : _departmanController.text.trim(),
        pozisyon: _pozisyonController.text.trim().isEmpty ? null : _pozisyonController.text.trim(),
        iseBaslamaTarihi: _iseBaslamaTarihi ?? DateTime.now(),
        maas: double.tryParse(_maasController.text) ?? 0.0,
        egitimDurumu: _egitimController.text.trim().isEmpty ? null : _egitimController.text.trim(),
        acilDurumKontagi: _acilKontakController.text.trim().isEmpty ? null : _acilKontakController.text.trim(),
        acilDurumTelefonu: _acilTelefonController.text.trim().isEmpty ? null : _acilTelefonController.text.trim(),
        notlar: _notlarController.text.trim().isEmpty ? null : _notlarController.text.trim(),
        adres: _adresController.text.trim().isEmpty ? null : _adresController.text.trim(),
        il: _ilController.text.trim(),
        ilce: _ilceController.text.trim(),
        uzmanlikAlani: _uzmanlikAlaniController.text.trim().isEmpty ? null : _uzmanlikAlaniController.text.trim(),
        bolge: _bolgeController.text.trim().isEmpty ? null : _bolgeController.text.trim(),
        tamamlananGorevSayisi: _tamamlananGorevSayisi,
        ortalamaPuan: _ortalamaPuan,
      );

      widget.onKaydet?.call(yeniPersonel);
      Navigator.pop(context);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _iseBaslamaTarihi ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _iseBaslamaTarihi) {
      setState(() {
        _iseBaslamaTarihi = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.personel == null ? 'Yeni Personel' : 'Personel Düzenle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _kaydet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildSection('Temel Bilgiler', [
                _buildTextFormField('Ad', _adController, Icons.person, isRequired: true),
                _buildTextFormField('Soyad', _soyadController, Icons.person, isRequired: true),
                _buildTextFormField('E-posta', _emailController, Icons.email, isRequired: true, keyboardType: TextInputType.emailAddress),
                _buildTextFormField('Telefon', _telefonController, Icons.phone, isRequired: true, keyboardType: TextInputType.phone),
                _buildTextFormField('Unvan', _unvanController, Icons.business_center, isRequired: true),
                ListTile(
                  leading: const Icon(Icons.date_range),
                  title: const Text('İşe Başlama Tarihi'),
                  subtitle: Text(_iseBaslamaTarihi != null 
                      ? '${_iseBaslamaTarihi!.day}/${_iseBaslamaTarihi!.month}/${_iseBaslamaTarihi!.year}'
                      : 'Seçiniz'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context),
                ),
              ]),
              const SizedBox(height: 20),
              _buildSection('İş Bilgileri', [
                DropdownButtonFormField<UserRole>(
                  initialValue: _selectedRol,
                  decoration: const InputDecoration(labelText: 'Rol', prefixIcon: Icon(Icons.work), border: OutlineInputBorder()),
                  items: UserRole.values.map((rol) {
                    return DropdownMenuItem<UserRole>(
                      value: rol,
                      child: Text(rol.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRol = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildTextFormField('İl ID', _ilIdController, Icons.map, isRequired: true),
                _buildTextFormField('Bölge ID', _bolgeIdController, Icons.map, isRequired: true),
                _buildTextFormField('Departman', _departmanController, Icons.business_center),
                _buildTextFormField('Pozisyon', _pozisyonController, Icons.work_outline),
                _buildTextFormField('Maaş (TL)', _maasController, Icons.attach_money, keyboardType: TextInputType.number),
                _buildTextFormField('Uzmanlık Alanı', _uzmanlikAlaniController, Icons.workspace_premium),
                _buildTextFormField('Bölge', _bolgeController, Icons.map),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField(String label, TextEditingController controller, IconData icon, {
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        validator: isRequired ? (value) {
          if (value == null || value.isEmpty) {
            return '$label zorunludur';
          }
          return null;
        } : null,
      ),
    );
  }
}
