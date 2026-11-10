import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak/analiz/analiz_durumu.dart';
import 'package:yerimebak/analiz/analiz_ekranlari.dart';
import 'package:yerimebak/analiz/arac_formu.dart';
import 'package:yerimebak/api/providers.dart';
import 'package:yerimebak/tema/tema.dart';

/// "Analizi başlat": eksik alan varsa sayfa o alana kayar, hata alanın altında yazar (11.11.2026).
void main() {
  testWidgets('fiyat boşsa analiz başlamaz, fiyat alanına götürür', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final taslak = AnalizTaslagi(
      AracFormu(marka: 'Seat', model: 'Ibiza', yil: '2021', km: '45000'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analizTaslagiProvider.overrideWith((ref) => taslak),
          parcalarProvider.overrideWith((ref) async => []),
          balanceProvider.overrideWith((ref) async => 5),
        ],
        child: MaterialApp(theme: YbTema.acik, home: const AracFormuEkrani()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final fiyat = find.widgetWithText(
      TextField,
      'İlan fiyatı',
      skipOffstage: false,
    );
    // Başlangıçta fiyat alanı alttaki düğme şeridinin altında, görünmüyor.
    final serit = tester.getRect(find.text('Analizi başlat')).top;
    expect(tester.getRect(fiyat).top, greaterThan(serit));

    await tester.tap(find.text('Analizi başlat'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.text('İlan fiyatı 10.000 TL ile 200.000.000 TL arasında olmalı.'),
      findsOneWidget,
    );
    final kutu = tester.getRect(fiyat);
    expect(kutu.top, greaterThanOrEqualTo(0));
    expect(kutu.bottom, lessThan(serit));
    final alan = tester.widget<TextField>(fiyat);
    expect(alan.focusNode?.hasFocus, isTrue);
    expect(tester.takeException(), isNull);

    // Müşteri yazınca hata kalkar.
    await tester.enterText(fiyat, '960000');
    await tester.pump();
    expect(
      find.text('İlan fiyatı 10.000 TL ile 200.000.000 TL arasında olmalı.'),
      findsNothing,
    );
  });
}
