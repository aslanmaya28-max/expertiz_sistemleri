import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expertiz/tam_rapor_model.dart';
import '../models/arac_rapor_model.dart';

/// Rapor Servisi - Supabase Backend Entegrasyonu
/// 
/// Bu servis, raporların Supabase (PostgreSQL) üzerinde kalıcı olarak 
/// saklanmasını ve yönetilmesini sağlar.
/// 
/// Özellikler:
/// - Supabase Client entegrasyonu
/// - PostgreSQL/JSONB desteği
/// - Row Level Security (RLS) uyumluluğu
/// - Geriye dönük uyumluluk (SharedPreferences fallback)
class RaporService {
  /// Supabase Client (Null kontrolü ile)
  static SupabaseClient? _supabaseClient;
  
  /// Supabase Client'ı başlat
  static void initSupabase(SupabaseClient client) {
    _supabaseClient = client;
    debugPrint('✅ RaporService: Supabase client bağlantısı sağlandı');
  }
  
  /// Supabase Client'ı al (fallback: SharedPreferences)
  static SupabaseClient? get supabaseClient => _supabaseClient;
  
  /// Supabase kullanılabilir mi?
  static bool get isSupabaseAvailable => _supabaseClient != null;
  
  // =====================================================
  // CRUD OPERATIONS - SUPABASE
  // =====================================================
  
  /// Raporu Kaydet (Create/Update) - Supabase
  /// 
  /// AracRapor modelini Supabase reports tablosuna kaydeder
  /// JSONB alanları (data, ai_analiz_detay) otomatik serialize edilir
  static Future<Result<AracRapor>> saveReportToSupabase(AracRapor rapor) async {
    try {
      if (!isSupabaseAvailable) {
        return Result.failure('Supabase bağlantısı yok. Lütfen initSupabase() çağırın.');
      }
      
      debugPrint('🔄 Rapor Supabase\'e kaydediliyor... ID: ${rapor.id}');
      
      // JSON'a dönüştür (PostgreSQL uyumlu)
      final jsonData = rapor.toJson();
      
      // Supabase'e gönder
      final response = await _supabaseClient!
          .from('reports')
          .upsert(jsonData)
          .select();
      
      if (response.isEmpty) {
        return Result.failure('Supabase upsert başarısız: Boş yanıt');
      }
      
      // Yanıtı AracRapor'a dönüştür
      final savedRapor = AracRapor.fromJson(response.first);
      
      debugPrint('✅ Rapor Supabase\'e kaydedildi: ${savedRapor.id}');
      return Result.success(savedRapor);
      
    } catch (e) {
      debugPrint('❌ Supabase kaydetme hatası: $e');
      return Result.failure('Supabase hatası: ${e.toString()}');
    }
  }
  
  /// Tekil Rapor Getir (ID ile) - Supabase
  static Future<Result<AracRapor>> getReportByIdFromSupabase(String id) async {
    try {
      if (!isSupabaseAvailable) {
        return Result.failure('Supabase bağlantısı yok');
      }
      
      debugPrint('🔄 Rapor getiriliyor: $id');
      
      final response = await _supabaseClient!
          .from('reports')
          .select()
          .eq('id', id)
          .single();
      
      final rapor = AracRapor.fromJson(response);
      
      debugPrint('✅ Rapor getirildi: ${rapor.id}');
      return Result.success(rapor);
      
    } catch (e) {
      debugPrint('❌ Rapor getirme hatası: $e');
      return Result.failure('Supabase hatası: ${e.toString()}');
    }
  }
  
