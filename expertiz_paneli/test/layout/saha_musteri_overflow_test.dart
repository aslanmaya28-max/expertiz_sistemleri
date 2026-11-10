import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yerimebak_sistemleri/bilesenler/bilesenler.dart';
import 'package:yerimebak_sistemleri/customer/analysis_history_screen.dart';
import 'package:yerimebak_sistemleri/customer/create_request_screen.dart';
import 'package:yerimebak_sistemleri/customer/customer_dashboard.dart';
import 'package:yerimebak_sistemleri/customer/profile_edit_screen.dart';
import 'package:yerimebak_sistemleri/models/user_model.dart';
import 'package:yerimebak_sistemleri/personnel/personnel_dashboard.dart';
import 'package:yerimebak_sistemleri/providers/expertiz_provider.dart';
import 'package:yerimebak_sistemleri/screens/expertiz_akisi/expertiz_baslat_sayfasi.dart';
import 'package:yerimebak_sistemleri/screens/login_screen.dart';
import 'package:yerimebak_sistemleri/screens/register_screen.dart';
import 'package:yerimebak_sistemleri/screens/musteri/oto_analiz_merkezi.dart';
import '../support/layout_audit.dart';

Map<String, dynamic> _response(String path, bool filled) {
  final request = {
    'id': '040',
    'report_id': '040',
    'plate': '34 UZUN 040',
    'firm_name': auditLongFirm,
    'status': 'in_progress',
    'progress': {
      'label': 'Araç bulunamadı — paket iadesi için yönetim kararı bekleniyor'
    },
    'created_at': '2026-11-10T10:30:00Z',
    'amount': 1250000,
    'vehicle': {
      'brand': auditLongVehicle,
      'model': auditLongVehicle,
      'year': 2026
    },
  };
  if (path.endsWith('/requests')) {
    return {
      'requests': filled ? [request, request] : []
    };
  }
  if (path.endsWith('/profile')) {
    return {
      'profile': {
        'company_name': filled ? auditLongFirm : '',
        'tax_office': 'İstanbul Anadolu Kurumlar Vergi Dairesi',
        'tax_number': '1234567890',
        'invoice_address': '$auditLongFirm Kadıköy İstanbul',
      }
    };
  }
  if (path.endsWith('/me')) {
    return {
      'personnel': {
        'full_name': auditLongName,
        'city': 'İstanbul',
        'district': 'Kadıköy',
        'on_duty': true,
      }
    };
  }
  if (path.endsWith('/tasks')) {
    return {
      'kontrol_merkezi': {
        'telefon': '08505550040',
        'calisma_saatleri': 'Her gün 08.00–23.00'
      },
      'tasks': filled
          ? [
              for (final bucket in [
                'active',
                'pending',
                'rejected',
                'approved'
              ])
                {
                  'id': bucket,
                  'personnel_bucket': bucket,
                  'stage': 'on_the_way',
                  'vehicle': {
                    'title': auditLongVehicle,
                    'plate': '34 UZUN 040'
                  },
                  'customer': {'name': auditLongName},
                  'city': 'İstanbul',
                  'district': 'Kadıköy',
                  'firm_name': auditLongFirm,
                  'package_name':
                      'Kapsamlı Kurumsal Ekspertiz ve Yol Testi Paketi',
                  'corporate_required': true,
                  'next_actions': ['arrive', 'corporate'],
                  'assignment': {
                    'status': 'on_the_way',
                    'assigned_at': '2026-11-10T10:00:00Z',
                    'departed_at': '2026-11-10T10:30:00Z'
                  },
                  'randevu': {
                    'tarih_saat': '2026-11-10T11:00:00Z',
                    'adres': '$auditLongFirm Uzun Sokak No 40',
                    'satici_adi': auditLongName
                  },
                  'note':
                      '$auditLongName tarafından girilen ayrıntılı görev notu.',
                  'rejection_reason':
                      '$auditLongVehicle fotoğrafları eksik; yeniden denetim gerekiyor.',
                  'submitted_at': '2026-11-10T11:00:00Z',
                  'published_at': '2026-11-10T12:00:00Z',
                }
            ]
          : [],
    };
  }
  if (path.contains('/notifications')) {
    return {
      'unread': filled ? 999 : 0,
      'notifications': filled
          ? [
              {
                'id': 40,
                'title': auditLongVehicle,
                'body': '$auditLongName — $auditLongFirm',
                'created_at': '2026-11-10T10:00:00Z'
              }
            ]
          : []
    };
  }
  if (path.endsWith('/report')) {
    return {
      'editable': true,
      'success': true,
      'task': {
        'vehicle': filled
            ? {
                'brand': auditLongVehicle,
                'model': auditLongVehicle,
                'plate': '34 UZUN 040',
                'year': 2026,
                'km': 1250000,
                'package': auditLongVehicle
              }
            : {}
      },
      'corporate': {
        'required': filled,
        'firm_name': filled ? auditLongFirm : '',
        'package_name':
            filled ? 'Kapsamlı Kurumsal Ekspertiz ve Yol Testi Paketi' : ''
      },
      'media': [],
      'draft_saved_at': '2026-11-10T10:00:00Z',
    };
  }
  return {'success': true};
}

