import 'ai/ai_analiz_sonucu_model.dart';

/// Unified Talep Model
/// 
/// Bu model, Müşteri → Admin → Personel → AI → Customer
/// tam döngüsü için tek bir veri tipi sağlar.
/// 
/// Özellikler:
/// - Talep oluşturma (Customer)
/// - Personel atama (Admin)
/// - Rapor tamamlama (Personel)
/// - AI analiz sonuçları (AI)
/// - Finansal durum (Finans)
class TalepModel {
  // Temel Kimlik
  final String id;
  
  // Müşteri Bilgileri
  final String musteriAdi;
  final String musteriId; // Yeni: Müşteri ID'si (filtreleme için)
  final String telefon;
  
  // Araç Bilgileri
  final String aracPlaka;
  final String aracMarka;
  final String aracModel;
  final String motorNo;
  
  // Durum Yönetimi
  final String durum; // 'Beklemede', 'Personele Atandı', 'Islemde', 'Raporlandı', 'Tamamlandi', 'Iptal'
  final DateTime olusturulma;
  final String? atananPersonel; // Personel ID'si
  final String aciklama;
  
  // Lokasyon ve Kurumsal
  final String sehir;
  final String expertizFirmasi;
  final String expertizPaketi;
  
  // Finansal
  final double paketFiyati;
  final double hizmetBedeli;
  final double toplamTutar;
  final double hasarTutar;
  final bool isPaid;
  
  // --- YENİ: YAPAY ZEKA VERİLERİ ---
  final bool aiAnaliziYapildiMi;
  final double? aiPiyasaDegeri;          // Araçın şu anki piyasa değeri
  final double? aiOnerilenAlimFiyati;     // Kâr etmek için max alınacak fiyat
  final double? aiAltiAylikGetiri;        // 6 ay sonraki tahmini değer
  final double? aiBirYillikGetiri;        // 1 yıl sonraki tahmini değer
  final String? aiYorumu;                 // AI'nın genel değerlendirmesi
  final double? aiDegerKaybi;              // Ekspertiz kusurlarına göre değer kaybı
  final double? aiNetKarPotansiyeli;       // Net kar potansiyeli
  final AIAnalizSonucu? aiAnalizSonucu;   // Tam AI analiz sonucu

  const TalepModel({
    required this.id,
    required this.musteriAdi,
    required this.musteriId, // Zorunlu
    required this.telefon,
    required this.aracPlaka,
    required this.aracMarka,
    required this.aracModel,
    required this.durum,
    required this.olusturulma,
    required this.aciklama,
    this.atananPersonel,
    this.sehir = 'İstanbul',
    this.expertizFirmasi = 'Standart',
    this.expertizPaketi = 'Basic',
    this.paketFiyati = 0.0,
    this.motorNo = '',
    this.hizmetBedeli = 6500.0,
    this.toplamTutar = 0.0,
    this.hasarTutar = 0.0,
    this.isPaid = false,
    this.aiAnaliziYapildiMi = false,
    this.aiPiyasaDegeri,
    this.aiOnerilenAlimFiyati,
    this.aiAltiAylikGetiri,
    this.aiBirYillikGetiri,
    this.aiYorumu,
    this.aiDegerKaybi,
    this.aiNetKarPotansiyeli,
    this.aiAnalizSonucu,
  });

