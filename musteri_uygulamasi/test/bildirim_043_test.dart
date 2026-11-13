import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:yerimebak/api/models.dart';
import 'package:yerimebak/app.dart';
import 'package:yerimebak/hizmetler/hizmet_api.dart';
import 'app_flow_test.dart';

const bildirimYolu = '/api/v1/expertiz/notifications';
const okunduYolu = '/api/v1/expertiz/notifications/read';
Json bildirimVerisi() => {
  'unread': 2,
  'notifications': [
    {
      'id': 11,
      'kind': 'credits_gifted',
      'title': 'Hesabınıza 5 hediye kredi tanımlandı',
      'body': 'Güle güle kullanın.',
      'read': false,
    },
    {
      'id': 12,
      'kind': 'report_ready',
      'title': 'Raporunuz hazır',
      'body': 'Raporunuzu açabilirsiniz.',
      'read': false,
    },
    {'id': 13, 'title': 'Eski bildirim', 'read': true},
  ],
};

void main() {
  testWidgets('başarılı okundu isteği provider sayacını hatasız yeniler', (
    tester,
  ) async {
    final data = bildirimVerisi();
    final app = AppFixture(responses: {bildirimYolu: data})
      ..store.token = 'valid';
    final container = await app.pump(tester);
    data['unread'] = 0;
    await container.read(hizmetRepositoryProvider).okundu(11);
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('Bildirimler, okunmamış bildirim yok'),
      findsOneWidget,
    );
  });
  testWidgets(
    'okundu POST sürerken geri dönülse de tamamlanınca zil yenilenir',
    (tester) async {
      final pending = Completer<http.Response>();
      final data = bildirimVerisi();
      final app = AppFixture(
        responses: {bildirimYolu: data},
        intercept: (r) => r.url.path == okunduYolu ? pending.future : null,
      )..store.token = 'valid';
      final container = await app.pump(tester);
      await tester.tap(find.byTooltip('Bildirimler, 2 okunmamış'));
      await tester.pumpAndSettle();
      expect(app.calls.where((r) => r.url.path == okunduYolu), hasLength(1));
      container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Bildirimler, 2 okunmamış'), findsOneWidget);
      data['unread'] = 0;
      pending.complete(http.Response('{}', 200));
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Bildirimler, okunmamış bildirim yok'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'üst rota açıkken gelen bildirim görünmeden okunmaz, dönüşte okunur',
    (tester) async {
      final pending = Completer<http.Response>();
      final data = bildirimVerisi();
      final app = AppFixture(
        responses: {bildirimYolu: data},
        intercept: (r) =>
            r.url.path == bildirimYolu &&
                r.url.queryParameters['unread_only'] != 'true'
            ? pending.future
            : null,
      )..store.token = 'valid';
      final container = await app.pump(tester);
      await tester.tap(find.byTooltip('Bildirimler, 2 okunmamış'));
      await tester.pumpAndSettle();
      container.read(routerProvider).push('/ornek-rapor');
      await tester.pumpAndSettle();
      pending.complete(
        http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      await tester.pumpAndSettle();
      expect(app.calls.where((r) => r.url.path == okunduYolu), isEmpty);
      container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(app.calls.where((r) => r.url.path == okunduYolu), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'zil okunmamış sayısını gösterir, hediye krediyi açar ve görünenleri okur',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final data = bildirimVerisi();
      final app = AppFixture(responses: {bildirimYolu: data})
        ..store.token = 'valid';
      final container = await app.pump(tester);
      final zil = find.byTooltip('Bildirimler, 2 okunmamış');
      expect(zil, findsOneWidget);
      expect(
        tester.getSemantics(zil).getSemanticsData().label,
        contains('2 okunmamış'),
      );
      semantics.dispose();
      expect(
        app.calls.any(
          (r) =>
              r.url.path == bildirimYolu &&
              r.url.queryParameters['unread_only'] == 'true',
        ),
        isTrue,
      );
      await tester.tap(zil);
      await tester.pumpAndSettle();
      expect(find.text('Hesabınıza 5 hediye kredi tanımlandı'), findsOneWidget);
      final posts = app.calls.where((r) => r.url.path == okunduYolu).toList();
      expect(posts, hasLength(1));
      expect(jsonDecode(posts.single.body), {
        'ids': [11, 12],
      });
      expect(find.text('Okundu işaretle'), findsNothing);
      data['unread'] = 0;
      container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Bildirimler, okunmamış bildirim yok'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sayaç öne gelince ve aşağı çekince yenilenir, sürekli istek yapmaz',
    (tester) async {
      final data = bildirimVerisi();
      final app = AppFixture(responses: {bildirimYolu: data})
        ..store.token = 'valid';
      await app.pump(tester);
      int count() => app.calls.where((r) => r.url.path == bildirimYolu).length;
      final initial = count();
      await tester.pump(const Duration(minutes: 2));
      expect(count(), initial);
      data['unread'] = 4;
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(find.byTooltip('Bildirimler, 4 okunmamış'), findsOneWidget);
      data['unread'] = 6;
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Bildirimler, 6 okunmamış'), findsOneWidget);
    },
  );

  testWidgets('bildirim hatası ana sayfayı kapatmaz ve zil sayıyı uydurmaz', (
    tester,
  ) async {
    final app = AppFixture(statuses: {bildirimYolu: 500})
      ..store.token = 'valid';
    await app.pump(tester);
    expect(find.text('Yeni araç analizi'), findsOneWidget);
    expect(find.byTooltip('Bildirimler, sayı alınamadı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'okundu hatasında bildirimler görünür ve elle yeniden denenebilir',
    (tester) async {
      final statuses = {okunduYolu: 500};
      final app = AppFixture(
        responses: {bildirimYolu: bildirimVerisi()},
        statuses: statuses,
      )..store.token = 'valid';
      final container = await app.pump(tester);
      container.read(routerProvider).push('/bildirimler');
      await tester.pumpAndSettle();
      expect(find.text('Hesabınıza 5 hediye kredi tanımlandı'), findsOneWidget);
      expect(find.text('Okundu işaretle'), findsNWidgets(2));
      statuses.remove(okunduYolu);
      await tester.tap(find.text('Okundu işaretle').first);
      await tester.pumpAndSettle();
      expect(find.text('Okundu işaretle'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
