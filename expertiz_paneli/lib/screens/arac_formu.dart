import 'package:flutter/material.dart';
import 'rapor_dis_ekspertiz.dart'; // DIŞ EKSPERTİZ'e geçiş

class AracMarka {
  final String marka;
  final List<String> modeller;

  AracMarka({required this.marka, required this.modeller});
}

class AracTipi {
  final String tipi;
  final List<AracMarka> markalar;

  AracTipi({required this.tipi, required this.markalar});
}

final List<AracTipi> aracVeri = [
  // 🚗 OTOMOBİL - 20 Marka
  AracTipi(
    tipi: "Otomobil",
    markalar: [
      AracMarka(marka: "Fiat", modeller: ["Egea Sedan", "Egea HB", "Linea", "Punto", "Bravo"]),
      AracMarka(marka: "Renault", modeller: ["Clio", "Megane", "Symbol", "Fluence", "Talisman"]),
      AracMarka(marka: "Peugeot", modeller: ["208", "308", "408", "508"]),
      AracMarka(marka: "Citroen", modeller: ["C3", "C4", "C5", "C-Elysee"]),
      AracMarka(marka: "Volkswagen", modeller: ["Polo", "Golf", "Passat", "Jetta"]),
      AracMarka(marka: "Hyundai", modeller: ["i10", "i20", "i30", "Elantra"]),
      AracMarka(marka: "Toyota", modeller: ["Corolla", "Yaris", "Camry"]),
      AracMarka(marka: "Honda", modeller: ["Civic", "City", "Accord"]),
      AracMarka(marka: "Ford", modeller: ["Fiesta", "Focus", "Mondeo"]),
      AracMarka(marka: "Kia", modeller: ["Rio", "Ceed", "Stinger"]),
      AracMarka(marka: "Skoda", modeller: ["Fabia", "Octavia", "Superb"]),
      AracMarka(marka: "Alfa Romeo", modeller: ["Giulia", "Stelvio"]),
      AracMarka(marka: "Audi", modeller: ["A1", "A3", "A4", "A6"]),
      AracMarka(marka: "BMW", modeller: ["1 Serisi", "3 Serisi", "5 Serisi"]),
      AracMarka(marka: "Mercedes", modeller: ["A Serisi", "C Serisi", "E Serisi"]),
      AracMarka(marka: "Mini", modeller: ["Cooper", "Cooper S", "Clubman"]),
      AracMarka(marka: "Lexus", modeller: ["IS", "ES", "NX"]),
      AracMarka(marka: "Mazda", modeller: ["Mazda3", "Mazda6", "CX-3"]),
    ],
  ),

  // 🚙 SUV & PICKUP - 15 Marka
  AracTipi(
    tipi: "SUV & Pickup",
    markalar: [
      AracMarka(marka: "Toyota", modeller: ["RAV4", "Hilux", "C-HR"]),
      AracMarka(marka: "Hyundai", modeller: ["Kona", "Tucson", "Santa Fe"]),
      AracMarka(marka: "Peugeot", modeller: ["2008", "3008", "5008"]),
      AracMarka(marka: "Dacia", modeller: ["Duster", "Jogger", "Sandero Stepway"]),
      AracMarka(marka: "Nissan", modeller: ["Qashqai", "Juke", "X-Trail", "Navara"]),
      AracMarka(marka: "Volkswagen", modeller: ["T-Roc", "Tiguan", "Amarok"]),
      AracMarka(marka: "Mitsubishi", modeller: ["ASX", "Outlander", "L200"]),
      AracMarka(marka: "Ford", modeller: ["Kuga", "Puma", "Ranger"]),
      AracMarka(marka: "Jeep", modeller: ["Renegade", "Compass", "Cherokee"]),
      AracMarka(marka: "Mazda", modeller: ["CX-3", "CX-5", "CX-60"]),
      AracMarka(marka: "Subaru", modeller: ["Forester", "XV", "Outback"]),
      AracMarka(marka: "Land Rover", modeller: ["Range Rover Evoque", "Discovery Sport"]),
      AracMarka(marka: "Audi", modeller: ["Q2", "Q3", "Q5", "Q7"]),
      AracMarka(marka: "BMW", modeller: ["X1", "X3", "X5"]),
      AracMarka(marka: "Mercedes", modeller: ["GLA", "GLC", "GLE"]),
    ],
  ),

  // 🚙 ELEKTRİKLİ ARAÇLAR - 13 Marka
  AracTipi(
    tipi: "Elektrikli Araçlar",
    markalar: [
      AracMarka(marka: "Tesla", modeller: ["Model 3", "Model Y", "Model S", "Model X"]),
      AracMarka(marka: "Renault", modeller: ["ZOE", "Megane E-Tech"]),
      AracMarka(marka: "Fiat", modeller: ["500e"]),
      AracMarka(marka: "Hyundai", modeller: ["IONIQ 5", "Kona EV"]),
      AracMarka(marka: "BMW", modeller: ["i3", "i4", "iX"]),
      AracMarka(marka: "Mercedes", modeller: ["EQA", "EQB", "EQE", "EQS"]),
      AracMarka(marka: "Volkswagen", modeller: ["ID.3", "ID.4"]),
      AracMarka(marka: "Volvo", modeller: ["C40", "XC40 Recharge"]),
      AracMarka(marka: "Peugeot", modeller: ["e-208", "e-2008"]),
      AracMarka(marka: "TOGG", modeller: ["T10X", "T8X"]),
      AracMarka(marka: "MG", modeller: ["ZS EV", "5 EV"]),
      AracMarka(marka: "BYD", modeller: ["Han EV", "Tang EV"]),
      AracMarka(marka: "Cupra", modeller: ["Born"]),
    ],
  ),

  // 🚙 MİNİVAN & PANELVAN - 12 Marka
  AracTipi(
    tipi: "Minivan & Panelvan",
    markalar: [
      AracMarka(marka: "Fiat", modeller: ["Fiorino", "Doblo", "Scudo", "Talento"]),
      AracMarka(marka: "Ford", modeller: ["Tourneo Courier", "Transit Custom", "Connect"]),
      AracMarka(marka: "Renault", modeller: ["Kangoo", "Trafic", "Master"]),
      AracMarka(marka: "Volkswagen", modeller: ["Caddy", "Transporter", "Caravelle"]),
      AracMarka(marka: "Peugeot", modeller: ["Rifter", "Traveller", "Expert"]),
      AracMarka(marka: "Citroen", modeller: ["Berlingo", "Spacetourer", "Jumpy"]),
      AracMarka(marka: "Mercedes", modeller: ["Citan", "Vito", "Sprinter"]),
      AracMarka(marka: "Opel", modeller: ["Combo", "Vivaro", "Movano"]),
      AracMarka(marka: "Toyota", modeller: ["ProAce City", "ProAce Verso"]),
      AracMarka(marka: "Hyundai", modeller: ["H-1", "Staria"]),
      AracMarka(marka: "Nissan", modeller: ["NV200", "e-NV200"]),
      AracMarka(marka: "Mitsubishi", modeller: ["L300", "Delica"]),
    ],
  ),
];

