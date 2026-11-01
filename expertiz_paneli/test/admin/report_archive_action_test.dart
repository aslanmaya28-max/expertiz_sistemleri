import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak_sistemleri/admin/modules/report_archive_action.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';

final _hash = List.filled(64, 'a').join();

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required MockClient client,
    Map<String, dynamic>? report,
    Future<bool> Function(ReportArchiveDownload, String)? save,
    Future<void> Function(String)? refresh,
  }) =>
      tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ReportArchiveAction(
        report: report ??
            {
              'id': 'r1',
              'status': 'published',
              'media_retention': {'archive_eligible': true}
            },
        api: YerimebakExpertizApiService(client: client, accessToken: 'admin'),
        saveArchive: save ?? (_, __) async => true,
        onArchived: refresh ?? (_) async {},
      ))));

  testWidgets('saklama süresi dolmadan pasif; arşivlenmiş raporda rozet',
      (tester) async {
    final client =
        MockClient((_) async => throw StateError('İstek gönderilmemeli'));
    await mount(tester, client: client, report: {
      'id': 'r1',
      'status': 'published',
      'media_retention': {'remaining_days': 3, 'archive_eligible': false},
    });
    expect(find.text('Arşivlemeye 3 gün kaldı.'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
    await mount(tester, client: client, report: {
      'id': 'r1',
      'status': 'published',
      'archive': {'at': '2026-10-01'}
    });
    expect(find.text('Arşivlendi'), findsOneWidget);
    expect(find.text('Arşivle'), findsNothing);
  });

  testWidgets('ZIP kaydı ve açık onaydan sonra gelen özetle siler ve yeniler',
      (tester) async {
    final events = <String>[];
    await mount(tester, client: MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer admin');
      if (request.method == 'GET') {
        events.add('download');
        expect(request.url.path, endsWith('/reports/r1/archive'));
        return http.Response.bytes([80, 75, 1], 200,
            headers: {'X-Archive-Sha256': _hash});
      }
      events.add('confirm');
      expect(request.url.path, endsWith('/reports/r1/archive/confirm'));
      expect(jsonDecode(request.body), {'sha256': _hash});
      return http.Response('{}', 200);
    }), save: (archive, name) async {
      expect(archive.bytes, [80, 75, 1]);
      expect(name, 'yerimebak_rapor_r1.zip');
      events.add('save');
      return true;
    }, refresh: (id) async {
      expect(id, 'r1');
      events.add('refresh');
    });
    await tester.tap(find.text('Arşivle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(events, ['download', 'save']);
    expect(
        find.text(
            'Dosya bilgisayarınıza kaydedildi mi? Onaylarsanız fotoğraf ve PDF’ler buluttan kalıcı olarak silinir.'),
        findsOneWidget);
    await tester.tap(find.text('İndirdim, buluttan sil'));
    await tester.pumpAndSettle();
    expect(events, ['download', 'save', 'confirm', 'refresh']);
  });

  testWidgets('onayı iptal etmek silme isteği göndermez', (tester) async {
    final calls = <String>[];
    await mount(tester, client: MockClient((request) async {
      calls.add(request.method);
      return http.Response.bytes([80, 75], 200,
          headers: {'x-archive-sha256': _hash});
    }));
    await tester.tap(find.text('Arşivle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(calls, ['GET']);
  });

  testWidgets('kaydetme iptalinde onay ve silme yok', (tester) async {
    await mount(tester,
        client: MockClient((request) async {
          expect(request.method, 'GET');
          return http.Response.bytes([80, 75], 200,
              headers: {'x-archive-sha256': _hash});
        }),
        save: (_, __) async => false);
    await tester.tap(find.text('Arşivle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('eksik özet veya indirme hatasında onay ve silme yok',
      (tester) async {
    for (final response in [
      http.Response.bytes([80, 75], 200),
      http.Response('{"detail":"Erken arşiv"}', 400,
          headers: {'content-type': 'application/json; charset=utf-8'})
    ]) {
      await mount(tester,
          client: MockClient((request) async {
            expect(request.method, 'GET');
            return response;
          }),
          save: (_, __) async => throw StateError('Kaydetme çağrılmamalı'));
      await tester.tap(find.text('Arşivle'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Arşivleme tamamlanamadı:'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('confirm hatası görünür ve rapor yenilenmez', (tester) async {
    var refreshed = false;
    await mount(tester,
        client: MockClient((request) async => request.method == 'GET'
            ? http.Response.bytes([80, 75], 200,
                headers: {'x-archive-sha256': _hash})
            : http.Response('{"detail":"SHA uyuşmuyor"}', 409,
                headers: {'content-type': 'application/json; charset=utf-8'})),
        refresh: (_) async {
      refreshed = true;
    });
    await tester.tap(find.text('Arşivle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('İndirdim, buluttan sil'));
    await tester.pumpAndSettle();
    expect(refreshed, isFalse);
    expect(find.textContaining('SHA uyuşmuyor'), findsOneWidget);
  });

  testWidgets(
      'kısmi silme hatasından sonra aynı özeti yeniden indirmeden onaylar',
      (tester) async {
    final calls = <String>[];
    var confirms = 0;
    await mount(tester, client: MockClient((request) async {
      calls.add(request.method);
      if (request.method == 'GET') {
        return http.Response.bytes([80, 75], 200,
            headers: {'x-archive-sha256': _hash});
      }
      expect(jsonDecode(request.body), {'sha256': _hash});
      confirms++;
      return confirms == 1
          ? http.Response('{"detail":"Aynı onayı tekrar deneyin"}', 502,
              headers: {'content-type': 'application/json; charset=utf-8'})
          : http.Response('{}', 200);
    }));
    await tester.tap(find.text('Arşivle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('İndirdim, buluttan sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arşivlemeyi tamamla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('İndirdim, buluttan sil'));
    await tester.pumpAndSettle();
    expect(calls, ['GET', 'POST', 'POST']);
  });

  testWidgets('yeniden açılan detayda kaydedilmiş onayı indirmeden tamamlar',
      (tester) async {
    await mount(tester,
        report: {
          'id': 'r1',
          'status': 'published',
          'archive_retry_sha256': _hash,
          'media_retention': {'archive_eligible': true},
        },
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {'sha256': _hash});
          return http.Response('{}', 200);
        }),
        save: (_, __) async => throw StateError('Tekrar indirilmemeli'));
    await tester.tap(find.text('Arşivlemeyi tamamla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('İndirdim, buluttan sil'));
    await tester.pumpAndSettle();
  });
}
