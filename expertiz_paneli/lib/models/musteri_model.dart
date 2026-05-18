import 'package:flutter/material.dart';

class Musteri {
  final String id;
  final String adSoyad;
  final String telefon;
  final String email;
  final DateTime kayitTarihi;
  final bool aktif;
  
  // İletişim bilgileri
  final String? adres;
  final String? il;
  final String? ilce;
  final String? vergiNo;
  final String? tcKimlik;
  
  // İstatistikler
  final int toplamExpertizSayisi;
  final int aktifTalepler;
  final double toplamHarcama;
  
  // Notlar ve tercihler
  final String? notlar;
  final List<String>? tercihEdilenMarkalar;

  Musteri({
    required this.id,
    required this.adSoyad,
    required this.telefon,
    required this.email,
    required this.kayitTarihi,
    this.aktif = true,
    this.adres,
    this.il,
    this.ilce,
    this.vergiNo,
    this.tcKimlik,
    this.toplamExpertizSayisi = 0,
    this.aktifTalepler = 0,
    this.toplamHarcama = 0,
    this.notlar,
    this.tercihEdilenMarkalar,
  });

  // JSON'dan Musteri nesnesi oluştur
  factory Musteri.fromJson(Map<String, dynamic> json) {
    return Musteri(
      id: json['id']?.toString() ?? '',
      adSoyad: json['adSoyad']?.toString() ?? '',
      telefon: json['telefon']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      kayitTarihi: json['kayitTarihi'] != null 
          ? DateTime.parse(json['kayitTarihi'].toString())
          : DateTime.now(),
      aktif: json['aktif'] ?? true,
      adres: json['adres']?.toString(),
      il: json['il']?.toString(),
      ilce: json['ilce']?.toString(),
      vergiNo: json['vergiNo']?.toString(),
      tcKimlik: json['tcKimlik']?.toString(),
      toplamExpertizSayisi: json['toplamExpertizSayisi'] != null 
          ? int.tryParse(json['toplamExpertizSayisi'].toString()) ?? 0 
          : 0,
      aktifTalepler: json['aktifTalepler'] != null 
          ? int.tryParse(json['aktifTalepler'].toString()) ?? 0 
          : 0,
      toplamHarcama: json['toplamHarcama'] != null 
          ? double.tryParse(json['toplamHarcama'].toString()) ?? 0.0 
          : 0.0,
      notlar: json['notlar']?.toString(),
      tercihEdilenMarkalar: json['tercihEdilenMarkalar'] != null
          ? List<String>.from(json['tercihEdilenMarkalar'])
          : null,
    );
  }

  // Musteri nesnesini JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'adSoyad': adSoyad,
      'telefon': telefon,
      'email': email,
      'kayitTarihi': kayitTarihi.toIso8601String(),
      'aktif': aktif,
      
