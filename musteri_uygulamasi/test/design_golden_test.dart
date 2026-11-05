import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yerimebak/api/api_client.dart';
import 'package:yerimebak/app.dart';
import 'package:yerimebak/bilesenler/ana_buton.dart';
import 'package:yerimebak/bilesenler/ikincil_buton.dart';
import 'package:yerimebak/bilesenler/metin_kutusu.dart';
import 'package:yerimebak/bilesenler/kart.dart';
import 'package:yerimebak/bilesenler/liste_satiri.dart';
import 'package:yerimebak/bilesenler/karar_rozeti.dart';
import 'package:yerimebak/bilesenler/yakinda_rozeti.dart';
import 'package:yerimebak/bilesenler/fiyat_araligi.dart';
import 'package:yerimebak/bilesenler/pazarlik_uclusu.dart';
import 'package:yerimebak/bilesenler/alt_eylem_cubugu.dart';
import 'package:yerimebak/bilesenler/alt_menu.dart';
import 'package:yerimebak/bilesenler/bos_durum.dart';
import 'package:yerimebak/bilesenler/hata.dart';
import 'package:yerimebak/bilesenler/yukleniyor.dart';
import 'package:yerimebak/bilesenler/kaporta_semasi.dart';
import 'package:yerimebak/bilesenler/marka.dart';
import 'package:yerimebak/tema/tema.dart';
import 'package:yerimebak/tema/olculer.dart';
import 'package:yerimebak/tema/gorunum.dart';
import 'app_flow_test.dart' show AppFixture;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
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
  });
  for (final dark in [false, true]) {
    final mode = dark ? 'koyu' : 'acik';
    testWidgets('ortak bileşenler $mode golden ve yüzde 130', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 3100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final field = TextEditingController();
      addTearDown(field.dispose);
      final children = <Widget>[
        const Marka(),
        AnaButon('Analizi başlat', () async {}),
        IkincilButon('Mesajı kopyala', () async {}),
        MetinKutusu('E-posta', field),
        const Kart(child: Text('Araç bilgileri')),
        ListeSatiri(
          'Kredi geçmişi',
          aciklama: 'Yükleme ve kullanım hareketleri',
          onTap: () {},
        ),
        const Wrap(
          spacing: Olcu.s8,
          runSpacing: Olcu.s8,
          children: [
            KararRozeti('AL'),
            KararRozeti('PAZARLIK YAP'),
            KararRozeti('ALMA'),
            KararRozeti('EK DOĞRULAMA GEREKLİ'),
          ],
        ),
        const Wrap(
          spacing: Olcu.s8,
          children: [YakindaRozeti(), YakindaRozeti(simdi: true)],
        ),
        const FiyatAraligi(
          alt: 900000,
          ust: 1000000,
          hesaplanan: 945000,
          ilan: 1050000,
        ),
        const PazarlikUclusu(acilis: 900000, hedef: 945000, ustSinir: 970000),
        AltEylemCubugu(mesaj: () async {}, pdf: () async {}),
        AltMenu(secili: 1, onChanged: (_) {}),
        const BosDurum('Henüz raporunuz yok', 'İlk analizinizi başlatın.'),
        Hata(const ApiFailure('Sunucu yanıtı gecikti.'), () {}),
        const Yukleniyor(),
        KaportaSemasi(
          degerler: const {
            'solOnKapi': 'degisen',
            'kaput': 'lokal_boyali',
            'bagajKapagi': 'boyali',
          },
          onChanged: (_) {},
        ),
      ];
      Future<void> pump(double scale) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? YbTema.koyu : YbTema.acik,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(Olcu.s16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final child in children)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Olcu.s16),
                            child: child,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(1);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/bilesenler-$mode.png'),
      );
      await tester.binding.setSurfaceSize(const Size(360, 4000));
      await pump(1.3);
      expect(tester.takeException(), isNull);
    });
    for (final page in ['giris', 'ana', 'rapor', 'profil']) {
      testWidgets('$page $mode ekran golden ve yüzde 130', (tester) async {
        SharedPreferences.setMockInitialValues({
          GorunumDenetleyicisi.anahtar: dark ? 'dark' : 'light',
        });
        await tester.binding.setSurfaceSize(const Size(420, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final app = AppFixture();
        if (page != 'giris') app.store.token = 'valid';
        final container = await app.pump(tester);
        if (page == 'rapor') {
          container.read(routerProvider).go('/raporlar/report20');
        }
        if (page == 'profil') container.read(routerProvider).go('/profil');
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$page-$mode.png'),
        );
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.binding.setSurfaceSize(const Size(360, 800));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final scroll = find.byType(Scrollable).first;
        await tester.drag(scroll, const Offset(0, -1200));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
