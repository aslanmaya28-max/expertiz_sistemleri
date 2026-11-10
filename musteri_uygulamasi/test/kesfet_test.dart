import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yerimebak/hizmetler/hizmet_api.dart';
import 'package:yerimebak/bilesenler/yukleniyor.dart';
import 'package:yerimebak/hizmetler/kesfet.dart';
import 'package:yerimebak/tema/tema.dart';

/// Keşfet: Yerinde inceleme, Araç değerleme, Örnek rapor, Fiyatlar (11.11.2026).
Future<void> _ac(
  WidgetTester tester,
  Widget ekran, {
  required double en,
  required ThemeData tema,
}) async {
  tester.view.physicalSize = Size(en * 3, 2400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hizmetKatalogProvider.overrideWith(
          (ref) async => {
            'service_fee_tl': 5000,
            'service_fee_incl_vat_tl': 6000,
            'vat_rate': 0.2,
            'firms': [],
          },
        ),
      ],
      child: MaterialApp(
        theme: tema,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(en, 2400),
            textScaler: const TextScaler.linear(1.3),
          ),
          child: ekran,
        ),
      ),
    ),
  );
  // Örnek rapor varlıktan yüklenir; sabit pump döngüsü (sonsuz animasyon olabilir).
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(Yukleniyor).evaluate().isEmpty && i > 2) {
      break;
    }
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  test('uygulamadaki örnek rapor sitedekiyle birebir aynı', () {
    final uygulama = File(
      'assets/ornek-rapor/degerleme.json',
    ).readAsStringSync();
    final site = File(
      '../musteri_paneli/frontend/public/ornek-rapor/degerleme.json',
    ).readAsStringSync();
    expect(jsonDecode(uygulama), jsonDecode(site));
  });

  for (final (ad, tema) in [('açık', YbTema.acik), ('koyu', YbTema.koyu)]) {
    for (final en in [360.0, 1080.0]) {
      testWidgets('Keşfet kartları $ad temada ${en.toInt()} px taşmaz', (
        tester,
      ) async {
        await _ac(
          tester,
          const Scaffold(body: SingleChildScrollView(child: KesfetKartlari())),
          en: en,
          tema: tema,
        );
        for (final b in [
          'Yerinde inceleme',
          'Araç değerleme',
          'Örnek rapor',
          'Fiyatlar',
        ]) {
          expect(find.text(b), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('Araç değerleme sayfası $ad temada ${en.toInt()} px taşmaz', (
        tester,
      ) async {
        await _ac(tester, const AracDegerlemeEkrani(), en: en, tema: tema);
        expect(find.text('Kimler için?'), findsOneWidget);
        expect(find.text('Nasıl işler?'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'Fiyatlar sayfası $ad temada ${en.toInt()} px: kredi fiyatı yazmaz, Kredi ekranına yönlendirir',
        (tester) async {
          await _ac(tester, const FiyatlarEkrani(), en: en, tema: tema);
          expect(find.text('1 rapor = 1 kredi'), findsOneWidget);
          expect(find.text('Kredi paketlerini gör'), findsOneWidget);
          // Google Play kuralı: dijital kredi için sitedeki TL fiyatları ya da web ödemesi gösterilmez.
          expect(find.textContaining('100 TL'), findsNothing);
          expect(find.textContaining('yerimebak.com.tr'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('Örnek rapor $ad temada ${en.toInt()} px açılır', (
        tester,
      ) async {
        await _ac(tester, const OrnekRaporEkrani(), en: en, tema: tema);
        expect(find.textContaining('ÖRNEK RAPOR'), findsOneWidget);
        expect(find.text('Kendi aracım için değerleme al'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
