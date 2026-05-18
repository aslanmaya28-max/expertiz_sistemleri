import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/finance/finance_model.dart';

/// Finans Servisi - Supabase destekli ödeme/hakediş yönetimi
///
/// SharedPreferences bağımlılığı kaldırılmıştır.
/// Tüm veri Supabase `payments` ve `staff_settlements` tablolarından gelir.
class FinanceService {
  static const double _komisyonOrani = 25.0;
  static const double _kdvOrani = 20.0;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<List<Odeme>> getOdemeler() async {
    try {
      final response = await _supabase
          .from('payments')
          .select()
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => Odeme.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Odemeler yuklenirken hata: $e');
      return [];
    }
  }

  Future<bool> odemeEkle(Odeme odeme) async {
    try {
      await _supabase.from('payments').insert(odeme.toJson());
      debugPrint('Odeme eklendi: ${odeme.id}');
      return true;
    } catch (e) {
      debugPrint('Odeme eklenirken hata: $e');
      return false;
    }
  }

  Future<bool> odemeGuncelle(Odeme odeme) async {
    try {
      await _supabase.from('payments').update(odeme.toJson()).eq('id', odeme.id);
      debugPrint('Odeme guncellendi: ${odeme.id}');
      return true;
    } catch (e) {
      debugPrint('Odeme guncellenirken hata: $e');
      return false;
    }
  }

  Future<List<Odeme>> getMusteriOdemeleri(String customerID) async {
    try {
      final response = await _supabase
          .from('payments')
          .select()
          .eq('customer_id', customerID)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => Odeme.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Musteriodemeleri hatasi: $e');
      return [];
    }
  }