  /// Personelin tamamladigi TamRaporModel'i mevcut Supabase reports kaydina isler.
  ///
  /// Musteri talebi olustugunda reports satiri zaten acilmis olmalidir. Bu metod
  /// yeni rapor acmaz; gorevId/reportId uzerinden var olan satiri saha rapor
  /// paketi ve AI sonucuyla gunceller.
  static Future<Result<bool>> updateTamRaporOnSupabase(TamRaporModel rapor) async {
    try {
      if (!isSupabaseAvailable) {
        return Result.failure('Supabase baglantisi yok');
      }

      final aiSonucu = rapor.aiAnalizSonucu;
      final existingRows = await _supabaseClient!
          .from('reports')
          .select('data')
          .eq('id', rapor.gorevId)
          .limit(1);
      final existingData = existingRows.isNotEmpty && existingRows.first['data'] is Map
          ? Map<String, dynamic>.from(existingRows.first['data'] as Map)
          : <String, dynamic>{};
      final now = DateTime.now().toIso8601String();
      final payload = <String, dynamic>{
        'durum': _mapTamRaporDurum(rapor.durum),
        'status': _mapTamRaporWorkflowStatus(rapor.durum),
        'plaka': rapor.adim1.plaka,
        'ai_analizi_yapildi_mi': aiSonucu != null,
        'ai_piyasa_degeri': aiSonucu?.raporOzeti.tahminiDeger,
        'ai_analiz_detay': aiSonucu?.toJson(),
        'data': {
          ...existingData,
          'tam_rapor': rapor.toJson(),
          'personel_id': rapor.personelId,
          'inspection_status': rapor.durum,
          'inspection_completed_at': rapor.bitisZamani?.toIso8601String(),
          'inspection_total_photos': rapor.toplamFotografSayisi,
          'inspection_damage_count': rapor.hasarSayisi,
        },
        'updated_at': now,
        'status_updated_at': now,
      };

      final response = await _supabaseClient!
          .from('reports')
          .update(payload)
          .eq('id', rapor.gorevId)
          .select('id');

      if (response.isEmpty) {
        return Result.failure('Supabase reports kaydi bulunamadi: ${rapor.gorevId}');
      }

      debugPrint('Tam rapor Supabase kaydina islendi: ${rapor.gorevId}');
      return Result.success(true);
    } catch (e) {
      debugPrint('Tam rapor Supabase guncelleme hatasi: $e');
      return Result.failure(e.toString());
    }
  }
  /// Kullanıcıya Ait Tüm Raporları Getir - Supabase
  static Future<Result<List<AracRapor>>> getUserReportsFromSupabase(String userId) async {
    try {
      if (!isSupabaseAvailable) {
        return Result.failure('Supabase bağlantısı yok');
      }
      
      debugPrint('🔄 Kullanıcı raporları getiriliyor: $userId');
      
      final response = await _supabaseClient!
          .from('reports')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      final raporlar = (response as List)
          .map((e) => AracRapor.fromJson(e as Map<String, dynamic>))
          .toList();
      
      debugPrint('✅ ${raporlar.length} rapor getirildi');
      return Result.success(raporlar);
      
    } catch (e) {
      debugPrint('❌ Raporlar getirme hatası: $e');
      return Result.failure('Supabase hatası: ${e.toString()}');
    }
  }
  
  /// Duruma Göre Raporları Filtrele - Supabase
  static Future<Result<List<AracRapor>>> getReportsByStatusFromSupabase(String durum) async {
    try {
      if (!isSupabaseAvailable) {
        return Result.failure('Supabase bağlantısı yok');
      }
      
      debugPrint('🔄 Duruma göre raporlar: $durum');
      
      final response = await _supabaseClient!
          .from('reports')
          .select()
          .eq('durum', durum)
          .order('created_at', ascending: false);
      
      final raporlar = (response as List)
          .map((e) => AracRapor.fromJson(e as Map<String, dynamic>))
          .toList();
      
      debugPrint('✅ ${raporlar.length} rapor bulundu');
      return Result.success(raporlar);
      
    } catch (e) {
      debugPrint('❌ Rapor filtreleme hatası: $e');
      return Result.failure('Supabase hatası: ${e.toString()}');
    }
  }
  
  /// AI Analizi Yapılmamış Raporları Getir - Supabase
  static Future<Result<List<AracRapor>>> getReportsWithoutAIAnalysis() async {
    try {
      if (!isSupabaseAvailable) {
        return Result.failure('Supabase bağlantısı yok');
      }
      
      debugPrint('🔄 AI analizi yapılmamış raporlar getiriliyor...');
      
      final response = await _supabaseClient!
          .from('reports')
          .select()
          .eq('ai_analizi_yapildi_mi', false)
          .order('created_at', ascending: false);
      
      final raporlar = (response as List)
          .map((e) => AracRapor.fromJson(e as Map<String, dynamic>))
          .toList();
      
      debugPrint('✅ ${raporlar.length} AI analizi bekleyen rapor bulundu');
      return Result.success(raporlar);
      
    } catch (e) {
      debugPrint('❌ Rapor getirme hatası: $e');
      return Result.failure('Supabase hatası: ${e.toString()}');
    }
  }
  
