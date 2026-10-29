import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yerimebak_sistemleri/models/user_model.dart';
import 'package:yerimebak_sistemleri/providers/user_provider.dart';
import 'package:yerimebak_sistemleri/repositories/auth_repository.dart';

class TestRepository extends AuthRepository {
  TestRepository() : super(supabase: SupabaseClient('http://localhost', 'test-key'));
  final events = StreamController<AuthState>.broadcast();
  bool centralActive = false;
  @override
  Stream<AuthState> get authStateChanges => events.stream;
  @override
  bool isAuthenticated() => centralActive;
  @override
  String? get centralAccessToken => centralActive ? 'test-token' : null;
  @override
  Future<AuthResult> signIn({required String email, required String password}) async {
    centralActive = true;
    return AuthResult.success(UserModel(id: '1', email: email, fullName: 'Test', role: UserRole.fieldStaff, createdAt: DateTime(2026)));
  }
}

void main() {
  test('Supabase boş oturum olayı merkezi personel oturumunu silmez', () async {
    final repo = TestRepository();
    final provider = UserProvider(authRepository: repo);
    expect(await provider.login(email: 'test@example.test', password: 'test'), isTrue);
    repo.events.add(const AuthState(AuthChangeEvent.signedOut, null));
    await Future<void>.delayed(Duration.zero);
    expect(provider.currentUser?.role, UserRole.fieldStaff);
    repo.centralActive = false;
    repo.events.add(const AuthState(AuthChangeEvent.signedOut, null));
    await Future<void>.delayed(Duration.zero);
    expect(provider.currentUser, isNull);
    provider.dispose();
    await repo.events.close();
  });
}
