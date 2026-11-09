import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak/app.dart';
import 'package:yerimebak/api/providers.dart';
import 'package:yerimebak/hizmetler/hizmet_api.dart';
import 'package:yerimebak/hizmetler/odeme_ekrani.dart';
import 'package:yerimebak/hizmetler/randevu.dart';
import 'package:yerimebak/tema/tema.dart';
import 'app_flow_test.dart' show AppFixture;
import 'ekspertiz_036_test.dart' show testBolgesi, teklif;
import 'hizmet_akis_test.dart' show katalog;

final sabitAn = DateTime.utc(2026, 11, 9, 12, 12, 53);
const sentetikArac = {
  'marka': 'Seat',
  'model': 'Ibiza',
  'yil': 2024,
  'km': 30000,
  'ilanFiyati': 960000,
};
AppFixture talepFixture({String? hata, bool tester = true}) => AppFixture(
  statuses: {if (hata != null) '/api/v1/expertiz/requests': 422},
  responses: {
    '/api/v1/app/config': {'expertiz_enabled': false},
    '/api/v1/expertiz/service-area': {...testBolgesi, 'tester': tester},
    '/api/v1/expertiz/packages': katalog,
    '/api/v1/expertiz/quote': teklif,
    '/api/v1/expertiz/requests': hata != null
        ? {
            'detail': {'code': hata, 'message': 'Server message'},
          }
        : {
            'order_id': 'order036',
            'kind': 'expertiz',
            'provider': 'simulation',
          },
    '/api/v1/payments/checkout/order036': {
      'order_id': 'order036',
      'kind': 'expertiz',
      'status': 'paid',
    },
    '/api/v1/expertiz/requests/unpaid': {
      'success': true,
      'request_id': 'sentetik',
    },
  },
);
Future<void> bas(WidgetTester t, String metin) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
  final f = find.widgetWithText(FilledButton, metin);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<ProviderContainer> formAc(WidgetTester t, AppFixture app) async {
  app.store.token = 'valid';
  final c = await app.pump(
    t,
    overrides: [randevuSimdiProvider.overrideWithValue(() => sabitAn)],
  );
  c.read(routerProvider).go('/ekspertiz/talep', extra: sentetikArac);
  await t.pumpAndSettle();
  await bas(t, 'Devam et');
  return c;
}

Future<void> randevuDoldur(WidgetTester t) async {
  for (final pair in {
    'ilce': 'Çankaya',
    'adres': 'Sentetik sokak 12, Ankara',
    'satici_adi': 'Örnek Satıcı',
    'satici_telefon': '+90 555 123 45 67',
  }.entries) {
    await t.enterText(find.byKey(ValueKey('talep-${pair.key}')), pair.value);
  }
  t
          .widget<TextFormField>(find.byKey(const ValueKey('talep-zaman')))
          .controller!
          .text =
      '2026-11-10T12:30';
  await bas(t, 'Devam et');
}

Future<void> onayla(WidgetTester t, int index) async {
  final field = find.byType(CheckboxListTile).at(index);
  await t.ensureVisible(field);
  await t.tap(field);
  await t.pumpAndSettle();
}

