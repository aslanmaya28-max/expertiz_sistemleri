import 'package:flutter/foundation.dart';
import '../core/constants/location_data.dart';

/// Personel Atama Servisi (Assignment Algorithm)
/// 
/// Bu servis, gelen müşteri taleplerini analiz eder ve
/// coğrafi konuma göre en uygun 'Müsait' personelleri filtreler.
/// 
/// Algoritma Mantığı:
/// 1. Talebin şehir bilgisini al.
/// 2. LocationData'dan o şehirdeki kayıtlı personel ID'lerini bul.
/// 3. PersonelService'den bu ID'lerin anlık durumunu (Müsait/Meşgul/İzinde) kontrol et.
/// 4. Müsait olanları ve iş yükü en az olanları Admin'e öner.
class AssignmentService {
  
  /// Belirli bir talep için uygun personelleri bul
  static Future<List<Map<String, dynamic>>> findAvailableStaffForRequest(String sehir) async {
    try {
      // 1. Şehri Bul
      final region = LocationData.cities.firstWhere(
        (c) => c.ilAdi.toLowerCase() == sehir.toLowerCase(),
        orElse: () => throw Exception("Bölge bulunamadı: $sehir"),
      );

      // 2. O bölgedeki personelleri al
      final regionStaffIds = region.personeller;
      
      // 3. Personellerin detaylarını ve durumlarını çek
      // Not: Gerçek senaryoda bu `PersonelService.getPersonelListByIds(regionStaffIds)` gibi olur.
      // Burada mock bir kontrol yapıyoruz.
      
      List<Map<String, dynamic>> availableStaff = [];

      for (String staffId in regionStaffIds) {
        // Mock Status Check
        final isAvailable = await _checkStaffAvailability(staffId);
        
        if (isAvailable) {
          availableStaff.add({
            'id': staffId,
            'adSoyad': 'Personel $staffId', // Gerçek isim DB'den çekilmeli
            'lokasyon': region.ilAdi,
            'puan': (4.0 + (staffId.hashCode % 10) / 10).toStringAsFixed(1), // Mock Puan 4.0 - 5.0
            'tamamlananGorev': (staffId.hashCode % 50) + 5, // Mock Görev Sayısı
            'durum': 'Müsait'
          });
        }
      }

      // 4. Sıralama (Puanı yüksek ve görev sayısı dengeli olanı öne çıkar)
      availableStaff.sort((a, b) => double.parse(b['puan']).compareTo(double.parse(a['puan'])));

      return availableStaff;

    } catch (e) {
      debugPrint("Atama algoritması hatası: $e");
      return [];
    }
  }

  /// Mock Availability Check
  static Future<bool> _checkStaffAvailability(String staffId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    // %80 ihtimalle müsait dönelim
    return (DateTime.now().millisecond % 5) != 0; 
  }
  
  /// En iyi personeli otomatik seç (Auto-Assign Opsiyonu için)
  static Future<String?> autoAssignBestStaff(String sehir) async {
    final candidates = await findAvailableStaffForRequest(sehir);
    if (candidates.isNotEmpty) {
      return candidates.first['id'];
    }
    return null;
  }
}
