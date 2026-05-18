import 'package:flutter/material.dart';

class Rapor {
  final String id;
  final String aracId;
  final String personelId;
  final DateTime olusturmaTarihi;
  final String raporTipi; // ekspertiz, aylik, performans, finans
  final String baslik;
  final String icerik;
  
  // Expertiz raporu için
  final Map<String, dynamic>? teknikDetaylar;
  final List<String>? tespitEdilenSorunlar;
  final List<String>? oneriler;
  final double? degerlendirmePuani;
  
  // Finansal bilgiler
  final double? gelir;
  final double? gider;
  final double? kar;
  final String? paraBirimi;
  
  // Durum
  final bool tamamlandi;
  final DateTime? sonGuncellemeTarihi;
  final String? imza;

  Rapor({
    required this.id,
    required this.aracId,
    required this.personelId,
    required this.olusturmaTarihi,
    required this.raporTipi,
    required this.baslik,
    required this.icerik,
    this.teknikDetaylar,
    this.tespitEdilenSorunlar,
    this.oneriler,
    this.degerlendirmePuani,
    this.gelir,
    this.gider,
    this.kar,
    this.paraBirimi = 'TRY',
    this.tamamlandi = false,
    this.sonGuncellemeTarihi,
    this.imza,
  });

  // JSON'dan Rapor nesnesi oluştur
  factory Rapor.fromJson(Map<String, dynamic> json) {
    return Rapor(
      id: json['id']?.toString() ?? '',
      aracId: json['aracId']?.toString() ?? '',
      personelId: json['personelId']?.toString() ?? '',
      olusturmaTarihi: json['olusturmaTarihi'] != null 
          ? DateTime.parse(json['olusturmaTarihi'].toString())
          : DateTime.now(),
      raporTipi: json['raporTipi']?.toString() ?? 'ekspertiz',
      baslik: json['baslik']?.toString() ?? '',
      icerik: json['icerik']?.toString() ?? '',
      teknikDetaylar: json['teknikDetaylar'] != null
          ? Map<String, dynamic>.from(json['teknikDetaylar'])
          : null,
      tespitEdilenSorunlar: json['tespitEdilenSorunlar'] != null
          ? List<String>.from(json['tespitEdilenSorunlar'])
          : null,
      oneriler: json['oneriler'] != null
          ? List<String>.from(json['oneriler'])
          : null,
      degerlendirmePuani: json['degerlendirmePuani'] != null
          ? double.tryParse(json['degerlendirmePuani'].toString())
          : null,
      gelir: json['gelir'] != null
          ? double.tryParse(json['gelir'].toString())
          : null,
      gider: json['gider'] != null
          ? double.tryParse(json['gider'].toString())
          : null,
      kar: json['kar'] != null
          ? double.tryParse(json['kar'].toString())
          : null,
      paraBirimi: json['paraBirimi']?.toString() ?? 'TRY',
      tamamlandi: json['tamamlandi'] ?? false,
      sonGuncellemeTarihi: json['sonGuncellemeTarihi'] != null
          ? DateTime.parse(json['sonGuncellemeTarihi'].toString())
          : null,
      imza: json['imza']?.toString(),
    );
  }

  // Rapor nesnesini JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'aracId': aracId,
      'personelId': personelId,
      'olusturmaTarihi': olusturmaTarihi.toIso8601String(),
      'raporTipi': raporTipi,
      'baslik': baslik,
      'icerik': icerik,
      
