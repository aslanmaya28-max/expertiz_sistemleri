import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yerimebak_sistemleri/models/user_model.dart';
import 'package:yerimebak_sistemleri/repositories/auth_repository.dart';
import 'package:yerimebak_sistemleri/services/central_auth_client.dart';

class FakeCentralAuthClient extends CentralAuthClient {
  String? loginEmail;
  String? loginPassword;
  String? registerEmail;
  String? registerPassword;
  String? registerFullName;
  String? registerPhone;
  String? lastMeToken;

  FakeCentralAuthClient();

  @override
  Future<CentralAuthSession> login({
    required String email,
    required String password,
  }) async {
    loginEmail = email;
    loginPassword = password;
    return CentralAuthSession(
      token: 'central-token',
      user: _user(email: email, fullName: 'Ali Veli'),
    );
  }

  @override
  Future<CentralAuthSession> registerCustomer({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    registerEmail = email;
    registerPassword = password;
    registerFullName = fullName;
    registerPhone = phone;
    return CentralAuthSession(
      token: 'registered-token',
      user: _user(email: email, fullName: fullName, phone: phone),
    );
  }

  @override
  Future<UserModel> me(String token) async {
    lastMeToken = token;
    return _user(email: 'ali@yerimebak.com', fullName: 'Ali Veli');
  }

  UserModel _user({
    required String email,
    required String fullName,
    String? phone,
  }) {
    return UserModel.fromJson({
      'id': 'user-1',
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'role': 'customer',
      'created_at': '2026-01-01T00:00:00.000Z',
    });
  }
}

void main() {
  late FakeCentralAuthClient centralAuth;
  late AuthRepository repository;

  setUp(() {
    centralAuth = FakeCentralAuthClient();
    repository = AuthRepository(
      supabase: SupabaseClient('http://localhost', 'anon-key'),
      centralAuthClient: centralAuth,
    );
  });

  test('signIn delegates credentials to central auth client', () async {
    final result = await repository.signIn(
      email: 'ali@yerimebak.com',
      password: 'secret-123',
    );

    expect(result.isSuccess, isTrue);
    expect(result.user!.email, 'ali@yerimebak.com');
    expect(repository.centralAccessToken, 'central-token');
    expect(centralAuth.loginEmail, 'ali@yerimebak.com');
    expect(centralAuth.loginPassword, 'secret-123');
  });

  test('signUp delegates customer registration to central auth client', () async {
    final result = await repository.signUp(
      email: 'ayse@yerimebak.com',
      password: 'secret-123',
      fullName: 'Ayse Yilmaz',
      phone: '+905551112233',
    );

    expect(result.isSuccess, isTrue);
    expect(result.user!.fullName, 'Ayse Yilmaz');
    expect(repository.centralAccessToken, 'registered-token');
    expect(centralAuth.registerEmail, 'ayse@yerimebak.com');
    expect(centralAuth.registerFullName, 'Ayse Yilmaz');
    expect(centralAuth.registerPhone, '+905551112233');
  });

  test('getCurrentUser reads current profile from central token', () async {
    await repository.signIn(
      email: 'ali@yerimebak.com',
      password: 'secret-123',
    );

    final result = await repository.getCurrentUser();

    expect(result.isSuccess, isTrue);
    expect(result.user!.fullName, 'Ali Veli');
    expect(centralAuth.lastMeToken, 'central-token');
  });
}