      // Opsiyonel alanlar - null değerleri dahil etme
      if (adres != null) 'adres': adres,
      if (il != null) 'il': il,
      if (ilce != null) 'ilce': ilce,
      if (vergiNo != null) 'vergiNo': vergiNo,
      if (tcKimlik != null) 'tcKimlik': tcKimlik,
      'toplamExpertizSayisi': toplamExpertizSayisi,
      'aktifTalepler': aktifTalepler,
      'toplamHarcama': toplamHarcama,
      if (notlar != null) 'notlar': notlar,
      if (tercihEdilenMarkalar != null) 'tercihEdilenMarkalar': tercihEdilenMarkalar,
    };
  }

  Musteri copyWith({
    String? id,
    String? adSoyad,
    String? telefon,
    String? email,
    DateTime? kayitTarihi,
    bool? aktif,
    String? adres,
    String? il,
    String? ilce,
    String? vergiNo,
    String? tcKimlik,
    int? toplamExpertizSayisi,
    int? aktifTalepler,
    double? toplamHarcama,
    String? notlar,
    List<String>? tercihEdilenMarkalar,
  }) {
    return Musteri(
      id: id ?? this.id,
      adSoyad: adSoyad ?? this.adSoyad,
      telefon: telefon ?? this.telefon,
      email: email ?? this.email,
      kayitTarihi: kayitTarihi ?? this.kayitTarihi,
      aktif: aktif ?? this.aktif,
      adres: adres ?? this.adres,
      il: il ?? this.il,
      ilce: ilce ?? this.ilce,
      vergiNo: vergiNo ?? this.vergiNo,
      tcKimlik: tcKimlik ?? this.tcKimlik,
      toplamExpertizSayisi: toplamExpertizSayisi ?? this.toplamExpertizSayisi,
      aktifTalepler: aktifTalepler ?? this.aktifTalepler,
      toplamHarcama: toplamHarcama ?? this.toplamHarcama,
      notlar: notlar ?? this.notlar,
      tercihEdilenMarkalar: tercihEdilenMarkalar ?? this.tercihEdilenMarkalar,
    );
  }

  // Helper getters
  String get ad => adSoyad.split(' ')[0];
  String get soyad => adSoyad.split(' ').length > 1 ? adSoyad.split(' ').skip(1).join(' ') : '';
  String get durumText => aktif ? 'Aktif' : 'Pasif';
  String get konum => ilce != null && il != null ? '$ilce / $il' : 'Belirtilmemiş';
  
  // Sadakat seviyesi
  String get sadakatSeviyesi {
    if (toplamExpertizSayisi >= 10) return 'VIP';
    if (toplamExpertizSayisi >= 5) return 'Sadık';
    if (toplamExpertizSayisi >= 1) return 'Yeni';
    return 'Potansiyel';
  }

  // Sadakat rengi
  Color get sadakatRengi {
    switch (sadakatSeviyesi) {
      case 'VIP': return Colors.purple[600]!;
      case 'Sadık': return Colors.green[600]!;
      case 'Yeni': return Colors.blue[600]!;
      default: return Colors.grey[600]!;
    }
  }

  // Ortalama harcama
  double get ortalamaHarcama {
    if (toplamExpertizSayisi == 0) return 0.0;
    return toplamHarcama / toplamExpertizSayisi;
  }

  // Müşteri segmenti
  String get musteriSegmenti {
    if (toplamHarcama >= 10000) return 'Kurumsal';
    if (toplamHarcama >= 5000) return 'Premium';
    if (toplamHarcama >= 1000) return 'Standart';
    return 'Başlangıç';
  }

  // Geçerli müşteri kontrolü
  bool get isValid {
    return id.isNotEmpty && 
           adSoyad.isNotEmpty && 
           telefon.isNotEmpty && 
           email.isNotEmpty;
  }

  // Kayıt tarihi formatlı
  String get formatliKayitTarihi {
    return '${kayitTarihi.day}.${kayitTarihi.month}.${kayitTarihi.year}';
  }

  // Müşteri tipi
  String get musteriTipi {
    if (vergiNo != null && vergiNo!.isNotEmpty) return 'Kurumsal';
    if (tcKimlik != null && tcKimlik!.isNotEmpty) return 'Bireysel';
    return 'Belirtilmemiş';
  }

  // Debug için string reprezentasyonu
  @override
  String toString() {
    return 'Musteri(id: $id, adSoyad: $adSoyad, telefon: $telefon, email: $email, aktif: $aktif)';
  }

  // Eşitlik kontrolü
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Musteri && 
           other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Boş müşteri oluştur
  static Musteri empty() {
    return Musteri(
      id: '',
      adSoyad: '',
      telefon: '',
      email: '',
      kayitTarihi: DateTime.now(),
      aktif: false,
    );
  }

  // Popüler markalar (tercihler için)
  static List<String> get populerMarkalar => [
    'Toyota',
    'Volkswagen',
    'Ford',
    'Hyundai',
    'Renault',
    'Fiat',
    'Peugeot',
    'Opel',
    'Nissan',
    'BMW',
    'Mercedes-Benz',
    'Audi',
    'Honda',
    'Kia',
    'Mazda',
  ];

  // İller listesi
  static List<String> get iller => [
    'İstanbul',
    'Ankara',
    'İzmir',
    'Bursa',
    'Antalya',
    'Adana',
    'Konya',
    'Mersin',
    'Gaziantep',
    'Kocaeli',
    'Kayseri',
    'Diyarbakır',
    'Eskişehir',
    'Samsun',
    'Denizli',
  ];
}