  factory TalepModel.fromJson(Map<String, dynamic> json) {
    return TalepModel(
      id: json['id'] ?? '',
      musteriAdi: json['musteriAdi'] ?? '',
      musteriId: json['musteriId']?.toString() ?? '', // Varsayılan boş string
      telefon: json['telefon'] ?? '',
      aracPlaka: json['aracPlaka'] ?? '',
      aracMarka: json['aracMarka'] ?? '',
      aracModel: json['aracModel'] ?? '',
      durum: json['durum'] ?? 'Beklemede',
      olusturulma: DateTime.parse(json['olusturulma'] ?? DateTime.now().toIso8601String()),
      atananPersonel: json['atananPersonel']?.toString(),
      aciklama: json['aciklama'] ?? '',
      sehir: json['sehir'] ?? 'İstanbul',
      expertizFirmasi: json['expertizFirmasi'] ?? 'Standart',
      expertizPaketi: json['expertizPaketi'] ?? 'Basic',
      paketFiyati: (json['paketFiyati'] as num?)?.toDouble() ?? 0.0,
      motorNo: json['motorNo'] ?? '',
      hizmetBedeli: (json['hizmetBedeli'] as num?)?.toDouble() ?? 6500.0,
      toplamTutar: (json['toplamTutar'] as num?)?.toDouble() ?? 0.0,
      hasarTutar: (json['hasarTutar'] as num?)?.toDouble() ?? 0.0,
      isPaid: json['isPaid'] ?? false,
      aiAnaliziYapildiMi: json['aiAnaliziYapildiMi'] ?? false,
      aiPiyasaDegeri: (json['aiPiyasaDegeri'] as num?)?.toDouble(),
      aiOnerilenAlimFiyati: (json['aiOnerilenAlimFiyati'] as num?)?.toDouble(),
      aiAltiAylikGetiri: (json['aiAltiAylikGetiri'] as num?)?.toDouble(),
      aiBirYillikGetiri: (json['aiBirYillikGetiri'] as num?)?.toDouble(),
      aiYorumu: json['aiYorumu']?.toString(),
      aiDegerKaybi: (json['aiDegerKaybi'] as num?)?.toDouble(),
      aiNetKarPotansiyeli: (json['aiNetKarPotansiyeli'] as num?)?.toDouble(),
      aiAnalizSonucu: json['aiAnalizSonucu'] != null
          ? AIAnalizSonucu.fromJson(json['aiAnalizSonucu'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'musteriAdi': musteriAdi,
      'musteriId': musteriId,
      'telefon': telefon,
      'aracPlaka': aracPlaka,
      'aracMarka': aracMarka,
      'aracModel': aracModel,
      'durum': durum,
      'olusturulma': olusturulma.toIso8601String(),
      'atananPersonel': atananPersonel,
      'aciklama': aciklama,
      'sehir': sehir,
      'expertizFirmasi': expertizFirmasi,
      'expertizPaketi': expertizPaketi,
      'paketFiyati': paketFiyati,
      'motorNo': motorNo,
      'hizmetBedeli': hizmetBedeli,
      'toplamTutar': toplamTutar,
      'hasarTutar': hasarTutar,
      'isPaid': isPaid,
      'aiAnaliziYapildiMi': aiAnaliziYapildiMi,
      'aiPiyasaDegeri': aiPiyasaDegeri,
      'aiOnerilenAlimFiyati': aiOnerilenAlimFiyati,
      'aiAltiAylikGetiri': aiAltiAylikGetiri,
      'aiBirYillikGetiri': aiBirYillikGetiri,
      'aiYorumu': aiYorumu,
      'aiDegerKaybi': aiDegerKaybi,
      'aiNetKarPotansiyeli': aiNetKarPotansiyeli,
      'aiAnalizSonucu': aiAnalizSonucu?.toJson(),
    };
  }

  // --- Yardımcı Metotlar ---

  /// Durum rengini döndürür
  String get durumRengi {
    switch (durum) {
      case 'Beklemede': return 'orange';
      case 'Personele Atandı': return 'blue';
      case 'Islemde': return 'purple';
      case 'Raporlandı': return 'green';
      case 'Tamamlandi': return 'green';
      case 'Iptal': return 'red';
      default: return 'grey';
    }
  }

  /// AI analizi yapıldı mı kontrolü
  bool get aiHazirMi => aiAnaliziYapildiMi && aiAnalizSonucu != null;

  /// Müşteri için erişilebilir mi kontrolü
  bool get musteriIcinErisilebilirMi => durum == 'Tamamlandi' && aiHazirMi;

  /// Ödeme durumu metni
  String get odemeDurumu => isPaid ? 'Ödendi' : 'Ödenmedi';

  /// Toplam tutarı hesapla (paket + hizmet + KDV)
  double get hesaplananToplamTutar {
    const kdvOrani = 0.20;
    final araToplam = paketFiyati + hizmetBedeli;
    final kdvTutar = araToplam * kdvOrani;
    return araToplam + kdvTutar;
  }
}