      // Opsiyonel alanlar - null değerleri dahil etme
      if (teknikDetaylar != null) 'teknikDetaylar': teknikDetaylar,
      if (tespitEdilenSorunlar != null) 'tespitEdilenSorunlar': tespitEdilenSorunlar,
      if (oneriler != null) 'oneriler': oneriler,
      if (degerlendirmePuani != null) 'degerlendirmePuani': degerlendirmePuani,
      if (gelir != null) 'gelir': gelir,
      if (gider != null) 'gider': gider,
      if (kar != null) 'kar': kar,
      'paraBirimi': paraBirimi,
      'tamamlandi': tamamlandi,
      if (sonGuncellemeTarihi != null) 'sonGuncellemeTarihi': sonGuncellemeTarihi!.toIso8601String(),
      if (imza != null) 'imza': imza,
    };
  }

  Rapor copyWith({
    String? id,
    String? aracId,
    String? personelId,
    DateTime? olusturmaTarihi,
    String? raporTipi,
    String? baslik,
    String? icerik,
    Map<String, dynamic>? teknikDetaylar,
    List<String>? tespitEdilenSorunlar,
    List<String>? oneriler,
    double? degerlendirmePuani,
    double? gelir,
    double? gider,
    double? kar,
    String? paraBirimi,
    bool? tamamlandi,
    DateTime? sonGuncellemeTarihi,
    String? imza,
  }) {
    return Rapor(
      id: id ?? this.id,
      aracId: aracId ?? this.aracId,
      personelId: personelId ?? this.personelId,
      olusturmaTarihi: olusturmaTarihi ?? this.olusturmaTarihi,
      raporTipi: raporTipi ?? this.raporTipi,
      baslik: baslik ?? this.baslik,
      icerik: icerik ?? this.icerik,
      teknikDetaylar: teknikDetaylar ?? this.teknikDetaylar,
      tespitEdilenSorunlar: tespitEdilenSorunlar ?? this.tespitEdilenSorunlar,
      oneriler: oneriler ?? this.oneriler,
      degerlendirmePuani: degerlendirmePuani ?? this.degerlendirmePuani,
      gelir: gelir ?? this.gelir,
      gider: gider ?? this.gider,
      kar: kar ?? this.kar,
      paraBirimi: paraBirimi ?? this.paraBirimi,
      tamamlandi: tamamlandi ?? this.tamamlandi,
      sonGuncellemeTarihi: sonGuncellemeTarihi ?? this.sonGuncellemeTarihi,
      imza: imza ?? this.imza,
    );
  }

  // Helper getters
  String get durumText => tamamlandi ? 'Tamamlandı' : 'Devam Ediyor';
  Color get durumRengi => tamamlandi ? Colors.green : Colors.orange;
  
  // Rapor tipi ikonu
  IconData get raporTipiIkonu {
    switch (raporTipi.toLowerCase()) {
      case 'ekspertiz':
        return Icons.assessment;
      case 'aylik':
        return Icons.calendar_today;
      case 'performans':
        return Icons.trending_up;
      case 'finans':
        return Icons.attach_money;
      default:
        return Icons.description;
    }
  }

  // Rapor tipi rengi
  Color get raporTipiRengi {
    switch (raporTipi.toLowerCase()) {
      case 'ekspertiz':
        return Colors.blue;
      case 'aylik':
        return Colors.purple;
      case 'performans':
        return Colors.green;
      case 'finans':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // Tarih formatı
  String get formatliTarih => '${olusturmaTarihi.day}.${olusturmaTarihi.month}.${olusturmaTarihi.year}';

  // Kısa içerik (ilk 100 karakter)
  String get kisaIcerik {
    if (icerik.length <= 100) return icerik;
    return '${icerik.substring(0, 100)}...';
  }

  // Değerlendirme durumu
  String? get degerlendirmeDurumu {
    if (degerlendirmePuani == null) return null;
    if (degerlendirmePuani! >= 4.5) return 'Mükemmel';
    if (degerlendirmePuani! >= 4.0) return 'Çok İyi';
    if (degerlendirmePuani! >= 3.5) return 'İyi';
    if (degerlendirmePuani! >= 3.0) return 'Orta';
    if (degerlendirmePuani! >= 2.0) return 'Yeterli';
    return 'Yetersiz';
  }

  // Finansal özet
  String get finansalOzet {
    if (gelir == null && gider == null && kar == null) return 'Finansal veri yok';
    
    if (kar != null) {
      return 'Kar: $kar $paraBirimi';
    } else if (gelir != null && gider != null) {
      final netKar = gelir! - gider!;
      return 'Net Kar: $netKar $paraBirimi';
    } else if (gelir != null) {
      return 'Gelir: $gelir $paraBirimi';
    } else {
      return 'Gider: $gider $paraBirimi';
    }
  }

  // Problem sayısı
  int get problemSayisi {
    if (tespitEdilenSorunlar == null) return 0;
    return tespitEdilenSorunlar!.length;
  }

  // Öneri sayısı
  int get oneriSayisi {
    if (oneriler == null) return 0;
    return oneriler!.length;
  }

  // Geçerli rapor kontrolü
  bool get isValid {
    return id.isNotEmpty && 
           aracId.isNotEmpty && 
           personelId.isNotEmpty && 
           baslik.isNotEmpty;
  }

  // Debug için string reprezentasyonu
  @override
  String toString() {
    return 'Rapor(id: $id, baslik: $baslik, tip: $raporTipi, tamamlandi: $tamamlandi)';
  }

  // Eşitlik kontrolü
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Rapor && 
           other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Boş rapor oluştur
  static Rapor empty() {
    return Rapor(
      id: '',
      aracId: '',
      personelId: '',
      olusturmaTarihi: DateTime.now(),
      raporTipi: 'ekspertiz',
      baslik: '',
      icerik: '',
      tamamlandi: false,
    );
  }

  // Rapor tipleri
  static List<String> get raporTipleri => [
    'ekspertiz',
    'aylik',
    'performans',
    'finans',
    'genel',
    'teknik',
  ];

  // Para birimleri
  static List<String> get paraBirimleri => [
    'TRY',
    'USD',
    'EUR',
    'GBP',
  ];
}
