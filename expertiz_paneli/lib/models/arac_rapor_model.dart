import 'package:flutter/material.dart';
import 'expertiz/adim1_arac_satici_model.dart';
import 'expertiz/adim2_dis_ekspertiz_model.dart';
import 'expertiz/adim3_ic_ekspertiz_model.dart';
import 'expertiz/adim4_boya_kaporta_model.dart';
import 'expertiz/adim5_kurumsal_ekspertiz_model.dart';
import 'expertiz/tam_rapor_model.dart';
import 'ai/ai_analiz_sonucu_model.dart';

/// AracRapor Modeli - PostgreSQL/Supabase Uyumlu
/// 
/// Bu model, veritabanı şeması (database_schema.sql) ile birebir uyumludur.
/// JSONB alanları (data, ai_analiz_detay) desteği içerir.
class AracRapor {
  // Primary Keys
  final String id; // UUID - PostgreSQL UUID type
  final String musteriId; // user_id -> profiles(id)
  final String? personelId; // Personel ID (opsiyonel)
  
  // Timestamps
  final DateTime olusturmaTarihi; // created_at
  final DateTime? guncellemeTarihi; // updated_at (opsiyonel)
  final DateTime? statusUpdatedAt; // status_updated_at
  final int versionId; // version_id
  
  // Durum Bilgileri
  final String durum; // 'OdemeBekliyor', 'Islemde', 'Tamamlandi', 'Iptal'
  final String status; // 'draft', 'pending_ai', 'pending_admin', 'published', 'rejected'
  final bool isPaid; // odendi_mi
  
  // Araç Bilgileri
  final String? vehicleId; // vehicle_id -> vehicles(id) (opsiyonel foreign key)
  final String? ilanLinki;
  final String? plaka;
  final String? marka;
  final String? model;
  final String? yil;
  final String? renk;
  final int? km;
  
  // Lokasyon ve Firma
  final String? sehir;
  final String? ilce;
  final String? ekspertizFirmasi;
  final String? secilenPaket; // secilen_paket -> vehicle_packages(package_id)
  
  // Fiyatlandırma
  final double hizmetBedeli; // hizmet_bedeli
  final double paketFiyati; // paket_fiyati
  final double toplamTutar; // toplam_tutar
  final double hasarTutar; // hasar_tutar
  
  // Rapor Sonuçları
  final String? olusturanKullanici; // olusturan_kullanici
  
  // --- YAPAY ZEKA VERİLERİ ---
  final bool aiAnaliziYapildiMi; // ai_analizi_yapildi_mi
  final double? aiPiyasaDegeri; // ai_piyasa_degeri
  final double? aiOnerilenAlimFiyati; // ai_onerilen_alim_fiyati
  final double? aiAltiAylikGetiri; // ai_alti_aylik_getiri
  final double? aiBirYillikGetiri; // ai_bir_yillik_getiri
  final String? aiYorumu; // ai_yorumu
  final double? aiDegerKaybi; // ai_deger_kaybi
  final double? aiEnflasyonTahmini12Ay; // ai_enflasyon_tahmini_12ay
  final double? aiNetKarPotansiyeli; // ai_net_kar_potansiyeli
  
  // --- JSONB ALANLARI ---
  /// Tüm expertiz detayları (JSONB formatında)
  /// Dis_ekspertiz, ic_ekspertiz, boya_kaporta vb. tüm adımlar
  final Map<String, dynamic>? data; // data (JSONB)
  
  /// AI Analiz detayları (JSONB formatında)
  /// AIAnalizSonucu objesinin serialize edilmiş hali
  final Map<String, dynamic>? aiAnalizDetay; // ai_analiz_detay (JSONB)
  
  /// AI Analiz Sonucu (Flutter objesi - veritabanına kaydedilmez)
  final AIAnalizSonucu? aiAnalizSonucu;
  
  // --- SİSTEM PİYASA DEĞERİ ---
  /// MarketRadarService sonucu
  final double? piyasaDegeriSistem; // piyasa_degeri_sistem
  final Map<String, dynamic>? piyasaDegeriAyarlamalar; // piyasa_degeri_ayarlamlar (JSONB)

