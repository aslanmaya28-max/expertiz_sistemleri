import 'package:flutter/material.dart';
import 'dart:io';
import '../../models/ekspertiz_model.dart';
import '../../data/rapor_manager.dart';
import 'ic_ekspertiz_data.dart';

class IcEkspertizScreen extends StatefulWidget {
  final RaporManager raporManager;
  
  const IcEkspertizScreen({super.key, required this.raporManager});

  @override
  State<IcEkspertizScreen> createState() => _IcEkspertizScreenState();
}

class _IcEkspertizScreenState extends State<IcEkspertizScreen> {
  List<EkspertizItem> items = [];

  @override
  void initState() {
    super.initState();
    items = IcEkspertizData.getIcEkspertizItems();
    _mevcutVerileriYukle();
  }

  void _mevcutVerileriYukle() {
    final mevcutData = widget.raporManager.mevcutRapor?.icEkspertizData ?? {};
    
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
    // TODO: FotoUtil implement edilecek
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fotoğraf özelliği yakında eklenecek'),
        backgroundColor: Colors.orange,
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
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Kapat'),
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
    
    widget.raporManager.icEkspertizVerisiGuncelle(kayitData);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('İç ekspertiz verileri kaydedildi'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  Color _getDurumRenk(String durum) {
    switch(durum) {
      case "Iyi": return Colors.green;
      case "Orta": return Colors.orange;
      case "Kotu": return Colors.red;
      case "Yok": return Colors.grey;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('İç Ekspertiz Kontrolü'),
        centerTitle: true,
        backgroundColor: Colors.purple,
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
                  color: Colors.purple[50],
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
                            child: Padding( // Added Padding to maintain original layout as SizedBox does not have a padding property
                              padding: EdgeInsets.only(top: 8),
                              child: SizedBox(
                                child: Text(
                                  item.bolumAdi,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
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
                                      value,
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
                                    ? Icon(Icons.photo_library, color: Colors.green, size: 18)
                                    : Icon(Icons.camera_alt, size: 18, color: Colors.grey),
                                padding: EdgeInsets.zero,
                                onPressed: () => item.fotografPath != null
                                    ? _fotografGoster(index)
                                    : _fotografEkle(index),
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
