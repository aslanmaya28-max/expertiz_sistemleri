import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yerimebak/api/models.dart';
import 'package:yerimebak/bilesenler/rapor_gorunumu.dart';
import 'package:yerimebak/tema/olculer.dart';
import 'package:yerimebak/tema/tema.dart';
import 'package:yerimebak/hizmetler/hizmet_tanitim.dart';

void main() {
  late ReportSnapshot snapshot;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('tr_TR');
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
    // Siteyle aynı gerçek rapor: görsel test için ikinci veri kopyası tutma.
    final fixture = File(
      '../musteri_paneli/frontend/public/ornek-rapor/degerleme.json',
    );
    snapshot = ReportSnapshot.fromJson(
      object(jsonDecode(await fixture.readAsString())),
    );
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'koyu' : 'acik';
    for (final (width, scale) in [(360.0, 1.3), (412.0, 1.0)]) {
      testWidgets('gerçek rapor $theme ${width.toInt()}dp ölçek $scale', (
        tester,
      ) async {
        const viewportHeight = 900.0;
        const captureKey = ValueKey('rapor-golden-viewport');
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.binding.setSurfaceSize(Size(width, viewportHeight));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: dark ? YbTema.koyu : YbTema.acik,
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: RepaintBoundary(
                    key: captureKey,
                    child: Scaffold(
                      body: SingleChildScrollView(
                        controller: controller,
                        padding: const EdgeInsets.all(Olcu.s16),
                        child: ReportView(
                          snapshot,
                          onLink: (_) async {},
                          sonrakiAdim: SonrakiAdim(snapshot.vehicle),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'İlk yerleşim taşmamalı.',
        );

        Future<void> capture(String position) async {
          expect(
            tester.takeException(),
            isNull,
            reason: '$position taşmamalı.',
          );
          await expectLater(
            find.byKey(captureKey),
            matchesGoldenFile(
              'goldens/rapor-034-$theme-${width.toInt()}-$position.png',
            ),
          );
        }

        await capture('upper');

        // Her görünür bölgeyi denetle; yalnız üç ekranın hatasızlığı yetmez.
        var offset = 0.0;
        while (offset < controller.position.maxScrollExtent) {
          offset = (offset + viewportHeight * .75)
              .clamp(0.0, controller.position.maxScrollExtent)
              .toDouble();
          controller.jumpTo(offset);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason:
                '$theme ${width.toInt()}dp raporun $offset konumu taşmamalı.',
          );
        }

        // Başlığı ekranın aşağısına alarak mesaj sonunu ve enflasyon kartını göster.
        final inflation = find.text('Enflasyona göre kazanç tahmini');
        expect(inflation, findsOneWidget);
        await Scrollable.ensureVisible(
          tester.element(inflation),
          alignment: .3,
        );
        await tester.pumpAndSettle();
        await capture('middle');

        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
        await capture('lower');
        for (final (position, label) in [
          ('pricing', 'İlan fiyatı'),
          ('negotiation', 'Pazarlık planı'),
          ('forecast', '1 yıl sonra'),
          ('findings', 'Modelin bilinen sorunları'),
        ]) {
          await Scrollable.ensureVisible(
            tester.element(find.text(label)),
            alignment: .05,
          );
          await tester.pumpAndSettle();
          await capture(position);
        }
      });
    }
  }
}
