import 'package:flutter/material.dart';

class Arac {
  final String id;
  final String plaka;
  final String marka;
  final String model;
  final int yil;
  final String renk;
  final String yakitTuru;
  final String vitesTuru;
  final int kilometre;
  final String motorHacmi;
  final String motorGucu;
  final String saseNo;
  final String ruhsatSahibi;
  final DateTime kayitTarihi;
  final bool aktif;
  
  // Ek bilgiler
  final String? aciklama;
  final double? fiyat;
  final String? konum;
  final String? durumu;
  final List<String>? fotograflar;
  final DateTime? sonGuncellemeTarihi;
  final String? guncelleyenKullanici;

  const Arac({
    required this.id,
    required this.plaka,
    required this.marka,
    required this.model,
    required this.yil,
    required this.renk,
    required this.yakitTuru,
    required this.vitesTuru,
    required this.kilometre,
    required this.motorHacmi,
    required this.motorGucu,
    required this.saseNo,
    required this.ruhsatSahibi,
    required this.kayitTarihi,
    this.aktif = true,
    
    // Opsiyonel alanlar
    this.aciklama,
    this.fiyat,
    this.konum,
    this.durumu,
    this.fotograflar,
    this.sonGuncellemeTarihi,
    this.guncelleyenKullanici,
  });

  // JSON'dan Arac nesnesi oluştur
  factory Arac.fromJson(Map<String, dynamic> json) {
    return Arac(
      id: json['id']?.toString() ?? '',
      plaka: json['plaka']?.toString() ?? '',
      marka: json['marka']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      yil: json['yil'] != null ? int.tryParse(json['yil'].toString()) ?? 0 : 0,
      renk: json['renk']?.toString() ?? '',
      yakitTuru: json['yakitTuru']?.toString() ?? '',
      vitesTuru: json['vitesTuru']?.toString() ?? '',
      kilometre: json['kilometre'] != null ? int.tryParse(json['kilometre'].toString()) ?? 0 : 0,
      motorHacmi: json['motorHacmi']?.toString() ?? '',
      motorGucu: json['motorGucu']?.toString() ?? '',
      saseNo: json['saseNo']?.toString() ?? '',
      ruhsatSahibi: json['ruhsatSahibi']?.toString() ?? '',
      kayitTarihi: json['kayitTarihi'] != null 
          ? DateTime.parse(json['kayitTarihi'].toString())
          : DateTime.now(),
      aktif: json['aktif'] ?? true,
      
      // Opsiyonel alanlar
      aciklama: json['aciklama']?.toString(),
      fiyat: json['fiyat'] != null ? double.tryParse(json['fiyat'].toString()) : null,
      konum: json['konum']?.toString(),
      durumu: json['durumu']?.toString(),
      fotograflar: json['fotograflar'] != null 
          ? List<String>.from(json['fotograflar'])
          : null,
      sonGuncellemeTarihi: json['sonGuncellemeTarihi'] != null
          ? DateTime.parse(json['sonGuncellemeTarihi'].toString())
          : null,
      guncelleyenKullanici: json['guncelleyenKullanici']?.toString(),
    );
  }

  // Arac nesnesini JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plaka': plaka,
      'marka': marka,
      'model': model,
      'yil': yil,
      'renk': renk,
      'yakitTuru': yakitTuru,
      'vitesTuru': vitesTuru,
      'kilometre': kilometre,
      'motorHacmi': motorHacmi,
      'motorGucu': motorGucu,
      'saseNo': saseNo,
      'ruhsatSahibi': ruhsatSahibi,
      'kayitTarihi': kayitTarihi.toIso8601String(),
      'aktif': aktif,
      
