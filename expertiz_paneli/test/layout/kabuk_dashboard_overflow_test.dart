import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yerimebak_sistemleri/admin/admin_shell.dart';
import 'package:yerimebak_sistemleri/admin/modules/dashboard_module.dart';
import '../support/layout_audit.dart';

Map<String, dynamic> dashboardData(bool filled) => {
      'ozet': {
        'musteriler': {
          'bugun': filled ? 12345678 : 0,
          'son7': filled ? 98765432 : 0
        },
        'degerlemeler': {
          'bugun': filled ? 12345678 : 0,
          'son7': filled ? 98765432 : 0
        },
        'kredi_satisi': {
          'son30_tl': filled ? 1250000000 : 0,
          'son30_adet': filled ? 1234567 : 0,
          'bekleyen_havale': filled ? 12345678 : 0,
          'play_son30_adet': filled ? 9876543 : 0
        },
        'ekspertiz': {
          'waiting_assignment': filled ? 12345678 : 0,
          'in_progress': filled ? 9876543 : 0,
          'pending_approval': filled ? 123456 : 0,
          'completed': filled ? 12345678 : 0,
          'cancelled': filled ? 12345 : 0,
          'arac_bulunamadi': filled ? 12345 : 0
        },
        'gunluk': [
          for (var i = 1; i <= 14; i++)
            {
              'tarih': '2026-11-${i.toString().padLeft(2, '0')}',
              'degerleme': filled ? i * 1234 : 0,
              'yeni_musteri': filled ? i * 500 : 0
            }
        ],
      },
      'status_distribution': {'pending_admin': filled ? 123456 : 0},
      'recent_activities': [
        if (filled)
          for (var i = 0; i < 5; i++)
            {
              'id': 'a$i',
              'type': 'reportCreated',
              'title':
                  '$auditLongName tarafından yeni ekspertiz raporu oluşturuldu',
              'description': '$auditLongVehicle — $auditLongFirm',
              'timestamp': '2026-11-10T10:00:00Z'
            }
      ],
    };

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  for (final size in [...auditSizes, const Size(1440, 900)]) {
    for (final dark in [false, true]) {
      for (final filled in [false, true]) {
        testWidgets(
            'ana sayfa ${size.width}x${size.height} koyu=$dark dolu=$filled',
            (tester) async {
          final client = auditClient((_) => dashboardData(filled));
          await auditLayout(tester,
              screen: DashboardModule(
                  apiService: auditApi(client),
                  displayName: auditLongName,
                  email: auditLongEmail),
              size: size,
              dark: dark,
              client: client, exercise: () async {
            final scroll = find.byType(Scrollable).first;
            for (var i = 0; i < 5; i++) {
              await tester.drag(scroll, const Offset(0, -450));
              await auditPump(tester, frames: 2);
            }
          });
        });
      }
      testWidgets(
          'gerçek yönetim kabuğu uzun kullanıcı ve rozet ${size.width} koyu=$dark',
          (tester) async {
        final client = auditClient((r) {
          if (r.url.path.endsWith('/dashboard')) return dashboardData(true);
          if (r.url.path.endsWith('/control-center/tasks')) {
            return {'gorevler': [], 'ayarlar': {}};
          }
          return {'notifications': [], 'unread': 1234567};
        });
        await auditLayout(tester,
            screen: const AdminShell(), size: size, dark: dark, client: client);
      });
    }
  }
}
