import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yerimebak_sistemleri/models/user_model.dart';
import 'package:yerimebak_sistemleri/routing/app_router.dart';
import 'package:yerimebak_sistemleri/providers/user_provider.dart';
import 'package:yerimebak_sistemleri/screens/login_screen.dart';

class TestUserProvider extends ChangeNotifier implements UserProvider {
  @override
  UserModel? get currentUser => null;
  @override
  bool get isLoading => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  UserModel user(UserRole role) => UserModel(id: '1', email: 'test@example.test', fullName: 'Test', role: role, createdAt: DateTime(2026));

  test('giriş ve başlangıç kullanıcı rolüne göre ayrı panele yönlendirir', () {
    expect(panelRedirect('/', null), '/login');
    expect(panelRedirect('/', user(UserRole.admin)), '/admin');
    expect(panelRedirect('/', user(UserRole.fieldStaff)), '/personel');
    expect(panelRedirect('/', user(UserRole.customer)), '/musteri');
  });

  test('başka role ait panele erişim engellenir', () {
    expect(panelRedirect('/personel', user(UserRole.customer)), '/unauthorized');
    expect(panelRedirect('/admin', user(UserRole.fieldStaff)), '/unauthorized');
    expect(panelRedirect('/musteri', user(UserRole.fieldStaff)), '/unauthorized');
    expect(panelRedirect('/personel', null), '/login');
    expect(panelRedirect('/personel', user(UserRole.fieldStaff)), isNull);
  });

  test('çıkışta kullanıcı durumu gerçekten temizlenir', () {
    final state = UserProviderState(currentUser: user(UserRole.fieldStaff));
    expect(state.copyWith(currentUser: null).currentUser, isNull);
    expect(state.copyWith(isLoading: true).currentUser, isNotNull);
  });

  testWidgets('uygulama açılışı giriş ekranına ulaşır', (tester) async {
    final provider = TestUserProvider();
    await tester.pumpWidget(ChangeNotifierProvider<UserProvider>.value(
      value: provider,
      child: Builder(builder: (context) => MaterialApp.router(routerConfig: createRouter(context))),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
