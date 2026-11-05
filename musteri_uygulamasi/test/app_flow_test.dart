import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yerimebak/api/api_client.dart';
import 'package:yerimebak/api/models.dart';
import 'package:yerimebak/api/providers.dart';
import 'package:yerimebak/api/repositories.dart';
import 'package:yerimebak/app.dart';
import 'package:yerimebak/bilesenler/pazarlik_uclusu.dart';
import 'api_client_test.dart' show MemoryTokens;
import 'report_view_test.dart' show fixture;

class FakePlatform implements PlatformServices {
  final opened = <String>[];
  @override
  Future<String> version() async => '1.0.0';
  @override
  Future<void> openLink(String url) async {
    opened.add(url);
  }

  @override
  Future<void> openPdf(ApiClient api, String reportId) async {
    final pdf = await api.getPdf('/valuation/reports/$reportId/pdf');
    expect(utf8.decode(pdf), startsWith('%PDF-'));
    opened.add(reportId);
  }
}

class AppFixture {
  final store = MemoryTokens();
  final platform = FakePlatform();
  final calls = <http.Request>[];
  final int configStatus;
  final String minVersion;
  final Json? report;
  late final ApiClient api;
  AppFixture({
    this.configStatus = 200,
    this.minVersion = '1.0.0',
    this.report,
  }) {
    api = ApiClient(
      store: store,
      client: MockClient((r) async {
        calls.add(r);
        final path = r.url.path;
        Json body = {};
        int status = 200;
        if (path.endsWith('/app/config')) {
          status = configStatus;
          body = {'min_supported_version': minVersion};
        }
        if (path.endsWith('/auth/login') || path.endsWith('/auth/register')) {
          body = {'token': 'valid'};
        }
        if (path.endsWith('/auth/profile')) {
          body = {
            'profile': {
              'id': 20,
              'email': 'sentetik@example.test',
              'full_name': 'Örnek Müşteri',
              'phone': '05551230000',
              'role': 'customer',
              'credits': 5,
              'email_verified': false,
            },
          };
        }
        if (path.endsWith('/credits/balance')) body = {'credits': 5};
        if (path.endsWith('/valuation/reports')) {
          body = {
            'reports': [
              {
                'id': 'report20',
                'arac': {'marka': 'Seat', 'model': 'Ibiza', 'yil': 2024},
                'report_no': 'YD 2026-000020',
                'created_at': '2026-11-04T12:00:00Z',
                'karar': 'Analiz',
                'ozet_kayit': false,
              },
            ],
            'total': 1,
            'offset': 0,
          };
        }
        if (path.endsWith('/valuation/reports/report20')) {
          body = report ?? fixture();
        }
        if (path.endsWith('/pdf')) {
          expect(r.headers['authorization'], 'Bearer valid');
          return http.Response(
            '%PDF-1.7\n',
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  }
  Future<ProviderContainer> pump(WidgetTester tester) async {
    await initializeDateFormatting('tr_TR');
    final container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(api),
        platformProvider.overrideWithValue(platform),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const YerimeBakApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }
}

void main() {
  testWidgets('giriş, raporlarım, detay ve kimlikli PDF akışı', (tester) async {
    final app = AppFixture();
    await app.pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-posta'),
      'sentetik@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Şifre'),
      'Musteri123!',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş yap'));
    await tester.pumpAndSettle();
    expect(find.text('5 kredi'), findsOneWidget);
    expect(find.text('E-posta adresinizi doğrulayın'), findsOneWidget);
    await tester.tap(find.text('Raporlarım').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seat Ibiza 2024'));
    await tester.pumpAndSettle();
    expect(find.text('Özet'), findsOneWidget);
    await tester.tap(find.text('PDF rapor'));
    await tester.pumpAndSettle();
    expect(app.platform.opened, ['report20']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'satıcı mesajı kısayolu fiyat planı yerine doğrudan mesajı açar',
    (tester) async {
      final data = fixture()
        ..['pazarlikPlani'] = {
          'saticiMesaji': 'Belgeleri paylaşır mısınız?',
          'acilisTeklifi': 900000,
          'hedefFiyat': 930000,
          'ustSinir': 940000,
        };
      final app = AppFixture(report: data);
      app.store.token = 'valid';
      final container = await app.pump(tester);
      container.read(routerProvider).go('/raporlar/report20');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Satıcıya mesaj'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.byType(SelectableText)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.byType(PazarlikUclusu)),
        findsNothing,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Mesajı kopyala')),
        findsOneWidget,
      );
    },
  );

  testWidgets('zorunlu güncelleme doğrudan profil rotasıyla geçilemez', (
    tester,
  ) async {
    final app = AppFixture(minVersion: '2.0.0');
    final container = await app.pump(tester);
    expect(find.text('Güncelleme gerekli'), findsOneWidget);
    container.read(routerProvider).go('/profil');
    await tester.pumpAndSettle();
    expect(find.text('Güncelleme gerekli'), findsOneWidget);
    expect(find.text('Hesap bilgileri'), findsNothing);
  });

  testWidgets(
    'eski sunucuda silme gizlenir, derin bağlantıda işlem gönderilmez',
    (tester) async {
      final app = AppFixture(configStatus: 404);
      app.store.token = 'valid';
      final container = await app.pump(tester);
      container.read(routerProvider).go('/profil');
      await tester.pumpAndSettle();
      expect(find.text('Hesabımı sil'), findsNothing);
      container.read(routerProvider).go('/profil/sil');
      await tester.pumpAndSettle();
      expect(find.text('Hesabımı kalıcı olarak sil'), findsNothing);
      expect(
        app.calls.where((r) => r.url.path.endsWith('delete-account')),
        isEmpty,
      );
    },
  );

  testWidgets('hesap silmede onay gereklidir, başarı oturumu kapatır', (
    tester,
  ) async {
    final app = AppFixture();
    app.store.token = 'valid';
    final container = await app.pump(tester);
    container.read(routerProvider).go('/profil/sil');
    await tester.pumpAndSettle();
    final button = find.widgetWithText(
      FilledButton,
      'Hesabımı kalıcı olarak sil',
    );
    await tester.ensureVisible(button);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mevcut şifre'),
      'Musteri123!',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(app.store.token, isNull);
    expect(find.widgetWithText(FilledButton, 'Giriş yap'), findsOneWidget);
    expect(
      app.calls.where((r) => r.url.path.endsWith('delete-account')),
      hasLength(1),
    );
  });
}
