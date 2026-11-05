import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yerimebak/api/api_client.dart';
import 'package:yerimebak/bilesenler/ana_buton.dart';
import 'package:yerimebak/bilesenler/karar_rozeti.dart';
import 'package:yerimebak/bilesenler/fiyat_araligi.dart';
import 'package:yerimebak/bilesenler/kaporta_semasi.dart';
import 'package:yerimebak/bilesenler/hata.dart';
import 'package:yerimebak/bilesenler/kart.dart';
import 'package:yerimebak/tema/tema.dart';
import 'package:yerimebak/tema/gorunum.dart';

Future<void> host(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: YbTema.acik,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('kararlar yazılı rozetlere eşlenir', (tester) async {
    await host(
      tester,
      const Column(
        children: [
          KararRozeti('AL'),
          KararRozeti('PAZARLIK YAP'),
          KararRozeti('ALMA'),
          KararRozeti('EK DOĞRULAMA GEREKLİ'),
        ],
      ),
    );
    for (final label in [
      'Alınabilir',
      'Pazarlık yapın',
      'Önerilmez',
      'Ek doğrulama gerekli',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });
  testWidgets('ana buton beklerken çift basış engellenir', (tester) async {
    final done = Completer<void>();
    var calls = 0;
    await host(
      tester,
      AnaButon('Gönder', () async {
        calls++;
        await done.future;
      }),
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    expect(calls, 1);
    done.complete();
    await tester.pumpAndSettle();
  });
  testWidgets('aralık dışındaki ilan çubukta tutulur ve metinle açıklanır', (
    tester,
  ) async {
    await host(
      tester,
      const SizedBox(
        width: 320,
        child: FiyatAraligi(
          alt: 900000,
          ust: 1000000,
          hesaplanan: 950000,
          ilan: 1700000,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('aralığın üstünde'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Adil fiyat aralığı 900.000 TL ile 1.000.000 TL arası; ilan fiyatı 1.700.000 TL',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('ters ve eksik aralık için fiyat uydurulmaz', (tester) async {
    await host(
      tester,
      const FiyatAraligi(
        alt: 1000000,
        ust: 900000,
        hesaplanan: null,
        ilan: 950000,
      ),
    );
    expect(find.text('Fiyat aralığı için yeterli veri yok.'), findsOneWidget);
  });
  testWidgets('13 kaporta parçası kontrollü döngü ve uzun basma ile seçilir', (
    tester,
  ) async {
    Map<String, String> values = {};
    await host(
      tester,
      StatefulBuilder(
        builder: (context, setState) => SizedBox(
          width: 360,
          child: KaportaSemasi(
            degerler: values,
            onChanged: (next) {
              setState(() => values = next);
            },
          ),
        ),
      ),
    );
    expect(KaportaSemasi.parcalar, hasLength(13));
    final part = find.byKey(const ValueKey('kaporta-solOnKapi'));
    for (final status in ['lokal_boyali', 'boyali', 'degisen', 'orijinal']) {
      await tester.tap(part);
      await tester.pump();
      expect(values['solOnKapi'], status);
    }
    await tester.longPress(part);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Değişen').last);
    await tester.pumpAndSettle();
    expect(values['solOnKapi'], 'degisen');
    expect(find.textContaining('Değişen: Sol Ön Kapı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('hata nedeni başlıktan ayrıdır', (tester) async {
    await host(
      tester,
      Hata(const ApiFailure('Sunucu yanıtı gecikti. Tekrar deneyin.'), () {}),
    );
    expect(find.text('Yanıt gecikti'), findsOneWidget);
    expect(find.text('İşlem tamamlanamadı'), findsNothing);
    await host(tester, Hata(const ApiFailure('Geçersiz', status: 401), () {}));
    expect(find.text('Oturumunuz sona erdi'), findsOneWidget);
  });
  testWidgets('hata kartı sınırlı ekranda gereksiz yere tam boya uzamaz', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: YbTema.acik,
        home: Scaffold(body: Hata(const ApiFailure('Bağlantı yok'), () {})),
      ),
    );
    expect(tester.getSize(find.byType(Kart)).height, lessThan(400));
  });
  test('görünüm seçimi yeniden açılışta korunur', () async {
    SharedPreferences.setMockInitialValues({});
    final first = GorunumDenetleyicisi();
    await first.hazir;
    await first.sec(ThemeMode.dark);
    first.dispose();
    final second = GorunumDenetleyicisi();
    await second.hazir;
    expect(second.state, ThemeMode.dark);
    second.dispose();
  });
}
