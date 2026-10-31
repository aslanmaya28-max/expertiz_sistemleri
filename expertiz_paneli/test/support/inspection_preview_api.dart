import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

YerimebakExpertizApiService inspectionPreviewApi({bool editable = true}) =>
    YerimebakExpertizApiService(
      baseUrl: 'https://preview.invalid/api/v1',
      accessToken: 'fake-preview-token',
      client: MockClient((request) async => http.Response(
          jsonEncode({
            'editable': editable,
            'task': {
              'vehicle': {
                'brand': 'Seat',
                'model': 'Arona',
                'plate': 'TEST 001'
              }
            },
            'corporate': {
              'required': true,
              'firm_name': 'Örnek Firma',
              'package_name': 'Test Paketi'
            },
            'media': [],
            'draft_saved_at': '2026-10-29T10:00:00Z',
            'success': true,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'})),
    );