class AracFormuSayfasi extends StatefulWidget {
  const AracFormuSayfasi({super.key});

  @override
  State<AracFormuSayfasi> createState() => _AracFormuSayfasiState();
}

class _AracFormuSayfasiState extends State<AracFormuSayfasi> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> formData = {};

  final List<String> motorSecenekleri = ['Benzin', 'Dizel', 'Hibrit', 'Elektrik'];
  final List<String> hasarDurumu = ['Var', 'Yok'];
  final List<String> durumSecenekleri = ['İyi', 'Orta', 'Kötü'];
  final List<String> evetHayir = ['Evet', 'Hayır'];
  final List<String> servisTipi = ['Yetkili Servis', 'Özel Servis'];

  String? secilenAracTipi;
  String? secilenMarka;
  List<String> mevcutMarkalar = [];
  List<String> mevcutModeller = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Araç Bilgileri')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🚗 ARAÇ BİLGİLERİ - YAN YANA DÜZEN
              const Text("🚗 Araç Bilgileri", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              // 1. SATIR: Araç Tipi - Plaka
              Row(
                children: [
                  Expanded(child: _buildAracTipiDropdown()),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField("Araç Plaka")),
                ],
              ),

              // 2. SATIR: Marka - Model
              Row(
                children: [
                  Expanded(child: _buildMarkaDropdown()),
                  const SizedBox(width: 10),
                  Expanded(child: _buildModelDropdown()),
                ],
              ),

              // 3. SATIR: KM - Motor - Şasi No
              Row(
                children: [
                  Expanded(child: _buildTextField("KM", keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDropdown("Motor Tipi", motorSecenekleri)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField("Şase No")),
                ],
              ),

              // 4. SATIR: TÜVTÜRK - Hasar Durumu - Hasar Adeti
              Row(
                children: [
                  Expanded(child: _buildDateField("Son TÜVTÜRK Muayene Tarihi")),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDropdown("Araç Hasar Durumu", hasarDurumu)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField("Hasar Adeti", keyboardType: TextInputType.number)),
                ],
              ),

              // Tek satır: Hasar Kayıt Miktarı
              _buildTextField("Hasar Kayıt Miktarı (°)", keyboardType: TextInputType.number),

              const SizedBox(height: 20),

              // 🚙 ARAÇ SAHİBİ BİLGİLERİ
              const Text("🚙 Araç Sahibi Bilgileri", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              // 1. SATIR: Araç Sahibi Ad Soyad
              Row(
                children: [
                  Expanded(child: _buildTextField("Araç Sahibi Ad Soyad")),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDropdown("Araç temiz mi geldi?", durumSecenekleri)),
                ],
              ),

              // 2. SATIR: Evveliyat - Pazarlık Açık mı?
              Row(
                children: [
                  Expanded(child: _buildDropdown("Araç evveliyat bilgisi", durumSecenekleri)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDropdown("Satıcı pazarlığa açık mı?", evetHayir)),
                ],
              ),

              // 3. SATIR: Pazarlık Miktarı - Servis Tipi
              Row(
                children: [
                  Expanded(child: _buildTextField("Pazarlık miktarı (varsa)", keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDropdown("Servis tipi", servisTipi)),
                ],
              ),

              // Tek satır: Son Bakım Tarihi
              _buildDateField("Son bakım tarihi"),

              const SizedBox(height: 30),

              // 🚙 KAYDET ve İLERLE BUTONU
              ElevatedButton.icon(
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text("Kaydet ve Dış Ekspertize Geç", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    // Tüm form verilerini al ve sonraki sayfaya geç
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RaporDisEkspertiz(
                          aracBilgileri: formData,
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAracTipiDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: "Araç Tipi"),
        items: aracVeri.map((tip) => DropdownMenuItem(value: tip.tipi, child: Text(tip.tipi))).toList(),
        onChanged: (val) {
          setState(() {
            secilenAracTipi = val;
            // Seçilen tipe göre markaları getir
            var secilenTip = aracVeri.firstWhere((tip) => tip.tipi == val, orElse: () => aracVeri.first);
            mevcutMarkalar = secilenTip.markalar.map((marka) => marka.marka).toList();
            secilenMarka = null;
            mevcutModeller = [];
            formData["Araç Tipi"] = val;
            formData["Marka"] = null;
            formData["Model"] = null;
          });
        },
      ),
    );
  }

  Widget _buildMarkaDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: "Marka"),
        items: mevcutMarkalar.isEmpty 
            ? [const DropdownMenuItem(value: null, child: Text("Önce araç tipi seçin"))]
            : mevcutMarkalar.map((marka) => DropdownMenuItem(value: marka, child: Text(marka))).toList(),
        onChanged: mevcutMarkalar.isEmpty ? null : (val) {
          setState(() {
            secilenMarka = val;
            // Seçilen markaya göre modelleri getir
            var secilenTip = aracVeri.firstWhere((tip) => tip.tipi == secilenAracTipi, orElse: () => aracVeri.first);
            var secilenMarkaObj = secilenTip.markalar.firstWhere((m) => m.marka == val, orElse: () => secilenTip.markalar.first);
            mevcutModeller = secilenMarkaObj.modeller;
            formData["Marka"] = val;
            formData["Model"] = null;
          });
        },
      ),
    );
  }

  Widget _buildModelDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: "Model"),
        items: mevcutModeller.isEmpty 
            ? [const DropdownMenuItem(value: null, child: Text("Önce marka seçin"))]
            : mevcutModeller.map((model) => DropdownMenuItem(value: model, child: Text(model))).toList(),
        onChanged: mevcutModeller.isEmpty ? null : (val) => formData["Model"] = val,
      ),
    );
  }

  Widget _buildTextField(String label, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
        onSaved: (val) => formData[label] = val,
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (val) => formData[label] = val,
      ),
    );
  }

  Widget _buildDateField(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        onTap: () async {
          final DateTime? date = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2030),
          );
          if (date != null) {
            setState(() => formData[label] = date.toString().split(" ")[0]);
          }
        },
        controller: TextEditingController(text: formData[label]?.toString() ?? ''),
      ),
    );
  }
}
