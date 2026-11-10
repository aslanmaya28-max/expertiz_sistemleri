import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak_sistemleri/admin/modules/finans_yonetimi.dart';
import 'package:yerimebak_sistemleri/admin/modules/fiyatlandirma_module.dart';
import 'package:yerimebak_sistemleri/admin/modules/piyasa_takibi_module.dart';
import 'package:yerimebak_sistemleri/admin/modules/ayarlar_module.dart';
import 'package:yerimebak_sistemleri/admin/modules/rapor_inceleme_module.dart';
import 'package:yerimebak_sistemleri/admin/widgets/hizmet_ayarlari.dart';
import 'package:yerimebak_sistemleri/screens/personel/personel_bolge_sistemi.dart';
import 'package:yerimebak_sistemleri/services/personel_service.dart';
import '../support/layout_audit.dart';

Map<String, dynamic> _response(String path, bool empty) {
  final firms = [
    for (var i = 0; i < 3; i++)
      {
        'id': 'firm-$i',
        'name': auditLongFirm,
        'firm_name': auditLongFirm,
        'active': true,
        'verified': false,
        'is_sayisi': 125000,
        'bulunamadi_sayisi': 125000,
        'hakedis_tl': 12500000,
        'paket_tl': 12500000,
        'odenecek_tl': 12500000,
        'packages': [
          {
            'id': 'package-$i',
            'name': auditLongVehicle,
            'active': true,
            'price': 1250000,
            'features': [auditLongFirm, auditLongVehicle]
          }
        ],
      }
  ];
  if (path.endsWith('/finance/summary')) {
    return {
      'ekspertiz': {
        'ciro_tl': 1250000000,
        'kdv_tl': 250000000,
        'net_tl': 1000000000,
        'request_count': 125000,
        'firma_paketi_tl': 12500000
      },
      'kredi_satislari': {
        'approved_tl': 1250000000,
        'pending_tl': 125000000,
        'approved_count': 125000,
        'pending_count': 125000
      },
      'personel': {
        'share_rate': 0.5,
        'hakedis_tl': 125000000,
        'by_personnel': empty
            ? []
            : [
                {
                  'personnel_id': 'p',
                  'personnel_name': auditLongName,
                  'report_count': 125000,
                  'hakedis_tl': 125000000
                }
              ]
      },
      'iadeler': {
        'expertiz_tl': 125000000,
        'expertiz_count': 125000,
        'kredi_tl': 125000000,
        'kredi_count': 125000
      },
      'firmalar': empty ? [] : firms
    };
  }
  if (path.endsWith('/payments/admin/orders')) {
    return {
      'orders': empty
          ? []
          : [
              for (var i = 0; i < 3; i++)
                {
                  'id': 'order-$i',
                  'status': 'approved',
                  'user_name': auditLongName,
                  'user_email': auditLongEmail,
                  'package_name': auditLongVehicle,
                  'amount_tl': 125000000,
                  'created_at': '2026-11-01T12:00:00'
                }
            ]
    };
  }
  if (path.endsWith('/pricing')) {
    return {
      'service_fee_tl': 1250000,
      'vat_rate': 0.2,
      'vehicle_inflation': {'monthly_pct': 12.5, 'note': auditLongFirm},
      'firms': empty ? [] : firms
    };
  }
  if (path.contains('market-gaps') || path.contains('/market/gaps')) {
    return {
      'modeller': empty
          ? []
          : [
              {
                'brand': 'Mercedes-Benz',
                'model': auditLongVehicle,
                'year': 2026,
                'requests': 125000,
                'last_count': 125000,
                'takip_ilan': 0
              }
            ]
    };
  }
  if (path.endsWith('/market/manual/preview')) {
    return {
      'marka': 'Mercedes-Benz',
      'atlanan': 1,
      'satirlar': empty
          ? []
          : [
              for (var i = 0; i < 2; i++)
                {
                  'iz': 'audit-market-$i',
                  'seri': auditLongVehicle,
                  'model': '$auditLongVehicle $i',
                  'yil': 2026,
                  'km': 1250000,
                  'fiyat': 125000000,
                  'beygir': 1250,
                  'ilan_tarihi': '2026-11-01',
                  'il': auditLongFirm,
                }
            ],
    };
  }
  if (path.endsWith('/reports')) {
    return {
      'reports': empty
          ? []
          : [
              {
                'id': 'report-040',
                'status': 'pending_admin',
                'plaka': '34 YB 040',
                'sehir': auditLongFirm,
                'user_id': auditLongEmail,
                'expertiz_firmasi': auditLongFirm,
                'created_at': '2026-11-01T12:00:00'
              }
            ]
    };
  }
  if (path.endsWith('/service-area')) {
    return {
      'pilot': auditLongFirm,
      'cities': empty
          ? []
          : [
              {'il': auditLongFirm, 'durum': 'test'},
              {'il': 'İstanbul', 'durum': 'acik'}
            ]
    };
  }
  if (path.endsWith('/control-center')) {
    return {'telefon': '08500000040', 'calisma_saatleri': auditLongFirm};
  }
  if (path.endsWith('/coverage')) {
    return {
      'summary': {
        'covered_city_count': 81,
        'critical_city_count': 125000,
        'unassigned_request_count': 125000
      },
      'critical_cities': empty ? [] : [auditLongFirm],
      'understaffed_cities': empty ? [] : [auditLongFirm],
      'regions': empty
          ? []
          : [
              {
                'region_id': 1,
                'region': 'Marmara Bölgesi',
                'province_count': 81,
                'covered_province_count': 81,
                'coverage_pct': 100,
                'active_personnel': 125000,
                'unassigned_request_count': 125000,
                'critical_cities': [auditLongFirm],
                'provinces': [
                  {
                    'city': 'İstanbul',
                    'region': 'Marmara Bölgesi',
                    'active_count': 125000,
                    'passive_count': 125000,
                    'open_request_count': 125000,
                    'unassigned_request_count': 125000,
                    'target_count': 125000,
                    'status': 'critical'
                  }
                ]
              }
            ]
    };
  }
  if (path.endsWith('/personnel')) {
    return {
      'personnel': empty
          ? []
          : [
              {
                'id': 'person-040',
                'full_name': auditLongName,
                'email': auditLongEmail,
                'phone': '05550000040',
                'city': 'İstanbul',
                'district': 'Kadıköy',
                'il_id': 34,
                'region_id': 1,
                'firm_name': auditLongFirm,
                'is_active': true,
                'open_task_count': 125000,
                'completed_task_count': 125000,
                'on_duty': true
              }
            ]
    };
  }
  if (path.endsWith('/firms')) return {'firms': empty ? [] : firms};
  throw StateError('Tanımsız denetim isteği: $path');
}

