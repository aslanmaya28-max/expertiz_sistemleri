import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yerimebak/api/api_client.dart';
import 'package:yerimebak/api/repositories.dart';
import 'package:yerimebak/api/report_list_controller.dart';
import 'api_client_test.dart' show MemoryTokens;

void main() {
  test(
    'sayfalama sunucu offset değerini kullanır, yenileme ilk sayfaya döner',
    () async {
      final offsets = <String?>[];
      final api = ApiClient(
        store: MemoryTokens('valid'),
        client: MockClient((r) async {
          offsets.add(r.url.queryParameters['offset']);
          final offset = int.parse(offsets.last!);
          return http.Response(
            jsonEncode({
              'total': 2,
              'offset': offset,
              'reports': [
                {
                  'id': 'r$offset',
                  'arac': {'marka': 'Seat'},
                },
              ],
            }),
            200,
          );
        }),
      );
      final list = ReportListController(ReportRepository(api));
      await list.refresh();
      expect(list.reports.single.id, 'r0');
      expect(list.hasMore, true);
      await list.next();
      expect(list.reports.map((r) => r.id), ['r0', 'r1']);
      expect(list.hasMore, false);
      await list.refresh();
      expect(list.reports.single.id, 'r0');
      expect(offsets, ['0', '1', '0']);
    },
  );

  test(
    'silinen rapor DELETE ile gider ve listeden çıkar (09.11.2026)',
    () async {
      final calls = <String>[];
      final api = ApiClient(
        store: MemoryTokens('valid'),
        client: MockClient((r) async {
          calls.add('${r.method} ${r.url.path}');
          if (r.method == 'DELETE') {
            return http.Response(jsonEncode({'success': true}), 200);
          }
          return http.Response(
            jsonEncode({
              'total': 2,
              'reports': [
                {
                  'id': 'a1',
                  'arac': {'marka': 'Skoda'},
                },
                {
                  'id': 'b2',
                  'arac': {'marka': 'Fiat'},
                },
              ],
            }),
            200,
          );
        }),
      );
      final list = ReportListController(ReportRepository(api));
      await list.refresh();
      await list.remove('a1');
      expect(list.reports.map((r) => r.id), ['b2']);
      expect(list.total, 1);
      expect(calls.last, endsWith('DELETE /api/v1/valuation/reports/a1'));
    },
  );
}
