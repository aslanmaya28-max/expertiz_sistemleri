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
}
