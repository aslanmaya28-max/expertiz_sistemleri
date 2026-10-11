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

  Future<Map<String, dynamic>> publishReport(String reportId) {
    return _post('/expertiz/admin/reports/$reportId/publish');
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
    return _post('/trigger', body: {'report_id': reportId});
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
