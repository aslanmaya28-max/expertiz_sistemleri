import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user_model.dart';
import 'shared_preferences_manager.dart';

/// Merkezi oturum anahtari. Bellekte tutulur ve cihazda saklanir; boylece web'de
/// sayfa yenilenince veya mobilde uygulama yeniden acilinca oturum kapanmaz.
/// Sunucu anahtari reddederse (suresi dolmus) [clear] ile silinir.
class CentralAuthTokenStore {
  static const _prefsKey = 'yerimebak_central_token';
  static String? _token;

  static String? get accessToken => _token;

  static set accessToken(String? value) {
    _token = value;
    // Kaydetme arka planda; hata olursa oturum yine bellekte surer
    if (value == null) {
      SharedPreferencesManager.remove(_prefsKey);
    } else {
      SharedPreferencesManager.setString(_prefsKey, value);
    }
  }

  /// Uygulama acilisinda cagrilir.
  static Future<void> restore() async {
    final saved = await SharedPreferencesManager.getString(_prefsKey);
    if (saved != null && saved.isNotEmpty && !_isExpired(saved)) {
      _token = saved;
    } else if (saved != null) {
      await SharedPreferencesManager.remove(_prefsKey);
    }
  }

  static void clear() => accessToken = null;

  /// JWT 'exp' alanina bakar (imza dogrulamasini sunucu yapar).
  static bool _isExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map;
      final exp = payload['exp'];
      if (exp is! num) return false;
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000).isBefore(DateTime.now());
    } catch (_) {
      return true;
    }
  }
}

class CentralAuthSession {
  const CentralAuthSession({
    required this.token,
    required this.user,
  });

  final String token;
  final UserModel user;
}

class CentralAuthException implements Exception {
  const CentralAuthException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
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
    required bool termsAccepted,
    String? phone,
  }) async {
    return _postSession('/auth/register', {
      'email': email,
      'password': password,
      'full_name': fullName,
      'terms_accepted': termsAccepted,
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
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      if (response.statusCode >= 400) {
        throw CentralAuthException(response.statusCode, 'Merkezi auth isteği başarısız');
      }
      rethrow;
    }
    final map = decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    if (response.statusCode >= 400) {
      throw CentralAuthException(response.statusCode, map['detail']?.toString() ?? 'Merkezi auth istegi basarisiz');
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
