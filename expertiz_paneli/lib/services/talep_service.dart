import 'package:flutter/foundation.dart';
import '../models/talep_model.dart';
import 'rapor_service.dart';
import 'yerimebak_expertiz_api_service.dart';

class TalepService {
  TalepService({YerimebakExpertizApiService? apiService}) : _apiService = apiService ?? YerimebakExpertizApiService();

  final YerimebakExpertizApiService _apiService;

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Admin için tüm müşteri talepleri (merkezi API).
  ///
  /// Müşteri talepleri merkezi veritabanına yazılır; admin paneli de oradan
  /// okur. API'ye ulaşılamazsa eski Supabase okumasına düşer.
  Future<List<TalepModel>> getTalepler() async {
    try {
      final response = await _apiService.getAdminRequests();
      final rows = (response['requests'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => fromApiRequest(Map<String, dynamic>.from(e)))
          .toList();
      return rows..sort((a, b) => b.olusturulma.compareTo(a.olusturulma));
    } catch (e) {
      debugPrint('Merkezi talep listesi alinamadi, Supabase deneniyor: $e');
    }
    try {
      final supabaseTalepler = await _getSupabaseTalepler();
      return supabaseTalepler
        ..sort((a, b) => b.olusturulma.compareTo(a.olusturulma));
    } catch (e) {
      debugPrint('Talep listesi alma hatası: $e');
      return [];
    }
  }

  /// Personel atar (merkezi API). Hata durumunda exception fırlatır.
  Future<void> personelAta(String talepId, String personelId, {String? not}) async {
    await _apiService.assignRequest(talepId, personelId, note: not);
  }

  /// Merkezi API talep/görev kaydını [TalepModel]'e çevirir.
  static TalepModel fromApiRequest(Map<String, dynamic> json) {
    Map<String, dynamic> asMap(dynamic value) =>
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    double asDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('${value ?? ''}') ?? 0.0;

    final vehicle = asMap(json['vehicle']);
    final customer = asMap(json['customer']);
    final assignment = asMap(json['assignment']);
    final assignedId = assignment['personnel_id']?.toString();
    final status = json['status']?.toString();

    String durum;
    switch (json['bucket']) {
      case 'completed':
        durum = 'Tamamlandı';
        break;
      case 'pending_approval':
        durum = 'Raporlandı';
        break;
      case 'in_progress':
        if (status == 'rejected') {
          durum = 'Düzeltme Gerekli';
        } else if (assignment['status'] == 'in_progress') {
          durum = 'İncelemede';
        } else if (assignment['status'] == 'accepted') {
          durum = 'Kabul Edildi';
        } else {
          durum = 'Personele Atandı';
        }
        break;
      default:
        durum = 'Beklemede';
    }

    final note = json['note']?.toString() ?? '';
    final listingUrl = vehicle['listing_url']?.toString() ?? '';
    return TalepModel(
      id: json['id']?.toString() ?? '',
      musteriAdi: customer['name']?.toString() ?? 'Müşteri',
      musteriId: customer['id']?.toString() ?? '',
      telefon: customer['phone']?.toString() ?? '',
      aracPlaka: vehicle['plate']?.toString() ?? '',
      aracMarka: (vehicle['brand']?.toString() ?? '').isEmpty ? 'Belirtilmedi' : vehicle['brand'].toString(),
      aracModel: (vehicle['model']?.toString() ?? '').isEmpty ? (vehicle['title']?.toString() ?? '') : vehicle['model'].toString(),
      durum: durum,
      olusturulma: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      atananPersonel: (assignedId == null || assignedId.isEmpty) ? null : assignedId,
      aciklama: [note, listingUrl].where((e) => e.isNotEmpty).join(' • '),
      sehir: json['city']?.toString() ?? '',
      expertizFirmasi: json['firm_name']?.toString() ?? '',
      expertizPaketi: json['package_name']?.toString() ?? '',
      toplamTutar: asDouble(json['total_tl']),
      isPaid: json['is_paid'] == true,
    );
  }

  Future<List<TalepModel>> _getSupabaseTalepler() async {
    if (!RaporService.isSupabaseAvailable) return [];

    try {
      final client = RaporService.supabaseClient;
      if (client == null) return [];

      final rows = await client
          .from('reports')
          .select('id,user_id,plaka,ilan_linki,sehir,ekspertiz_firmasi,hizmet_bedeli,paket_fiyati,toplam_tutar,odendi_mi,durum,status,data,created_at')
          .order('created_at', ascending: false);

      return rows
          .whereType<Map<String, dynamic>>()
          .map(_mapReportRowToTalep)
          .whereType<TalepModel>()
          .toList();
    } catch (e) {
      debugPrint('Supabase talepleri alma hatasi: $e');
      return [];
    }
  }

  TalepModel? _mapReportRowToTalep(Map<String, dynamic> row) {
    try {
      final data = row['data'] is Map
          ? Map<String, dynamic>.from(row['data'] as Map)
          : <String, dynamic>{};
      final talepData = data['talep'] is Map
          ? Map<String, dynamic>.from(data['talep'] as Map)
          : null;

      if (talepData != null) {
        return _applyReportRowOverrides(
          TalepModel.fromJson(talepData),
          row,
          data,
        );
      }

      final assignedPersonel = data['assigned_personel_id']?.toString();
      final status = row['status']?.toString();
      final workflowDurum = _mapWorkflowStatusToTalepDurum(status, assignedPersonel);
      final durum = status == null ? (row['durum']?.toString() ?? workflowDurum) : workflowDurum;
      final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now();

      return TalepModel(
        id: row['id']?.toString() ?? '',
        musteriAdi: data['customer_name']?.toString() ?? 'Supabase Müşteri',
        musteriId: row['user_id']?.toString() ?? '',
        telefon: data['customer_phone']?.toString() ?? '',
        aracPlaka: row['plaka']?.toString() ?? '',
        aracMarka: data['vehicle_snapshot'] is Map
            ? (data['vehicle_snapshot']['marka']?.toString() ?? 'Belirtilmedi')
            : 'Belirtilmedi',
        aracModel: data['vehicle_snapshot'] is Map
            ? (data['vehicle_snapshot']['model']?.toString() ?? 'Belirtilmedi')
            : 'Belirtilmedi',
        durum: durum,
        olusturulma: createdAt,
        atananPersonel: assignedPersonel,
        aciklama: row['ilan_linki']?.toString() ?? '',
        sehir: row['sehir']?.toString() ?? '',
        expertizFirmasi: row['ekspertiz_firmasi']?.toString() ?? '',
        expertizPaketi: data['expertiz_paketi']?.toString() ?? 'Belirtilmedi',
        paketFiyati: (row['paket_fiyati'] as num?)?.toDouble() ?? 0.0,
        hizmetBedeli: (row['hizmet_bedeli'] as num?)?.toDouble() ?? 6500.0,
        toplamTutar: (row['toplam_tutar'] as num?)?.toDouble() ?? 0.0,
        isPaid: row['odendi_mi'] == true,
      );
    } catch (e) {
      debugPrint('Supabase talep map hatasi: $e');
      return null;
    }
  }

  TalepModel _applyReportRowOverrides(
    TalepModel base,
    Map<String, dynamic> row,
    Map<String, dynamic> data,
  ) {
    final assignedPersonel =
        data['assigned_personel_id']?.toString() ?? base.atananPersonel;
    final status = row['status']?.toString();
    final workflowDurum = _mapWorkflowStatusToTalepDurum(status, assignedPersonel);
    final durum = status == null ? (row['durum']?.toString() ?? workflowDurum) : workflowDurum;
    final plaka = row['plaka']?.toString();
    final sehir = row['sehir']?.toString();
    final ekspertizFirmasi = row['ekspertiz_firmasi']?.toString();

    return TalepModel(
      id: base.id,
      musteriAdi: base.musteriAdi,
      musteriId: base.musteriId,
      telefon: base.telefon,
      aracPlaka: plaka?.isNotEmpty == true ? plaka! : base.aracPlaka,
      aracMarka: base.aracMarka,
      aracModel: base.aracModel,
      motorNo: base.motorNo,
      durum: durum,
      olusturulma: base.olusturulma,
      atananPersonel: assignedPersonel,
      aciklama: base.aciklama,
      sehir: sehir?.isNotEmpty == true ? sehir! : base.sehir,
      expertizFirmasi: ekspertizFirmasi?.isNotEmpty == true
          ? ekspertizFirmasi!
          : base.expertizFirmasi,
      expertizPaketi: base.expertizPaketi,
      paketFiyati: (row['paket_fiyati'] as num?)?.toDouble() ?? base.paketFiyati,
      hizmetBedeli: (row['hizmet_bedeli'] as num?)?.toDouble() ?? base.hizmetBedeli,
      toplamTutar: (row['toplam_tutar'] as num?)?.toDouble() ?? base.toplamTutar,
      hasarTutar: base.hasarTutar,
      isPaid: row['odendi_mi'] == true || base.isPaid,
      aiAnaliziYapildiMi: base.aiAnaliziYapildiMi,
      aiPiyasaDegeri: base.aiPiyasaDegeri,
      aiOnerilenAlimFiyati: base.aiOnerilenAlimFiyati,
      aiAltiAylikGetiri: base.aiAltiAylikGetiri,
      aiBirYillikGetiri: base.aiBirYillikGetiri,
      aiYorumu: base.aiYorumu,
      aiDegerKaybi: base.aiDegerKaybi,
      aiNetKarPotansiyeli: base.aiNetKarPotansiyeli,
      aiAnalizSonucu: base.aiAnalizSonucu,
    );
  }

  Future<bool> talepEkle(TalepModel talep) async {
    try {
      await _syncTalepToSupabase(talep);
      return true;
    } catch (e) {
      debugPrint('Talep ekleme hatası: $e');
      return false;
    }
  }

  Future<bool> talepGuncelle(String talepId, TalepModel yeniTalep) async {
    try {
      await _syncTalepToSupabase(yeniTalep);
      return true;
    } catch (e) {
      debugPrint('Talep güncelleme hatası: $e');
      return false;
    }
  }

  Future<void> _syncTalepToSupabase(TalepModel talep) async {
    if (!RaporService.isSupabaseAvailable) return;

    try {
      final client = RaporService.supabaseClient;
      if (client == null) return;

      final authUserId = client.auth.currentUser?.id;
      final userId = _uuidRegex.hasMatch(talep.musteriId)
          ? talep.musteriId
          : authUserId;

      if (userId == null || !_uuidRegex.hasMatch(userId)) {
        debugPrint('Talep Supabase senkronu atlandi: gecerli user_id yok (${talep.id})');
        return;
      }

      final existingRows = await client
          .from('reports')
          .select('data')
          .eq('id', talep.id)
          .limit(1);

      final existingData = existingRows.isNotEmpty && existingRows.first['data'] is Map
          ? Map<String, dynamic>.from(existingRows.first['data'] as Map)
          : <String, dynamic>{};

      final now = DateTime.now().toIso8601String();
      final payload = <String, dynamic>{
        'id': talep.id,
        'user_id': userId,
        'plaka': talep.aracPlaka,
        'firma': talep.expertizFirmasi,
        'ilan_linki': _extractIlanLink(talep.aciklama),
        'sehir': talep.sehir,
        'ekspertiz_firmasi': talep.expertizFirmasi,
        'hizmet_bedeli': talep.hizmetBedeli,
        'paket_fiyati': talep.paketFiyati,
        'toplam_tutar': talep.toplamTutar > 0 ? talep.toplamTutar : talep.hesaplananToplamTutar,
        'odendi_mi': talep.isPaid,
        'durum': _mapTalepDurumToReportDurum(talep.durum, talep.isPaid),
        'status': _mapTalepDurumToWorkflowStatus(talep.durum, talep.isPaid),
        'data': {
          ...existingData,
          'talep': talep.toJson(),
          'assigned_personel_id': talep.atananPersonel,
          'vehicle_snapshot': {
            'plaka': talep.aracPlaka,
            'marka': talep.aracMarka,
            'model': talep.aracModel,
            'motor_no': talep.motorNo,
          },
        },
        'updated_at': now,
        'status_updated_at': now,
      };

      await client.from('reports').upsert(payload);
    } catch (e) {
      debugPrint('Talep Supabase senkron hatasi (${talep.id}): $e');
    }
  }

  String _mapTalepDurumToReportDurum(String durum, bool isPaid) {
    final normalized = durum.toLowerCase();
    if (normalized.contains('tamamland')) return 'Tamamlandi';
    if (normalized.contains('iptal')) return 'Iptal';
    if (!isPaid && durum == 'OdemeBekliyor') return 'OdemeBekliyor';
    return 'Islemde';
  }

  String _mapTalepDurumToWorkflowStatus(String durum, bool isPaid) {
    final normalized = durum.toLowerCase();
    if (normalized.contains('tamamland')) return 'published';
    if (normalized.contains('iptal')) return 'rejected';
    if (normalized.contains('raporlan')) return 'pending_admin';
    if (!isPaid) return 'draft';
    return 'draft';
  }

  String _mapWorkflowStatusToTalepDurum(String? status, String? assignedPersonel) {
    switch (status) {
      case 'published':
        return 'Tamamlandi';
      case 'rejected':
        return 'Iptal';
      case 'pending_admin':
        return 'Raporlandı';
      case 'pending_ai':
        return 'Raporlandı';
      default:
        return assignedPersonel == null || assignedPersonel.isEmpty
            ? 'Beklemede'
            : 'Personele Atandı';
    }
  }

  String? _extractIlanLink(String text) {
    final match = RegExp(r'https?://\S+').firstMatch(text);
    return match?.group(0);
  }
}

