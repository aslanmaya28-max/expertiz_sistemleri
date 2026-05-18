import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class EkspertizItem {
  String bolumAdi;
  String durum;
  String aciklama;
  String? fotografPath;
  List<String> durumSecenekleri;

  EkspertizItem({
    required this.bolumAdi,
    required this.durum,
    required this.aciklama,
    this.fotografPath,
    required this.durumSecenekleri,
  });

  Map<String, dynamic> toJson() {
    return {
      'bolumAdi': bolumAdi,
      'durum': durum,
      'aciklama': aciklama,
      'fotografPath': fotografPath,
      'durumSecenekleri': durumSecenekleri,
      'kayitTarihi': DateTime.now().toIso8601String(),
    };
  }

  factory EkspertizItem.fromJson(Map<String, dynamic> json) {
    return EkspertizItem(
      bolumAdi: json['bolumAdi'] ?? '',
      durum: json['durum'] ?? '',
      aciklama: json['aciklama'] ?? '',
      fotografPath: json['fotografPath'],
      durumSecenekleri: List<String>.from(json['durumSecenekleri'] ?? []),
    );
  }
}

class EkspertizRapor {
  String raporId;
  String talepId;
  String personelId;
  String personelAd;
  String musteriAd;
  String aracPlaka;
  String aracMarka;
  String aracModel;
  int aracYil;
  DateTime tarih;
  Map<String, dynamic> kaportaData;
  Map<String, dynamic> elektronikData;
  Map<String, dynamic> icEkspertizData;
  List<String> yuklenenDosyalar;
  String durum;
  DateTime? gonderilmeTarihi;
  DateTime? onaylanmaTarihi;
  String? adminNotlari;
  String? raporNotu;

  EkspertizRapor({
    required this.raporId,
    required this.talepId,
    required this.personelId,
    required this.personelAd,
    required this.musteriAd,
    required this.aracPlaka,
    required this.aracMarka,
    required this.aracModel,
    required this.aracYil,
    required this.tarih,
    required this.kaportaData,
    required this.elektronikData,
    required this.icEkspertizData,
    required this.yuklenenDosyalar,
    this.durum = 'Tamamlanmadi',
    this.gonderilmeTarihi,
    this.onaylanmaTarihi,
    this.adminNotlari,
    this.raporNotu,
  });

  Map<String, dynamic> toJson() {
    return {
      'raporId': raporId,
      'talepId': talepId,
      'personelId': personelId,
      'personelAd': personelAd,
      'musteriAd': musteriAd,
      'aracPlaka': aracPlaka,
      'aracMarka': aracMarka,
      'aracModel': aracModel,
      'aracYil': aracYil,
      'tarih': tarih.toIso8601String(),
      'kaportaData': kaportaData,
      'elektronikData': elektronikData,
      'icEkspertizData': icEkspertizData,
      'yuklenenDosyalar': yuklenenDosyalar,
      'durum': durum,
      'gonderilmeTarihi': gonderilmeTarihi?.toIso8601String(),
      'onaylanmaTarihi': onaylanmaTarihi?.toIso8601String(),
      'adminNotlari': adminNotlari,
      'raporNotu': raporNotu,
    };
  }

  factory EkspertizRapor.fromJson(Map<String, dynamic> json) {
    return EkspertizRapor(
      raporId: json['raporId'] ?? '',
      talepId: json['talepId'] ?? '',
      personelId: json['personelId'] ?? '',
      personelAd: json['personelAd'] ?? '',
      musteriAd: json['musteriAd'] ?? '',
      aracPlaka: json['aracPlaka'] ?? '',
      aracMarka: json['aracMarka'] ?? '',
      aracModel: json['aracModel'] ?? '',
      aracYil: json['aracYil'] ?? DateTime.now().year,
      tarih: DateTime.parse(json['tarih'] ?? DateTime.now().toIso8601String()),
      kaportaData: json['kaportaData'] ?? {},
      elektronikData: json['elektronikData'] ?? {},
      icEkspertizData: json['icEkspertizData'] ?? {},
      yuklenenDosyalar: List<String>.from(json['yuklenenDosyalar'] ?? []),
      durum: json['durum'] ?? 'Tamamlanmadi',
      gonderilmeTarihi: json['gonderilmeTarihi'] != null 
          ? DateTime.parse(json['gonderilmeTarihi'])
          : null,
      onaylanmaTarihi: json['onaylanmaTarihi'] != null 
          ? DateTime.parse(json['onaylanmaTarihi'])
          : null,
      adminNotlari: json['adminNotlari'],
      raporNotu: json['raporNotu'],
    );
  }

