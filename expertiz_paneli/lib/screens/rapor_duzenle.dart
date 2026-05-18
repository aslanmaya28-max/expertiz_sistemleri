import 'package:flutter/material.dart';
import '../models/arac_rapor_model.dart';

class RaporDuzenle extends StatefulWidget {
  final AracRapor rapor;
  final Function(AracRapor)? onKaydet;

  const RaporDuzenle({
    super.key,
    required this.rapor,
    this.onKaydet,
  });

  @override
  State<RaporDuzenle> createState() => _RaporDuzenleState();
}

class _RaporDuzenleState extends State<RaporDuzenle> {
  final _formKey = GlobalKey<FormState>();
  final _plakaController = TextEditingController();
  final _markaController = TextEditingController();
  final _modelController = TextEditingController();
  final _yilController = TextEditingController();
  final _sehirController = TextEditingController();
  final _ilceController = TextEditingController();
  final _ekspertizFirmasiController = TextEditingController();
  final _secilenPaketController = TextEditingController();
  final _hizmetBedeliController = TextEditingController();
  final _paketFiyatiController = TextEditingController();
  final _toplamTutarController = TextEditingController();
  final _hasarTutarController = TextEditingController();

  String _selectedDurum = 'OdemeBekliyor';

  @override
  void initState() {
    super.initState();
    _plakaController.text = widget.rapor.plaka ?? '';
    _markaController.text = widget.rapor.marka ?? '';
    _modelController.text = widget.rapor.model ?? '';
    _yilController.text = widget.rapor.yil ?? '';
    _sehirController.text = widget.rapor.sehir ?? '';
    _ilceController.text = widget.rapor.ilce ?? '';
    _ekspertizFirmasiController.text = widget.rapor.ekspertizFirmasi ?? '';
    _secilenPaketController.text = widget.rapor.secilenPaket ?? '';
    _hizmetBedeliController.text = widget.rapor.hizmetBedeli.toString();
    _paketFiyatiController.text = widget.rapor.paketFiyati.toString();
    _toplamTutarController.text = widget.rapor.toplamTutar.toString();
    _hasarTutarController.text = widget.rapor.hasarTutar.toString();
    _selectedDurum = widget.rapor.durum;
  }

  @override
  void dispose() {
    _plakaController.dispose();
    _markaController.dispose();
    _modelController.dispose();
    _yilController.dispose();
    _sehirController.dispose();
    _ilceController.dispose();
    _ekspertizFirmasiController.dispose();
    _secilenPaketController.dispose();
    _hizmetBedeliController.dispose();
    _paketFiyatiController.dispose();
    _toplamTutarController.dispose();
    _hasarTutarController.dispose();
    super.dispose();
  }

  void _kaydet() {
    if (_formKey.currentState!.validate()) {
      final guncellenenRapor = AracRapor(
        id: widget.rapor.id,
        musteriId: widget.rapor.musteriId,
        personelId: widget.rapor.personelId,
        olusturmaTarihi: widget.rapor.olusturmaTarihi,
        durum: _selectedDurum,
        ilanLinki: widget.rapor.ilanLinki,
        plaka: _plakaController.text,
        marka: _markaController.text,
        model: _modelController.text,
        yil: _yilController.text,
        sehir: _sehirController.text,
        ilce: _ilceController.text,
        ekspertizFirmasi: _ekspertizFirmasiController.text,
        secilenPaket: _secilenPaketController.text,
        hizmetBedeli: double.tryParse(_hizmetBedeliController.text) ?? 0.0,
        paketFiyati: double.tryParse(_paketFiyatiController.text) ?? 0.0,
        toplamTutar: double.tryParse(_toplamTutarController.text) ?? 0.0,
        hasarTutar: double.tryParse(_hasarTutarController.text) ?? 0.0,
        olusturanKullanici: widget.rapor.olusturanKullanici,
        aiAnaliziYapildiMi: widget.rapor.aiAnaliziYapildiMi,
        aiPiyasaDegeri: widget.rapor.aiPiyasaDegeri,
        aiOnerilenAlimFiyati: widget.rapor.aiOnerilenAlimFiyati,
        aiAltiAylikGetiri: widget.rapor.aiAltiAylikGetiri,
        aiBirYillikGetiri: widget.rapor.aiBirYillikGetiri,
        aiYorumu: widget.rapor.aiYorumu,
        aiDegerKaybi: widget.rapor.aiDegerKaybi,
      );

      widget.onKaydet?.call(guncellenenRapor);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapor Düzenle'),
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
              // Plaka
              TextFormField(
                controller: _plakaController,
                decoration: const InputDecoration(
                  labelText: 'Plaka',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Plaka zorunludur';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Marka
              TextFormField(
                controller: _markaController,
                decoration: const InputDecoration(
                  labelText: 'Marka',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Marka zorunludur';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Model
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Model zorunludur';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Yıl
              TextFormField(
                controller: _yilController,
                decoration: const InputDecoration(
                  labelText: 'Yıl',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Yıl zorunludur';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Şehir
              TextFormField(
                controller: _sehirController,
                decoration: const InputDecoration(
                  labelText: 'Şehir',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // İlçe
              TextFormField(
                controller: _ilceController,
                decoration: const InputDecoration(
                  labelText: 'İlçe',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Ekspertiz Firması
              TextFormField(
                controller: _ekspertizFirmasiController,
                decoration: const InputDecoration(
                  labelText: 'Ekspertiz Firması',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Seçilen Paket
              TextFormField(
                controller: _secilenPaketController,
                decoration: const InputDecoration(
                  labelText: 'Seçilen Paket',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Hizmet Bedeli
              TextFormField(
                controller: _hizmetBedeliController,
                decoration: const InputDecoration(
                  labelText: 'Hizmet Bedeli (TL)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Paket Fiyatı
              TextFormField(
                controller: _paketFiyatiController,
                decoration: const InputDecoration(
                  labelText: 'Paket Fiyatı (TL)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Toplam Tutar
              TextFormField(
                controller: _toplamTutarController,
                decoration: const InputDecoration(
                  labelText: 'Toplam Tutar (TL)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Hasar Tutarı
              TextFormField(
                controller: _hasarTutarController,
                decoration: const InputDecoration(
                  labelText: 'Hasar Tutarı (TL)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Durum Seçimi
              DropdownButtonFormField<String>(
                initialValue: _selectedDurum,
                decoration: const InputDecoration(
                  labelText: 'Rapor Durumu',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'OdemeBekliyor',
                    child: Text('Ödeme Bekliyor'),
                  ),
                  DropdownMenuItem(
                    value: 'OnayBekliyor',
                    child: Text('Onay Bekliyor'),
                  ),
                  DropdownMenuItem(
                    value: 'Onaylandi',
                    child: Text('Onaylandı'),
                  ),
                  DropdownMenuItem(
                    value: 'Reddedildi',
                    child: Text('Reddedildi'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDurum = value!;
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
                child: const Text(
                  'Raporu Güncelle',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
