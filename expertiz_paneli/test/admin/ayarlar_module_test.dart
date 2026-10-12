import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yerimebak_sistemleri/admin/modules/ayarlar_module.dart';
import 'package:yerimebak_sistemleri/admin/services/admin_preferences.dart';
import 'package:yerimebak_sistemleri/providers/theme_provider.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

Widget _app(ThemeProvider theme, http.Client client) => ChangeNotifierProvider.value(
      value: theme,
      child: Consumer<ThemeProvider>(
        builder: (context, t, _) => MaterialApp(
          themeMode: t.themeMode,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: Scaffold(
            body: AyarlarModule(
              apiService: YerimebakExpertizApiService(
                baseUrl: 'http://api.test/api/v1',
                client: client,
                accessToken: 'admin-token',
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('tema kartlari secilen temaya gecer (toggle degil)', (tester) async {
    final theme = ThemeProvider();
    await tester.pumpWidget(_app(theme, MockClient((_) async => http.Response('{}', 200))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('🌙 Gece Modu'));
    await tester.pumpAndSettle();
    expect(theme.themeMode, ThemeMode.dark);

    // Aynı karta tekrar basmak temayı geri çevirmez.
    await tester.tap(find.text('🌙 Gece Modu'));
    await tester.pumpAndSettle();
    expect(theme.themeMode, ThemeMode.dark);

    await tester.tap(find.text('☀️ Aydınlık Mod'));
    await tester.pumpAndSettle();
    expect(theme.themeMode, ThemeMode.light);
  });

  testWidgets('yeni rapor uyarisi tercihi kaydedilir', (tester) async {
    await tester.pumpWidget(_app(ThemeProvider(), MockClient((_) async => http.Response('{}', 200))));
    await tester.pumpAndSettle();
    expect(await AdminPreferences.newReportAlertsEnabled(), isTrue);

    await tester.tap(find.text('Yeni rapor uyarıları'));
    await tester.pumpAndSettle();

    expect(await AdminPreferences.newReportAlertsEnabled(), isFalse);
  });

  testWidgets('sifre degistirme API ye gonderilir, hata mesaji gosterilir', (tester) async {
    final bodies = <Map<String, dynamic>>[];
    var cevap = http.Response('{"detail":"Mevcut sifre hatali"}', 403);
    await tester.pumpWidget(_app(ThemeProvider(), MockClient((request) async {
      expect(request.url.path, '/api/v1/auth/change-password');
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return cevap;
    })));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Şifre Değiştir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Mevcut şifre'), 'EskiSifre1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Yeni şifre'), 'zayif');
    await tester.enterText(find.widgetWithText(TextFormField, 'Yeni şifre (tekrar)'), 'zayif');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('En az 8 karakter'), findsOneWidget);
    expect(bodies, isEmpty);

    await tester.enterText(find.widgetWithText(TextFormField, 'Yeni şifre'), 'YeniSifre2');
    await tester.enterText(find.widgetWithText(TextFormField, 'Yeni şifre (tekrar)'), 'YeniSifre2');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(bodies.single, {'current_password': 'EskiSifre1', 'new_password': 'YeniSifre2'});
    expect(find.text('Mevcut sifre hatali'), findsOneWidget);

    cevap = http.Response('{"success":true}', 200);
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Şifreniz değiştirildi'), findsOneWidget);
  });
}
