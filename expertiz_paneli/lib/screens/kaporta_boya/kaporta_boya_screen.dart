import 'package:flutter/material.dart';
import 'dart:io';
import '../../models/ekspertiz_model.dart';
import '../../utils/foto_util.dart';
import '../../data/rapor_manager.dart';
import 'kaporta_data.dart';

class KaportaBoyaScreen extends StatefulWidget {
  final RaporManager raporManager;
  
  const KaportaBoyaScreen({super.key, required this.raporManager});

  @override
  State<KaportaBoyaScreen> createState() => _KaportaBoyaScreenState();
}

class _KaportaBoyaScreenState extends State<KaportaBoyaScreen> {
  List<EkspertizItem> items = [];

  @override
  void initState() {
    super.initState();
    items = KaportaData.getKaportaItems();
    _mevcutVerileriYukle();
  }

  void _mevcutVerileriYukle() {
    final mevcutData = widget.raporManager.mevcutRapor?.kaportaData ?? {};
    
    for (var item in items) {
      if (mevcutData.containsKey(item.bolumAdi)) {
        final kayitliVeri = mevcutData[item.bolumAdi];
        item.durum = kayitliVeri['durum'] ?? item.durum;
        item.aciklama = kayitliVeri['aciklama'] ?? item.aciklama;
        item.fotografPath = kayitliVeri['fotografPath'];
      }
    }
  }

  Future<void> _fotografEkle(int index) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Fotoğraf Çek'),
              onTap: () async {
                Navigator.pop(context);
                final String? fotoPath = await FotoUtil.fotografCek();
                if (fotoPath != null && mounted) {
                  setState(() {
                    items[index].fotografPath = fotoPath;
                  });
                  _verileriKaydet();
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Galeriden Seç'),
              onTap: () async {
                Navigator.pop(context);
                final String? fotoPath = await FotoUtil.galeridenSec();
                if (fotoPath != null && mounted) {
                  setState(() {
                    items[index].fotografPath = fotoPath;
                  });
                  _verileriKaydet();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _fotografSil(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Fotoğrafı Sil'),
        content: Text('Bu fotoğrafı silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                items[index].fotografPath = null;
              });
              _verileriKaydet();
              Navigator.pop(context);
            },
            child: Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _fotografGoster(int index) {
    if (items[index].fotografPath != null) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  items[index].bolumAdi,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Image.file(File(items[index].fotografPath!)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Kapat'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _fotografSil(index);
                    },
                    child: Text('Sil', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  void _verileriKaydet() {
    Map<String, dynamic> kayitData = {};
    
    for (var item in items) {
      kayitData[item.bolumAdi] = item.toJson();
    }
    
    widget.raporManager.kaportaVerisiGuncelle(kayitData);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kaporta boya verileri kaydedildi'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  Color _getDurumRenk(String durum) {
    switch(durum) {
      case "Orjinal": return Colors.green;
      case "Boyali": return Colors.orange;
      case "Lokal Boyali": return Colors.blue;
      case "Cizik": return Colors.yellow[700]!;
      case "Gocuk": return Colors.red;
      case "Degisen": return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _getDurumLabel(String durum) {
    switch(durum) {
      case "Orjinal": return "Orjinal";
      case "Boyali": return "Boyalı";
      case "Lokal Boyali": return "Lokal Boyalı";
      case "Cizik": return "Çizik";
      case "Gocuk": return "Göçük";
      case "Degisen": return "Değişen";
      default: return durum;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kaporta Boya Kontrolü'),
        centerTitle: true,
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _verileriKaydet,
            tooltip: 'Tüm verileri kaydet',
          ),
        ],
      ),
      body: Column(
        children: [
          // İstatistik Kartı
          Card(
            margin: EdgeInsets.all(8),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Tamamlanan', style: TextStyle(fontSize: 12)),
                      Text(
                        '${items.where((item) => item.durum.isNotEmpty).length}/${items.length}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text('Fotoğraf', style: TextStyle(fontSize: 12)),
                      Text(
                        '${items.where((item) => item.fotografPath != null).length}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text('İlerleme', style: TextStyle(fontSize: 12)),
                      Text(
                        '${(widget.raporManager.ilerlemeOrani * 100).toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Liste
          Expanded(
            child: ListView(
              children: [
                // Başlık
                Container(
                  padding: EdgeInsets.all(12),
                  color: Colors.red[50],
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text('BÖLÜM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 2, child: Text('DURUM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 3, child: Text('AÇIKLAMA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 1, child: Text('FOTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                  ),
                ),
                
                // Liste Elemanları
                ...items.asMap().entries.map((entry) {
                  int index = entry.key;
                  EkspertizItem item = entry.value;
                  
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                      color: item.durum.isNotEmpty ? Colors.green[50] : null,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // BÖLÜM ADI
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                item.bolumAdi,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          
                          // DURUM SEÇENEĞİ
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 35,
                              child: DropdownButtonFormField<String>(
                                initialValue: item.durum.isEmpty ? null : item.durum,
                                decoration: InputDecoration(
                                  hintText: "Seçiniz",
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                style: TextStyle(fontSize: 11),
                                items: item.durumSecenekleri.map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      _getDurumLabel(value),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _getDurumRenk(value),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  setState(() {
                                    items[index].durum = newValue ?? '';
                                  });
                                  _verileriKaydet();
                                },
                              ),
                            ),
                          ),
                          
                          // AÇIKLAMA
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 35,
                              child: TextField(
                                controller: TextEditingController(text: item.aciklama),
                                decoration: InputDecoration(
                                  hintText: "Açıklama...",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  isDense: true,
                                ),
                                style: TextStyle(fontSize: 11),
                                onChanged: (value) {
                                  items[index].aciklama = value;
                                },
                                onEditingComplete: () {
                                  _verileriKaydet();
                                },
                              ),
                            ),
                          ),
                          
                          // FOTOĞRAF
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 35,
                              child: IconButton(
                                icon: item.fotografPath != null
                                    ? Icon(Icons.photo_library, color: Colors.green, size: 20)
                                    : Icon(Icons.camera_alt, size: 20, color: Colors.red),
                                padding: EdgeInsets.zero,
                                onPressed: () => item.fotografPath != null
                                    ? _fotografGoster(index)
                                    : _fotografEkle(index),
                                tooltip: item.fotografPath != null 
                                    ? 'Fotoğrafı görüntüle' 
                                    : 'Fotoğraf ekle',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