  /// Raporu Sil - Supabase
  static Future<Result<bool>> deleteReportFromSupabase(String id) async {
    try {
      if (!isSupabaseAvailable) {
        return Result.failure('Supabase bağlantısı yok');
      }
      
      debugPrint('🔄 Rapor siliniyor: $id');
      
      await _supabaseClient!
          .from('reports')
          .delete()
          .eq('id', id);
      
      debugPrint('✅ Rapor silindi: $id');
      return Result.success(true);
      
    } catch (e) {
      debugPrint('❌ Rapor silme hatası: $e');
      return Result.failure('Supabase hatası: ${e.toString()}');
    }
  }
  
  // =====================================================
  // LEGACY METHODS - SUPABASE-ONLY (SharedPreferences removed)
  // =====================================================
  
  /// Raporu Kaydet (Create/Update) - Supabase (TamRaporModel)
  /// 
  /// SharedPreferences fallback kaldırıldı.
  /// Sadece Supabase üzerinden çalışır.
  static Future<Result<bool>> saveReport(TamRaporModel rapor) async {
    try {
      if (!isSupabaseAvailable) {
        return Result.failure('Supabase bağlantısı yok. Rapor kaydedilemedi.');
      }
      return await updateTamRaporOnSupabase(rapor);
    } catch (e) {
      debugPrint("Rapor kaydetme hatası: $e");
      return Result.failure(e.toString());
    }
  }

  /// Tüm Raporları Getir - Supabase
  /// 
  /// SharedPreferences fallback kaldırıldı.
  /// Sadece Supabase üzerinden çalışır.
  static Future<Result<List<TamRaporModel>>> getAllReports() async {
    try {
      if (!isSupabaseAvailable) {
        return Result.failure('Supabase bağlantısı yok');
      }
      
      final response = await _supabaseClient!
          .from('reports')
          .select('data->tam_rapor')
          .not('data->tam_rapor', 'is', null)
          .order('created_at', ascending: false);
      
      final raporlar = response
          .where((row) => row['tam_rapor'] != null)
          .map((row) => TamRaporModel.fromJson(
              Map<String, dynamic>.from(row['tam_rapor'] as Map)))
          .toList();
      
      return Result.success(raporlar);
    } catch (e) {
      return Result.failure("Raporlar getirilemedi: $e");
    }
  }

