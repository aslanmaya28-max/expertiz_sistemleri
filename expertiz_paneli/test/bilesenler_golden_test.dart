import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak_sistemleri/bilesenler/bilesenler.dart';
import 'package:yerimebak_sistemleri/tema/tema.dart';

const _vitrinAnahtari = Key('ortak-bilesen-vitrini');

/// Aynı gerçek bileşenler iki palette karşılaştırılır; ağ ve saat verisi yoktur.
class _BilesenVitrini extends StatelessWidget {
  const _BilesenVitrini();

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        key: _vitrinAnahtari,
        child: SizedBox(
          width: 1000,
          height: 920,
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Yönetim paneli bileşenleri',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  YbKart(
                    baslik: 'Ekspertiz operasyonu',
                    eylem: YbButon(
                      metin: 'Ayrıntılar',
                      tur: YbButonTuru.metin,
                      onPressed: () {},
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Talepleri, saha ekibini ve raporları yönetin.'),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            YbButon(metin: 'Yeni talep', onPressed: () {}),
                            YbButon(
                                metin: 'Dışa aktar',
                                tur: YbButonTuru.ikincil,
                                onPressed: () {}),
                            YbButon(
                                metin: 'İptal et',
                                tur: YbButonTuru.tehlike,
                                onPressed: () {}),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const YbKart(
                    baslik: 'Talep bilgileri',
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: YbGirdi(
                                etiket: 'Müşteri adı', ipucu: 'Ad ve soyad')),
                        SizedBox(width: 20),
                        Expanded(
                            child: YbGirdi(
                                etiket: 'Araç plakası', ipucu: 'Plaka yazın')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      YbRozet('Tamamlandı', tur: YbRozetTuru.basari),
                      YbRozet('Atama bekliyor', tur: YbRozetTuru.uyari),
                      YbRozet('İptal edildi', tur: YbRozetTuru.tehlike),
                      YbRozet('İnceleniyor', tur: YbRozetTuru.bilgi),
                      YbRozet('Taslak'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  YbKart(
                    padding: EdgeInsets.zero,
                    child: YbTablo(
                      columns: const [
                        DataColumn(label: Text('Plaka')),
                        DataColumn(label: Text('Müşteri')),
                        DataColumn(label: Text('Durum')),
                        DataColumn(label: Text('Kredi'), numeric: true),
                      ],
                      rows: const [
                        DataRow(cells: [
                          DataCell(Text('34 YB 2026')),
                          DataCell(Text('Ayşe Yılmaz')),
                          DataCell(YbRozet('Tamamlandı',
                              tur: YbRozetTuru.basari)),
                          DataCell(Text('1.250')),
                        ]),
                        DataRow(cells: [
                          DataCell(Text('06 YB 2026')),
                          DataCell(Text('Mehmet Kaya')),
                          DataCell(YbRozet('Atama bekliyor',
                              tur: YbRozetTuru.uyari)),
                          DataCell(Text('750')),
                        ]),
                      ],
                      onPageChanged: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

}

Future<void> _vitriniAc(WidgetTester tester,
    {required bool koyu, double metinOlcegi = 1}) async {
  tester.view.physicalSize = const Size(1100, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: koyu ? YbTema.koyu : YbTema.acik,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(metinOlcegi)),
      child: child!,
    ),
    home: const Scaffold(body: Center(child: _BilesenVitrini())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await inter.load();
    final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
      ..addFont(rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'));
    await lucide.load();
  });

  for (final koyu in [false, true]) {
    final ad = koyu ? 'koyu' : 'acik';
    testWidgets('Ortak bileşenlerin $ad teması görsel olarak korunur',
        (tester) async {
      await _vitriniAc(tester, koyu: koyu);
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(_vitrinAnahtari),
          matchesGoldenFile('goldens/038-bilesenler-$ad.png'));
    });

    testWidgets('Ortak bileşenler $ad temada yüzde 130 metinde taşmaz',
        (tester) async {
      await _vitriniAc(tester, koyu: koyu, metinOlcegi: 1.3);
      expect(tester.takeException(), isNull);
      expect(find.text('Müşteri adı'), findsOneWidget);
      expect(find.text('34 YB 2026'), findsOneWidget);
      expect(find.text('750'), findsOneWidget);
    });
  }
}


