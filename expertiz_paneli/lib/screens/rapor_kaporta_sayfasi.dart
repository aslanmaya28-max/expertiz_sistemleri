import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'rapor_onay_sayfasi.dart';

class RaporKaportaSayfasi extends StatefulWidget {
  final Map<String, dynamic> aracBilgileri;

  const RaporKaportaSayfasi({super.key, required this.aracBilgileri});

  @override
  State<RaporKaportaSayfasi> createState() => _RaporKaportaSayfasiState();
}

class _RaporKaportaSayfasiState extends State<RaporKaportaSayfasi> {
  final List<String> durumSecenekleri = [
    'Orijinal',
    'Çizik',
    'Boyalı',
    'Lokal Boya',
    'Değişen',
    'Göçük',
    'Çatlak',
    'Pas',
    'Tamir Edilmiş'
  ];

  // KAPORTA/BOYA MADDELERİ
  final List<String> maddeler = [
    "Tavan",
    "Ön Kaput",
    "Arka Bagaj Kapağı",
    "Sol Ön Çamurluk",
    "Sol Ön Kapı",
    "Sol Arka Kapı",
    "Sol Arka Çamurluk",
    "Sağ Ön Çamurluk",
    "Sağ Ön Kapı",
    "Sağ Arka Kapı",
    "Sağ Arka Çamurluk",
    "Ön Tampon",
    "Arka Tampon",
    "Sağ Üst Direk",
    "Sağ İç Direk",
    "Sağ Orta Direk",
    "Sol Üst Direk", 
    "Sol İç Direk",
    "Sol Orta Direk",
    "Sol Ön Şase",
    "Sağ Ön Şase",
    "Sol Arka Şase",
    "Sağ Arka Şase",
    "Motor Kaputu",
    "Bagaj Tabanı",
    "Çamurluk İçleri",
    "Kapı İçleri",
    "Boy Kalitesi (Genel)"
  ];

  final List<Map<String, dynamic>> raporListesi = [];
  final ImagePicker picker = ImagePicker();
  final TextEditingController _ekNotController = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (var madde in maddeler) {
      raporListesi.add({'madde': madde, 'durum': null, 'aciklama': '', 'foto': null});
    }
  }

  Future<void> _fotoSec(int index) async {
    final XFile? secilen = await picker.pickImage(source: ImageSource.camera);
    if (secilen != null) {
      setState(() {
        raporListesi[index]['foto'] = File(secilen.path);
      });
    }
  }

  void _fotoSil(int index) {
    setState(() {
      raporListesi[index]['foto'] = null;
    });
  }

  bool _tumAlanlarDoldurulduMu() {
    for (var item in raporListesi) {
      if (item['durum'] == null || item['durum']!.isEmpty) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kaporta / Boya Kontrol Raporu"),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          // 📋 ÖNCEKİ RAPOR ÖZETİ
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border.all(color: Colors.orange),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📋 Mevcut Raporlar', 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Plaka: ${widget.aracBilgileri['plaka'] ?? "Belirtilmedi"}'),
                Text('Marka-Model: ${widget.aracBilgileri['marka'] ?? ""} ${widget.aracBilgileri['model'] ?? ""}'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildDurumGostergesi('Dış', widget.aracBilgileri.containsKey('disEkspertizRapor')),
                    const SizedBox(width: 8),
                    _buildDurumGostergesi('İç', widget.aracBilgileri.containsKey('icMekanRapor')),
                    const SizedBox(width: 8),
                    _buildDurumGostergesi('Kaporta', false, aktif: true),
                  ],
                ),
              ],
            ),
          ),

          // İlerleme Çubuğu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange[50],
            child: Row(
              children: [
                const Icon(Icons.car_repair, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Kaporta/Boya Kontrol', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${raporListesi.where((item) => item['durum'] != null).length}/${maddeler.length}'),
              ],
            ),
          ),

          // 📝 KAPORTA/BOYA MADDELERİ LİSTESİ
          Expanded(
            child: ListView.builder(
              itemCount: raporListesi.length,
              itemBuilder: (context, index) {
                var item = raporListesi[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['madde'], 
                          style: const TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16,
                            color: Colors.orange
                          )
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: "Durum",
                                  border: OutlineInputBorder(),
                                ),
                                items: durumSecenekleri.map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e))
                                ).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    item['durum'] = val;
                                  });
                                },
                                initialValue: item['durum'],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  labelText: "Açıklama",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) => item['aciklama'] = val,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.orange),
                              onPressed: () => _fotoSec(index),
                            ),
                            if (item['foto'] != null)
                              const Icon(Icons.check_circle, color: Colors.green),
                          ],
                        ),
                        // Fotoğraf önizleme (varsa)
                        if (item['foto'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.orange),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Image.file(
                                    item['foto'] as File,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _fotoSil(index),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 📝 KAPORTA/BOYA EK NOTLAR
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "📝 Kaporta/Boya Ek Notlar",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ekNotController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "Kaporta ve boya ile ilgili ek notlarınızı buraya yazın...",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),

          // 📱 KAYDET ve İLERLE BUTONU
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Geri (İç Mekan)'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('Kaydet ve Onay Sayfasına Geç', 
                      style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _tumAlanlarDoldurulduMu() ? Colors.orange : Colors.grey,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _tumAlanlarDoldurulduMu()
                        ? () {
                            // Tüm verileri birleştir
                            Map<String, dynamic> tumVeriler = {};
                            tumVeriler.addAll(widget.aracBilgileri);
                            tumVeriler['kaportaBoyaRapor'] = raporListesi;
                            tumVeriler['kaportaBoyaEkNotlar'] = _ekNotController.text;
                            
                            // Onay sayfasına geç - DÜZELTİLMİŞ KISIM
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RaporOnaySayfasi(
                                  aracBilgi: tumVeriler,  // aracBilgileri -> aracBilgi
                                  raporlar: raporListesi, // raporlar parametresi eklendi
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurumGostergesi(String text, bool tamamlandi, {bool aktif = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: aktif ? Colors.orange.withValues(alpha: 0.2) : 
               tamamlandi ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: aktif ? Colors.orange : 
                 tamamlandi ? Colors.green : Colors.grey,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            aktif ? Icons.radio_button_checked : 
                   tamamlandi ? Icons.check_circle : Icons.circle,
            size: 12,
            color: aktif ? Colors.orange : 
                   tamamlandi ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: aktif ? Colors.orange : 
                     tamamlandi ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
