import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yerimebak/api/models.dart';
import 'package:yerimebak/bilesenler/rapor_gorunumu.dart';
import 'package:yerimebak/tema/tema.dart';

Json fixture() => {
  'arac': {
    'marka': 'Seat',
    'model': 'Ibiza',
    'yil': 2024,
    'km': 30000,
    'ilanFiyati': 960000,
  },
  'ozet': {
    'piyasaKonumu': {'metin': 'Piyasayla uyumlu'},
    'adilFiyat': {'min': 900000, 'max': 950000},
    'riskler': ['Servis kayıtlarını doğrulayın'],
    'pazarlikGerekceleri': [],
    'simdiNeYapmali': 'Belgeleri inceleyin.',
  },
  'piyasa': {
    'ortalama': 950000,
    'medyan': 940000,
    'min': 900000,
    'max': 1000000,
    'emsalSayisi': 3,
    'kaynaklar': [],
    'uyarilar': ['Yalnızca 3 doğrulanmış emsal ilan bulundu (hedef 5).'],
  },
  'degerleme': {
    'aiDegeri': 945000,
    'tavsiyeFiyat': 930000,
    'temizPiyasaDegeri': 950000,
    'adilFiyatAraligi': {'min': 900000, 'max': 950000},
    'kalemler': [],
    'toplamDegerKaybiYuzde': 0,
    'toplamDegerKaybiTutar': 0,
  },
  'karar': {'sonuc': 'ALMA', 'aciklama': 'Ek inceleme yaptırın.'},
  'admin_note': 'YALNIZ ADMIN',
  'kredi': {'dusulen': 1, 'kalan': 4},
};