Future<void> _scroll(WidgetTester tester) async {
  final scroll = find.byWidgetPredicate((widget) =>
      widget is Scrollable &&
      (widget.axisDirection == AxisDirection.down ||
          widget.axisDirection == AxisDirection.up));
  if (scroll.evaluate().isEmpty) return;
  for (var i = 0; i < 8; i++) {
    await tester.drag(scroll.first, const Offset(0, -520));
    await auditPump(tester, frames: 4);
  }
}

void main() {
  for (final size in auditSizes) {
    for (final dark in [false, true]) {
      for (final empty in [false, true]) {
        for (final name in [
          'finans',
          'fiyatlandırma',
          'piyasa',
          'ayarlar',
          'rapor',
          'hizmet',
          'personel'
        ]) {
          testWidgets(
              '$name ${size.width}x${size.height} koyu=$dark boş=$empty',
              (tester) async {
            final client =
                auditClient((request) => _response(request.url.path, empty));
            final api = auditApi(client);
            PersonelService().apiServiceForTesting = api;
            final Widget screen = switch (name) {
              'finans' => FinansYonetimi(apiService: api),
              'fiyatlandırma' => FiyatlandirmaModule(apiService: api),
              'piyasa' => PiyasaTakibiModule(apiService: api),
              'ayarlar' => AyarlarModule(apiService: api),
              'rapor' => const RaporIncelemeModule(),
              'hizmet' => HizmetBolgeleriSayfasi(api: api),
              _ => const PersonelBolgePaneli(),
            };
            await auditLayout(tester,
                screen: screen,
                size: size,
                dark: dark,
                client: client, exercise: () async {
              expect(
                  find.textContaining(RegExp(
                      'yüklenemedi|yüklenemiyor|Tanımsız denetim',
                      caseSensitive: false)),
                  findsNothing);
              if (name == 'rapor' && !empty) {
                await tester.tap(find.text('34 YB 040'));
                await auditPump(tester);
              }
              if (name == 'piyasa') {
                if (!empty && size.width < 1100) {
                  final gapCards = find.byKey(const Key('marketGapsCards'));
                  final riskCard = tester.widget<Card>(find.descendant(
                      of: gapCards, matching: find.byType(Card)));
                  expect(
                      riskCard.color,
                      Theme.of(tester.element(gapCards))
                          .colorScheme
                          .errorContainer
                          .withValues(alpha: .4));
                }
                final paste = find.byKey(const Key('marketPaste'));
                await tester.ensureVisible(paste);
                await tester.enterText(paste, 'Uzun araç listesi denetimi');
                await auditPump(tester, frames: 2);
                final preview = find.widgetWithText(FilledButton, 'Önizle');
                await tester.ensureVisible(preview);
                await tester.tap(preview);
                await auditPump(tester);
                expect(
                    find.text('${empty ? 0 : 2} ilan hazır, 1 satır atlandı.'),
                    findsOneWidget);
                if (!empty) {
                  final remove = find.byKey(const Key('removeMarketRow-0'));
                  expect(remove, findsOneWidget);
                  expect(find.byKey(const Key('removeMarketRow-1')),
                      findsOneWidget);
                  await tester.ensureVisible(remove);
                  await tester.tap(remove);
                  await auditPump(tester);
                  expect(find.text('1 ilan hazır, 1 satır atlandı.'),
                      findsOneWidget);
                  expect(
                      find.byKey(const Key('removeMarketRow-1')), findsNothing);
                  expect(find.byKey(const Key('removeMarketRow-0')),
                      findsOneWidget);
                }
              }
              if (name == 'personel') {
                await tester.tap(find.text('Personel Ekle'));
                await auditPump(tester);
                expect(find.text('Yeni Personel Ekle'), findsOneWidget);
                await tester.tap(find.text('Vazgeç'));
                await auditPump(tester);
              }
              if (name == 'ayarlar') {
                final settings = find.byKey(const Key('ayar-kontrol-merkezi'));
                await tester.ensureVisible(settings);
                await tester.tap(settings);
                await auditPump(tester);
                expect(find.byType(AlertDialog), findsOneWidget);
                await tester.tap(find.text('Vazgeç'));
                await auditPump(tester);
              }
              await _scroll(tester);
            });
            client.close();
          });
        }
      }
    }
  }
}
