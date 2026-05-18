import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'rapor_kaporta_sayfasi.dart';

class RaporIcMekan extends StatefulWidget {
  final Map<String, dynamic> aracBilgileri;

  const RaporIcMekan({super.key, required this.aracBilgileri});

  @override
  State<RaporIcMekan> createState() => _RaporIcMekanState();
}

class _RaporIcMekanState extends State<RaporIcMekan> {
  final List<String> durumSecenekleri = [
    'Çalışıyor',
    'Çalışmıyor',
    'Bozuk',
    'Değiştirilmiş',
    'Kusurlu',
    'Eksik',
    'Çizik',
    'Lekeli',
    'Yıpranmış'
  ];

  // İÇ MEKAN MADDELERİ
  final List<String> maddeler = [
    "Koltuklar (Ön)",
    "Koltuklar (Arka)",
    "Direksiyon",
    "Gösterge Paneli",
    "Klima Sistemi",
    "Ses Sistemi",
    "İç Aydınlatma",
    "Cam Kontrolleri",
    "Ayna Kontrolleri",
    "Havalandırma",
    "Koltuk Isıtma",
    "Koltuk Havalandırma",
    "Kontrol Paneli",
    "Elektrik Sistemleri",
    "Anahtarlar/Düğmeler",
    "Depo Kapağı",
    "Bagaj",
    "İç Döşeme",
    "Tavan Döşemesi",
    "Kokpit Temizliği",
    "Koltuk Hafızası",
    "Direksiyon Ayarları",
    "Hava Yastıkları",
    "Emniyet Kemerleri",
    "Güneşlikler",
    "Torpido Gözü",
    "Küçük Saklama Bölmeleri"
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
        title: const Text("İç Mekan Kontrol Raporu"),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          // 📋 ÖNCEKİ RAPOR ÖZETİ
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border.all(color: Colors.green),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📋 Mevcut Raporlar', 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Plaka: ${widget.aracBilgileri['plaka'] ?? "Belirtilmedi"}'),
                Text('Marka-Model: ${widget.aracBilgileri['marka'] ?? ""} ${widget.aracBilgileri['model'] ?? ""}'),
                const Text('Dış Ekspertiz: Tamamlandı ✓'),
              ],
            ),
          ),

          // İlerleme Çubuğu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.green[50],
            child: Row(
              children: [
                const Icon(Icons.chair, size: 20, color: Colors.green),
                const SizedBox(width: 8),
                const Text('İç Mekan Kontrol', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${raporListesi.where((item) => item['durum'] != null).length}/${maddeler.length}'),
              ],
            ),
          ),

          // 📝 İÇ MEKAN MADDELERİ LİSTESİ
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
                            color: Colors.green
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
                              icon: const Icon(Icons.camera_alt, color: Colors.green),
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
                                    border: Border.all(color: Colors.green),
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

          // 📝 İÇ MEKAN EK NOTLAR
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "📝 İç Mekan Ek Notlar",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ekNotController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "İç mekan ile ilgili ek notlarınızı buraya yazın...",
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
                    label: const Text('Geri (Dış Ekspertiz)'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('Kaydet ve İlerle', 
                      style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _tumAlanlarDoldurulduMu() ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _tumAlanlarDoldurulduMu()
                        ? () {
                            // Verileri birleştir ve ilerle
                            Map<String, dynamic> tumVeriler = {};
                            tumVeriler.addAll(widget.aracBilgileri);
                            tumVeriler['icMekanRapor'] = raporListesi;
                            tumVeriler['icMekanEkNotlar'] = _ekNotController.text;
                            
                            // Kaporta/Boya sayfasına geç - DÜZELTİLMİŞ
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RaporKaportaSayfasi(
                                  aracBilgileri: tumVeriler,
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
}