  // CopyWith metodu
  EkspertizRapor copyWith({
    String? raporId,
    String? talepId,
    String? personelId,
    String? personelAd,
    String? musteriAd,
    String? aracPlaka,
    String? aracMarka,
    String? aracModel,
    int? aracYil,
    DateTime? tarih,
    Map<String, dynamic>? kaportaData,
    Map<String, dynamic>? elektronikData,
    Map<String, dynamic>? icEkspertizData,
    List<String>? yuklenenDosyalar,
    String? durum,
    DateTime? gonderilmeTarihi,
    DateTime? onaylanmaTarihi,
    String? adminNotlari,
    String? raporNotu,
  }) {
    return EkspertizRapor(
      raporId: raporId ?? this.raporId,
      talepId: talepId ?? this.talepId,
      personelId: personelId ?? this.personelId,
      personelAd: personelAd ?? this.personelAd,
      musteriAd: musteriAd ?? this.musteriAd,
      aracPlaka: aracPlaka ?? this.aracPlaka,
      aracMarka: aracMarka ?? this.aracMarka,
      aracModel: aracModel ?? this.aracModel,
      aracYil: aracYil ?? this.aracYil,
      tarih: tarih ?? this.tarih,
      kaportaData: kaportaData ?? this.kaportaData,
      elektronikData: elektronikData ?? this.elektronikData,
      icEkspertizData: icEkspertizData ?? this.icEkspertizData,
      yuklenenDosyalar: yuklenenDosyalar ?? this.yuklenenDosyalar,
      durum: durum ?? this.durum,
      gonderilmeTarihi: gonderilmeTarihi ?? this.gonderilmeTarihi,
      onaylanmaTarihi: onaylanmaTarihi ?? this.onaylanmaTarihi,
      adminNotlari: adminNotlari ?? this.adminNotlari,
      raporNotu: raporNotu ?? this.raporNotu,
    );
  }

  // İstatistikler
  int get toplamKontrolNoktasi {
    return kaportaData.length + elektronikData.length + icEkspertizData.length;
  }

  int get tamamlananKontrolNoktasi {
    int tamamlanan = 0;
    
    void kontrolEt(Map<String, dynamic> data) {
      data.forEach((key, value) {
        if (value is Map && value['durum'] != null && value['durum'].toString().isNotEmpty) {
          tamamlanan++;
        }
      });
    }
    
    kontrolEt(kaportaData);
    kontrolEt(elektronikData);
    kontrolEt(icEkspertizData);
    
    return tamamlanan;
  }

  double get ilerlemeOrani {
    if (toplamKontrolNoktasi == 0) return 0.0;
    return tamamlananKontrolNoktasi / toplamKontrolNoktasi;
  }

  // Durum renk ve ikonları
  Color get durumRengi {
    switch (durum) {
      case 'Tamamlanmadi': return Colors.orange;
      case 'Gonderildi': return Colors.blue;
      case 'Onaylandi': return Colors.green;
      case 'Reddedildi': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData get durumIkonu {
    switch (durum) {
      case 'Tamamlanmadi': return Icons.access_time;
      case 'Gonderildi': return Icons.send;
      case 'Onaylandi': return Icons.check_circle;
      case 'Reddedildi': return Icons.cancel;
      default: return Icons.help;
    }
  }

  String get formatliTarih => DateFormat('dd.MM.yyyy HH:mm').format(tarih);
  String? get formatliGonderilmeTarihi => 
      gonderilmeTarihi != null ? DateFormat('dd.MM.yyyy HH:mm').format(gonderilmeTarihi!) : null;
  String? get formatliOnaylanmaTarihi => 
      onaylanmaTarihi != null ? DateFormat('dd.MM.yyyy HH:mm').format(onaylanmaTarihi!) : null;
}
