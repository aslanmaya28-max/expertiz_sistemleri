import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yerimebak/app.dart';
import 'app_flow_test.dart' show AppFixture;
import 'randevu_036_test.dart' show talepFixture, formAc, randevuDoldur;

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
  for (final page in ['form', 'onay', 'talep-detay', 'yakinda']) {
    testWidgets('036 $page 390 px gerçek arayüz', (t) async {
      SharedPreferences.setMockInitialValues({});
      await t.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => t.binding.setSurfaceSize(null));
      if (page == 'form' || page == 'onay') {
        final app = talepFixture();
        await formAc(t, app);
        if (page == 'form') {
          await t.ensureVisible(find.text('Randevu ve iletişim'));
        } else {
          await randevuDoldur(t);
          await t.ensureVisible(find.text('Talebinizi kontrol edin'));
        }
      } else {
        final app = AppFixture(
          responses: {
            '/api/v1/app/config': {'expertiz_enabled': false},
            '/api/v1/expertiz/requests': {
              'requests': [
                {
                  'id': 'sentetik036',
                  'durum_kodu': 'vehicle_not_found',
                  'status': 'cancelled',
                  'payment_status': 'partially_refunded',
                  'vehicle': {'brand': 'Seat', 'model': 'Ibiza', 'year': 2024},
                  'firm_name': 'Örnek Kurumsal Ekspertiz',
                  'package_name': 'Kontrol paketi',
                  'randevu': {
                    'tarih_saat': '2026-11-10T12:30',
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
        final c = await app.pump(t);
        c
            .read(routerProvider)
            .go(page == 'yakinda' ? '/ekspertiz/talep' : '/talepler');
      }
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/ekspertiz-036-$page-390.png'),
      );
      t.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.binding.setSurfaceSize(const Size(360, 800));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
