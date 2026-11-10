import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak_sistemleri/admin/modules/arac_operasyonu.dart';
import 'package:yerimebak_sistemleri/admin/modules/kontrol_merkezi_module.dart';
import 'package:yerimebak_sistemleri/admin/modules/musteri_yonetimi_module.dart';
import '../support/layout_audit.dart';

Map<String, dynamic> _request(String bucket) => {
      'id': '040',
      'request_id': '040',
      'bucket': bucket,
      'status': 'draft',
      'vehicle': {'title': auditLongVehicle, 'plate': '34 UZUN 040'},
      'customer': {
        'name': auditLongName,
        'phone': '05550000040',
        'email': auditLongEmail
      },
      'city': 'İstanbul',
      'district': 'Şereflikoçhisar',
      'region': 'Marmara Bölgesi',
      'firm_name': auditLongFirm,
      'firm_id': '40',
      'package_name':
          'Kurumsal kapsamlı ekspertiz ve yerinde araç inceleme paketi',
      'total_tl': 1250000000,
      'is_paid': true,
      'payment_status': 'paid',
      'durum_kodu': bucket == 'in_progress' ? 'vehicle_not_found' : '',
      'assignment': {
        'personnel_name': auditLongName,
        'personnel_phone': '05550000040',
        'status': 'vehicle_not_found',
        'note': auditLongFirm,
        'history': [
          {
            'action': 'vehicle_not_found',
            'note': '$auditLongName $auditLongFirm',
            'actor_name': auditLongName
          }
        ]
      },
      'randevu': {
        'tarih_saat': '2026-11-10T10:30:00',
        'adres': '$auditLongFirm Şereflikoçhisar İstanbul',
        'satici_adi': auditLongName,
        'satici_telefon': '05550000040'
      },
      'created_at': '2026-11-10T09:00:00',
    };

final _customer = <String, dynamic>{
  'id': 40,
  'full_name': auditLongName,
  'email': auditLongEmail,
  'phone': '05550000040',
  'is_active': true,
  'tester': true,
  'credits': 1250000000,
  'request_count': 1250000,
  'total_spent_tl': 1250000000,
  'created_at': '2026-11-10T09:00:00',
};

Map<String, dynamic> _response(
        {required bool filled, String bucket = 'waiting_assignment'}) =>
    {
      'requests': filled ? [_request(bucket)] : [],
      'counts': {bucket: filled ? 1 : 0},
      'customers': filled ? [_customer] : [],
      'customer': _customer,
      'credit_movements': filled
          ? [
              {
                'description': '$auditLongFirm $auditLongVehicle',
                'credits_used': -1250000000
              }
            ]
          : [],
      'gorevler': filled
          ? [
              {
                ..._request('in_progress'),
                'stage': 'assigned',
                'stage_label': 'Araç bulunamadı — paket iadesi bekliyor'
              }
            ]
          : [],
      'ayarlar': {
        'telefon': '08500000040',
        'calisma_saatleri': '08.00–20.00',
        'tanimli': true
      },
      'firm_id': '40',
      'recommended_id': '40',
      'candidates': [
        {
          'id': '40',
          'full_name': auditLongName,
          'firm_name': auditLongFirm,
          'assignable': true,
          'match': 'same_district',
          'city': 'İstanbul',
          'district': 'Şereflikoçhisar',
          'region': 'Marmara Bölgesi',
          'expertise': auditLongVehicle,
          'open_task_count': 1250000
        }
      ],
      'kayitlar': [
        {
          'hedef': 'musteri',
          'sonuc': 'baglandi',
          'note': '$auditLongName $auditLongFirm',
          'actor_name': auditLongName,
          'created_at': '2026-11-10T10:30:00'
        }
      ],
    };

Future<void> _tap(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; finder.evaluate().isEmpty && attempt < 40; attempt++) {
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await auditPump(tester);
  }
  expect(finder, findsWidgets);
  await tester.ensureVisible(finder.first);
  await auditPump(tester);
  await tester.tap(finder.first);
  await auditPump(tester);
}

