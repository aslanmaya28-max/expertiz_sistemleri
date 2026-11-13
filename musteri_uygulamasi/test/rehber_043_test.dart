import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yerimebak/analiz/analiz_durumu.dart';
import 'package:yerimebak/analiz/analiz_ekranlari.dart';
import 'package:yerimebak/analiz/arac_formu.dart';
import 'package:yerimebak/app.dart';
import 'package:yerimebak/rehber/ilk_kullanim_rehberi.dart';
import 'app_flow_test.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final okumaHatasi in [true, false]) {
    testWidgets(
      'depolama ${okumaHatasi ? 'okuma' : 'yazma'} hatasında uygulama ve tekrar açma çalışır',
      (tester) async {
        var yukleme = 0;
        final depo = RehberDeposu(
          yukle: () async {
            yukleme++;
            if (okumaHatasi || yukleme > 1) throw StateError('Depolama kapalı');
            return SharedPreferences.getInstance();
          },
        );
        final app = AppFixture()..store.token = 'valid';
        final container = await app.pump(
          tester,
          rehberiGoster: true,
          overrides: [rehberDeposuProvider.overrideWithValue(depo)],
        );
        expect(find.text('İlanı ekleyin'), findsOneWidget);
        await tester.tap(find.text('Atla'));
        await tester.pumpAndSettle();
        container.read(routerProvider).go('/profil');
        await tester.pumpAndSettle();
        container.read(routerProvider).go('/');
        await tester.pumpAndSettle();
        expect(find.text('İlanı ekleyin'), findsNothing);
        await tester.tap(find.text('Nasıl kullanılır?'));
        await tester.pumpAndSettle();
        expect(find.text('İlanı ekleyin'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('ilk açılış turu atlanır ve sonraki açılışta görünmez', (
    tester,
  ) async {
    final app = AppFixture()..store.token = 'valid';
    await app.pump(tester, rehberiGoster: true);
    expect(find.text('İlanı ekleyin'), findsOneWidget);
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(find.text('İlanı ekleyin'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await (AppFixture()..store.token = 'valid').pump(
      tester,
      rehberiGoster: true,
    );
    expect(find.text('İlanı ekleyin'), findsNothing);
    await tester.tap(find.text('Nasıl kullanılır?'));
    await tester.pumpAndSettle();
    expect(find.text('İlanı ekleyin'), findsOneWidget);
  });

  testWidgets('tur 390 dp yüzde 130 ve sıfır kredide satışa yönlendirmez', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final app = AppFixture(
      responses: {
        '/api/v1/credits/balance': {'credits': 0},
      },
    )..store.token = 'valid';
    await app.pump(tester, rehberiGoster: true);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Paylaş → YerimeBak'),
      ),
      findsOneWidget,
    );
    expect(
      ModalRoute.of(
        tester.element(find.byType(AlertDialog)),
      )!.transitionDuration,
      Duration.zero,
    );
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.textContaining('Bakiyeniz şu an 0'), findsOneWidget);
    expect(find.textContaining('1 kredi'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Kredi yükle'), findsNothing);
    await tester.tap(find.text('Başlayalım'));
    await tester.pumpAndSettle();
    expect(find.text('İlanı ekleyin'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form bilgi düğmesi açıklamayı açar ve girilen alanı korur', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final semantics = tester.ensureSemantics();
    final app = AppFixture()..store.token = 'valid';
    final container = await app.pump(tester);
    container.read(analizTaslagiProvider.notifier).state = AnalizTaslagi(
      AracFormu(marka: 'Seat', model: 'Ibiza', paket: 'Style'),
    );
    container.read(routerProvider).go('/analiz/form');
    await tester.pumpAndSettle();
    final info = find.byTooltip('Paket / motor hakkında bilgi');
    await tester.ensureVisible(info);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(info).getSemanticsData().label,
      contains('Paket / motor hakkında bilgi'),
    );
    semantics.dispose();
    await tester.tap(info);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('İlandaki donanım ya da motor adı'),
      findsOneWidget,
    );
    await tester.tap(find.text('Anladım'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Style'), findsOneWidget);
    expect(find.byType(AracFormuEkrani), findsOneWidget);
    for (final alan in {
      'Model yılı': 'Ruhsattaki model yılı',
      'Kilometre': 'kilometre farkına göre düzeltir',
      'Motor gücü (hp)': 'farklı motorlu ilanlarını',
      'İlan fiyatı': 'Satıcının istediği fiyat',
      'Tramer (hasar kaydı) toplamı':
          'Sigorta hasar kayıtlarının toplam tutarı',
    }.entries) {
      final dugme = find.byTooltip('${alan.key} hakkında bilgi');
      await tester.ensureVisible(dugme);
      await tester.tap(dugme);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining(alan.value),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Anladım'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
