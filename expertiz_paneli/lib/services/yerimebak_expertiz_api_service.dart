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

  /// Müşteri ekspertiz talebi oluşturur → admin "Atama Bekleyen" kuyruğuna düşer.
  Future<Map<String, dynamic>> createExpertizRequest({
    required String firmId,
    required String packageId,
    String? plate,
    String? city,
    String? listingUrl,
    String? note,
  }) {
    return _post('/expertiz/requests', body: {
      'firm_id': firmId,
      'package_id': packageId,
      if (plate != null && plate.isNotEmpty) 'plate': plate,
      if (city != null && city.isNotEmpty) 'city': city,
      if (listingUrl != null && listingUrl.isNotEmpty) 'listing_url': listingUrl,
      if (note != null && note.isNotEmpty) 'note': note,
    });
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

  /// action: accept | start
  Future<Map<String, dynamic>> updateMyTask(String taskId, String action) {
    return _post('/expertiz/personnel/tasks/$taskId/$action');
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
