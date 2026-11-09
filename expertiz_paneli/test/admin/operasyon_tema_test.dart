import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/admin/modules/arac_operasyonu.dart';
import 'package:yerimebak_sistemleri/admin/modules/kontrol_merkezi_module.dart';
import 'package:yerimebak_sistemleri/admin/modules/musteri_yonetimi_module.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';
import 'package:yerimebak_sistemleri/tema/tema.dart';

void main() {
  for (final koyu in [false, true]) {
    for (final genislik in [760.0, 1440.0]) {
      testWidgets('operasyon boş durumları tema=$koyu genişlik=$genislik', (tester) async {
        tester.view.physicalSize = Size(genislik, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = YerimebakExpertizApiService(
          baseUrl: 'http://api.test/api/v1',
          accessToken: 'test-token',
          client: MockClient((_) async => http.Response(jsonEncode({
            'requests': [], 'counts': {}, 'customers': [], 'gorevler': [], 'ayarlar': {},
          }), 200, headers: {'content-type': 'application/json; charset=utf-8'})),
        );
        for (final (ekran, bosMetin) in <(Widget, String)>[
          (KontrolMerkeziModule(apiService: api), 'Açık görev yok.'),
          (AracOperasyonu(apiService: api), 'Atama bekleyen talep yok'),
          (MusteriYonetimiModule(apiService: api), 'Henüz müşteri yok.'),
        ]) {
          await tester.pumpWidget(MaterialApp(theme: koyu ? YbTema.koyu : YbTema.acik, home: Scaffold(body: ekran)));
          await tester.pumpAndSettle();
          expect(find.text(bosMetin), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      });
      testWidgets('operasyon kayıtları tema=$koyu genişlik=$genislik', (tester) async {
        tester.view.physicalSize = Size(genislik, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = YerimebakExpertizApiService(
          baseUrl: 'http://api.test/api/v1', accessToken: 'test-token',
          client: MockClient((_) async => http.Response(jsonEncode({
            'requests': [{
              'id': 'r1', 'bucket': 'waiting_assignment', 'vehicle': {'title': 'Skoda Kamiq', 'plate': '34 ABC 123'},
              'city': 'İstanbul', 'district': 'Kadıköy', 'firm_name': 'Örnek Ekspertiz', 'assignment': {},
              'randevu': {'tarih_saat': '2026-11-10T11:00:00'},
            }],
            'counts': {'waiting_assignment': 1},
            'customers': [{'id': 1, 'full_name': 'Ayşe Yılmaz', 'email': 'ayse@example.com', 'is_active': true, 'credits': 3}],
            'gorevler': [{
              'id': 'g1', 'vehicle': {'title': 'Skoda Kamiq'}, 'city': 'İstanbul', 'district': 'Kadıköy',
              'firm_name': 'Örnek Ekspertiz', 'stage': 'on_the_way', 'stage_label': 'Yolda',
              'customer': {'name': 'Ayşe Yılmaz', 'phone': '05551112233'},
              'assignment': {'personnel_name': 'Saha Personeli', 'personnel_phone': '05552223344'},
              'randevu': {'tarih_saat': '2026-11-10T11:00:00', 'satici_telefon': '05553334455'},
            }],
            'ayarlar': {'telefon': '08501112233'},
          }), 200, headers: {'content-type': 'application/json; charset=utf-8'})),
        );
        for (final (ekran, kayitMetni) in <(Widget, String)>[
          (KontrolMerkeziModule(apiService: api), 'Skoda Kamiq'),
          (AracOperasyonu(apiService: api), 'Skoda Kamiq'),
          (MusteriYonetimiModule(apiService: api), 'Ayşe Yılmaz'),
        ]) {
          await tester.pumpWidget(MaterialApp(theme: koyu ? YbTema.koyu : YbTema.acik, home: Scaffold(body: ekran)));
          await tester.pumpAndSettle();
          expect(find.text(kayitMetni), findsOneWidget);
          expect(find.byType(DataTable), genislik >= 1000 ? findsOneWidget : findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }
}
