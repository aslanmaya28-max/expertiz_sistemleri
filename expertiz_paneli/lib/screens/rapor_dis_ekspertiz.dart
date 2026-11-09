import 'package:yerimebak_sistemleri/tema/renkler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'rapor_ic_mekan.dart';

class RaporDisEkspertiz extends StatefulWidget {
  final Map<String, dynamic> aracBilgileri;

  const RaporDisEkspertiz({super.key, required this.aracBilgileri});

  @override
  State<RaporDisEkspertiz> createState() => _RaporDisEkspertizState();
}

class _RaporDisEkspertizState extends State<RaporDisEkspertiz> {
  final List<String> durumSecenekleri = [
    'Mükemmel',
    'İyi',
    'Orta',
    'Kötü',
    'Hasarlı',
    'Değişmiş',
    'Çizik',
    'Göçük',
    'Boyalı'
  ];

  // DIŞ EKSPERTİZ MADDELERİ
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
    "Ön Cam",
    "Arka Cam",
    "Sol Ön Cam",
    "Sol Arka Cam",
    "Sağ Ön Cam",
    "Sağ Arka Cam",
    "Sol Yan Ayna",
    "Sağ Yan Ayna",
    "Arka Tampon",
    "Jantlar (Ön Sol)",
    "Jantlar (Ön Sağ)",
    "Jantlar (Arka Sol)",
    "Jantlar (Arka Sağ)",
    "Lastikler (Ön Sol)",
    "Lastikler (Ön Sağ)",
    "Lastikler (Arka Sol)",
    "Lastikler (Arka Sağ)",
    "Ön Far Sol",
    "Ön Far Sağ",
    "Arka Stop Sol",
    "Arka Stop Sağ",
    "Sinyal Lambaları",
    "Plakalar"
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
        title: const Text("Dış Ekspertiz Raporu"),
        backgroundColor: context.renkler.birincil,
      ),
      body: Column(
        children: [
          // ARAÇ BİLGİLERİ
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.renkler.yuzeyIkincil,
              border: Border.all(color: context.renkler.birincil),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Araç Bilgileri', 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Plaka: ${widget.aracBilgileri['plaka'] ?? "Belirtilmedi"}'),
                Text('Marka: ${widget.aracBilgileri['marka'] ?? ""}'),
                Text('Model: ${widget.aracBilgileri['model'] ?? ""}'),
                Text('Yıl: ${widget.aracBilgileri['yil']?.toString() ?? ""}'),
                Text('Şase No: ${widget.aracBilgileri['saseNo'] ?? ""}'),
              ],
            ),
          ),

          // İlerleme Çubuğu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: context.renkler.birincilYuzey,
            child: Row(
              children: [
                Icon(LucideIcons.carFront, size: 20, color: context.renkler.birincil),
                const SizedBox(width: 8),
                const Text('Dış Ekspertiz Kontrol', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${raporListesi.where((item) => item['durum'] != null).length}/${maddeler.length}'),
              ],
            ),
          ),

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
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16,
                            color: context.renkler.birincil
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
                              icon: Icon(LucideIcons.camera, color: context.renkler.birincil),
                              onPressed: () => _fotoSec(index),
                            ),
                            if (item['foto'] != null)
                              Icon(LucideIcons.circleCheck, color: context.renkler.birincilMetin),
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
                                    border: Border.all(color: context.renkler.birincil),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Image.file(
                                    item['foto'] as File,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(LucideIcons.trash2, color: context.renkler.tehlike),
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

          // DIŞ EKSPERTİZ EK NOTLAR
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Dış Ekspertiz Ek Notlar",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ekNotController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "Dış ekspertiz ile ilgili ek notlarınızı buraya yazın...",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),

          // KAYDET ve İLERLE BUTONU
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.renkler.yuzeyIkincil,
              border: Border.all(color: context.renkler.girdiKenarlik),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(LucideIcons.arrowLeft),
                    label: const Text('Geri (Rapor Detay)'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(LucideIcons.save, color: context.renkler.birincilUstu),
                    label: Text('Kaydet ve İlerle', 
                      style: TextStyle(color: context.renkler.birincilUstu)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _tumAlanlarDoldurulduMu() ? context.renkler.birincil : context.renkler.metinIkincil,
                      foregroundColor: context.renkler.birincilUstu,
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _tumAlanlarDoldurulduMu()
                        ? () {
                            // Verileri birleştir ve ilerle
                            Map<String, dynamic> tumVeriler = {};
                            tumVeriler.addAll(widget.aracBilgileri);
                            tumVeriler['disEkspertizRapor'] = raporListesi;
                            tumVeriler['disEkspertizEkNotlar'] = _ekNotController.text;
                            
                            // İç Mekan sayfasına geç
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RaporIcMekan(
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