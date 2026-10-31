import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yerimebak_sistemleri/core/theme/futuristic_theme.dart';
import 'package:yerimebak_sistemleri/providers/expertiz_provider.dart';
import 'package:yerimebak_sistemleri/models/expertiz/kontrol_listesi.dart';
import 'package:yerimebak_sistemleri/screens/expertiz_akisi/expertiz_baslat_sayfasi.dart';
import '../support/inspection_preview_api.dart';

Future<ExpertizProvider> pumpReport(WidgetTester tester, double width,
    {double textScale = 1}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = ExpertizProvider(apiService: inspectionPreviewApi());
  await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
          theme: FuturisticTheme.theme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!),
          home: const ExpertizBaslatSayfasi(
              gorevId: 'preview',
              personelId: 'fake',
              personelAdi: 'Test Personeli',
              musteriAdi: 'Test Müşterisi',
              aracPlakasi: 'TEST 001'))));
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
  return provider;
}

void main() {
  testWidgets(
      'kontrol secenekleri koyu uygulama temasinda okunabilir bir saha formunda',
      (tester) async {
    final provider = await pumpReport(tester, 1440);
    provider.goToStep(2);
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip).first);
    final context = tester.element(find.byType(ChoiceChip).first);
    final theme = Theme.of(context);
    expect(theme.brightness, Brightness.light);
    final surface = theme.cardTheme.color ?? theme.colorScheme.surface;
    final foreground = Color.alphaBlend(
        chip.labelStyle?.color ?? theme.colorScheme.onSurface, surface);
    final luminances = [
      foreground.computeLuminance(),
      surface.computeLuminance()
    ]..sort();
    expect((luminances.last + .05) / (luminances.first + .05),
        greaterThanOrEqualTo(4.5));
  });

  for (final (width, scale) in [
    (320.0, 1.0),
    (390.0, 1.0),
    (1440.0, 1.0),
    (390.0, 1.3)
  ]) {
    for (var step = 1; step <= 5; step++) {
      testWidgets('adim $step genislik $width yazi $scale yatay tasma yapmaz',
          (tester) async {
        final provider = await pumpReport(tester, width, textScale: scale);
        provider.goToStep(step);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Scroll through the complete page, not just the first visible card.
        final list = find.byType(ListView).hitTestable();
        if (list.evaluate().isNotEmpty) {
          for (var i = 0; i < 14; i++) {
            await tester.drag(list.first, const Offset(0, -650));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }
      });
    }
  }

  testWidgets(
      'sorun secimi not ve fotograf uyarisini korur; modal acik temadadir',
      (tester) async {
    final provider = await pumpReport(tester, 390);
    provider.goToStep(2);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sorunlu').first);
    await tester.pumpAndSettle();
    expect(provider.adim2Model!.durum('onTampon'), KontrolDurumu.sorunlu);
    expect(find.text('Eksikliği açıklayın'), findsOneWidget);
    expect(
        provider.adimEksikleri(2).any((e) => e.contains('fotoğraf')), isTrue);
    await tester.tap(find.text('Eksikleri Gör'));
    await tester.pumpAndSettle();
    final sheet = tester.element(find.byType(BottomSheet));
    expect(Theme.of(sheet).brightness, Brightness.light);
  });
}
