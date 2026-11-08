import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak/kredi/rapor_icerigi.dart';
import 'package:yerimebak/tema/tema.dart';

/// Kredi ekranındaki "1 kredi ile neler alırsınız?" kartı (09.11.2026).
void main() {
  for (final (ad, tema) in [('açık', YbTema.acik), ('koyu', YbTema.koyu)]) {
    testWidgets('kart $ad temada ve %130 yazıda taşmadan görünür', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360 * 3, 1600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: tema,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 1600),
              textScaler: TextScaler.linear(1.3),
            ),
            child: const Scaffold(
              body: SingleChildScrollView(child: RaporIcerigiKarti()),
            ),
          ),
        ),
      );
      expect(find.text('1 kredi ile neler alırsınız?'), findsOneWidget);
      for (final grup in [
        'Fiyat',
        'Pazarlık',
        'Riskler ve kontrol',
        'Teslim',
      ]) {
        expect(find.text(grup), findsOneWidget);
      }
      expect(find.text('Satıcıya hazır mesaj'), findsOneWidget);
      expect(find.text('Enflasyona göre kazanç'), findsOneWidget);
      expect(find.textContaining('krediniz düşülmez'), findsOneWidget);
      // Fiyat Google Play'den gelir; kartta sabit TL tutarı yazılmaz.
      expect(find.textContaining('TL'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