void main() {
  test('kurumsal sabit telefonlar sunucu normalizasyonuyla kabul edilir', () {
    for (final phone in [
      '08501234567',
      '+908501234567',
      '8501234567',
      '05551234567',
      '5551234567',
    ]) {
      expect(saticiTelefonHatasi(phone), isNull, reason: phone);
    }
    for (final phone in ['0555123456', '555', '+90', '555123456789']) {
      expect(saticiTelefonHatasi(phone), isNotNull, reason: phone);
    }
  });
  testWidgets(
    'takvim ve saat seçicisi İstanbul dakikasını sözleşme biçiminde yazar',
    (t) async {
      await formAc(t, talepFixture());
      final field = find.byKey(const ValueKey('talep-zaman'));
      await t.ensureVisible(field);
      await t.tap(field);
      await t.pumpAndSettle();
      expect(find.text('Randevu günü · İstanbul saati'), findsOneWidget);
      await t.tap(find.text('Tamam'));
      await t.pumpAndSettle();
      expect(find.text('Randevu saati · İstanbul'), findsOneWidget);
      await t.tap(find.text('Tamam'));
      await t.pumpAndSettle();
      expect(
        t.widget<TextFormField>(field).controller!.text,
        '2026-11-09T17:13',
      );
    },
  );
  testWidgets('ödeme bölge izni geç yüklenince sipariş sorgusunu başlatır', (
    t,
  ) async {
    final app = talepFixture();
    app.store.token = 'valid';
    final izin = Completer<HizmetBolgesi>();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(app.api),
          hizmetBolgesiProvider.overrideWith((ref) => izin.future),
        ],
        child: MaterialApp(
          theme: YbTema.acik,
          home: const HizmetOdemeEkrani('order036'),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(app.calls.where((r) => r.url.path.contains('/checkout/')), isEmpty);
    izin.complete(HizmetBolgesi.fromJson(testBolgesi));
    await t.pumpAndSettle();
    expect(find.text('Ödemeniz alındı'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  test('İstanbul duvar saati, UTC/ofset dönüşü ve randevu sınırları', () {
    expect(randevuDegeri(randevuOku('2027-03-14T02:30')!), '2027-03-14T02:30');
    expect(randevuDegeri(ilkRandevu(sabitAn)), '2026-11-09T17:13');
    expect(randevuHatasi('2026-11-09T17:12', sabitAn), isNotNull);
    expect(randevuHatasi('2026-11-09T17:13', sabitAn), isNull);
    expect(randevuHatasi('2026-12-09T15:12', sabitAn), isNull);
    expect(randevuHatasi('2026-12-09T15:13', sabitAn), isNotNull);
    expect(randevuHatasi('2026-11-31T12:30', sabitAn), isNotNull);
    expect(
      randevuMetni('2026-11-10T09:30:00Z'),
      '10.11.2026 12:30 · İstanbul saati',
    );
    expect(
      randevuMetni('2026-11-10T12:30:00+03:00'),
      '10.11.2026 12:30 · İstanbul saati',
    );
    expect(
      randevuMetni('2026-11-10T12:30'),
      '10.11.2026 12:30 · İstanbul saati',
    );
  });
  test(
    'il izni durum ve tester yerine yalnız sunucu talep_acabilir değeridir',
    () {
      final bolge = HizmetBolgesi.fromJson({
        'tester': false,
        'cities': [
          {'il': 'Ankara', 'durum': 'test', 'talep_acabilir': true},
          {'il': 'İstanbul', 'durum': 'acik', 'talep_acabilir': false},
        ],
      });
      expect(bolge.talepAcabilir, true);
      expect(bolge.iller.first.talepAcabilir, true);
      expect(bolge.iller.last.talepAcabilir, false);
    },
  );
  testWidgets('alanlar zorunludur ve iki onay olmadan ödeme gönderilmez', (
    t,
  ) async {
    final app = talepFixture(tester: false);
    await formAc(t, app);
    await bas(t, 'Devam et');
    expect(find.text('Randevu tarihi ve saatini seçin.'), findsOneWidget);
    expect(find.text('Satıcı telefonu alanını doldurun.'), findsOneWidget);
    await randevuDoldur(t);
    expect(find.text(bulunamamaOnayi), findsOneWidget);
    expect(find.text('Ödemesiz test talebi'), findsNothing);
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Ödemeye geç'),
          )
          .onPressed,
      isNull,
    );
    await onayla(t, 0);
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Ödemeye geç'),
          )
          .onPressed,
      isNull,
    );
    expect(
      app.calls.where(
        (r) => r.method == 'POST' && r.url.path.endsWith('/requests'),
      ),
      isEmpty,
    );
    await onayla(t, 1);
    await bas(t, 'Ödemeye geç');
    final body = jsonDecode(
      app.calls
          .firstWhere(
            (r) => r.method == 'POST' && r.url.path.endsWith('/requests'),
          )
          .body,
    );
    expect(body['city'], 'Ankara');
    expect(body['appointment_at'], '2026-11-10T12:30');
    expect(body['address'], 'Sentetik sokak 12, Ankara');
    expect(body['seller_phone'], '+90 555 123 45 67');
    expect(body['not_found_accepted'], true);
    expect(find.text('Ödemeniz alındı'), findsOneWidget);
  });
  for (final pair in talepHataAlanlari.entries) {
    testWidgets(
      '${pair.key} hata kodu ilgili alanın altında Türkçe gösterilir',
      (t) async {
        final app = talepFixture(hata: pair.key);
        await formAc(t, app);
        await randevuDoldur(t);
        await onayla(t, 0);
        await onayla(t, 1);
        await bas(t, 'Ödemeye geç');
        expect(find.text(talepHataMetinleri[pair.key]!), findsOneWidget);
        expect(find.text('Server message'), findsNothing);
        if (pair.value != 'bulunamama') {
          final field = find.byKey(ValueKey('talep-${pair.value}'));
          expect(
            find.descendant(
              of: field,
              matching: find.text(talepHataMetinleri[pair.key]!),
            ),
            findsOneWidget,
          );
        }
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'tester kullanıcı ödemesiz talep seçeneğini ayrı uç noktaya gönderir',
    (t) async {
      final app = talepFixture();
      await formAc(t, app);
      await randevuDoldur(t);
      await onayla(t, 0);
      await onayla(t, 1);
      final testSecimi = find.byType(SwitchListTile);
      await t.ensureVisible(testSecimi);
      await t.tap(testSecimi);
      await t.pumpAndSettle();
      await bas(t, 'Test talebi oluştur');
      expect(
        app.calls.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/requests/unpaid'),
        ),
        hasLength(1),
      );
      expect(
        app.calls.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/requests'),
        ),
        isEmpty,
      );
    },
  );
}
