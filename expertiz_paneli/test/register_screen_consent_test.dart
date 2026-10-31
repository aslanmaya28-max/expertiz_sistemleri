import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak_sistemleri/screens/register_screen.dart';

void main() {
  testWidgets('kayıt açık onay olmadan gönderilmez', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await tester.enterText(find.byType(TextFormField).at(0), 'Ayşe Yılmaz');
    await tester.enterText(find.byType(TextFormField).at(1), 'ayse@example.test');
    await tester.enterText(find.byType(TextFormField).at(3), 'Password123');
    await tester.ensureVisible(find.byType(ElevatedButton));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(find.text('Kullanım koşullarını kabul etmelisiniz.'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isFalse);
  });
}
