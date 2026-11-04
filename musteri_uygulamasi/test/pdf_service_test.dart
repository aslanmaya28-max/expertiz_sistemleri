import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak/api/api_client.dart';
import 'package:yerimebak/api/repositories.dart';
import 'api_client_test.dart' show MemoryTokens;

void main() {
  test(
    'geçici dosya hazırlanırken değişen oturum eski raporu açamaz',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final directory = await Directory.systemTemp.createTemp('yb020-pdf-');
      addTearDown(() => directory.delete(recursive: true));
      final api = ApiClient(
        store: MemoryTokens('user-a'),
        client: MockClient(
          (r) async => http.Response(
            '%PDF-1.7\n',
            200,
            headers: {'content-type': 'application/pdf'},
          ),
        ),
      );
      final service = AndroidServices(
        temporaryDirectory: () async {
          entered.complete();
          await release.future;
          return directory;
        },
        openDocument: (_) async => fail('Eski oturumun PDF dosyası açılmamalı'),
      );
      final opening = expectLater(
        service.openPdf(api, 'id'),
        throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 401)),
      );
      await entered.future;
      await api.clearSession();
      await api.saveSession('user-b');
      release.complete();
      await opening;
      expect(directory.listSync(), isEmpty);
    },
  );
}
