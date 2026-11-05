import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../oturum/token_store.dart';

class ApiFailure implements Exception {
  final String message;
  final int status;
  final String? code;
  const ApiFailure(this.message, {this.status = 0, this.code});
  static ApiFailure fromResponse(int status, String body) {
    String message = 'İşlem tamamlanamadı. Tekrar deneyin.';
    String? code;
    try {
      final data = jsonDecode(body);
      final detail = data is Map ? data['detail'] : null;
      if (detail is String) message = detail;
      if (detail is Map) {
        message = detail['message']?.toString() ?? message;
        code = detail['code']?.toString();
      }
      if (detail is List) {
        message = detail
            .whereType<Map>()
            .map((e) => e['msg']?.toString() ?? '')
            .join('; ');
      }
    } catch (_) {
      /* HTML/boş hata gövdesi kullanıcıya gösterilmez. */
    }
    if (status == 402 && code == 'insufficient_credits') {
      return InsufficientCredits(message);
    }
    return ApiFailure(message, status: status, code: code);
  }

  @override
  String toString() => message;
}

class InsufficientCredits extends ApiFailure {
  const InsufficientCredits(super.message)
    : super(status: 402, code: 'insufficient_credits');
}

class ApiClient {
  final http.Client client;
  final TokenStore store;
  final Uri baseUri;
  final Duration timeout;
  void Function()? onUnauthorized;
  Future<String?>? _refreshing;
  int _generation = 0;
  Future<void> _storageWrites = Future.value();

  ApiClient({
    required this.store,
    http.Client? client,
    Uri? baseUri,
    this.timeout = const Duration(seconds: 30),
  }) : client = client ?? http.Client(),
       baseUri =
           baseUri ??
           Uri.parse(
             const String.fromEnvironment(
               'API_BASE_URL',
               defaultValue: 'http://10.0.2.2:8000/api/v1',
             ),
           ) {
    if (!['http', 'https'].contains(this.baseUri.scheme) ||
        !this.baseUri.hasAuthority) {
      throw ArgumentError('Geçersiz API adresi');
    }
    const release = bool.fromEnvironment('dart.vm.product');
    if (release && this.baseUri.scheme != 'https') {
      throw ArgumentError('Üretimde HTTPS API adresi gerekir');
    }
  }

  Future<void> _serialize(Future<void> Function() action) {
    final next = _storageWrites.then((_) => action());
    _storageWrites = next.catchError((Object _) {});
    return next;
  }

  Future<void> saveSession(String token) {
    _generation++;
    _refreshing = null;
    return _serialize(() => store.write(token));
  }

  Future<void> clearSession() {
    _generation++;
    _refreshing = null;
    return _serialize(store.clear);
  }

  Future<http.Response> _send(
    String method,
    String path,
    Object? body,
    String? token, {
    Duration? timeout,
  }) async {
    if (!path.startsWith('/') ||
        path.startsWith('//') ||
        path.contains('://')) {
      throw ArgumentError('Geçersiz API yolu');
    }
    final url = Uri.parse(
      '${baseUri.toString().replaceAll(RegExp(r'/$'), '')}$path',
    );
    try {
      final request = http.Request(method, url)
        ..followRedirects = false
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'application/json';
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (body != null) request.body = jsonEncode(body);
      return await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout ?? this.timeout);
    } on TimeoutException {
      throw const ApiFailure('Sunucu yanıtı gecikti. Lütfen tekrar deneyin.');
    } on http.ClientException {
      throw const ApiFailure(
        'İnternet bağlantınızı kontrol edip tekrar deneyin.',
      );
    }
  }

  Future<String?> _refresh(String oldToken, int generation) async {
    final response = await _send('POST', '/auth/refresh-token', null, oldToken);
    if (response.statusCode != 200) return null;
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final token = data is Map ? data['token'] : null;
      if (token is! String || token.isEmpty || generation != _generation) {
        return null;
      }
      var saved = false;
      await _serialize(() async {
        final currentToken = await store.read();
        if (generation == _generation && currentToken == oldToken) {
          await store.write(token);
          saved = true;
        }
      });
      return saved ? token : null;
    } on FormatException {
      return null;
    }
  }

  Future<http.Response> request(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
    Duration? timeout,
  }) async {
    final generation = _generation;
    await _storageWrites;
    final token = authenticated ? await store.read() : null;
    _checkSession(generation, authenticated);
    var response = await _send(method, path, body, token, timeout: timeout);
    if (response.statusCode == 401 &&
        authenticated &&
        token != null &&
        generation == _generation) {
      String? replacement;
      final current = await store.read();
      _checkSession(generation, authenticated);
      if (current != token) {
        replacement = current;
      } else {
        final pending = _refreshing ??= _refresh(token, generation);
        try {
          replacement = await pending;
        } finally {
          if (identical(_refreshing, pending)) _refreshing = null;
        }
      }
      if (replacement != null && generation == _generation) {
        response = await _send(
          method,
          path,
          body,
          replacement,
          timeout: timeout,
        );
      }
    }
    if (authenticated && generation != _generation) {
      throw const ApiFailure(
        'Oturum değişti. Tekrar giriş yapın.',
        status: 401,
      );
    }
    if (response.statusCode == 401 && authenticated) {
      final clearingGeneration = _generation + 1;
      await clearSession();
      if (_generation == clearingGeneration) onUnauthorized?.call();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiFailure.fromResponse(
        response.statusCode,
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
    }
    return response;
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path,
    Object? body,
    bool authenticated, {
    Duration? timeout,
  }) async {
    final response = await request(
      method,
      path,
      body: body,
      authenticated: authenticated,
      timeout: timeout,
    );
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map<String, dynamic>) return value;
    } catch (_) {
      /* Yanlış biçimli başarılı yanıt da güvenilir veri değildir. */
    }
    throw const ApiFailure('Sunucu yanıtı okunamadı. Tekrar deneyin.');
  }

  Future<Map<String, dynamic>> get(String path, {bool authenticated = true}) =>
      _json('GET', path, null, authenticated);
  /// [timeout] yalnız uzun süren işlerde (analiz 60–180 sn) varsayılan 30 sn'yi aşar.
  Future<Map<String, dynamic>> post(
    String path,
    Object body, {
    bool authenticated = true,
    Duration? timeout,
  }) => _json('POST', path, body, authenticated, timeout: timeout);
  Future<Map<String, dynamic>> put(String path, Object body) =>
      _json('PUT', path, body, true);
  Future<Uint8List> getPdf(String path) async {
    final response = await request('GET', path);
    if (!(response.headers['content-type'] ?? '').contains('application/pdf') ||
        !utf8
            .decode(response.bodyBytes.take(5).toList(), allowMalformed: true)
            .startsWith('%PDF-')) {
      throw const ApiFailure('Sunucu geçerli bir PDF raporu döndürmedi.');
    }
    return response.bodyBytes;
  }

  int get sessionEpoch => _generation;
  void _checkSession(int expected, bool authenticated) {
    if (authenticated && expected != _generation) {
      throw const ApiFailure(
        'Oturum değişti. Tekrar giriş yapın.',
        status: 401,
      );
    }
  }

  void close() => client.close();
}
