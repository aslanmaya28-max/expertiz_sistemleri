import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'report_view_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('bulgular 390 dp yüzde 130 ${dark ? 'koyu' : 'açık'} taşmaz', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await showReport(
        tester,
        fixture()
          ..['ekspertizRaporu'] = {
            'aciklama':
                'Ekspertiz fotoğrafından okunan bulgular yerinde doğrulanmalıdır.',
            'bulgular': [
              {
                'metin':
                    'Şasi bağlantısında işlem şüphesi; yerinde kontrol ettirin.',
                'ciddiyet': 'ciddi',
              },
            ],
          },
        dark: dark,
      );
      await tester.ensureVisible(
        find.text('Ekspertiz raporundan okunan bulgular'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Yerinde doğrulatın:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'ekspertiz bulguları açıklama ve ciddiyet etiketleriyle gösterilir',
    (tester) async {
      final data = fixture()
        ..['ekspertizRaporu'] = {
          'aciklama': 'Fotoğraftan okunan bulgular doğrulanmalıdır.',
          'bulgular': [
            {'metin': 'Şaside işlem şüphesi', 'ciddiyet': 'ciddi'},
            {'metin': 'Tampon çizik', 'ciddiyet': 'pazarlik'},
            {'metin': 'Bakım kaydı mevcut', 'ciddiyet': 'bilgi'},
          ],
        };
      await showReport(tester, data);
      expect(find.text('Ekspertiz raporundan okunan bulgular'), findsOneWidget);
      expect(
        find.text('Fotoğraftan okunan bulgular doğrulanmalıdır.'),
        findsOneWidget,
      );
      expect(
        find.text('Yerinde doğrulatın: Şaside işlem şüphesi'),
        findsOneWidget,
      );
      expect(
        find.text('Kozmetik / küçük onarım: Tampon çizik'),
        findsOneWidget,
      );
      expect(find.text('Bilgi: Bakım kaydı mevcut'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final value in [
    null,
    {},
    [],
    'bozuk',
    {
      'aciklama': {'bozuk': 'veri'},
    },
    {
      'bulgular': [null, 3, {}],
    },
  ]) {
    testWidgets(
      'ekspertiz verisi yok veya anlamsızsa boş bölüm açılmaz: $value',
      (tester) async {
        await showReport(tester, fixture()..['ekspertizRaporu'] = value);
        expect(find.text('Ekspertiz raporundan okunan bulgular'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
