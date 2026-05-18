import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../personnel/personnel_dashboard.dart'; // PersonelAnaSayfa yerine PersonnelDashboard'a dönüştü

class RaporOnaySayfasi extends StatefulWidget {
  final Map<String, dynamic> aracBilgi;
  final List<Map<String, dynamic>> raporlar;

  const RaporOnaySayfasi({
    super.key,
    required this.aracBilgi,
    required this.raporlar,
  });

  @override
  State<RaporOnaySayfasi> createState() => _RaporOnaySayfasiState();
}

class _RaporOnaySayfasiState extends State<RaporOnaySayfasi> {
  final ImagePicker picker = ImagePicker();
  final int maxFotoSayisi = 10;
  final int maxDosyaSayisi = 5;

  List<File> secilenFotolar = [];
  List<File> secilenDosyalar = [];
  bool raporGonderildi = false;

  Future<void> _fotoSec() async {
    if (secilenFotolar.length >= maxFotoSayisi) {
      _showUyari("Maksimum $maxFotoSayisi fotoğraf yükleyebilirsiniz");
      return;
    }

    final XFile? secilen = await picker.pickImage(source: ImageSource.camera);
    if (secilen != null) {
      setState(() {
        secilenFotolar.add(File(secilen.path));
      });
    }
  }

  Future<void> _galeridenFotoSec() async {
    if (secilenFotolar.length >= maxFotoSayisi) {
      _showUyari("Maksimum $maxFotoSayisi fotoğraf yükleyebilirsiniz");
      return;
    }

    final List<XFile> secilenler = await picker.pickMultiImage();
    for (var foto in secilenler) {
      if (secilenFotolar.length < maxFotoSayisi) {
        setState(() {
          secilenFotolar.add(File(foto.path));
        });
      }
    }
  }

  Future<void> _dosyaSec() async {
    if (secilenDosyalar.length >= maxDosyaSayisi) {
      _showUyari("Maksimum $maxDosyaSayisi dosya yükleyebilirsiniz");
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() {
        for (var file in result.files) {
          if (secilenDosyalar.length < maxDosyaSayisi) {
            secilenDosyalar.add(File(file.path!));
          }
        }
      });
    }
  }

  void _fotoSil(int index) {
    setState(() {
      secilenFotolar.removeAt(index);
    });
  }

  void _dosyaSil(int index) {
    setState(() {
      secilenDosyalar.removeAt(index);
    });
  }

  void _showUyari(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _raporuGonder() {
    if (secilenFotolar.isEmpty) {
      _showUyari("Lütfen en az 1 fotoğraf yükleyin");
      return;
    }

    // Tüm rapor verilerini birleştir
    Map<String, dynamic> tamRapor = {};
    tamRapor.addAll(widget.aracBilgi);
    tamRapor['kaportaBoyaRapor'] = widget.raporlar;
    tamRapor['fotograflar'] = secilenFotolar;
    tamRapor['dosyalar'] = secilenDosyalar;
    tamRapor['raporTarihi'] = DateTime.now().toString();
    tamRapor['durum'] = 'Beklemede';

    setState(() {
      raporGonderildi = true;
    });

    // Personel Dashboard'a Dön
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PersonnelDashboard()),
      (route) => false,
    );

    _showBasariliMesaj("Rapor başarıyla admin paneline gönderildi!");
  }

  void _showBasariliMesaj(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kurumsal Expertiz Rapor Onayı'),
        backgroundColor: Colors.purple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📋 ARAÇ BİLGİLERİ ÖZETİ
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📋 Araç Bilgileri Özeti',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Plaka: ${widget.aracBilgi["plaka"] ?? widget.aracBilgi["Araç Plaka"]}'),
                  Text('Marka: ${widget.aracBilgi["marka"] ?? widget.aracBilgi["Marka"]}'),
                  Text('Model: ${widget.aracBilgi["model"] ?? widget.aracBilgi["Model"]}'),
                  const SizedBox(height: 4),
                  const Text('✓ Dış Ekspertiz Tamamlandı'),
                  const Text('✓ İç Mekan Kontrolü Tamamlandı'),
                  const Text('✓ Kaporta/Boya Kontrolü Tamamlandı'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 📷 FOTOĞRAF YÜKLEME
            const Text('📷 Fotoğraflar (Maksimum 10)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${secilenFotolar.length}/10 fotoğraf yüklendi',
              style: TextStyle(color: Colors.grey[600])),

            const SizedBox(height: 10),

            // FOTOĞRAF YÜKLEME BUTONLARI
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt, size: 20),
                    label: const Text('Kamera ile Çek'),
                    onPressed: _fotoSec,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library, size: 20),
                    label: const Text('Galeriden Seç'),
                    onPressed: _galeridenFotoSec,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // YÜKLENEN FOTOĞRAFLAR
            if (secilenFotolar.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.8,
                ),
                itemCount: secilenFotolar.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(secilenFotolar[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _fotoSil(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 20),

            // 📁 DOSYA YÜKLEME
            const Text('📁 Belgeler (Maksimum 5)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${secilenDosyalar.length}/5 dosya yüklendi',
              style: TextStyle(color: Colors.grey[600])),

            const SizedBox(height: 10),

            // DOSYA YÜKLEME BUTONU
            ElevatedButton.icon(
              icon: const Icon(Icons.attach_file, size: 20),
              label: const Text('Belge Yükle (PDF, Word, Excel, Resim)'),
              onPressed: _dosyaSec,
            ),

            const SizedBox(height: 10),

            // YÜKLENEN DOSYALAR
            if (secilenDosyalar.isNotEmpty)
              Column(
                children: secilenDosyalar.asMap().entries.map((entry) {
                  int index = entry.key;
                  File dosya = entry.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                      title: Text(
                        dosya.path.split('/').last,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _dosyaSil(index),
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 30),

            // 🚀 TÜM RAPORLARI GÖNDER BUTONU
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple),
              ),
              child: Column(
                children: [
                  const Text('🚀 Rapor Özeti',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Araç Bilgileri: Tamamlandı ✓'),
                  const Text('Dış Ekspertiz: Tamamlandı ✓'),
                  const Text('İç Mekan: Tamamlandı ✓'),
                  Text('Kaporta/Boya: ${widget.raporlar.length} madde ✓'),
                  Text('Fotoğraflar: ${secilenFotolar.length}/10'),
                  Text('Dosyalar: ${secilenDosyalar.length}/5'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text('TÜM RAPORLARI ONAYA GÖNDER',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _raporuGonder,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