      // Opsiyonel alanlar - null değerleri dahil etme
      if (aciklama != null) 'aciklama': aciklama,
      if (fiyat != null) 'fiyat': fiyat,
      if (konum != null) 'konum': konum,
      if (durumu != null) 'durumu': durumu,
      if (fotograflar != null) 'fotograflar': fotograflar,
      if (sonGuncellemeTarihi != null) 'sonGuncellemeTarihi': sonGuncellemeTarihi!.toIso8601String(),
      if (guncelleyenKullanici != null) 'guncelleyenKullanici': guncelleyenKullanici,
    };
  }

  // Aracı kopyala (güncelleme için)
  Arac copyWith({
    String? id,
    String? plaka,
    String? marka,
    String? model,
    int? yil,
    String? renk,
    String? yakitTuru,
    String? vitesTuru,
    int? kilometre,
    String? motorHacmi,
    String? motorGucu,
    String? saseNo,
    String? ruhsatSahibi,
    DateTime? kayitTarihi,
    bool? aktif,
    String? aciklama,
    double? fiyat,
    String? konum,
    String? durumu,
    List<String>? fotograflar,
    DateTime? sonGuncellemeTarihi,
    String? guncelleyenKullanici,
  }) {
    return Arac(
      id: id ?? this.id,
      plaka: plaka ?? this.plaka,
      marka: marka ?? this.marka,
      model: model ?? this.model,
      yil: yil ?? this.yil,
      renk: renk ?? this.renk,
      yakitTuru: yakitTuru ?? this.yakitTuru,
      vitesTuru: vitesTuru ?? this.vitesTuru,
      kilometre: kilometre ?? this.kilometre,
      motorHacmi: motorHacmi ?? this.motorHacmi,
      motorGucu: motorGucu ?? this.motorGucu,
      saseNo: saseNo ?? this.saseNo,
      ruhsatSahibi: ruhsatSahibi ?? this.ruhsatSahibi,
      kayitTarihi: kayitTarihi ?? this.kayitTarihi,
      aktif: aktif ?? this.aktif,
      aciklama: aciklama ?? this.aciklama,
      fiyat: fiyat ?? this.fiyat,
      konum: konum ?? this.konum,
      durumu: durumu ?? this.durumu,
      fotograflar: fotograflar ?? this.fotograflar,
      sonGuncellemeTarihi: sonGuncellemeTarihi ?? this.sonGuncellemeTarihi,
      guncelleyenKullanici: guncelleyenKullanici ?? this.guncelleyenKullanici,
    );
  }

  // Araç tam adını döndür
  String get fullName => '$marka $model';

  // Araç yaşını hesapla
  int get aracYasi => DateTime.now().year - yil;

  // Araç durumunu döndür
  String get durumText => aktif ? 'Aktif' : 'Pasif';

  // Araç değer kategori hesapla
  String get degerKategorisi {
    if (aracYasi <= 3) return 'Yeni';
    if (aracYasi <= 7) return 'Orta Yaş';
    if (aracYasi <= 15) return 'Yaşlı';
    return 'Çok Yaşlı';
  }

  // Kilometre kategorisi
  String get kilometreKategorisi {
    if (kilometre <= 50000) return 'Az Kilometreli';
    if (kilometre <= 100000) return 'Orta Kilometreli';
    if (kilometre <= 200000) return 'Yüksek Kilometreli';
    return 'Çok Yüksek Kilometreli';
  }

  // Araç değer tahmini (basit algoritma)
  double? get tahminiDeger {
    if (fiyat == null) return null;
    
    double depreciation = 1.0;
    
    // Yaş faktörü
    depreciation *= (1 - (aracYasi * 0.08));
    
    // Kilometre faktörü
    if (kilometre > 20000) {
      depreciation *= (1 - ((kilometre - 20000) * 0.000005));
    }
    
    // Minimum %10 değer kalsın
    if (depreciation < 0.1) depreciation = 0.1;
    
    return fiyat! * depreciation;
  }

  // Renk ikonu döndür
  Color get renkKodu {
    switch (renk.toLowerCase()) {
      case 'beyaz':
        return Colors.white;
      case 'siyah':
        return Colors.black;
      case 'gri':
        return Colors.grey;
      case 'kırmızı':
        return Colors.red;
      case 'mavi':
        return Colors.blue;
      case 'yeşil':
        return Colors.green;
      case 'sarı':
        return Colors.yellow;
      case 'turuncu':
        return Colors.orange;
      case 'kahverengi':
        return Colors.brown;
      case 'gümüş':
        return Colors.grey[400]!;
      default:
        return Colors.grey;
    }
  }

  // Yakıt türü ikonu
  IconData get yakitIkonu {
    switch (yakitTuru.toLowerCase()) {
      case 'benzin':
        return Icons.local_gas_station;
      case 'dizel':
        return Icons.oil_barrel;
      case 'lpg':
        return Icons.propane_tank;
      case 'elektrik':
        return Icons.electric_car;
      case 'hibrit':
        return Icons.eco;
      default:
        return Icons.local_gas_station;
    }
  }

  // Vites türü ikonu
  IconData get vitesIkonu {
    switch (vitesTuru.toLowerCase()) {
      case 'manuel':
      case 'düz':
        return Icons.settings_applications;
      case 'otomatik':
        return Icons.settings;
      case 'yarı otomatik':
        return Icons.settings_suggest;
      default:
        return Icons.settings;
    }
  }

  // Geçerli araç kontrolü
  bool get isValid {
    return id.isNotEmpty && 
           plaka.isNotEmpty && 
           marka.isNotEmpty && 
           model.isNotEmpty &&
           yil > 1900 &&
           yil <= DateTime.now().year + 1;
  }

  // Debug için string reprezentasyonu
  @override
  String toString() {
    return 'Arac(id: $id, plaka: $plaka, marka: $marka, model: $model, yil: $yil)';
  }

  // Eşitlik kontrolü
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Arac && 
           other.id == id &&
           other.plaka == plaka;
  }

  @override
  int get hashCode => id.hashCode ^ plaka.hashCode;

  // Boş araç oluştur (test için)
  static Arac empty() {
    return Arac(
      id: '',
      plaka: '',
      marka: '',
      model: '',
      yil: DateTime.now().year,
      renk: '',
      yakitTuru: '',
      vitesTuru: '',
      kilometre: 0,
      motorHacmi: '',
      motorGucu: '',
      saseNo: '',
      ruhsatSahibi: '',
      kayitTarihi: DateTime.now(),
      aktif: false,
    );
  }

  // Popüler marka listesi
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
    'Skoda',
    'Seat',
    'Citroen',
    'Dacia',
    'Suzuki',
  ];

  // Yakıt türü listesi
  static List<String> get yakitTurleri => [
    'Benzin',
    'Dizel',
    'LPG',
    'Benzin + LPG',
    'Elektrik',
    'Hibrit',
  ];

  // Vites türü listesi
  static List<String> get vitesTurleri => [
    'Manuel',
    'Otomatik',
    'Yarı Otomatik',
  ];

  // Renk listesi
  static List<String> get renkler => [
    'Beyaz',
    'Siyah',
    'Gri',
    'Gümüş',
    'Kırmızı',
    'Mavi',
    'Yeşil',
    'Sarı',
    'Turuncu',
    'Kahverengi',
  ];
}
