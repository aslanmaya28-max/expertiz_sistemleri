class ExpertizFormu {
  final String id;
  final String aracId;
  final String personelId;
  final DateTime olusturmaTarihi;
  
  // Kaporta & Boya Değerlendirmesi
  final Map<String, dynamic> kaportaBoya;
  
  // Elektrik Aksamı Değerlendirmesi
  final Map<String, dynamic> elektrikAksami;
  
  // Mekanik Aksam Değerlendirmesi
  final Map<String, dynamic> mekanikAksam;
  
  // İç Döşeme Değerlendirmesi
  final Map<String, dynamic> icDoseme;
  
  // Lastik ve Jant Değerlendirmesi
  final Map<String, dynamic> lastikJant;
  
  // Genel Değerlendirme
  final String genelDegerlendirme;
  final double toplamPuan;
  final String oneriler;
  final String imza;

  ExpertizFormu({
    required this.id,
    required this.aracId,
    required this.personelId,
    required this.olusturmaTarihi,
    required this.kaportaBoya,
    required this.elektrikAksami,
    required this.mekanikAksam,
    required this.icDoseme,
    required this.lastikJant,
    required this.genelDegerlendirme,
    required this.toplamPuan,
    required this.oneriler,
    required this.imza,
  });

  factory ExpertizFormu.fromJson(Map<String, dynamic> json) {
    return ExpertizFormu(
      id: json['id']?.toString() ?? '',
      aracId: json['aracId']?.toString() ?? '',
      personelId: json['personelId']?.toString() ?? '',
      olusturmaTarihi: json['olusturmaTarihi'] != null ? DateTime.parse(json['olusturmaTarihi'].toString()) : DateTime.now(),
      kaportaBoya: Map<String, dynamic>.from(json['kaportaBoya'] ?? {}),
      elektrikAksami: Map<String, dynamic>.from(json['elektrikAksami'] ?? {}),
      mekanikAksam: Map<String, dynamic>.from(json['mekanikAksam'] ?? {}),
      icDoseme: Map<String, dynamic>.from(json['icDoseme'] ?? {}),
      lastikJant: Map<String, dynamic>.from(json['lastikJant'] ?? {}),
      genelDegerlendirme: json['genelDegerlendirme']?.toString() ?? '',
      toplamPuan: (json['toplamPuan'] as num?)?.toDouble() ?? 0.0,
      oneriler: json['oneriler']?.toString() ?? '',
      imza: json['imza']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'aracId': aracId,
      'personelId': personelId,
      'olusturmaTarihi': olusturmaTarihi.toIso8601String(),
      'kaportaBoya': kaportaBoya,
      'elektrikAksami': elektrikAksami,
      'mekanikAksam': mekanikAksam,
      'icDoseme': icDoseme,
      'lastikJant': lastikJant,
      'genelDegerlendirme': genelDegerlendirme,
      'toplamPuan': toplamPuan,
      'oneriler': oneriler,
      'imza': imza,
    };
  }
}

// Kaporta & Boya formu için sabitler
class KaportaBoyaSabitler {
  static const List<String> bolumler = [
    'Ön Kaput',
    'Arka Kaput',
    'Sağ Ön Çamurluk',
    'Sol Ön Çamurluk',
    'Sağ Arka Çamurluk',
    'Sol Arka Çamurluk',
    'Sağ Ön Kapı',
    'Sol Ön Kapı',
    'Sağ Arka Kapı',
    'Sol Arka Kapı',
    'Tavan',
    'Ön Tampon',
    'Arka Tampon',
  ];

  static const List<String> durumlar = [
    'Orjinal',
    'Boyalı',
    'Değişmiş',
    'Hasarlı',
    'Çizik',
    'Çürük',
  ];
}

// Elektrik Aksamı formu için sabitler
class ElektrikAksamiSabitler {
  static const List<String> sistemler = [
    'Aydınlatma Sistemi',
    'Sinyal Sistemi',
    'Akü ve Şarj Sistemi',
    'Marş Sistemi',
    'Klima Sistemi',
    'Ses Sistemi',
    'Güvenlik Sistemleri',
    'Gösterge Paneli',
  ];

  static const List<String> durumlar = [
    'Çalışıyor',
    'Arızalı',
    'Değişmiş',
    'Orjinal Değil',
    'Onarım Gerekli',
  ];
}
