import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak/app.dart';
import 'app_flow_test.dart' show AppFixture;
import 'hizmet_akis_test.dart' show katalog;

const testBolgesi = {
  'pilot': 'İstanbul',
  'tester': true,
  'cities': [
    {'il': 'Adana', 'durum': 'kapali', 'talep_acabilir': false},
    {'il': 'Ankara', 'durum': 'test', 'talep_acabilir': true},
  ],
};
const teklif = {
  'totals': {
    'service_fee_tl': 5000,
    'service_fee_incl_vat_tl': 6000,
    'package_price_tl': 2300,
    'vat_tl': 1000,
    'total_tl': 8300,
  },
};
void main() {
  for (final rota in ['/ekspertiz/talep', '/yerinde-inceleme']) {
    testWidgets(
      '$rota hizmet bölgesi 503 hatasından tekrar deneyerek kurtulur',
      (tester) async {
        final statuses = {'/api/v1/expertiz/service-area': 503};
        final app = AppFixture(
          statuses: statuses,
          responses: {
            '/api/v1/app/config': {'expertiz_enabled': false},
            '/api/v1/expertiz/service-area': testBolgesi,
            '/api/v1/expertiz/packages': katalog,
            '/api/v1/expertiz/quote': teklif,
          },
        );
        app.store.token = 'valid';
        final c = await app.pump(tester);
        c.read(routerProvider).go(rota);
        await tester.pumpAndSettle();
        expect(find.text('Bağlantı kurulamadı'), findsOneWidget);
        expect(find.text('Hangi firmada inceletmek istersiniz?'), findsNothing);
        statuses['/api/v1/expertiz/service-area'] = 200;
        await tester.ensureVisible(find.text('Tekrar dene'));
        await tester.tap(find.text('Tekrar dene'));
        await tester.pumpAndSettle();
        expect(find.text('Bağlantı kurulamadı'), findsNothing);
        expect(
          find.text(
            rota == '/ekspertiz/talep'
                ? 'Hangi firmada inceletmek istersiniz?'
                : 'Talep oluştur',
          ),
          findsOneWidget,
        );
      },
    );
  }
  testWidgets(
    'genel ayar kapalıyken sunucu izinli test ili talep formunu açar',
    (tester) async {
      final app = AppFixture(
        responses: {
          '/api/v1/app/config': {'expertiz_enabled': false},
          '/api/v1/expertiz/service-area': testBolgesi,
          '/api/v1/expertiz/packages': katalog,
          '/api/v1/expertiz/quote': teklif,
        },
      );
      app.store.token = 'valid';
      final c = await app.pump(tester);
      c.read(routerProvider).go('/ekspertiz/talep');
      await tester.pumpAndSettle();
      expect(find.text('Hangi firmada inceletmek istersiniz?'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Devam et'));
      await tester.tap(find.widgetWithText(FilledButton, 'Devam et'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Satıcı telefonu'),
        findsOneWidget,
      );
      final city = find.byKey(const ValueKey('talep-il'));
      await tester.ensureVisible(city);
      await tester.tap(city);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownMenuItem<String>>(
              find
                  .ancestor(
                    of: find.text('Adana (yakında)').last,
                    matching: find.byType(DropdownMenuItem<String>),
                  )
                  .first,
            )
            .enabled,
        false,
      );
      expect(find.text('Ankara (test)'), findsWidgets);
    },
  );
  testWidgets('bütün iller kapalıysa genel ayar açıkken de form gösterilmez', (
    tester,
  ) async {
    final app = AppFixture(
      responses: {
        '/api/v1/app/config': {'expertiz_enabled': true},
        '/api/v1/expertiz/service-area': {
          'cities': [
            {'il': 'İstanbul', 'durum': 'kapali', 'talep_acabilir': false},
          ],
        },
        '/api/v1/expertiz/packages': katalog,
      },
    );
    app.store.token = 'valid';
    final c = await app.pump(tester);
    c.read(routerProvider).go('/ekspertiz/talep');
    await tester.pumpAndSettle();
    expect(find.text('Hangi firmada inceletmek istersiniz?'), findsNothing);
    expect(find.text('Yerinde inceleme yakında'), findsOneWidget);
  });
  testWidgets(
    'talep kartı İstanbul randevusunu ve bulunamama iade rozetini gösterir',
    (tester) async {
      final app = AppFixture(
        responses: {
          '/api/v1/expertiz/requests': {
            'requests': [
              {
                'id': 'sentetik',
                'durum_kodu': 'vehicle_not_found',
                'payment_status': 'partially_refunded',
                'randevu': {
                  'tarih_saat': '2026-11-10T09:30:00Z',
                  'adres': 'Sentetik sokak 12, Ankara',
                  'satici_adi': 'Örnek Satıcı',
                  'satici_telefon': '05551234567',
                },
              },
            ],
          },
        },
      );
      app.store.token = 'valid';
      final c = await app.pump(tester);
      c.read(routerProvider).go('/talepler');
      await tester.pumpAndSettle();
      expect(find.text('10.11.2026 12:30 · İstanbul saati'), findsOneWidget);
      expect(find.text('Sentetik sokak 12, Ankara'), findsOneWidget);
      expect(find.text('Örnek Satıcı'), findsOneWidget);
      expect(
        find.text('Araç adreste bulunamadı — paket ücreti iade edildi'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'araç bulunamama bildirimi iade gerçekleşmeden iade edildi demez',
    (tester) async {
      final app = AppFixture(
        responses: {
          '/api/v1/expertiz/requests': {
            'requests': [
              {
                'id': 'sentetik',
                'durum_kodu': 'vehicle_not_found',
                'payment_status': 'paid',
              },
            ],
          },
        },
      );
      app.store.token = 'valid';
      final c = await app.pump(tester);
      c.read(routerProvider).go('/talepler');
      await tester.pumpAndSettle();
      expect(
        find.text('Araç adreste bulunamadı — paket ücreti iade sürecinde'),
        findsOneWidget,
      );
      expect(
        find.text('Araç adreste bulunamadı — paket ücreti iade edildi'),
        findsNothing,
      );
    },
  );
}
