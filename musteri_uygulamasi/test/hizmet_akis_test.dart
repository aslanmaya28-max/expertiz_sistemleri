import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak/app.dart';
import 'package:yerimebak/hizmetler/hizmet_tanitim.dart';
import 'package:yerimebak/hizmetler/randevu.dart';
import 'package:yerimebak/tema/tema.dart';
import 'app_flow_test.dart' show AppFixture;

const katalog = {
  'service_fee_tl': 4321.37,
  'service_fee_incl_vat_tl': 9876.54,
  'firms': [
    {
      'id': 'firma',
      'name': 'Örnek Firma',
      'packages': [
        {'id': 'paket', 'name': 'Kontrol paketi', 'price': 2300.51},
      ],
    },
  ],
};

void main() {
  testWidgets('talep durumu müşteri zaman çizelgesini gösterir', (
    tester,
  ) async {
    final app = AppFixture(
      responses: {
        '/api/v1/expertiz/requests': {
          'requests': [
            {
              'id': 'talep1',
              'status': 'draft',
              'progress': {
                'label': 'Uzman araç başında',
                'next_label': 'Kurumsal ekspertizde',
                'person_name': 'Örnek K.',
                'admin_note': 'İç not gösterilmemeli',
                'steps': [
                  {'label': 'Talebiniz alındı', 'done': true},
                  {'label': 'Kurumsal ekspertizde', 'done': false},
                ],
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
    expect(find.text('Uzman araç başında'), findsOneWidget);
    expect(find.text('Örnek K.'), findsOneWidget);
    expect(find.text('Talebiniz alındı'), findsOneWidget);
    expect(find.text('İç not gösterilmemeli'), findsNothing);
  });
  testWidgets(
    'fiyatlar ve KDV dahil hizmet tutarı hesaplanmadan sunucudan gösterilir',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: YbTema.acik,
          home: const Scaffold(
            body: HizmetFiyati({
              'totals': {
                'service_fee_tl': 4321.37,
                'service_fee_incl_vat_tl': 9876.54,
                'vat_tl': 222.33,
                'package_price_tl': 100.25,
                'total_tl': 7654.32,
              },
            }, toplam: true),
          ),
        ),
      );
      for (final price in [
        '4.321,37 TL',
        'KDV hariç · KDV dahil 9.876,54 TL',
        '222,33 TL',
        '100,25 TL',
        '7.654,32 TL',
      ]) {
        expect(find.text(price), findsOneWidget);
      }
    },
  );
  testWidgets(
    'kapalı kart tanıtıma gider, derin talep ve ödeme rotaları da kapalıdır',
    (tester) async {
      final app = AppFixture(responses: {'/api/v1/expertiz/packages': katalog});
      app.store.token = 'valid';
      final c = await app.pump(tester);
      await tester.ensureVisible(find.text('Yerinde ekspertiz yaptırın'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yerinde ekspertiz yaptırın'));
      await tester.pumpAndSettle();
      expect(find.text('Açılınca bana haber ver'), findsOneWidget);
      for (final path in ['/ekspertiz/talep', '/ekspertiz/odeme/order1']) {
        c.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(find.text('Açılınca bana haber ver'), findsOneWidget);
        expect(find.text('Ödemeye geç'), findsNothing);
      }
      expect(
        app.calls.where(
          (r) => r.method == 'POST' && r.url.path.contains('expertiz'),
        ),
        isEmpty,
      );
    },
  );
  testWidgets('açık kart firma seçimiyle talep akışını açar', (tester) async {
    final app = AppFixture(
      responses: {
        '/api/v1/app/config': {'expertiz_enabled': true},
        '/api/v1/expertiz/packages': katalog,
        '/api/v1/expertiz/quote': {
          'totals': {
            'service_fee_tl': 4321.37,
            'service_fee_incl_vat_tl': 9876.54,
            'package_price_tl': 2300.51,
            'vat_tl': 222.33,
            'total_tl': 8765.43,
          },
        },
      },
    );
    app.store.token = 'valid';
    await app.pump(tester);
    await tester.ensureVisible(find.text('Yerinde ekspertiz yaptırın'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yerinde ekspertiz yaptırın'));
    await tester.pumpAndSettle();
    expect(find.text('Hangi firmada inceletmek istersiniz?'), findsOneWidget);
    expect(find.text('Açılınca bana haber ver'), findsNothing);
    expect(find.text('4.321,37 TL'), findsOneWidget);
    expect(find.text('8.765,43 TL'), findsOneWidget);
  });
  testWidgets(
    'rapordan araç ön dolumu ve onaylı talep sunucuya hesap eklemeden gider',
    (tester) async {
      final app = AppFixture(
        responses: {
          '/api/v1/app/config': {'expertiz_enabled': true},
          '/api/v1/expertiz/packages': katalog,
          '/api/v1/expertiz/quote': {
            'totals': {
              'service_fee_tl': 4321.37,
              'service_fee_incl_vat_tl': 9876.54,
              'package_price_tl': 2300.51,
              'vat_tl': 222.33,
              'total_tl': 8765.43,
            },
          },
          '/api/v1/expertiz/requests': {
            'order_id': 'order1',
            'request_id': 'request1',
            'provider': 'simulation',
            'kind': 'expertiz',
            'amount_tl': 8765.43,
          },
          '/api/v1/payments/checkout/order1': {
            'order_id': 'order1',
            'kind': 'expertiz',
            'status': 'pending',
          },
        },
      );
      app.store.token = 'valid';
      final container = await app.pump(tester);
      container
          .read(routerProvider)
          .go(
            '/ekspertiz/talep',
            extra: {
              'marka': 'Seat',
              'model': 'Ibiza',
              'yil': 2024.0,
              'km': 30000.0,
              'ilanFiyati': 960000.0,
            },
          );
      await tester.pumpAndSettle();
      Future<void> press(String label) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final f = find.widgetWithText(FilledButton, label);
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await press('Devam et');
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'İlan fiyatı (TL)'),
            )
            .controller!
            .text,
        '960000',
      );
      await tester.enterText(
        find.byKey(const ValueKey('talep-ilce')),
        'Adalar',
      );
      await tester.enterText(
        find.byKey(const ValueKey('talep-adres')),
        'Örnek sokak 1',
      );
      await tester.enterText(
        find.byKey(const ValueKey('talep-satici_telefon')),
        '05551234567',
      );
      final appointment = tester.widget<TextFormField>(
        find.byKey(const ValueKey('talep-zaman')),
      );
      appointment.controller!.text = randevuDegeri(
        ilkRandevu(DateTime.now()).add(const Duration(hours: 1)),
      );
      await press('Devam et');
      final legal = find.text('Ön Bilgilendirme Formu');
      await tester.ensureVisible(legal);
      await tester.pumpAndSettle();
      await tester.tap(legal);
      await tester.pumpAndSettle();
      expect(
        app.platform.opened.last,
        'https://www.yerimebak.com.tr/mesafeli-satis',
      );
      final check = find.byType(CheckboxListTile).first;
      await tester.ensureVisible(check);
      await tester.pumpAndSettle();
      await tester.tap(check);
      await tester.pumpAndSettle();
      final absent = find.byKey(const ValueKey('bulunamama-onayi'));
      await tester.ensureVisible(absent);
      await tester.tap(absent);
      await tester.pumpAndSettle();
      await press('Ödemeye geç');
      expect(find.text('Deneme ödeme modu'), findsOneWidget);
      final body = jsonDecode(
        app.calls
            .firstWhere(
              (r) =>
                  r.method == 'POST' &&
                  r.url.path.endsWith('/expertiz/requests'),
            )
            .body,
      );
      expect(body['city'], 'İstanbul');
      expect(body['district'], 'Adalar');
      expect(body['vehicle']['price'], 960000);
      expect(body['address'], 'Örnek sokak 1');
      expect(body['not_found_accepted'], true);
      expect(body['seller_phone'], '05551234567');
      expect(randevuHatasi(body['appointment_at'], DateTime.now()), isNull);
      expect(body.containsKey('total_tl'), false);
      container.read(routerProvider).go('/talepler');
      await tester.pumpAndSettle();
    },
  );
}
