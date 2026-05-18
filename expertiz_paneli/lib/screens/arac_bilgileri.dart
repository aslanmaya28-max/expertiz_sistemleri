import '../models/arac_rapor_model.dart';
import 'package:flutter/material.dart';

class AracBilgileriSayfasi extends StatefulWidget {
  final Function(AracRapor) onRaporEkle;

  const AracBilgileriSayfasi({super.key, required this.onRaporEkle});

  @override
  State<AracBilgileriSayfasi> createState() => _AracBilgileriSayfasiState();
}

class _AracBilgileriSayfasiState extends State<AracBilgileriSayfasi> {
  final _formKey = GlobalKey<FormState>();
  final _plakaController = TextEditingController();
  final _markaController = TextEditingController();
  final _modelController = TextEditingController();
  final _yilController = TextEditingController();
  final _kmController = TextEditingController();
  final _saseController = TextEditingController();

  bool _hasarKaydiVar = false;
  final _hasarAdetController = TextEditingController();
  final _hasarTutarController = TextEditingController();

  void _kaydetVeIlerle() {
    if (_formKey.currentState!.validate()) {
      final yeniRapor = AracRapor(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        musteriId: 'musteri-id-placeholder',
        personelId: null,
        olusturmaTarihi: DateTime.now(),
        durum: 'OdemeBekliyor',
        ilanLinki: null,
        plaka: _plakaController.text,
        marka: _markaController.text,
        model: _modelController.text,
        yil: _yilController.text,
        sehir: null,
        ilce: null,
        ekspertizFirmasi: null,
        secilenPaket: null,
        hizmetBedeli: 6500.0,
        paketFiyati: 0.0,
        toplamTutar: 0.0,
        hasarTutar: 0.0,
        olusturanKullanici: null,
        aiAnaliziYapildiMi: false,
      );

      widget.onRaporEkle(yeniRapor);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rapor başarıyla oluşturuldu!'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _plakaController.dispose();
    _markaController.dispose();
    _modelController.dispose();
    _yilController.dispose();
    _kmController.dispose();
    _saseController.dispose();
    _hasarAdetController.dispose();
    _hasarTutarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Araç Bilgileri'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _bilgiAlani('Plaka', _plakaController, Icons.confirmation_number),
              const SizedBox(height: 16),
              _bilgiAlani('Marka', _markaController, Icons.directions_car),
              const SizedBox(height: 16),
              _bilgiAlani('Model', _modelController, Icons.model_training),
              const SizedBox(height: 16),
              _bilgiAlani('Yıl', _yilController, Icons.calendar_today,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _bilgiAlani('Kilometre', _kmController, Icons.speed,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _bilgiAlani('Şase No', _saseController, Icons.code),
              const SizedBox(height: 20),
              
              // Hasar Kaydı Bölümü
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hasar Kaydı Bilgisi',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Hasar Kayıtlı:'),
                          const SizedBox(width: 8),
                          Switch(
                            value: _hasarKaydiVar,
                            onChanged: (value) {
                              setState(() {
                                _hasarKaydiVar = value;
                              });
                            },
                          ),
                        ],
                      ),
                      if (_hasarKaydiVar) ...[
                        const SizedBox(height: 16),
                        _bilgiAlani('Hasar Kayıt Adeti', _hasarAdetController, 
                            Icons.format_list_numbered, keyboardType: TextInputType.number),
                        const SizedBox(height: 16),
                        _bilgiAlani('Toplam Hasar Tutarı (TL)', _hasarTutarController, 
                            Icons.attach_money, keyboardType: TextInputType.number),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _kaydetVeIlerle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Raporu Oluştur',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bilgiAlani(String label, TextEditingController controller, IconData icon,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Bu alan zorunludur';
        }
        return null;
      },
    );
  }
}
