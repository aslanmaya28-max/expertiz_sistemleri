import 'package:flutter/material.dart';
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
}) async {
  await initializeDateFormatting('tr_TR');
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? YbTema.koyu : YbTema.acik,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReportView(
            ReportSnapshot.fromJson(data),
            onLink: (_) async {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'boş ve eksik bölümler gizlenir, rakamlar sunucudaki gibi gösterilir',
    (tester) async {
      await showReport(tester, fixture());
      expect(find.text('Özet'), findsOneWidget);
      expect(find.text('ÖNERİLMEZ'), findsOneWidget);
      expect(find.text('Ek inceleme yaptırın.'), findsOneWidget);
      expect(find.text('945.000 TL'), findsOneWidget);
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
      expect(find.text('930.000 TL'), findsNWidgets(3));
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
