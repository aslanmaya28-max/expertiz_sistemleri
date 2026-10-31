import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/services/central_auth_client.dart';

void main() {
  test('login posts credentials to central auth endpoint and returns session', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'http://localhost:8000/api/v1/auth/login');
      expect(jsonDecode(request.body), {
        'email': 'ali@yerimebak.com',
        'password': 'secret-123',
      });

      return http.Response(
        jsonEncode({
          'success': true,
          'token': 'central-token',
          'user': {
            'id': 'user-1',
            'email': 'ali@yerimebak.com',
            'full_name': 'Ali Veli',
            'role': 'customer',
            'is_active': true,
          },
        }),
        200,
      );
    });

    final authClient = CentralAuthClient(client: client);
    final session = await authClient.login(
      email: 'ali@yerimebak.com',
      password: 'secret-123',
    );

    expect(session.token, 'central-token');
    expect(session.user.email, 'ali@yerimebak.com');
    expect(session.user.isCustomer, isTrue);
  });

  test('registerCustomer posts profile data to central register endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'http://localhost:8000/api/v1/auth/register');
      expect(jsonDecode(request.body), {
        'email': 'ayse@yerimebak.com',
        'password': 'secret-123',
        'full_name': 'Ayse Yilmaz',
        'phone': '+905551112233',
        'terms_accepted': true,
      });

      return http.Response(
        jsonEncode({
          'success': true,
          'token': 'new-token',
          'user': {
            'id': 'user-2',
            'email': 'ayse@yerimebak.com',
            'full_name': 'Ayse Yilmaz',
            'phone': '+905551112233',
            'role': 'customer',
          },
        }),
        200,
      );
    });

    final authClient = CentralAuthClient(client: client);
    final session = await authClient.registerCustomer(
      email: 'ayse@yerimebak.com',
      password: 'secret-123',
      fullName: 'Ayse Yilmaz',
      phone: '+905551112233',
      termsAccepted: true,
    );

    expect(session.token, 'new-token');
    expect(session.user.fullName, 'Ayse Yilmaz');
    expect(session.user.phone, '+905551112233');
  });

  test('me sends bearer token to central current-user endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'http://localhost:8000/api/v1/auth/me');
      expect(request.headers['Authorization'], 'Bearer central-token');

      return http.Response(
        jsonEncode({
          'success': true,
          'user': {
            'id': 'admin-1',
            'email': 'admin@yerimebak.com',
            'full_name': 'Admin User',
            'role': 'admin',
          },
        }),
        200,
      );
    });

    final authClient = CentralAuthClient(client: client);
    final user = await authClient.me('central-token');

    expect(user.email, 'admin@yerimebak.com');
    expect(user.isAdmin, isTrue);
  });

  test('me preserves HTTP status when server rejects a token', () async {
    final auth = CentralAuthClient(client: MockClient((_) async => http.Response('unauthorized', 401)));
    await expectLater(auth.me('token'), throwsA(isA<CentralAuthException>().having((e) => e.statusCode, 'status', 401)));
  });
}
