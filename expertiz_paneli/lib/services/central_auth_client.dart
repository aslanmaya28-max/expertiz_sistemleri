import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user_model.dart';

class CentralAuthTokenStore {
  static String? accessToken;
}

class CentralAuthSession {
  const CentralAuthSession({
    required this.token,
    required this.user,
  });

  final String token;
  final UserModel user;
}

class CentralAuthClient {
  CentralAuthClient({
    this.baseUrl = const String.fromEnvironment(
      'YERIMEBAK_API_BASE_URL',
      defaultValue: 'http://localhost:8000/api/v1',
    ),
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<CentralAuthSession> login({
    required String email,
    required String password,
  }) async {
    return _postSession('/auth/login', {
      'email': email,
      'password': password,
    });
  }

  Future<CentralAuthSession> registerCustomer({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    return _postSession('/auth/register', {
      'email': email,
      'password': password,
      'full_name': fullName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
  }

  Future<UserModel> me(String token) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final decoded = _decode(response);
    return UserModel.fromJson(_userJson(decoded));
  }

  Future<CentralAuthSession> _postSession(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final decoded = _decode(response);
    return CentralAuthSession(
      token: decoded['token']?.toString() ?? '',
      user: UserModel.fromJson(_userJson(decoded)),
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    final map = decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    if (response.statusCode >= 400) {
      throw Exception(map['detail']?.toString() ?? 'Merkezi auth istegi basarisiz');
    }
    return map;
  }

  Map<String, dynamic> _userJson(Map<String, dynamic> decoded) {
    final user = decoded['user'];
    if (user is Map<String, dynamic>) return user;
    if (user is Map) return Map<String, dynamic>.from(user);
    throw Exception('Merkezi auth kullanici verisi eksik');
  }
}
