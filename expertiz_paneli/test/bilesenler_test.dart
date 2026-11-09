import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak_sistemleri/bilesenler/bilesenler.dart';
import 'package:yerimebak_sistemleri/tema/tema.dart';
import 'package:yerimebak_sistemleri/screens/login_screen.dart';

void main() {
  testWidgets('Yüklenen ana eylem yeniden gönderilemez', (tester) async {
    var clicks = 0;
    await tester.pumpWidget(MaterialApp(
        theme: YbTema.koyu,
        home: Scaffold(
            body: YbButon(
                metin: 'Kaydet',
                yukleniyor: true,
                onPressed: () => clicks++))));
    await tester.tap(find.byType(FilledButton));
    expect(clicks, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.style!.textStyle!.resolve({})!.fontFamily, 'Inter');
  });
  testWidgets('Tablo boşken açıklama sunar ve sonraki sayfa devre dışıdır',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: YbTema.acik,
        home: Scaffold(
            body: YbTablo(
                columns: const [DataColumn(label: Text('Ad'))],
                rows: const [],
                onPageChanged: (_) {}))));
    expect(find.text('Kayıt bulunamadı'), findsOneWidget);
    expect(tester.widget<IconButton>(find.ancestor(of: find.byTooltip('Sonraki sayfa'), matching: find.byType(IconButton))).onPressed,
        isNull);
  });
  testWidgets('Tablo sonraki sayfada doğru kayıtları gösterir', (tester) async {
    var page = 0;
    await tester.pumpWidget(MaterialApp(
        theme: YbTema.acik,
        home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
                body: YbTablo(
                    columns: const [DataColumn(label: Text('Ad'))],
                    rows: List.generate(
                        3, (i) => DataRow(cells: [DataCell(Text('Kişi $i'))])),
                    sayfa: page,
                    sayfaBoyutu: 2,
                    onPageChanged: (value) => setState(() => page = value))))));
    expect(find.text('Kişi 0'), findsOneWidget);
    expect(find.text('Kişi 2'), findsNothing);
    await tester.tap(find.byTooltip('Sonraki sayfa'));
    await tester.pump();
    expect(find.text('Kişi 0'), findsNothing);
    expect(find.text('Kişi 2'), findsOneWidget);
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets('Giriş $width genişlikte form doğrulamasını korur',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
          MaterialApp(theme: YbTema.koyu, home: const LoginScreen()));
      await tester.ensureVisible(find.text('Giriş yap'));
      await tester.tap(find.text('Giriş yap'));
      await tester.pump();
      expect(find.text('E-posta veya kullanıcı adı gerekli'), findsOneWidget);
      expect(find.text('Şifre gerekli'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