  Future<List<PersonelHakedis>> getHakedisler() async {
    try {
      final response = await _supabase
          .from('staff_settlements')
          .select()
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) =>
              PersonelHakedis.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Hakedisler yuklenirken hata: $e');
      return [];
    }
  }

  Future<List<PersonelHakedis>> getPersonelHakedisleri(
      String personelID) async {
    try {
      final response = await _supabase
          .from('staff_settlements')
          .select()
          .eq('staff_id', personelID)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) =>
              PersonelHakedis.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Personel hakedis hatasi: $e');
      return [];
    }
  }

  Future<bool> hakedisEkle(PersonelHakedis hakedis) async {
    try {
      await _supabase.from('staff_settlements').insert(hakedis.toJson());
      debugPrint('Hakedis eklendi: ${hakedis.id}');
      return true;
    } catch (e) {
      debugPrint('Hakedis eklenirken hata: $e');
      return false;
    }
  }

  Future<Odeme?> musteriOdemeYap({
    required String customerID,
    required String staffID,
    required String reportID,
    required double amount,
    required String odemeYontemi,
  }) async {
    try {
      final odeme = Odeme(
        id: 'odeme_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        customerID: customerID,
        staffID: staffID,
        reportID: reportID,
        commission: _komisyonOrani,
        status: 'Paid',
        olusturmaTarihi: DateTime.now(),
        odemeTarihi: DateTime.now(),
        odemeYontemi: odemeYontemi,
        referansNo: 'REF${DateTime.now().millisecondsSinceEpoch}',
      );

      final saved = await odemeEkle(odeme);
      if (!saved) return null;

      final hakedis = PersonelHakedis(
        id: 'hakedis_${DateTime.now().millisecondsSinceEpoch}',
        personelID: staffID,
        odemeID: odeme.id,
        reportID: reportID,
        hakedisTutari: odeme.komisyonTutari,
        kazanimTarihi: DateTime.now(),
        durum: 'bekleniyor',
      );

      await hakedisEkle(hakedis);
      return odeme;
    } catch (e) {
      debugPrint('Odeme islemi hatasi: $e');
      return null;
    }
  }

  Future<double> getToplamCiro() async {
    final odemeler = await getOdemeler();
    return odemeler
        .where((o) => o.isPaid)
        .fold<double>(0.0, (sum, o) => sum + o.amount);
  }

  Future<double> getToplamHakedisBorcu() async {
    final hakedisler = await getHakedisler();
    return hakedisler
        .where((h) => h.durum == 'bekleniyor')
        .fold<double>(0.0, (sum, h) => sum + h.hakedisTutari);
  }

  Future<Map<String, double>> getPersonelHakedisOzeti() async {
    final hakedisler = await getHakedisler();
    final Map<String, double> ozet = {};
    for (var hakedis in hakedisler) {
      if (hakedis.durum == 'bekleniyor') {
        ozet[hakedis.personelID] =
            (ozet[hakedis.personelID] ?? 0.0) + hakedis.hakedisTutari;
      }
    }
    return ozet;
  }

  Future<Map<String, dynamic>> getFinansalOzet() async {
    final odemeler = await getOdemeler();
    final hakedisler = await getHakedisler();

    final toplamCiro =
        odemeler.where((o) => o.isPaid).fold(0.0, (sum, o) => sum + o.amount);

    final toplamKomisyon = toplamCiro * (_komisyonOrani / 100);
    final netGelir = toplamCiro - toplamKomisyon;
    final kdvTutari = netGelir * (_kdvOrani / 100);
    final kdvDahilToplam = netGelir + kdvTutari;

    final toplamHakedisBorcu = hakedisler
        .where((h) => h.durum == 'bekleniyor')
        .fold(0.0, (sum, h) => sum + h.hakedisTutari);

    final odenenHakedisler = hakedisler
        .where((h) => h.durum == 'odendi')
        .fold(0.0, (sum, h) => sum + h.hakedisTutari);

    return {
      'toplamCiro': toplamCiro,
      'toplamKomisyon': toplamKomisyon,
      'netGelir': netGelir,
      'kdvTutari': kdvTutari,
      'kdvOrani': _kdvOrani,
      'kdvDahilToplam': kdvDahilToplam,
      'toplamHakedisBorcu': toplamHakedisBorcu,
      'odenenHakedisler': odenenHakedisler,
      'toplamOdemeSayisi': odemeler.where((o) => o.isPaid).length,
      'bekleyenOdemeSayisi': odemeler.where((o) => o.isPending).length,
      'toplamHakedisSayisi': hakedisler.length,
      'bekleyenHakedisSayisi':
          hakedisler.where((h) => h.durum == 'bekleniyor').length,
    };
  }

  Future<bool> raporOdendiMi(String reportID) async {
    try {
      final response = await _supabase
          .from('payments')
          .select('id')
          .eq('report_id', reportID)
          .eq('status', 'Paid')
          .limit(1);
      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<Odeme?> getRaporOdemesi(String reportID) async {
    try {
      final response = await _supabase
          .from('payments')
          .select()
          .eq('report_id', reportID)
          .limit(1);
      if (response.isEmpty) return null;
      return Odeme.fromJson(response.first);
    } catch (e) {
      return null;
    }
  }

  Future<bool> odemeDurumuGuncelle({
    required String odemeID,
    required String yeniDurum,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': yeniDurum,
      };
      if (yeniDurum == 'Paid') {
        updates['payment_date'] = DateTime.now().toIso8601String();
      }
      await _supabase.from('payments').update(updates).eq('id', odemeID);
      return true;
    } catch (e) {
      debugPrint('Odeme durumu guncelleme hatasi: $e');
      return false;
    }
  }

  Future<bool> personelHakedisiOde(String hakedisID) async {
    try {
      await _supabase.from('staff_settlements').update({
        'status': 'odendi',
        'payment_date': DateTime.now().toIso8601String(),
      }).eq('id', hakedisID);
      debugPrint('Hakedis odendi: $hakedisID');
      return true;
    } catch (e) {
      debugPrint('Hakedis odeme hatasi: $e');
      return false;
    }
  }
}
