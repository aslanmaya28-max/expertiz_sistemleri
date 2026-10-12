import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'central_auth_client.dart';

class YerimebakExpertizApiService {
  YerimebakExpertizApiService({
    this.baseUrl = const String.fromEnvironment(
      'YERIMEBAK_API_BASE_URL',
      defaultValue: 'http://localhost:8000/api/v1',
    ),
    http.Client? client,
    String? accessToken,
    SupabaseClient? supabase,
  })  : _client = client ?? http.Client(),
        _accessToken = accessToken,
        _supabase = supabase;

  final String baseUrl;
  final http.Client _client;
  final String? _accessToken;
  final SupabaseClient? _supabase;

  /// Admin onayı: personel raporu + kurumsal rapor + AI değerlemesi müşteriye yayınlanır.
  /// [adminNote] müşteri raporunda "Admin notu" olarak görünür (opsiyonel).
  Future<Map<String, dynamic>> publishReport(String reportId, {String? adminNote}) {
    final note = adminNote?.trim() ?? '';
    return _post(
      '/expertiz/admin/reports/$reportId/publish',
      body: note.isEmpty ? null : {'admin_note': note},
    );
  }

  /// Merkezi AI değerlemesini (piyasa fiyatı − ekspertiz değer kayıpları) yeniden çalıştırır.
  Future<Map<String, dynamic>> reanalyzeReport(String reportId) {
    return _post('/expertiz/admin/reports/$reportId/reanalyze');
  }

  Future<Map<String, dynamic>> rejectReport(String reportId, String reason) {
    return _post(
      '/expertiz/admin/reports/$reportId/reject',
      body: {'reason': reason},
    );
  }

  Future<Map<String, dynamic>> getAdminReports({String? status, int limit = 100}) {
    final query = <String, String>{'limit': '$limit'};
    if (status != null) query['status'] = status;
    return _get('/expertiz/admin/reports', queryParams: query);
  }

  Future<Map<String, dynamic>> getAdminReportDetail(String reportId) {
    return _get('/expertiz/admin/reports/$reportId');
  }

  Future<Map<String, dynamic>> triggerCentralAnalysis(String reportId) {
    return reanalyzeReport(reportId);
  }

  Future<Map<String, dynamic>> getAnalysisStatus(String reportId) {
    return _get('/status/$reportId');
  }
  Future<Map<String, dynamic>> getPersonnel({bool? active}) {
    final query = <String, String>{};
    if (active != null) query['active'] = '$active';
    return _get('/personnel/admin/personnel', queryParams: query);
  }

  Future<Map<String, dynamic>> createPersonnel(Map<String, dynamic> payload) {
    return _post('/personnel/admin/personnel', body: payload);
  }

  Future<Map<String, dynamic>> updatePersonnel(String personnelId, Map<String, dynamic> payload) {
    return _put('/personnel/admin/personnel/$personnelId', body: payload);
  }

  Future<Map<String, dynamic>> deactivatePersonnel(String personnelId, String reason) {
    return _post(
      '/personnel/admin/personnel/$personnelId/deactivate',
      body: {'reason': reason},
    );
  }

  Future<Map<String, dynamic>> activatePersonnel(String personnelId) {
    return _post('/personnel/admin/personnel/$personnelId/activate');
  }

  Future<Map<String, dynamic>> resetPersonnelPassword(String personnelId, String temporaryPassword) {
    return _post(
      '/personnel/admin/personnel/$personnelId/reset-password',
      body: {'temporary_password': temporaryPassword},
    );
  }

  Future<Map<String, dynamic>> getPersonnelCoverage() {
    return _get('/personnel/admin/coverage');
  }