  const AracRapor({
    required this.id,
    required this.musteriId,
    this.personelId,
    required this.olusturmaTarihi,
    this.guncellemeTarihi,
    this.statusUpdatedAt,
    this.versionId = 0,
    required this.durum,
    this.status = 'draft',
    this.isPaid = false,
    this.vehicleId,
    this.ilanLinki,
    this.plaka,
    this.marka,
    this.model,
    this.yil,
    this.renk,
    this.km,
    this.sehir,
    this.ilce,
    this.ekspertizFirmasi,
    this.secilenPaket,
    this.hizmetBedeli = 6500.0,
    this.paketFiyati = 0.0,
    this.toplamTutar = 0.0,
    this.hasarTutar = 0.0,
    this.olusturanKullanici,
    this.aiAnaliziYapildiMi = false,
    this.aiPiyasaDegeri,
    this.aiOnerilenAlimFiyati,
    this.aiAltiAylikGetiri,
    this.aiBirYillikGetiri,
    this.aiYorumu,
    this.aiDegerKaybi,
    this.aiEnflasyonTahmini12Ay,
    this.aiNetKarPotansiyeli,
    this.data,
    this.aiAnalizDetay,
    this.aiAnalizSonucu,
    this.piyasaDegeriSistem,
    this.piyasaDegeriAyarlamalar,
  });