Future<void> showReport(
  WidgetTester tester,
  Json data, {
  bool dark = false,
  Future<void> Function(String)? onLink,
}) async {
  await initializeDateFormatting('tr_TR');
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? YbTema.koyu : YbTema.acik,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReportView(
            ReportSnapshot.fromJson(data),
            onLink: onLink ?? (_) async {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mesaj bağımsız bölümde paragraflarıyla kopyalanır', (
    tester,
  ) async {
    const message =
        'Merhaba, araçla ilgileniyorum.\n\nBelgeleri paylaşır mısınız?';
    final data = fixture()
      ..['pazarlikPlani'] = {
        'acilisTeklifi': 900000,
        'hedefFiyat': 930000,
        'ustSinir': 940000,
        'saticiMesaji': message,
      };
    String? copied;
    String? shared;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await showReport(
      tester,
      data,
      onLink: (url) async {
        shared = url;
      },
    );
    expect(find.text("WhatsApp'ta paylaş"), findsOneWidget);
    expect(find.text('Satıcıya gönderilecek mesaj'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Satıcıya gönderilecek mesaj')).dy,
      greaterThan(tester.getTopLeft(find.text('Pazarlık planı')).dy),
    );
    await tester.ensureVisible(find.text('Kopyala'));
    await tester.tap(find.text('Kopyala'));
    await tester.pumpAndSettle();
    expect(copied, message);
    await tester.ensureVisible(find.text("WhatsApp'ta paylaş"));
    await tester.tap(find.text("WhatsApp'ta paylaş"));
    await tester.pumpAndSettle();
    expect(Uri.parse(shared!).host, 'wa.me');
    expect(Uri.parse(shared!).queryParameters['text'], message);
  });

  testWidgets('enflasyon oranları ve kazançları sunucudan, tarih Türkçe', (
    tester,
  ) async {
    final data = fixture()
      ..['getiri'] = {
        'aylikEnflasyonYuzde': 2,
        'altiAylikEnflasyonYuzde': 12.9,
        'yillikEnflasyonYuzde': 26,
        'kaynak': 'TÜİK',
        'gecerlilikTarihi': '2026-11-01',
        'aciklama': 'Tahmindir.',
        'altiAy': {
          'tahminiDeger': 1060000,
          'getiriTl': 130000,
          'getiriYuzde': 14,
          'alimKazanciTl': 15000,
          'enflasyonKazanciTl': 115000,
        },
        'birYil': {
          'tahminiDeger': 1190000,
          'getiriTl': 260000,
          'getiriYuzde': 28,
        },
      };
    await showReport(tester, data);
    expect(find.text('Enflasyona göre kazanç tahmini'), findsOneWidget);
    expect(find.textContaining('%12,9'), findsWidgets);
    expect(find.textContaining('130.000 TL'), findsWidgets);
    expect(find.textContaining('260.000 TL'), findsWidgets);
    expect(find.textContaining('01.11.2026'), findsOneWidget);
    expect(find.textContaining('15.000 TL'), findsWidgets);
    expect(find.text('Getiri tahmini (araç enflasyonu)'), findsNothing);
    expect(tester.takeException(), isNull);
    await showReport(tester, fixture());
    expect(find.text('Enflasyona göre kazanç tahmini'), findsNothing);
  });

  testWidgets('eski getiri raporunda altı aylık oran aylıktan türetilir', (
    tester,
  ) async {
    await showReport(
      tester,
      fixture()
        ..['getiri'] = {
          'aylikEnflasyonYuzde': 2,
          'yillikEnflasyonYuzde': 26,
          'altiAy': {
            'tahminiDeger': 1060000,
            'getiriTl': 130000,
            'getiriYuzde': 14,
          },
        },
    );
    expect(find.textContaining('%12,6'), findsWidgets);
    expect(find.text('6 ay sonra'), findsOneWidget);
    expect(find.text('1 yıl sonra'), findsNothing);
  });
  testWidgets(
    'boş ve eksik bölümler gizlenir, rakamlar sunucudaki gibi gösterilir',
    (tester) async {
      await showReport(tester, fixture());
      expect(find.text('En önemli riskler'), findsOneWidget);
      // Karar verisi müşteriye gösterilmez (sitedeki kuralla aynı, 09.11.2026).
      expect(find.text('ÖNERİLMEZ'), findsNothing);
      expect(find.text('Ek inceleme yaptırın.'), findsNothing);
      expect(find.text('945.000 TL'), findsNWidgets(2));
      expect(find.text('930.000 TL'), findsOneWidget);
      for (final label in [
        'Pazarlık planı',
        'Modelin bilinen sorunları',
        'Satıcıya sorulacak sorular',
        'YALNIZ ADMIN',
        'ALMA',
      ]) {
        expect(find.text(label), findsNothing);
      }
      expect(find.textContaining('3 benzer ilan bulundu;'), findsOneWidget);
      expect(
        find.text('Yalnızca 3 doğrulanmış emsal ilan bulundu (hedef 5).'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pazarlık hedefi üst sınıra eşitse değişmez, düşük güvenli risk gizlenir',
    (tester) async {
      final data = fixture()
        ..addAll({
          'pazarlikPlani': {
            'acilisTeklifi': 900000,
            'hedefFiyat': 930000,
            'ustSinir': 930000,
            'potansiyelKazanc': 30000,
            'adimlar': ['Satıcıyla görüşün'],
            'gerekceler': [],
            'kanitIlanlar': [],
            'saticiMesaji': 'Belgeleri paylaşır mısınız?',
          },
          'modelRiskleri': {
            'riskler': [
              {'baslik': 'Gizli düşük güven', 'guven': 'dusuk'},
              {
                'baslik': 'Doğrulanmış bakım',
                'guven': 'orta',
                'kontrol': 'Serviste kontrol edin',
                'kaynaklar': [],
              },
            ],
          },
          'kullaniciSikayetleri': [],
          'bakim': [],
          'saticiSorulari': ['Bakımlar ne zaman yapıldı?'],
        });
      await showReport(tester, data, dark: true);
      expect(find.text('Pazarlık planı'), findsOneWidget);
      expect(find.text('930.000 TL'), findsNWidgets(4));
      expect(find.text('Gizli düşük güven'), findsNothing);
      expect(find.text('Doğrulanmış bakım'), findsOneWidget);
      expect(
        find.text(
          'Birden fazla kaynakta tekrarlanan kullanıcı şikâyeti bulunamadı.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('eski özet kayıt tam rapor gibi gösterilmez', (tester) async {
    await showReport(tester, {
      'ozet_kayit': true,
      'arac': {'marka': 'Seat'},
      'report_no': 'YD 2026-000020',
    });
    expect(find.textContaining('Tam rapor bulunmuyor'), findsOneWidget);
    expect(find.text('Adil fiyat aralığı'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('yüzde 130 yazı ölçeğinde fiyat satırları taşmaz', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: YbTema.acik,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: ReportView(
                  ReportSnapshot.fromJson(fixture()),
                  onLink: (_) async {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
