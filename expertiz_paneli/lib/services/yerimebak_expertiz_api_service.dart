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

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = _accessToken ??
        CentralAuthTokenStore.accessToken ??
        (_supabase ?? Supabase.instance.client).auth.currentSession?.accessToken;
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body ?? <String, dynamic>{}),
    );

    final decoded = _decodeResponse(response.body);
    if (response.statusCode >= 400) {
      throw Exception(decoded['detail']?.toString() ?? 'API istegi basarisiz');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final token = _accessToken ??
        CentralAuthTokenStore.accessToken ??
        (_supabase ?? Supabase.instance.client).auth.currentSession?.accessToken;
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final response = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    final decoded = _decodeResponse(response.body);
    if (response.statusCode >= 400) {
      throw Exception(decoded['detail']?.toString() ?? 'API istegi basarisiz');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = _accessToken ??
        CentralAuthTokenStore.accessToken ??
        (_supabase ?? Supabase.instance.client).auth.currentSession?.accessToken;
    final response = await _client.put(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body ?? <String, dynamic>{}),
    );

    final decoded = _decodeResponse(response.body);
    if (response.statusCode >= 400) {
      throw Exception(decoded['detail']?.toString() ?? 'API istegi basarisiz');
    }
    return decoded;
  }

  Map<String, dynamic> _decodeResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'data': decoded};
  }
}
