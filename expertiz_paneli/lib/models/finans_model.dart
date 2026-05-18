class Finans {
  final String id;
  final String tip; // gelir, gider, yatirim
  final String kategori;
  final double tutar;
  final DateTime tarih;
  final String aciklama;
  final String paraBirimi;
  
  // İlişkili kayıtlar
  final String? musteriId;
  final String? aracId;
  final String? personelId;
  final String? raporId;
  
  // Ödeme bilgileri
  final String? odemeYontemi; // nakit, krediKarti, havale
  final String? odemeDurumu; // bekliyor, odendi, iptal
  final DateTime? odemeTarihi;
  
  // Vergi ve muhasebe
  final double? kdvOrani;
  final double kdvTutari;
  final String? faturaNo;
  final bool? faturaEdildi;

  Finans({
    required this.id,
    required this.tip,
    required this.kategori,
    required this.tutar,
    required this.tarih,
    required this.aciklama,
    this.paraBirimi = 'TRY',
    this.musteriId,
    this.aracId,
    this.personelId,
    this.raporId,
    this.odemeYontemi,
    this.odemeDurumu = 'bekliyor',
    this.odemeTarihi,
    this.kdvOrani = 0.18,
    double? kdvTutari,
    this.faturaNo,
    this.faturaEdildi = false,
  }) : kdvTutari = kdvTutari ?? (tutar * (kdvOrani ?? 0.18));

  Finans copyWith({
    String? id,
    String? tip,
    String? kategori,
    double? tutar,
    DateTime? tarih,
    String? aciklama,
    String? paraBirimi,
    String? musteriId,
    String? aracId,
    String? personelId,
    String? raporId,
    String? odemeYontemi,
    String? odemeDurumu,
    DateTime? odemeTarihi,
    double? kdvOrani,
    double? kdvTutari,
    String? faturaNo,
    bool? faturaEdildi,
  }) {
    return Finans(
      id: id ?? this.id,
      tip: tip ?? this.tip,
      kategori: kategori ?? this.kategori,
      tutar: tutar ?? this.tutar,
      tarih: tarih ?? this.tarih,
      aciklama: aciklama ?? this.aciklama,
      paraBirimi: paraBirimi ?? this.paraBirimi,
      musteriId: musteriId ?? this.musteriId,
      aracId: aracId ?? this.aracId,
      personelId: personelId ?? this.personelId,
      raporId: raporId ?? this.raporId,
      odemeYontemi: odemeYontemi ?? this.odemeYontemi,
      odemeDurumu: odemeDurumu ?? this.odemeDurumu,
      odemeTarihi: odemeTarihi ?? this.odemeTarihi,
      kdvOrani: kdvOrani ?? this.kdvOrani,
      kdvTutari: kdvTutari ?? this.kdvTutari,
      faturaNo: faturaNo ?? this.faturaNo,
      faturaEdildi: faturaEdildi ?? this.faturaEdildi,
    );
  }

  factory Finans.fromJson(Map<String, dynamic> json) {
    return Finans(
      id: json['id']?.toString() ?? '',
      tip: json['tip']?.toString() ?? '',
      kategori: json['kategori']?.toString() ?? '',
      tutar: (json['tutar'] as num?)?.toDouble() ?? 0.0,
      tarih: json['tarih'] != null ? DateTime.parse(json['tarih'].toString()) : DateTime.now(),
      aciklama: json['aciklama']?.toString() ?? '',
      paraBirimi: json['paraBirimi']?.toString() ?? 'TRY',
      musteriId: json['musteriId']?.toString(),
      aracId: json['aracId']?.toString(),
      personelId: json['personelId']?.toString(),
      raporId: json['raporId']?.toString(),
      odemeYontemi: json['odemeYontemi']?.toString(),
      odemeDurumu: json['odemeDurumu']?.toString() ?? 'bekliyor',
      odemeTarihi: json['odemeTarihi'] != null ? DateTime.parse(json['odemeTarihi'].toString()) : null,
      kdvOrani: (json['kdvOrani'] as num?)?.toDouble() ?? 0.18,
      kdvTutari: (json['kdvTutari'] as num?)?.toDouble(),
      faturaNo: json['faturaNo']?.toString(),
      faturaEdildi: json['faturaEdildi'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tip': tip,
      'kategori': kategori,
      'tutar': tutar,
      'tarih': tarih.toIso8601String(),
      'aciklama': aciklama,
      'paraBirimi': paraBirimi,
      'musteriId': musteriId,
      'aracId': aracId,
      'personelId': personelId,
      'raporId': raporId,
      'odemeYontemi': odemeYontemi,
      'odemeDurumu': odemeDurumu,
      'odemeTarihi': odemeTarihi?.toIso8601String(),
      'kdvOrani': kdvOrani,
      'kdvTutari': kdvTutari,
      'faturaNo': faturaNo,
      'faturaEdildi': faturaEdildi,
    };
  }
}

class FinansOzet {
  final double toplamGelir;
  final double toplamGider;
  final double netKar;
  final int toplamIslem;
  final Map<String, double> kategorilereGoreGelir;
  final Map<String, double> kategorilereGoreGider;
  final DateTime hesapDonemi;

  FinansOzet({
    required this.toplamGelir,
    required this.toplamGider,
    required this.netKar,
    required this.toplamIslem,
    required this.kategorilereGoreGelir,
    required this.kategorilereGoreGider,
    required this.hesapDonemi,
  });

  factory FinansOzet.fromJson(Map<String, dynamic> json) {
    return FinansOzet(
      toplamGelir: (json['toplamGelir'] as num?)?.toDouble() ?? 0.0,
      toplamGider: (json['toplamGider'] as num?)?.toDouble() ?? 0.0,
      netKar: (json['netKar'] as num?)?.toDouble() ?? 0.0,
      toplamIslem: json['toplamIslem'] ?? 0,
      kategorilereGoreGelir: Map<String, double>.from(json['kategorilereGoreGelir'] ?? {}),
      kategorilereGoreGider: Map<String, double>.from(json['kategorilereGoreGider'] ?? {}),
      hesapDonemi: json['hesapDonemi'] != null ? DateTime.parse(json['hesapDonemi'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'toplamGelir': toplamGelir,
      'toplamGider': toplamGider,
      'netKar': netKar,
      'toplamIslem': toplamIslem,
      'kategorilereGoreGelir': kategorilereGoreGelir,
      'kategorilereGoreGider': kategorilereGoreGider,
      'hesapDonemi': hesapDonemi.toIso8601String(),
    };
  }
}
