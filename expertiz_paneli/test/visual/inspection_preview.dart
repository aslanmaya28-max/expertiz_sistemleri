// Visual-only fixture. All report reads/writes are intercepted by MockClient.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yerimebak_sistemleri/core/theme/futuristic_theme.dart';
import 'package:yerimebak_sistemleri/providers/expertiz_provider.dart';
import 'package:yerimebak_sistemleri/screens/expertiz_akisi/expertiz_baslat_sayfasi.dart';
import '../support/inspection_preview_api.dart';

void main() => runApp(ChangeNotifierProvider(
      create: (_) => ExpertizProvider(apiService: inspectionPreviewApi()),
      child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: FuturisticTheme.theme,
          home: const ExpertizBaslatSayfasi(
              gorevId: 'preview',
              personelId: 'fake',
              personelAdi: 'Test Personeli',
              musteriAdi: 'Test Müşterisi',
              aracPlakasi: 'TEST 001')),
    ));
