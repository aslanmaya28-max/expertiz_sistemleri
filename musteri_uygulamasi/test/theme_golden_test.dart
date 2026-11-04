import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak/bilesenler/ortak.dart';
import 'package:yerimebak/tema/olculer.dart';
import 'package:yerimebak/tema/tema.dart';
import 'package:yerimebak/tema/yazi.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
  });
  for (final dark in [false, true]) {
    testWidgets('ana bileşenler ${dark ? 'koyu' : 'açık'} tema golden', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final field = TextEditingController();
      addTearDown(field.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? YbTema.koyu : YbTema.acik,
          home: RepaintBoundary(
            key: const ValueKey('golden'),
            child: Scaffold(
              appBar: AppBar(title: const Text('YerimeBak')),
              body: PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Panel('Kredi bakiyesi', [
                      Text('5 kredi', style: Yazilar.rakamBuyuk),
                      Text('Raporlarınız hesabınıza bağlıdır.'),
                    ]),
                    FormFieldView('E-posta', field),
                    const SizedBox(height: Olcu.s12),
                    ActionButton('Araç analizi başlat', () async {}),
                    const SizedBox(height: Olcu.s12),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Raporlarım'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('golden')),
        matchesGoldenFile('goldens/temel-${dark ? 'koyu' : 'acik'}.png'),
      );
    });
  }
}
