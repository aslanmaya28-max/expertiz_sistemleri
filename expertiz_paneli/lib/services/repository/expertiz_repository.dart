import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/expertiz/tam_rapor_model.dart';
import '../../models/expertiz/adim1_arac_satici_model.dart';
import '../../models/expertiz/adim2_dis_ekspertiz_model.dart';
import '../../models/expertiz/adim3_ic_ekspertiz_model.dart';
import '../../models/expertiz/adim4_boya_kaporta_model.dart';
import '../../models/expertiz/adim5_kurumsal_ekspertiz_model.dart';
import '../../models/ai/ai_analiz_sonucu_model.dart';
import '../storage/hive_service.dart';
import '../ai/ai_analiz_service.dart';

/// Expertiz Repository
/// Expertiz akışını yönetir - Taslak ve tamamlanmış raporları HiveService ile saklar
class ExpertizRepository {
  // Keys
  static const String _draftStepPrefix = 'draft_step_';
  static const String _reportPrefix = 'report_';
  static const String _reportsListKey = 'reports_list';

  // ============================================
  // DRAFT MANAGEMENT (Taslak Yönetimi)
  // ============================================

  /// Taslak adım verisini kaydet
  /// Örnek kullanım: saveDraftStep(1, {'plaka': '34ABC123', 'marka': 'VW'})
  static Future<bool> saveDraftStep(int stepNumber, Map<String, dynamic> data) async {
    try {
      final key = '$_draftStepPrefix$stepNumber';
      final success = await HiveService.saveString(key, jsonEncode(data));
      
      if (success) {
        debugPrint('📝 Taslak adım $stepNumber kaydedildi: ${data.length} alan');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ Taslak adım kaydetme hatası [$stepNumber]: $e');
      return false;
    }
  }

  /// Taslak adım verisini getir
  /// Örnek kullanım: final step1 = await getDraftStep(1);
  static Future<Map<String, dynamic>?> getDraftStep(int stepNumber) async {
    try {
      final key = '$_draftStepPrefix$stepNumber';
      final jsonString = await HiveService.getString(key);
      
      if (jsonString == null) {
        debugPrint('⚠️ Taslak adım $stepNumber bulunamadı');
        return null;
      }
      
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      debugPrint('📖 Taslak adım $stepNumber getirildi: ${data.length} alan');
      
      return data;
    } catch (e) {
      debugPrint('❌ Taslak adım getirme hatası [$stepNumber]: $e');
      return null;
    }
  }

  /// Tüm taslak adımlarını getir
  static Future<Map<int, Map<String, dynamic>>> getAllDraftSteps() async {
    try {
      final allSteps = <int, Map<String, dynamic>>{};
      
      // 5 adım için kontrol et
      for (int i = 1; i <= 5; i++) {
        final stepData = await getDraftStep(i);
        if (stepData != null) {
          allSteps[i] = stepData;
        }
      }
      
      debugPrint('📋 Tüm taslak adımları getirildi: ${allSteps.length} adet');
      return allSteps;
    } catch (e) {
      debugPrint('❌ Tüm taslak adımlarını getirme hatası: $e');
      return {};
    }
  }

  /// Tüm taslakları temizle
  static Future<bool> clearDrafts() async {
    try {
      // 5 adımı sil
      final keys = List.generate(5, (i) => '$_draftStepPrefix${i + 1}');
      final success = await HiveService.deleteAll(keys);
      
      if (success) {
        debugPrint('🗑️ Tüm taslaklar temizlendi');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ Taslakları temizleme hatası: $e');
      return false;
    }
  }

  // ============================================
  // FINAL REPORT MANAGEMENT (Sonuç Raporu Yönetimi)
  // ============================================

  /// Unique rapor ID üret
  /// Format: RPT-YYYYMMDD-XXX (örneğin: RPT-20231027-001)
  static Future<String> _generateReportId() async {
    try {
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      
      // Mevcut raporları al ve sayıyı hesapla
      final reports = await getAllReports();
      final count = reports.length + 1;
      final countStr = count.toString().padLeft(3, '0');
      
      return 'RPT-$dateStr-$countStr';
    } catch (e) {
      debugPrint('❌ Rapor ID üretme hatası: $e');
      return 'RPT-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Sonuç raporu oluştur
  /// Tüm 5 adım verisini alır, tek bir TamRaporModel'e birleştirir
  /// Örnek kullanım: await createFinalReport({1: step1Data, 2: step2Data, ...})
  static Future<String?> createFinalReport(Map<int, dynamic> allStepsData) async {
    try {
      debugPrint('📊 Sonuç raporu oluşturuluyor...');
      
      // Tüm 5 adımın geldiğini kontrol et
      if (allStepsData.length != 5) {
        debugPrint('⚠️ Tüm 5 adım gerekli, mevcut: ${allStepsData.length}');
        return null;
      }
      
      // Unique ID üret
      final reportId = await _generateReportId();
      debugPrint('🆔 Rapor ID: $reportId');
      
      // Adım verilerini model tipine dönüştür
      final adim1 = allStepsData[1] is Adim1AracSaticiModel
          ? allStepsData[1] as Adim1AracSaticiModel
          : Adim1AracSaticiModel.fromJson(allStepsData[1] as Map<String, dynamic>);
      
      final adim2 = allStepsData[2] is Adim2DisEkspertizModel
          ? allStepsData[2] as Adim2DisEkspertizModel
          : Adim2DisEkspertizModel.fromJson(allStepsData[2] as Map<String, dynamic>);
      
      final adim3 = allStepsData[3] is Adim3IcEkspertizModel
          ? allStepsData[3] as Adim3IcEkspertizModel
          : Adim3IcEkspertizModel.fromJson(allStepsData[3] as Map<String, dynamic>);
      
      final adim4 = allStepsData[4] is Adim4BoyaKaportaModel
          ? allStepsData[4] as Adim4BoyaKaportaModel
          : Adim4BoyaKaportaModel.fromJson(allStepsData[4] as Map<String, dynamic>);
      
      final adim5 = allStepsData[5] is Adim5KurumsalEkspertizModel
          ? allStepsData[5] as Adim5KurumsalEkspertizModel
          : Adim5KurumsalEkspertizModel.fromJson(allStepsData[5] as Map<String, dynamic>);
      
      // Personel ID'yi Adım 5'ten al
      final personelId = adim5.personelId;
      
      // TamRaporModel oluştur
      final tamRaporModel = TamRaporModel(
        gorevId: reportId,
        personelId: personelId,
        adim1: adim1,
        adim2: adim2,
        adim3: adim3,
        adim4: adim4,
        adim5: adim5,
        durum: 'Tamamlandı',
        baslangicZamani: DateTime.now(),
        bitisZamani: DateTime.now(),
      );
      
      // Raporu kaydet
      final reportJson = jsonEncode(tamRaporModel.toJson());
      final success = await HiveService.saveString('$_reportPrefix$reportId', reportJson);
      
      if (!success) {
        debugPrint('❌ Rapor kaydedilemedi');
        return null;
      }
      
      // Rapor listesine ekle
      await _addReportToList(reportId);
      
      debugPrint('✅ Sonuç raporu oluşturuldu: $reportId');
      
      // Taslakları temizle
      await clearDrafts();
      
      return reportId;
    } catch (e) {
      debugPrint('❌ Sonuç raporu oluşturma hatası: $e');
      return null;
    }
  }

  /// Rapor listesine ekle
  static Future<void> _addReportToList(String reportId) async {
    try {
      final listJson = await HiveService.getString(_reportsListKey);
      final reportList = listJson != null 
          ? List<String>.from(jsonDecode(listJson))
          : <String>[];
      
      if (!reportList.contains(reportId)) {
        reportList.add(reportId);
        await HiveService.saveString(_reportsListKey, jsonEncode(reportList));
        debugPrint('📋 Rapor listesine eklendi: $reportId');
      }
    } catch (e) {
      debugPrint('❌ Rapor listesine ekleme hatası: $e');
    }
  }

  /// Rapor listesinden çıkar
  static Future<void> _removeReportFromList(String reportId) async {
    try {
      final listJson = await HiveService.getString(_reportsListKey);
      if (listJson == null) return;
      
      final reportList = List<String>.from(jsonDecode(listJson));
      reportList.remove(reportId);
      
      await HiveService.saveString(_reportsListKey, jsonEncode(reportList));
      debugPrint('📋 Rapor listesinden çıkarıldı: $reportId');
    } catch (e) {
      debugPrint('❌ Rapor listesinden çıkarma hatası: $e');
    }
  }

  // ============================================
  // RETRIEVAL (Veri Getirme)
  // ============================================

  /// Tüm raporları getir
  /// Dashboard için kullanılır
  static Future<List<TamRaporModel>> getAllReports() async {
    try {
      final listJson = await HiveService.getString(_reportsListKey);
      if (listJson == null) {
        debugPrint('📋 Rapor listesi boş');
        return [];
      }
      
      final reportIds = List<String>.from(jsonDecode(listJson));
      final reports = <TamRaporModel>[];
      
      for (final reportId in reportIds) {
        final report = await getReportById(reportId);
        if (report != null) {
          reports.add(report);
        }
      }
      
      debugPrint('📋 Tüm raporlar getirildi: ${reports.length} adet');
      return reports;
    } catch (e) {
      debugPrint('❌ Tüm raporları getirme hatası: $e');
      return [];
    }
  }

  /// ID'ye göre raporu getir
  static Future<TamRaporModel?> getReportById(String reportId) async {
    try {
      final key = '$_reportPrefix$reportId';
      final jsonString = await HiveService.getString(key);
      
      if (jsonString == null) {
        debugPrint('⚠️ Rapor bulunamadı: $reportId');
        return null;
      }
      
      final reportJson = jsonDecode(jsonString) as Map<String, dynamic>;
      final report = TamRaporModel.fromJson(reportJson);
      
      debugPrint('📖 Rapor getirildi: $reportId');
      return report;
    } catch (e) {
      debugPrint('❌ Rapor getirme hatası [$reportId]: $e');
      return null;
    }
  }

  /// Personel ID'ye göre raporları getir
  static Future<List<TamRaporModel>> getReportsByPersonelId(String personelId) async {
    try {
      final allReports = await getAllReports();
      
      return allReports.where((r) => r.personelId == personelId).toList();
    } catch (e) {
      debugPrint('❌ Personel raporları getirme hatası: $e');
      return [];
    }
  }

  /// Plaka'ya göre raporları getir
  static Future<List<TamRaporModel>> getReportsByPlaka(String plaka) async {
    try {
      final allReports = await getAllReports();
      
      return allReports.where((r) => r.aracPlakasi == plaka).toList();
    } catch (e) {
      debugPrint('❌ Plaka raporları getirme hatası: $e');
      return [];
    }
  }

  /// Duruma göre raporları getir
  static Future<List<TamRaporModel>> getReportsByDurum(String durum) async {
    try {
      final allReports = await getAllReports();
      
      return allReports.where((r) => r.durum == durum).toList();
    } catch (e) {
      debugPrint('❌ Durum raporları getirme hatası: $e');
      return [];
    }
  }

  /// Tarihe göre raporları getir (başlangıç ve bitiş tarihleri arası)
  static Future<List<TamRaporModel>> getReportsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final allReports = await getAllReports();
      
      return allReports.where((r) {
        return r.baslangicZamani.isAfter(startDate.subtract(const Duration(days: 1))) &&
               r.baslangicZamani.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();
    } catch (e) {
      debugPrint('❌ Tarih aralığı raporları getirme hatası: $e');
      return [];
    }
  }

  // ============================================
  // DELETE (Silme İşlemleri)
  // ============================================

  /// Raporu sil
  static Future<bool> deleteReport(String reportId) async {
    try {
      final key = '$_reportPrefix$reportId';
      final success = await HiveService.deleteData(key);
      
      if (success) {
        await _removeReportFromList(reportId);
        debugPrint('🗑️ Rapor silindi: $reportId');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ Rapor silme hatası [$reportId]: $e');
      return false;
    }
  }

  /// Tüm raporları sil
  static Future<bool> deleteAllReports() async {
    try {
      final reportIds = await _getReportIdList();
      
      if (reportIds.isEmpty) {
        debugPrint('⚠️ Silinecek rapor yok');
        return true;
      }
      
      final keys = reportIds.map((id) => '$_reportPrefix$id').toList();
      final success1 = await HiveService.deleteAll(keys);
      final success2 = await HiveService.deleteData(_reportsListKey);
      
      if (success1 && success2) {
        debugPrint('🗑️ Tüm raporlar silindi: ${reportIds.length} adet');
      }
      
      return success1 && success2;
    } catch (e) {
      debugPrint('❌ Tüm raporları silme hatası: $e');
      return false;
    }
  }

  /// Rapor ID listesini getir
  static Future<List<String>> _getReportIdList() async {
    try {
      final listJson = await HiveService.getString(_reportsListKey);
      if (listJson == null) return [];
      
      return List<String>.from(jsonDecode(listJson));
    } catch (e) {
      debugPrint('❌ Rapor ID listesi getirme hatası: $e');
      return [];
    }
  }

  // ============================================
  // UTILITY (Yardımcı Metodlar)
  // ============================================

  /// Rapor sayısı
  static Future<int> getReportCount() async {
    final reports = await getAllReports();
    return reports.length;
  }

  /// Taslak adım sayısı
  static Future<int> getDraftStepCount() async {
    try {
      int count = 0;
      
      for (int i = 1; i <= 5; i++) {
        final exists = await HiveService.containsKey('$_draftStepPrefix$i');
        if (exists) count++;
      }
      
      return count;
    } catch (e) {
      debugPrint('❌ Taslak adım sayısı alma hatası: $e');
      return 0;
    }
  }

  /// Depolama bilgisi
  static Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final reports = await getAllReports();
      final draftCount = await getDraftStepCount();
      
      return {
        'report_count': reports.length,
        'draft_count': draftCount,
        'total_count': reports.length + draftCount,
      };
    } catch (e) {
      debugPrint('❌ Depolama bilgisi alma hatası: $e');
      return {'_ERROR': 1};
    }
  }

  /// Debug: Tüm verileri yazdır
  static Future<void> debugPrintAll() async {
    try {
      final draftSteps = await getAllDraftSteps();
      final reports = await getAllReports();
      
      debugPrint('=== Expertiz Repository Debug ===');
      
      debugPrint('Taslak Adımlar: ${draftSteps.length}/5');
      for (var entry in draftSteps.entries) {
        debugPrint('  📝 Adım ${entry.key}: ${entry.value.length} alan');
      }
      
      debugPrint('Tamamlanmış Raporlar: ${reports.length}');
      for (var report in reports) {
        debugPrint('  ✅ ${report.gorevId} - ${report.aracTamAdi} (${report.durum})');
      }
      
      debugPrint('=== Debug Sonu ===');
    } catch (e) {
      debugPrint('❌ Debug yazdırma hatası: $e');
    }
  }

  /// Raporu analiz et ve kaydet (AI Entegrasyonu için)
  /// Bu metod Adım 5 sayfasından çağrılır ve AIAnalizService üzerinden raporu kaydeder
  static Future<String?> analyzeAndSaveReport(TamRaporModel report) async {
    try {
      debugPrint('📊 Rapor analiz ediliyor ve kaydediliyor...');
      
      // AIAnalizService'i kullanarak raporu analiz et
      final analizSonucu = await AIAnalizService.analizEtVeKaydet(
        raporId: report.gorevId,
        marka: report.adim1.marka,
        model: report.adim1.model,
        yil: report.adim1.yil ?? DateTime.now().year.toString(),
        km: report.adim1.guncelKm,
        hasarKayitlar: report.adim4.hasarKayitlari.map((h) => h.konum).toList(),
        donanimlar: {},
        boyaliParcalar: report.adim4.boyaliParcalar,
      );
      
      // Başarılı: AI sonucunu rapora kaydet ve HiveService ile kaydet
      final updatedReport = kaydetAnalizSonucu(report, analizSonucu);
      
      // Güncellenmiş raporu kaydet
      final reportKey = 'report_${report.gorevId}';
      final reportJson = jsonEncode(updatedReport.toJson());
      await HiveService.saveString(reportKey, reportJson);
      
      debugPrint('✅ Rapor analiz edildi ve kaydedildi: ${report.gorevId}');
      return report.gorevId;
    } catch (e) {
      debugPrint('❌ Rapor analiz ve kaydetme hatası: $e');
      return null;
    }
  }

  /// Analiz sonucunu rapora kaydet
  static TamRaporModel kaydetAnalizSonucu(TamRaporModel report, AIAnalizSonucu analizSonucu) {
    return report.copyWith(aiAnalizSonucu: analizSonucu);
  }
}