void main() {
  for (final size in auditSizes) {
    for (final dark in [false, true]) {
      for (final filled in [false, true]) {
        for (final module in ['talepler', 'kontrol', 'müşteriler']) {
          testWidgets(
              '$module ${size.width}x${size.height} koyu=$dark dolu=$filled',
              (tester) async {
            final client = auditClient((_) => _response(filled: filled));
            final api = auditApi(client);
            final Widget screen = switch (module) {
              'talepler' => AracOperasyonu(apiService: api),
              'kontrol' => KontrolMerkeziModule(
                  apiService: api,
                  simdi: () => DateTime(2026, 11, 10, 10),
                  telefonAc: (_) async => true),
              _ => MusteriYonetimiModule(apiService: api),
            };
            await auditLayout(tester,
                screen: screen,
                size: size,
                dark: dark,
                client: client, exercise: () async {
              if (!filled) {
                expect(
                    find.text(switch (module) {
                      'talepler' => 'Atama bekleyen talep yok',
                      'kontrol' => 'Açık görev yok.',
                      _ => 'Henüz müşteri yok.'
                    }),
                    findsOneWidget);
                return;
              }
              expect(
                  find.text(module == 'müşteriler'
                      ? auditLongName
                      : auditLongVehicle),
                  findsWidgets);
              if (module == 'müşteriler') {
                await _tap(tester, find.text(auditLongName));
                expect(find.text(auditLongEmail), findsWidgets);
                await _tap(tester,
                    find.widgetWithText(OutlinedButton, 'Kredi yükle / düş'));
                await tester.enterText(
                    find.byType(TextFormField).first, '10000');
                await tester.enterText(find.byType(TextFormField).last,
                    '$auditLongName $auditLongFirm');
                await auditPump(tester);
                expect(find.text('Kaydet').hitTestable(), findsOneWidget);
                await _tap(tester, find.text('Vazgeç'));
                await tester.drag(
                    find.byType(ListView).last, const Offset(0, -500));
                await auditPump(tester);
                await tester.drag(
                    find.byType(ListView).last, const Offset(0, -500));
                await auditPump(tester);
              } else if (module == 'talepler') {
                await _tap(tester, find.text(auditLongVehicle));
                expect(find.text(auditLongName), findsWidgets);
                await _tap(
                    tester,
                    find.descendant(
                        of: find.byType(Dialog),
                        matching: find.text('Personel Ata')));
                expect(find.text(auditLongName), findsWidgets);
                await _tap(tester, find.text('İptal'));
              } else {
                await _tap(tester, find.byKey(const Key('ara-musteri-040')));
                expect(find.text('Müşteri araması — sonuç'), findsOneWidget);
                await tester.enterText(find.byType(TextField).last,
                    '$auditLongName $auditLongFirm');
                await auditPump(tester);
                await _tap(tester, find.text('Vazgeç'));
                if (size.width >= 1000) {
                  await _tap(tester, find.byTooltip('Görev ayrıntısı'));
                }
                await _tap(tester, find.text('Geçmiş'));
                expect(find.text('İletişim geçmişi'), findsOneWidget);
                expect(find.textContaining(auditLongFirm), findsWidgets);
                await _tap(tester, find.text('Kapat'));
              }
            });
          });
        }
      }
      testWidgets('paket iade diyaloğu ${size.width}x${size.height} koyu=$dark',
          (tester) async {
        final client =
            auditClient((_) => _response(filled: true, bucket: 'in_progress'));
        await auditLayout(tester,
            screen: AracOperasyonu(
                apiService: auditApi(client), initialBucket: 'in_progress'),
            size: size,
            dark: dark,
            client: client, exercise: () async {
          await _tap(tester, find.text(auditLongVehicle));
          await _tap(
              tester,
              find.descendant(
                  of: find.byType(Dialog),
                  matching: find.text('Paket ücretini iade et')));
          expect(
              find.textContaining(
                  'hizmet bedeli müşterinin ödeme öncesi onayı'),
              findsOneWidget);
          await tester.enterText(find.byKey(const Key('bulunamadi-neden')),
              '$auditLongName $auditLongFirm');
          await auditPump(tester);
          expect(find.byKey(const Key('bulunamadi-iade-onay')).hitTestable(),
              findsOneWidget);
          await _tap(tester, find.text('Vazgeç'));
        });
      });
    }
  }
}