Future<void> _scroll(WidgetTester tester) async {
  // Her kartı/form alanını oluşturur; sonsuz animasyonu beklemez.
  for (var i = 0; i < 12; i++) {
    final scroll = find
        .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
        .hitTestable();
    if (scroll.evaluate().isEmpty) break;
    await tester.drag(scroll.last, const Offset(0, -600));
    await auditPump(tester, frames: 2);
  }
}

void main() {
  for (final size in auditSizes) {
    for (final dark in [false, true]) {
      for (final filled in [false, true]) {
        final label =
            '${size.width}x${size.height} ${dark ? 'koyu' : 'açık'} ${filled ? 'dolu' : 'boş'}';
        testWidgets('müşteri oto analiz formu ve sonuçları $label taşmaz',
            (tester) async {
          final client = auditClient((r) => _response(r.url.path, filled));
          await auditLayout(tester,
              screen: const OtoAnalizMerkezi(),
              size: size,
              dark: dark,
              client: client,
              role: UserRole.customer, exercise: () async {
            if (filled) {
              final brand = tester.widget<DropdownButton<String>>(
                  find.byType(DropdownButton<String>).first);
              final brands = brand.items!.map((item) => item.value!).toList()
                ..sort((a, b) => b.length.compareTo(a.length));
              brand.onChanged!(brands.first);
              await auditPump(tester);
              final model = tester.widget<DropdownButton<String>>(
                  find.byType(DropdownButton<String>).last);
              final models = model.items!.map((item) => item.value!).toList()
                ..sort((a, b) => b.length.compareTo(a.length));
              model.onChanged!(models.first);
              await auditPump(tester);
              final packageCard = find.ancestor(
                  of: find.text('Paket seçimi'), matching: find.byType(YbKart));
              final packages = tester
                  .widgetList<ListTile>(find.descendant(
                      of: packageCard, matching: find.byType(ListTile)))
                  .toList()
                ..sort((a, b) => ((b.title as Text).data ?? '')
                    .length
                    .compareTo(((a.title as Text).data ?? '').length));
              packages.first.onTap!();
              await auditPump(tester);
              await _scroll(tester);
              expect(find.byType(Slider), findsOneWidget,
                  reason:
                      'Paket seçilince üretim yılı alanı görünmeli; paket: ${(packages.first.title as Text).data}');
              tester.widget<Slider>(find.byType(Slider).first).onChanged!(2020);
              await auditPump(tester);
              tester
                  .widget<Slider>(find.byType(Slider).last)
                  .onChanged!(300000);
              final color = find
                  .ancestor(
                      of: find.text('Gümüş Gri'),
                      matching: find.byType(GestureDetector))
                  .first;
              tester.widget<GestureDetector>(color).onTap!();
              for (final option in tester.widgetList<CheckboxListTile>(
                  find.byType(CheckboxListTile))) {
                option.onChanged!(true);
              }
              await auditPump(tester);
            }
            await _scroll(tester);
            if (filled) {
              final start = find.widgetWithText(FilledButton, 'Analizi Başlat');
              await tester.ensureVisible(start);
              await auditPump(tester);
              await tester.tap(start);
              await auditPump(tester);
              expect(find.text('AI Tahmini Değer'), findsOneWidget);
              await _scroll(tester);
            }
          });
          client.close();
        });
        for (final entry in <String, Widget Function()>{
          'müşteri ana sayfa': () => const CustomerDashboard(),
          'müşteri profil': () => const ProfileEditScreen(),
          'müşteri analiz geçmişi': () => const AnalysisHistoryScreen(),
          'müşteri site yönlendirme': () =>
              CreateRequestScreen(baglantiAc: (_) async => true),
          'giriş': () => const LoginScreen(),
          'kayıt': () => const RegisterScreen(),
        }.entries) {
          testWidgets('${entry.key} $label taşmaz', (tester) async {
            final client = auditClient((r) => _response(r.url.path, filled));
            await auditLayout(tester,
                screen: entry.value(),
                size: size,
                dark: dark,
                client: client,
                role: UserRole.customer, exercise: () async {
              if (filled && (entry.key == 'giriş' || entry.key == 'kayıt')) {
                final fields = find.byType(TextFormField);
                for (var i = 0; i < fields.evaluate().length; i++) {
                  await tester.enterText(
                      fields.at(i), i == 0 ? auditLongName : auditLongEmail);
                }
              }
              await _scroll(tester);
            });
            client.close();
          });
        }
        testWidgets('saha görevlerinin dört sekmesi $label taşmaz',
            (tester) async {
          final client = auditClient((r) => _response(r.url.path, filled));
          await auditLayout(tester,
              screen: PersonnelDashboard(apiService: auditApi(client)),
              size: size,
              dark: dark,
              client: client,
              role: UserRole.fieldStaff, exercise: () async {
            if (filled) {
              for (final key in ['kontrol-not-active', 'bulunamadi-active']) {
                final button = find.byKey(Key(key));
                await tester.ensureVisible(button);
                await auditPump(tester);
                for (var attempt = 0;
                    attempt < 12 && button.hitTestable().evaluate().isEmpty;
                    attempt++) {
                  final list = find.byType(ListView).hitTestable().first;
                  await tester.drag(list, const Offset(0, -300));
                  await auditPump(tester, frames: 2);
                }
                expect(button.hitTestable(), findsOneWidget);
                await tester.tap(button);
                await auditPump(tester);
                await tester.tap(find.text('Vazgeç').last);
                await auditPump(tester);
              }
            }
            final context = tester.element(find.byType(TabBarView));
            final tabs = DefaultTabController.of(context);
            for (var i = 0; i < 4; i++) {
              tabs.animateTo(i);
              await auditPump(tester);
              await _scroll(tester);
            }
            await tester.tap(find.byKey(const Key('notificationsButton')));
            await auditPump(tester);
          });
          client.close();
        });
        for (var step = 1; step <= 5; step++) {
          testWidgets('saha adım $step $label taşmaz', (tester) async {
            final client = auditClient((r) => _response(r.url.path, filled));
            final provider = ExpertizProvider(apiService: auditApi(client));
            await auditLayout(tester,
                screen: ChangeNotifierProvider.value(
                    value: provider,
                    child: const ExpertizBaslatSayfasi(
                        gorevId: '040',
                        personelId: '040',
                        personelAdi: auditLongName,
                        musteriAdi: auditLongName,
                        aracPlakasi: '34 UZUN 040')),
                size: size,
                dark: dark,
                client: client,
                role: UserRole.fieldStaff, exercise: () async {
              expect(provider.adim1Model, isNotNull,
                  reason: 'Sahte rapor yanıtı ekrana yüklenmeli');
              if (filled) {
                provider.updateAdim1(provider.adim1Model!.copyWith(
                    ruhsatSahibiAdSoyad: auditLongName,
                    pazarlikPayiVar: true,
                    pazarlikMiktari: 1250000,
                    hasarKayitAdet: 12,
                    hasarKayitToplamTutar: 1250000,
                    genelNot: '$auditLongVehicle — $auditLongFirm'));
                provider.updateAdim5(provider.adim5Model!.copyWith(
                    kurumsalRaporNo: '040-UZUN-KURUMSAL-EKSPERTİZ-RAPORU',
                    kurumsalSonucOzeti: '$auditLongVehicle — $auditLongFirm',
                    genelPuan: 99,
                    ozetNot: '$auditLongName tarafından incelenmiştir.'));
              }
              provider.goToStep(step);
              await auditPump(tester);
              await _scroll(tester);
            });
            provider.dispose();
            client.close();
          });
        }
      }
    }
  }
}
