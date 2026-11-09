import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak_sistemleri/core/widgets/sidebar.dart';
import 'package:yerimebak_sistemleri/tema/tema.dart';

void main() {
  for (final width in [390.0, 760.0, 1100.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('kabuk $width tema=$dark taşmaz, gezinir', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = -1;
        await tester.pumpWidget(MaterialApp(theme: dark ? YbTema.koyu : YbTema.acik,
          home: MediaQuery(data: MediaQueryData(size: Size(width,1000),textScaler: TextScaler.linear(1.3)),
            child: PanelYerlesim(secili: 0, onSelect: (value) => selected = value,
              sayilar: const {2: 3}, child: const Text('İçerik')))));
        expect(tester.takeException(), isNull);
        if (width < 760) {
          await tester.tap(find.byTooltip('Menüyü aç'));
          await tester.pumpAndSettle();
        }
        final sidebar = tester.widget<PanelSidebar>(find.byType(PanelSidebar).last);
        expect(sidebar.dar, width >= 760 && width < 1100);
        if (sidebar.dar) {
          await tester.tap(find.byTooltip('Talepler'));
        } else {
          await tester.tap(find.text('Talepler'));
        }
        await tester.pumpAndSettle();
        expect(selected, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
