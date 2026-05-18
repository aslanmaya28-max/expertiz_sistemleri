import 'package:flutter/material.dart';

class AracKabulFormu extends StatefulWidget {
  const AracKabulFormu({super.key});

  @override
  State<AracKabulFormu> createState() => _AracKabulFormuState();
}

class _AracKabulFormuState extends State<AracKabulFormu> {
  final _formKey = GlobalKey<FormState>();
  final _plakaController = TextEditingController();
  final _markaController = TextEditingController();
  final _modelController = TextEditingController();
  final _yilController = TextEditingController();
  final _kilometreController = TextEditingController();
  final _saseNoController = TextEditingController();
  final _musteriAdSoyadController = TextEditingController();
  final _musteriTelefonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Araç Kabul Formu')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Araç Bilgileri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _plakaController,
                decoration: const InputDecoration(labelText: 'Plaka'),
                validator: (v) => v?.isEmpty ?? true ? 'Zorunlu alan' : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _markaController,
                      decoration: const InputDecoration(labelText: 'Marka'),
                      validator: (v) => v?.isEmpty ?? true ? 'Zorunlu alan' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(labelText: 'Model'),
                      validator: (v) => v?.isEmpty ?? true ? 'Zorunlu alan' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _yilController,
                      decoration: const InputDecoration(labelText: 'Yıl'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty ?? true ? 'Zorunlu alan' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _kilometreController,
                      decoration: const InputDecoration(labelText: 'Kilometre'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty ?? true ? 'Zorunlu alan' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _saseNoController,
                decoration: const InputDecoration(labelText: 'Şase No'),
                validator: (v) => v?.isEmpty ?? true ? 'Zorunlu alan' : null,
              ),
              const SizedBox(height: 24),
              const Text('Müşteri Bilgileri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _musteriAdSoyadController,
                decoration: const InputDecoration(labelText: 'Ad Soyad'),
                validator: (v) => v?.isEmpty ?? true ? 'Zorunlu alan' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _musteriTelefonController,
                decoration: const InputDecoration(labelText: 'Telefon'),
                keyboardType: TextInputType.phone,
                validator: (v) => v?.isEmpty ?? true ? 'Zorunlu alan' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Araç kabul edildi')),
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Kaydet'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
