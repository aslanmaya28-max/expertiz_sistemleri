import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak_sistemleri/customer/create_request_screen.dart';

/// Eski panel talep formu kaldırıldı; talep siteden açılır (037).
void main() {
  testWidgets('talep ekrani siteye yonlendirir', (tester) async {
    Uri? acilan;
    await tester.pumpWidget(MaterialApp(
      home: CreateRequestScreen(baglantiAc: (uri) async {
        acilan = uri;
        return true;
      }),
    ));
    await tester.tap(find.byKey(const Key('ekspertiz-talebi-siteye-git')));
    await tester.pumpAndSettle();
    expect(acilan.toString(), 'https://www.yerimebak.com.tr/ekspertiz-talebi');
  });
}