  /// AracRapor'u JSON'a dönüştür (PostgreSQL/Supabase uyumlu)
  /// Veritabanı şemasındaki alan isimleri ile birebir uyumludur
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'user_id': musteriId,
      'created_at': olusturmaTarihi.toIso8601String(),
      'durum': durum,
      'status': status,
      'odendi_mi': isPaid,
      'hizmet_bedeli': hizmetBedeli,
      'paket_fiyati': paketFiyati,
      'toplam_tutar': toplamTutar,
      'hasar_tutar': hasarTutar,
      'ai_analizi_yapildi_mi': aiAnaliziYapildiMi,
      'version_id': versionId,
    };
    if (personelId != null) json['personel_id'] = personelId;
    if (guncellemeTarihi != null) json['updated_at'] = guncellemeTarihi!.toIso8601String();
    if (statusUpdatedAt != null) json['status_updated_at'] = statusUpdatedAt!.toIso8601String();
    if (vehicleId != null) json['vehicle_id'] = vehicleId;
    if (ilanLinki != null) json['ilan_linki'] = ilanLinki;
    if (plaka != null) json['plaka'] = plaka;
    if (marka != null) json['marka'] = marka;
    if (model != null) json['model'] = model;
    if (yil != null) json['yil'] = yil;
    if (renk != null) json['renk'] = renk;
    if (km != null) json['km'] = km;
    if (sehir != null) json['sehir'] = sehir;
    if (ilce != null) json['ilce'] = ilce;
    if (ekspertizFirmasi != null) json['ekspertiz_firmasi'] = ekspertizFirmasi;
    if (secilenPaket != null) json['secilen_paket'] = secilenPaket;
    if (olusturanKullanici != null) json['olusturan_kullanici'] = olusturanKullanici;
    if (aiPiyasaDegeri != null) json['ai_piyasa_degeri'] = aiPiyasaDegeri;
    if (aiOnerilenAlimFiyati != null) json['ai_onerilen_alim_fiyati'] = aiOnerilenAlimFiyati;
    if (aiAltiAylikGetiri != null) json['ai_alti_aylik_getiri'] = aiAltiAylikGetiri;
    if (aiBirYillikGetiri != null) json['ai_bir_yillik_getiri'] = aiBirYillikGetiri;
    if (aiYorumu != null) json['ai_yorumu'] = aiYorumu;
    if (aiDegerKaybi != null) json['ai_deger_kaybi'] = aiDegerKaybi;
    if (aiEnflasyonTahmini12Ay != null) json['ai_enflasyon_tahmini_12ay'] = aiEnflasyonTahmini12Ay;
    if (aiNetKarPotansiyeli != null) json['ai_net_kar_potansiyeli'] = aiNetKarPotansiyeli;
    if (data != null) json['data'] = data;
    if (aiAnalizDetay != null) json['ai_analiz_detay'] = aiAnalizDetay;
    if (piyasaDegeriSistem != null) json['piyasa_degeri_sistem'] = piyasaDegeriSistem;
    if (piyasaDegeriAyarlamalar != null) json['piyasa_degeri_ayarlamlar'] = piyasaDegeriAyarlamalar;
    return json;
  }

  /// JSON'dan AracRapor oluştur (PostgreSQL/Supabase uyumlu)
  /// Veritabanı şemasındaki alan isimlerini destekler
  /// JSONB alanları (data, ai_analiz_detay) parse edilir
  factory AracRapor.fromJson(Map<String, dynamic> json) {
    // JSONB alanları parse et
    Map<String, dynamic>? dataField;
    if (json['data'] != null) {
      if (json['data'] is Map) {
        dataField = Map<String, dynamic>.from(json['data'] as Map);
      }
    }
    
    Map<String, dynamic>? aiAnalizDetayField;
    if (json['ai_analiz_detay'] != null) {
      if (json['ai_analiz_detay'] is Map) {
        aiAnalizDetayField = Map<String, dynamic>.from(json['ai_analiz_detay'] as Map);
      }
    }
    
    Map<String, dynamic>? piyasaDegeriAyarlamalarField;
    if (json['piyasa_degeri_ayarlamlar'] != null) {
      if (json['piyasa_degeri_ayarlamlar'] is Map) {
        piyasaDegeriAyarlamalarField = Map<String, dynamic>.from(json['piyasa_degeri_ayarlamlar'] as Map);
      }
    }
    
    // AI Analiz Sonucu objesini oluştur (JSONB'den veya aiAnalizSonucu'dan)
    AIAnalizSonucu? aiAnalizSonucuField;
    if (json['aiAnalizSonucu'] != null) {
      // Eski format (Flutter objesi)
      aiAnalizSonucuField = AIAnalizSonucu.fromJson(json['aiAnalizSonucu'] as Map<String, dynamic>);
    } else if (aiAnalizDetayField != null) {
      // Yeni format (JSONB)
      try {
        aiAnalizSonucuField = AIAnalizSonucu.fromJson(aiAnalizDetayField);
      } catch (e) {
        // Parse hatası durumunda null bırak
        aiAnalizSonucuField = null;
      }
    }
    
    return AracRapor(
      // Primary Keys - Hem eski hem yeni format desteği
      id: json['id']?.toString() ?? '',
      musteriId: json['user_id']?.toString() ?? json['musteriId']?.toString() ?? '',
      personelId: json['personel_id']?.toString() ?? json['personelId']?.toString(),
      
      // Timestamps
      olusturmaTarihi: json['created_at'] != null || json['olusturmaTarihi'] != null
          ? DateTime.parse(
              (json['created_at'] ?? json['olusturmaTarihi']).toString()
            )
          : DateTime.now(),
      guncellemeTarihi: json['updated_at'] != null || json['guncellemeTarihi'] != null
          ? DateTime.parse(
              (json['updated_at'] ?? json['guncellemeTarihi']).toString()
            )
          : null,
      statusUpdatedAt: json['status_updated_at'] != null
          ? DateTime.parse(json['status_updated_at'].toString())
          : null,
      versionId: (json['version_id'] as int?) ?? 0,
      
      // Durum Bilgileri
      durum: json['durum']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      isPaid: json['odendi_mi'] ?? json['isPaid'] ?? false,
      
      // Araç Bilgileri
      vehicleId: json['vehicle_id']?.toString(),
      ilanLinki: json['ilan_linki']?.toString() ?? json['ilanLinki']?.toString(),
      plaka: json['plaka']?.toString(),
      marka: json['marka']?.toString(),
      model: json['model']?.toString(),
      yil: json['yil']?.toString(),
      renk: json['renk']?.toString(),
      km: json['km']?.toInt(),
      
      // Lokasyon ve Firma
      sehir: json['sehir']?.toString(),
      ilce: json['ilce']?.toString(),
      ekspertizFirmasi: json['ekspertiz_firmasi']?.toString() ?? json['ekspertizFirmasi']?.toString(),
      secilenPaket: json['secilen_paket']?.toString() ?? json['secilenPaket']?.toString(),
      
      // Fiyatlandırma
      hizmetBedeli: (json['hizmet_bedeli'] as num?)?.toDouble() ?? 
                    (json['hizmetBedeli'] as num?)?.toDouble() ?? 6500.0,
      paketFiyati: (json['paket_fiyati'] as num?)?.toDouble() ?? 
                   (json['paketFiyati'] as num?)?.toDouble() ?? 0.0,
      toplamTutar: (json['toplam_tutar'] as num?)?.toDouble() ?? 
                  (json['toplamTutar'] as num?)?.toDouble() ?? 0.0,
      hasarTutar: (json['hasar_tutar'] as num?)?.toDouble() ?? 
                 (json['hasarTutar'] as num?)?.toDouble() ?? 0.0,
      olusturanKullanici: json['olusturan_kullanici']?.toString() ?? 
                         json['olusturanKullanici']?.toString(),
      
      // AI Analiz Sonuçları
      aiAnaliziYapildiMi: json['ai_analizi_yapildi_mi'] ?? json['aiAnaliziYapildiMi'] ?? false,
      aiPiyasaDegeri: (json['ai_piyasa_degeri'] as num?)?.toDouble() ?? 
                     (json['aiPiyasaDegeri'] as num?)?.toDouble(),
      aiOnerilenAlimFiyati: (json['ai_onerilen_alim_fiyati'] as num?)?.toDouble() ?? 
                          (json['aiOnerilenAlimFiyati'] as num?)?.toDouble(),
      aiAltiAylikGetiri: (json['ai_alti_aylik_getiri'] as num?)?.toDouble() ?? 
                       (json['aiAltiAylikGetiri'] as num?)?.toDouble(),
      aiBirYillikGetiri: (json['ai_bir_yillik_getiri'] as num?)?.toDouble() ?? 
                        (json['aiBirYillikGetiri'] as num?)?.toDouble(),
      aiYorumu: json['ai_yorumu']?.toString() ?? json['aiYorumu']?.toString(),
      aiDegerKaybi: (json['ai_deger_kaybi'] as num?)?.toDouble() ?? 
                   (json['aiDegerKaybi'] as num?)?.toDouble(),
      aiEnflasyonTahmini12Ay: (json['ai_enflasyon_tahmini_12ay'] as num?)?.toDouble() ?? 
                             (json['aiEnflasyonTahmini12Ay'] as num?)?.toDouble(),
      aiNetKarPotansiyeli: (json['ai_net_kar_potansiyeli'] as num?)?.toDouble() ?? 
                         (json['aiNetKarPotansiyeli'] as num?)?.toDouble(),
      
      // JSONB Alanlar
      data: dataField,
      aiAnalizDetay: aiAnalizDetayField,
      aiAnalizSonucu: aiAnalizSonucuField,
      
      // Sistem Piyasa Değeri
      piyasaDegeriSistem: (json['piyasa_degeri_sistem'] as num?)?.toDouble(),
      piyasaDegeriAyarlamalar: piyasaDegeriAyarlamalarField,
    );
  }

  Color get durumRengi {
    switch (durum) {
      case 'OdemeBekliyor': return Colors.orange;
      case 'Islemde': return Colors.blue;
      case 'Tamamlandi': return Colors.green;
      case 'Iptal': return Colors.red;
      default: return Colors.grey;
    }
  }

  String get durumMetni {
    switch (durum) {
      case 'OdemeBekliyor': return 'Ödeme Bekleniyor';
      case 'Islemde': return 'İşlemde';
      case 'Tamamlandi': return 'Tamamlandı';
      case 'Iptal': return 'İptal Edildi';
      default: return durum;
    }
  }

  // Odeme durumu getter
  String get odemeDurumu => isPaid ? 'Odendi' : 'Odenmedi';
  Color get odemeDurumuRengi => isPaid ? Colors.green : Colors.red;
  IconData get odemeDurumuIkonu => isPaid ? Icons.check_circle : Icons.payment;

  Color get statusRengi {
    switch (status) {
      case 'pending_admin': return Colors.orange;
      case 'pending_ai': return Colors.blue;
      case 'published': return Colors.green;
      case 'rejected': return Colors.red;
      case 'draft': return Colors.grey;
      default: return Colors.grey;
    }
  }

  String get statusMetni {
    switch (status) {
      case 'draft': return 'Taslak';
      case 'pending_ai': return 'AI Analizi Bekliyor';
      case 'pending_admin': return 'Admin Onayi Bekliyor';
      case 'published': return 'Yayinlandi';
      case 'rejected': return 'Reddedildi';
      default: return status;
    }
  }

  bool get isAdminOnayinaHazir => status == 'pending_admin';
  bool get isYayinda => status == 'published';
  bool get isReddedildi => status == 'rejected';

  /// AracRapor'u TamRaporModel'e dönüştür
  /// AI analiz servisi için adaptör metod
  TamRaporModel toTamRaporModel() {
    // Gorev ID oluştur (rapor ID'sini kullan)
    String gorevId = id;
    
    // Personel ID oluştur (mevcut personelId veya varsayılan)
    String personelId = this.personelId ?? 'unknown';
    
    // Adım 1: Araç & Satıcı (AracRapor'dan doldur)
    Adim1AracSaticiModel adim1 = Adim1AracSaticiModel(
      gorevId: gorevId,
      personelId: personelId,
      marka: marka ?? '',
      model: model ?? '',
      yakitTuru: 'Benzin', // Varsayılan yakıt türü
      plaka: plaka ?? '',
      saseNo: '', // AracRapor'da yok, varsayılan
      motorNo: '', // AracRapor'da yok, varsayılan
      guncelKm: 0, // AracRapor'da yok, varsayılan
      ruhsatSahibiAdSoyad: '', // AracRapor'da yok, varsayılan
      iletisimTelefon: '', // AracRapor'da yok, varsayılan
    );
    
    // Adım 2: Dış Ekspertiz (boş/varsayılan)
    Adim2DisEkspertizModel adim2 = Adim2DisEkspertizModel.empty();
    
    // Adım 3: İç Ekspertiz (boş/varsayılan)
    Adim3IcEkspertizModel adim3 = Adim3IcEkspertizModel.empty();
    
    // Adım 4: Boya / Kaporta (boş/varsayılan)
    Adim4BoyaKaportaModel adim4 = Adim4BoyaKaportaModel.empty();
    
    // Adım 5: Kurumsal Ekspertiz (boş/varsayılan)
    Adim5KurumsalEkspertizModel adim5 = Adim5KurumsalEkspertizModel.empty();
    
    // Durum map'le
    String tamRaporDurum = _mapDurum(durum);
    
    return TamRaporModel(
      gorevId: gorevId,
      personelId: personelId,
      adim1: adim1,
      adim2: adim2,
      adim3: adim3,
      adim4: adim4,
      adim5: adim5,
      durum: tamRaporDurum,
      aiAnalizSonucu: aiAnalizSonucu,
    );
  }
  
  /// Durum map'leme (AracRapor -> TamRaporModel)
  String _mapDurum(String aracRaporDurum) {
    switch (aracRaporDurum) {
      case 'OdemeBekliyor':
        return 'Onay Bekliyor';
      case 'Islemde':
        return 'Onay Bekliyor';
      case 'Tamamlandi':
        return 'Tamamlandı';
      case 'Iptal':
        return 'Reddedildi';
      default:
        return 'Onay Bekliyor';
    }
  }
}
