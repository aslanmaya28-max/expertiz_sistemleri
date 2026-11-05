import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yerimebak/app.dart';
import 'package:yerimebak/tema/gorunum.dart';
import 'app_flow_test.dart' show AppFixture;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final dark in [false, true]) {
    for (final page in ['yerinde', 'surec', 'talep']) {
      testWidgets('$page ${dark ? 'koyu' : 'acik'} ve yüzde130 taşma', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({
          GorunumDenetleyicisi.anahtar: dark ? 'dark' : 'light',
        });
        await tester.binding.setSurfaceSize(const Size(420, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final app = AppFixture(
          responses: {
            '/api/v1/app/config': {'expertiz_enabled': page == 'talep'},
            '/api/v1/expertiz/packages': {
              'service_fee_tl': 5000,
              'service_fee_incl_vat_tl': 6000,
              'firms': [
                {
                  'id': 'firma',
                  'name': 'Örnek Kurumsal Ekspertiz İstanbul Anadolu Şubesi',
                  'packages': [
                    {
                      'id': 'paket',
                      'name':
                          'Motor, Mekanik, Kaporta ve Elektronik Kontrol Paketi',
                      'price': 3250.5,
                      'features': [
                        'Motor ve mekanik',
                        'Boya / kaporta',
                        'Elektronik sistemler',
                      ],
                    },
                  ],
                },
              ],
            },
            '/api/v1/expertiz/quote': {
              'totals': {
                'service_fee_tl': 5000,
                'service_fee_incl_vat_tl': 6000,
                'package_price_tl': 3250.5,
                'vat_tl': 1000,
                'total_tl': 9250.5,
              },
            },
          },
        );
        app.store.token = 'valid';
        final c = await app.pump(tester);
        c
            .read(routerProvider)
            .go(
              {
                'yerinde': '/yerinde-inceleme',
                'surec': '/uzaktan-satin-alma',
                'talep': '/ekspertiz/talep',
              }[page]!,
            );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/hizmet-$page-${dark ? 'koyu' : 'acik'}.png',
          ),
        );
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.binding.setSurfaceSize(const Size(360, 800));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -1800),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