  /// Personeli sistemden çıkarır. Açık görevleri admin kuyruğuna geri döner.
  Future<Map<String, dynamic>> removePersonnel(String personnelId, {String? reason}) {
    return _send(
      'DELETE',
      '/personnel/admin/personnel/$personnelId',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  /// Güncel kurumsal ekspertiz kataloğu: hizmet bedeli, KDV oranı, firmalar/paketler.
  Future<Map<String, dynamic>> getExpertizPackages() {
    return _get('/expertiz/packages');
  }

  /// Müşteri ekspertiz talebi oluşturur ve PayTR ödemesini başlatır.
  /// Talep, ödeme onaylanınca admin "Atama Bekleyen" kuyruğuna düşer.
  /// Cevap: order_id, request_id, amount_tl, provider (paytr|simulation), iframe_url.
  Future<Map<String, dynamic>> createExpertizRequest({
    required String firmId,
    required String packageId,
    String? plate,
    String? city,
    String? district,
    String? listingUrl,
    String? note,
    Map<String, dynamic>? vehicle,
  }) {
    return _post('/expertiz/requests', body: {
      'firm_id': firmId,
      'package_id': packageId,
      if (plate != null && plate.isNotEmpty) 'plate': plate,
      if (city != null && city.isNotEmpty) 'city': city,
      if (district != null && district.isNotEmpty) 'district': district,
      if (listingUrl != null && listingUrl.isNotEmpty) 'listing_url': listingUrl,
      if (note != null && note.isNotEmpty) 'note': note,
      if (vehicle != null && vehicle.isNotEmpty) 'vehicle': vehicle,
    });
  }

  /// Ödeme durumu: status = pending | paid | failed
  Future<Map<String, dynamic>> getCheckoutStatus(String orderId) {
    return _get('/payments/checkout/$orderId');
  }

  /// Sadece sunucu PAYMENT_SIMULATION=true iken (geliştirme/test).
  Future<Map<String, dynamic>> simulateCheckout(String orderId, {bool success = true}) {
    return _post('/payments/checkout/$orderId/simulate', body: {'success': success});
  }

  // ---------------------------------------------------------------------------
  // Fiyatlandırma (admin): hizmet bedeli, araç enflasyonu, ekspertiz firma/paketleri
  // ---------------------------------------------------------------------------

  /// Hizmet bedeli, KDV, aylık araç enflasyonu ve tüm (pasifler dahil) firma/paketler.
  Future<Map<String, dynamic>> getAdminPricing() {
    return _get('/expertiz/admin/pricing');
  }

  Future<Map<String, dynamic>> updatePricingSettings({
    double? serviceFeeTl,
    double? inflationMonthlyPct,
    String? inflationNote,
    String? inflationEffectiveDate,
  }) {
    return _put('/expertiz/admin/pricing/settings', body: {
      if (serviceFeeTl != null) 'service_fee_tl': serviceFeeTl,
      if (inflationMonthlyPct != null) 'vehicle_inflation_monthly_pct': inflationMonthlyPct,
      if (inflationNote != null) 'inflation_note': inflationNote,
      if (inflationEffectiveDate != null) 'inflation_effective_date': inflationEffectiveDate,
    });
  }

  Future<Map<String, dynamic>> createFirm(String name, {String? sourceUrl}) {
    return _post('/expertiz/admin/firms', body: {
      'name': name,
      if (sourceUrl != null && sourceUrl.isNotEmpty) 'source_url': sourceUrl,
    });
  }

  /// [fields]: name, active, sort_order, source_url, verified
  Future<Map<String, dynamic>> updateFirm(String firmId, Map<String, dynamic> fields) {
    return _put('/expertiz/admin/firms/$firmId', body: fields);
  }

  Future<Map<String, dynamic>> createPackage(String firmId, {required String name, required double price, List<String> features = const []}) {
    return _post('/expertiz/admin/firms/$firmId/packages', body: {
      'name': name,
      'price': price,
      'features': features,
    });
  }

  /// [fields]: name, price, features, active, sort_order
  Future<Map<String, dynamic>> updatePackage(String firmId, String packageId, Map<String, dynamic> fields) {
    return _put('/expertiz/admin/firms/$firmId/packages/$packageId', body: fields);
  }

  // ---------------------------------------------------------------------------
  // Piyasa verisi: kazıyıcı kontrolü (admin) ve güncel piyasa özeti
  // ---------------------------------------------------------------------------

  /// arabam / borusan kazıyıcılarının çalışma durumu.
  Future<Map<String, dynamic>> getScraperStatus() {
    return _get('/scrapers/status');
  }

  /// [source]: arabam | borusan | all
  Future<Map<String, dynamic>> startScraper(String source) {
    return _post('/scrapers/start/$source');
  }

  /// [source]: arabam | borusan | all
  Future<Map<String, dynamic>> stopScraper(String source) {
    return _post('/scrapers/stop/$source');
  }

  /// Kazınan ilanlardan güncel piyasa özeti (toplam, analiz edilen, kaynak dağılımı).
  Future<Map<String, dynamic>> getMarketStats() {
    return _get('/vitrin/stats');
  }

  /// Marka/model/yıl bazında piyasa verisi kapsamı (hedef emsal sayısına göre).
  Future<Map<String, dynamic>> getMarketCoverageSummary() {
    return _get('/market-coverage/summary');
  }

  /// Giriş yapmış kullanıcının şifresini değiştirir (merkezi hesap).
  Future<Map<String, dynamic>> changePassword({required String currentPassword, required String newPassword}) {
    return _post(
      '/auth/change-password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }

  /// Admin müşteri listesi (arama: e-posta, ad veya telefon).
  Future<Map<String, dynamic>> getAdminCustomers({String? search}) {
    final term = search?.trim() ?? '';
    return _get('/expertiz/admin/customers', queryParams: term.isEmpty ? null : {'search': term});
  }

  /// Müşteri detayı ve ekspertiz talepleri.
  Future<Map<String, dynamic>> getAdminCustomer(int customerId) {
    return _get('/expertiz/admin/customers/$customerId');
  }

  /// Müşteri hesabını aktif/pasif yapar. Pasife almada [reason] zorunludur.
  Future<Map<String, dynamic>> setCustomerActive(int customerId, {required bool active, String? reason}) {
    final note = reason?.trim() ?? '';
    return _post(
      '/expertiz/admin/customers/$customerId/status',
      body: {'active': active, if (note.isNotEmpty) 'reason': note},
    );
  }

  /// Admin finans özeti: ekspertiz cirosu/KDV, kredi satışları, personel hakedişi.
  Future<Map<String, dynamic>> getAdminFinanceSummary() {
    return _get('/expertiz/admin/finance/summary');
  }

  // ---------------------------------------------------------------------------
  // Talep kuyruğu ve personel atama (admin)
  // ---------------------------------------------------------------------------

  /// bucket: waiting_assignment | in_progress | pending_approval | completed
  Future<Map<String, dynamic>> getAdminRequests({String? bucket, int? regionId, int? ilId}) {
    final query = <String, String>{};
    if (bucket != null) query['bucket'] = bucket;
    if (regionId != null && regionId > 0) query['region_id'] = '$regionId';
    if (ilId != null && ilId > 0) query['il_id'] = '$ilId';
    return _get('/expertiz/admin/requests', queryParams: query);
  }

  Future<Map<String, dynamic>> getRequestCandidates(String requestId) {
    return _get('/expertiz/admin/requests/$requestId/candidates');
  }

  Future<Map<String, dynamic>> assignRequest(String requestId, String personnelId, {String? note}) {
    return _post(
      '/expertiz/admin/requests/$requestId/assign',
      body: {
        'personnel_id': personnelId,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  Future<Map<String, dynamic>> unassignRequest(String requestId, {String? reason}) {
    return _post(
      '/expertiz/admin/requests/$requestId/unassign',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  // ---------------------------------------------------------------------------
  // Personel görevleri
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getMyTasks() {
    return _get('/expertiz/personnel/tasks');
  }

  /// Saha adımı: accept | depart (harekete geçti) | arrive (araç başında) |
  /// corporate (kurumsal ekspertizde) | start (rapora başla / düzeltmeye başla)
  Future<Map<String, dynamic>> updateMyTask(String taskId, String action) {
    return _post('/expertiz/personnel/tasks/$taskId/$action');
  }

  /// Giriş yapmış personelin profili (il, ilçe, görev durumu).
  Future<Map<String, dynamic>> getPersonnelMe() {
    return _get('/expertiz/personnel/me');
  }

  /// Personel kendini görev için aktif/pasif yapar.
  Future<Map<String, dynamic>> setMyDuty(bool onDuty) {
    return _send('PUT', '/expertiz/personnel/me/duty', body: {'on_duty': onDuty});
  }

  /// Admin: personelin görev durumunu değiştirir.
  Future<Map<String, dynamic>> setPersonnelDuty(String personnelId, bool onDuty) {
    return _send('PUT', '/expertiz/admin/personnel/$personnelId/duty', body: {'on_duty': onDuty});
  }

  // ---------------------------------------------------------------------------
  // Admin ana ekran, iptal/iade, fatura dökümü, vitrin toplu işlemleri
  // ---------------------------------------------------------------------------

  /// Kullanıcı profili (fatura bilgileri dahil).
  Future<Map<String, dynamic>> getMyProfile() {
    return _get('/auth/profile');
  }

  /// [fields]: full_name, phone, company_name, city, tax_number, tax_office, invoice_address
  Future<Map<String, dynamic>> updateMyProfile(Map<String, dynamic> fields) {
    return _send('PUT', '/auth/profile', body: fields);
  }

  /// Müşterinin kendi talepleri (canlı durum `progress` ile).
  Future<Map<String, dynamic>> getMyRequests() {
    return _get('/expertiz/requests');
  }

  Future<Map<String, dynamic>> getAdminDashboard() {
    return _get('/expertiz/admin/dashboard');
  }

  /// Talebi iptal eder; [refund] true ise ödeme PayTR üzerinden iade edilir.
  Future<Map<String, dynamic>> cancelRequest(String reportId, {required String reason, bool refund = true}) {
    return _post('/expertiz/admin/requests/$reportId/cancel', body: {'reason': reason, 'refund': refund});
  }

  /// Kredi paketi siparişleri (admin). [status]: approved | refunded | pending | failed
  Future<Map<String, dynamic>> getCreditOrders({String? status}) {
    return _get('/payments/admin/orders${status == null ? '' : '?status=$status'}');
  }

  /// Kullanılmamış kredi paketini iade eder.
  Future<Map<String, dynamic>> refundCreditOrder(String orderId, {required String reason}) {
    return _post('/payments/admin/orders/$orderId/refund', body: {'reason': reason});
  }

  /// Muhasebe / e-Arşiv için tahsilat dökümü (CSV). Tarih: YYYY-AA-GG.
  Future<List<int>> downloadInvoiceCsv({required String start, required String end}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/expertiz/admin/finance/invoices.csv?start=$start&end=$end'),
      headers: _headers(),
    );
    if (response.statusCode >= 400) {
      throw ApiException(_errorMessage(_decodeResponse(response.body), response.statusCode), response.statusCode);
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> vitrinActivateHidden() {
    return _post('/vitrin/admin/activate-hidden');
  }

  Future<Map<String, dynamic>> vitrinReanalyze() {
    return _post('/vitrin/admin/reanalyze');
  }

  // ---------------------------------------------------------------------------
  // Bildirimler
  // ---------------------------------------------------------------------------

  /// [admin]: true ise admin ortak bildirim kutusu (+ kendi bildirimleri).
  Future<Map<String, dynamic>> getNotifications({bool admin = false, int limit = 30}) {
    return _get('/expertiz/${admin ? 'admin/' : ''}notifications?limit=$limit');
  }

  /// [ids] verilmezse tüm okunmamış bildirimler okundu olur.
  Future<Map<String, dynamic>> markNotificationsRead({bool admin = false, List<int>? ids}) {
    return _post('/expertiz/${admin ? 'admin/' : ''}notifications/read', body: {if (ids != null) 'ids': ids});
  }

  // ---------------------------------------------------------------------------
  // Personel saha raporu, fotoğraflar, kurumsal rapor
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getTaskReport(String taskId) {
    return _get('/expertiz/personnel/tasks/$taskId/report');
  }

  Future<Map<String, dynamic>> saveTaskDraft(String taskId, Map<String, dynamic> tamRapor) {
    return _send('PUT', '/expertiz/personnel/tasks/$taskId/draft', body: {'tam_rapor': tamRapor});
  }

  Future<Map<String, dynamic>> submitTaskReport(String taskId, Map<String, dynamic> tamRapor) {
    return _post('/expertiz/personnel/tasks/$taskId/submit', body: {'tam_rapor': tamRapor});
  }

  /// Fotoğraf veya kurumsal rapor (PDF/fotoğraf) yükler.
  /// [category]: inspection_photo | corporate_report
  /// [section]: arac | dis | ic | boya_kaporta | kurumsal | genel
  Future<Map<String, dynamic>> uploadTaskMedia(
    String taskId, {
    required List<int> bytes,
    required String fileName,
    required String category,
    String? section,
    String? itemKey,
    String? itemLabel,
    String? note,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/expertiz/personnel/tasks/$taskId/media'));
    final headers = _headers()..remove('Content-Type');
    request.headers.addAll(headers);
    request.fields['category'] = category;
    if (section != null) request.fields['section'] = section;
    if (itemKey != null) request.fields['item_key'] = itemKey;
    if (itemLabel != null) request.fields['item_label'] = itemLabel;
    if (note != null && note.isNotEmpty) request.fields['note'] = note;
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    return _handle(response);
  }

  Future<Map<String, dynamic>> deleteTaskMedia(String taskId, String mediaId) {
    return _send('DELETE', '/expertiz/personnel/tasks/$taskId/media/$mediaId');
  }

  /// Sunucunun döndürdüğü göreli medya yolunu (/api/v1/...) tam adrese çevirir.
  String resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return Uri.parse(baseUrl).resolve(path).toString();
  }

  /// Dosya içeriğini indirir (PDF önizleme için). Bağlantı imzalı olduğundan
  /// ek kimlik bilgisi gerekmez.
  Future<List<int>> downloadBytes(String path) async {
    final response = await _client.get(Uri.parse(resolveUrl(path)));
    if (response.statusCode >= 400) {
      throw ApiException('Dosya indirilemedi (HTTP ${response.statusCode})', response.statusCode);
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers.addAll(_headers());
    request.body = jsonEncode(body ?? <String, dynamic>{});
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    return _handle(response);
  }

  Map<String, String> _headers() {
    final token = _accessToken ??
        CentralAuthTokenStore.accessToken ??
        (_supabase ?? Supabase.instance.client).auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _handle(http.Response response) {
    final decoded = _decodeResponse(response.body);
    if (response.statusCode >= 400) {
      throw ApiException(_errorMessage(decoded, response.statusCode), response.statusCode);
    }
    return decoded;
  }

  String _errorMessage(Map<String, dynamic> decoded, int statusCode) {
    final detail = decoded['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is List && detail.isNotEmpty) {
      // FastAPI doğrulama hatası: [{loc: [...], msg: '...'}]
      return detail
          .map((item) => item is Map ? (item['msg']?.toString() ?? item.toString()) : item.toString())
          .join(', ');
    }
    if (statusCode == 401) return 'Oturum süresi doldu, lütfen tekrar giriş yapın';
    if (statusCode == 403) return 'Bu işlem için yetkiniz yok';
    return 'API isteği başarısız (HTTP $statusCode)';
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _handle(response);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: (queryParams == null || queryParams.isEmpty) ? null : queryParams,
    );
    final response = await _client.get(uri, headers: _headers());
    return _handle(response);
  }

  Future<Map<String, dynamic>> _put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _client.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _handle(response);
  }

  Map<String, dynamic> _decodeResponse(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    } on FormatException {
      return {'detail': body.length > 200 ? body.substring(0, 200) : body};
    }
  }
}

/// Merkezi API hatası. [message] kullanıcıya gösterilebilir Türkçe mesajdır.
class ApiException implements Exception {
  ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
