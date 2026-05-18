/// Mobil paylasim yoluyla gelen ilan URL'lerini normalizes edip
/// backend'in analysis-intake endpoint'ine yollar.
///
/// Kaynak: mobile_share
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

class SharedListingIntakeService {
  static const String _defaultApiBase = '/api/v1/analysis-intake/url';

  /// Ham paylasim metninden URL cikarir ve backend'e gonderir.
  ///
  /// [rawText] paylasilan metin (genelde bir URL).
  /// [apiBase] API base URL, testlerde override edilebilir.
  ///
  /// Returns: Map with 'success', 'status', 'history_id' keys.
  static Future<Map<String, dynamic>> submitSharedUrl({
    required String rawText,
    String apiBase = _defaultApiBase,
    String? authToken,
  }) async {
    final url = _extractUrl(rawText.trim());

    if (url == null) {
      return {'success': false, 'error': 'Gecerli bir URL bulunamadi'};
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    try {
      final response = await http.post(
        Uri.parse(apiBase),
        headers: headers,
        body: jsonEncode({
          'url': url,
          'source': 'mobile_share',
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body;
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Ham paylasim metninden URL ayiklar.
  ///
  /// Basit regex ile http/https linkini bulur.
  /// Bulamazsa butun metni URL olarak dener.
  static String? _extractUrl(String text) {
    final urlRegex = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(text);
    if (match != null) {
      return match.group(0);
    }
    // Regex bulamadiysa, tum metin gecerli bir URL olabilir
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return text;
    }
    return null;
  }

  /// Test amaciyla payload olusturur (bagimsiz, http cagrisi yapmaz).
  static Map<String, String> buildPayload(String rawText) {
    final url = rawText.trim();
    return {'url': url, 'source': 'mobile_share'};
  }
}