  /// Tekil Rapor Getir - Supabase
  static Future<Result<TamRaporModel>> getReportById(String gorevId) async {
    try {
      if (!isSupabaseAvailable) {
        return Result.failure('Supabase bağlantısı yok');
      }
      
      final response = await _supabaseClient!
          .from('reports')
          .select('data->tam_rapor')
          .eq('id', gorevId)
          .single();
      
      final tamRaporData = response['tam_rapor'];
      if (tamRaporData == null) {
        return Result.failure('Rapor bulunamadı: $gorevId');
      }
      
      final rapor = TamRaporModel.fromJson(
          Map<String, dynamic>.from(tamRaporData as Map));
      
      return Result.success(rapor);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  /// Eski/Mock Metod - Geriye dönük uyumluluk için
  static Future<bool> gonderRapor({
    required Map<String, dynamic> aracBilgi,
    required List<Map<String, dynamic>> raporlar,
  }) async {
    // Bu metod artık kullanılmamalı, ama eski kodları kırmamak için tutuyoruz.
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
  
  // =====================================================
  // YARDIMCI METODLAR
  // =====================================================
  
  /// AracRapor oluşturucu - Factory metod
  static AracRapor createAracRapor({
    required String musteriId,
    required String marka,
    required String model,
    String? yil,
    String? plaka,
    String? secilenPaket,
    double hizmetBedeli = 6500.0,
  }) {
    return AracRapor(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Basit ID (UUID yerine)
      musteriId: musteriId,
      olusturmaTarihi: DateTime.now(),
      durum: 'OdemeBekliyor',
      isPaid: false,
      marka: marka,
      model: model,
      yil: yil,
      plaka: plaka,
      secilenPaket: secilenPaket,
      hizmetBedeli: hizmetBedeli,
      paketFiyati: 0.0,
      toplamTutar: hizmetBedeli,
      hasarTutar: 0.0,
      aiAnaliziYapildiMi: false,
    );
  }
  
  /// TamRaporModel'den AracRapor'a dönüştür
  static AracRapor fromTamRaporModel(TamRaporModel tamRapor, String musteriId) {
    return AracRapor(
      id: tamRapor.gorevId,
      musteriId: musteriId,
      personelId: tamRapor.personelId,
      olusturmaTarihi: tamRapor.baslangicZamani,
      durum: _mapTamRaporDurum(tamRapor.durum),
      status: _mapTamRaporWorkflowStatus(tamRapor.durum),
      marka: tamRapor.adim1.marka,
      model: tamRapor.adim1.model,
      plaka: tamRapor.adim1.plaka,
      aiAnaliziYapildiMi: tamRapor.aiAnalizSonucu != null,
      aiPiyasaDegeri: tamRapor.aiAnalizSonucu?.raporOzeti.tahminiDeger,
      aiAnalizSonucu: tamRapor.aiAnalizSonucu,
      isPaid: false,
      hizmetBedeli: 6500.0,
      paketFiyati: 0.0,
      toplamTutar: 6500.0,
      hasarTutar: 0.0,
    );
  }
  
  /// Durum map'leme (TamRaporModel -> AracRapor)
  static String _mapTamRaporDurum(String tamRaporDurum) {
    switch (tamRaporDurum) {
      case 'Onay Bekliyor':
        return 'Islemde';
      case 'Tamamlandı':
        return 'Tamamlandi';
      case 'Reddedildi':
        return 'Iptal';
      default:
        return 'Islemde';
    }
  }

  static String _mapTamRaporWorkflowStatus(String tamRaporDurum) {
    final normalized = tamRaporDurum.toLowerCase();
    if (normalized.contains('redded')) return 'rejected';
    return 'pending_admin';
  }

  // =====================================================
  // SUPABASE STATISTICS & HELPERS
  // =====================================================

  /// İstatistikleri Getir - Supabase
  /// 
  /// SharedPreferences kullanımı kaldırıldı.
  /// Sadece Supabase üzerinden çalışır.
  static Future<Result<Map<String, int>>> getIstatistikler() async {
    try {
      if (!isSupabaseAvailable) {
        return Result.failure('Supabase bağlantısı yok');
      }
      
      final response = await _supabaseClient!
          .from('reports')
          .select('durum');
      
      final raporlar = response as List;
      
      final istatistikler = {
        'toplam': raporlar.length,
        'onayBekleyen': raporlar.where((r) => r['durum'] == 'Onay Bekliyor').length,
        'onaylanan': raporlar.where((r) => r['durum'] == 'Onaylandı').length,
        'reddedilen': raporlar.where((r) => r['durum'] == 'Reddedildi').length,
      };

      return Result.success(istatistikler);
    } catch (e) {
      debugPrint('İstatistik alma hatası: $e');
      return Result.failure('İstatistik hatası: ${e.toString()}');
    }
  }

  /// Raporları Getir - Supabase
  /// 
  /// SharedPreferences kullanımı kaldırıldı.
  /// Sadece Supabase üzerinden çalışır.
  static Future<Result<List<AracRapor>>> getRaporlar() async {
    try {
      if (!isSupabaseAvailable) {
        return Result.failure('Supabase bağlantısı yok');
      }
      
      final response = await _supabaseClient!
          .from('reports')
          .select()
          .order('created_at', ascending: false);
      
      final raporlar = (response as List)
          .map((e) => AracRapor.fromJson(e as Map<String, dynamic>))
          .toList();
      
      return Result.success(raporlar);
    } catch (e) {
      debugPrint('Rapor listesi alma hatası: $e');
      return Result.failure('Rapor listesi hatası: ${e.toString()}');
    }
  }

  /// Rapor Kaydet - Supabase
  /// 
  /// SharedPreferences kullanımı kaldırıldı.
  /// Sadece Supabase üzerinden çalışır.
  static Future<Result<bool>> raporKaydet(AracRapor rapor) async {
    try {
      if (!isSupabaseAvailable) {
        return Result.failure('Supabase bağlantısı yok');
      }
      
      await _supabaseClient!
          .from('reports')
          .upsert(rapor.toJson());
      
      return Result.success(true);
    } catch (e) {
      debugPrint('Rapor kaydetme hatası: $e');
      return Result.failure('Rapor kaydetme hatası: ${e.toString()}');
    }
  }
}

/// Basit Result Wrapper (Backend yanıt standardı)
class Result<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  Result.success(this.data) : isSuccess = true, error = null;
  Result.failure(this.error) : isSuccess = false, data = null;
}

