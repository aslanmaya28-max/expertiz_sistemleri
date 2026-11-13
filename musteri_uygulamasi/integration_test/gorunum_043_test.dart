import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yerimebak/app.dart';
import 'package:yerimebak/tema/gorunum.dart';
import '../test/app_flow_test.dart' show AppFixture;
import '../test/bildirim_043_test.dart' show bildirimYolu, bildirimVerisi;
import '../test/report_view_test.dart' show fixture;

/// Sentetik verilerle çalışır; sunucu, müşteri hesabı veya ödeme kullanmaz.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('043 rehber, zil ve ekspertiz bulguları 390 dp', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final data = fixture()
      ..['ekspertizRaporu'] = {
        'aciklama':
            'Ekspertiz fotoğrafından okunan bulguları yerinde doğrulatın.',
        'bulgular': [
          {'metin': 'Şasi bağlantısında işlem şüphesi', 'ciddiyet': 'ciddi'},
          {'metin': 'Ön tamponda çizik', 'ciddiyet': 'pazarlik'},
          {'metin': 'Bakım kaydı mevcut', 'ciddiyet': 'bilgi'},
        ],
      };
    final app = AppFixture(
      report: data,
      responses: {bildirimYolu: bildirimVerisi()},
    )..store.token = 'valid';
    final container = await app.pump(tester, rehberiGoster: true);
    expect(tester.view.physicalSize.width / tester.view.devicePixelRatio, 390);
    await binding.convertFlutterSurfaceToImage();
    for (var i = 1; i <= 4; i++) {
      await tester.pumpAndSettle();
      await binding.takeScreenshot('043-rehber-$i');
      if (i < 4) await tester.tap(find.text('İleri'));
    }
    await tester.tap(find.text('Başlayalım'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('043-bildirim-zili');
    await tester.tap(find.byTooltip('Bildirimler, 2 okunmamış'));
    await tester.pumpAndSettle();
    expect(find.text('Hesabınıza 5 hediye kredi tanımlandı'), findsOneWidget);
    await binding.takeScreenshot('043-hediye-kredi-bildirimi');
    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/raporlar/report20');
    await tester.pumpAndSettle();
    Future<void> bulgulariGoster() async {
      final baslik = find.text('Ekspertiz raporundan okunan bulgular');
      await Scrollable.ensureVisible(tester.element(baslik), alignment: .1);
      await tester.pumpAndSettle();
      // Android yüzeyindeki yeni kaydırma karesi de çizilmiş olmalı.
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(baslik).top, greaterThan(0));
      expect(
        tester.getRect(baslik).bottom,
        lessThan(
          tester.view.physicalSize.height / tester.view.devicePixelRatio,
        ),
      );
      expect(
        find
            .text('Yerinde doğrulatın: Şasi bağlantısında işlem şüphesi')
            .hitTestable(),
        findsOneWidget,
      );
    }

    await bulgulariGoster();
    await binding.takeScreenshot('043-ekspertiz-bulgulari');
    await container.read(themeModeProvider.notifier).sec(ThemeMode.dark);
    await tester.pumpAndSettle();
    await bulgulariGoster();
    await binding.takeScreenshot('043-ekspertiz-bulgulari-koyu');
    expect(tester.takeException(), isNull);
  });
}
