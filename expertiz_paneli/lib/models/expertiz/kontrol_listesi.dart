/// Saha ekspertiz kontrol listeleri (tek kaynak).
///
/// Dış ekspertiz, iç ekspertiz ve boya/kaporta adımlarında personelin
/// işaretlediği maddeler buradan gelir. Admin paneli ve müşteri raporu da
/// raporun içine yazılan `kontrolListesi` dizisini okuyarak aynı etiketleri
/// gösterir (web tarafı bu dosyayı bilmek zorunda değildir).
library;

import 'package:flutter/material.dart';

/// Bir kontrol maddesi (ör. "Ön Tampon").
class KontrolMaddesi {
  final String key;
  final String label;
  final String grup;

  /// Fotoğraf çekerken personele gösterilecek ipucu.
  final String? fotoIpucu;

  const KontrolMaddesi(this.key, this.label, this.grup, {this.fotoIpucu});
}

/// Dış / iç ekspertiz durum değerleri.
///
/// Değerler [Durum] enum adlarıyla aynıdır (eski raporlarla uyumlu).
class KontrolDurumu {
  static const mukemmel = 'mukemmel';
  static const iyi = 'iyi';
  static const orta = 'orta';
  static const sorunlu = 'sorunlu';
  static const kotu = 'kotu';
  static const agirHasar = 'agirHasar';

  /// Araçta bulunmayan / uygulanamayan madde (ör. sunroof yok).
  static const yok = 'yok';

  static const List<String> secenekler = [mukemmel, iyi, orta, sorunlu, kotu, agirHasar, yok];

  static const Map<String, String> etiketler = {
    mukemmel: 'Mükemmel',
    iyi: 'İyi',
    orta: 'Orta',
    sorunlu: 'Sorunlu',
    kotu: 'Kötü',
    agirHasar: 'Ağır Hasar',
    yok: 'Yok / Uygulanamaz',
  };

  /// Kötüden iyiye sıralama (en kötü durum özetlerde kullanılır).
  static const Map<String, int> _agirlik = {
    agirHasar: 0,
    kotu: 1,
    sorunlu: 2,
    orta: 3,
    iyi: 4,
    mukemmel: 5,
    yok: 6,
  };

  /// Eksiklik / hasar sayılan durumlar → fotoğraf zorunlu.
  static bool eksiklikMi(String? durum) => durum == sorunlu || durum == kotu || durum == agirHasar;

  static String etiket(String? durum) => etiketler[durum] ?? (durum ?? '-');

  static Color renk(String? durum) {
    switch (durum) {
      case mukemmel:
      case iyi:
        return Colors.green;
      case orta:
        return Colors.orange;
      case sorunlu:
        return Colors.deepOrange;
      case kotu:
      case agirHasar:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Verilen durumlardan en kötüsü (hepsi boşsa null).
  static String? enKotu(Iterable<String?> durumlar) {
    String? sonuc;
    for (final durum in durumlar) {
      if (durum == null || !_agirlik.containsKey(durum)) continue;
      if (sonuc == null || _agirlik[durum]! < _agirlik[sonuc]!) sonuc = durum;
    }
    return sonuc;
  }
}

/// Boya / kaporta parça durumları.
class ParcaDurumu {
  static const orijinal = 'orijinal';
  static const lokalBoyali = 'lokal_boyali';
  static const boyali = 'boyali';
  static const degisen = 'degisen';
  static const sokTak = 'sokulup_takilmis';
  static const hasarli = 'hasarli';

  static const List<String> secenekler = [orijinal, lokalBoyali, boyali, degisen, sokTak, hasarli];

  static const Map<String, String> etiketler = {
    orijinal: 'Orijinal',
    lokalBoyali: 'Lokal Boyalı',
    boyali: 'Boyalı',
    degisen: 'Değişen',
    sokTak: 'Sökülüp Takılmış',
    hasarli: 'Hasarlı (Çizik/Göçük)',
  };

  static String etiket(String? durum) => etiketler[durum] ?? (durum ?? '-');

  /// Orijinal dışındaki her durumda fotoğraf zorunlu.
  static bool eksiklikMi(String? durum) => durum != null && durum != orijinal;

  static Color renk(String? durum) {
    switch (durum) {
      case orijinal:
        return Colors.green;
      case lokalBoyali:
        return Colors.amber;
      case boyali:
        return Colors.orange;
      case degisen:
        return Colors.red;
      case sokTak:
        return Colors.blueGrey;
      case hasarli:
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }
}

/// Şasi, direk, podye gibi yapısal elemanların durumu.
class YapisalDurum {
  static const orijinal = 'orijinal';
  static const islemli = 'islemli';
  static const hasarli = 'hasarli';

  static const List<String> secenekler = [orijinal, islemli, hasarli];

  static const Map<String, String> etiketler = {
    orijinal: 'Orijinal / İşlemsiz',
    islemli: 'İşlemli (Kaynak/Düzeltme)',
    hasarli: 'Hasarlı',
  };

  static String etiket(String? durum) => etiketler[durum] ?? (durum ?? '-');
  static bool eksiklikMi(String? durum) => durum == islemli || durum == hasarli;

  static Color renk(String? durum) {
    switch (durum) {
      case orijinal:
        return Colors.green;
      case islemli:
        return Colors.orange;
      case hasarli:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Adım 2 – Dış ekspertiz maddeleri.
class DisEkspertizListesi {
  static const List<KontrolMaddesi> maddeler = [
    // Ön
    KontrolMaddesi('onTampon', 'Ön Tampon', 'Ön', fotoIpucu: 'Araca 45° açıyla önden bakın'),
    KontrolMaddesi('onKaput', 'Kaput', 'Ön', fotoIpucu: 'Araca tam önden bakın'),
    KontrolMaddesi('onFarlar', 'Ön Farlar', 'Ön', fotoIpucu: 'Farların önünden düz çekin'),
    KontrolMaddesi('sisFarlari', 'Sis Farları', 'Ön'),
    KontrolMaddesi('onPanjur', 'Ön Panjur / Izgara', 'Ön'),
    KontrolMaddesi('onCam', 'Ön Cam', 'Ön', fotoIpucu: 'Çatlak/taş izini yakından çekin'),
    KontrolMaddesi('silecekler', 'Silecekler', 'Ön'),
    // Sol yan
    KontrolMaddesi('solOnCamurluk', 'Sol Ön Çamurluk', 'Sol Yan'),
    KontrolMaddesi('solOnKapi', 'Sol Ön Kapı', 'Sol Yan'),
    KontrolMaddesi('solArkaKapi', 'Sol Arka Kapı', 'Sol Yan'),
    KontrolMaddesi('solArkaCamurluk', 'Sol Arka Çamurluk', 'Sol Yan'),
    KontrolMaddesi('solAyna', 'Sol Ayna', 'Sol Yan'),
    // Sağ yan
    KontrolMaddesi('sagOnCamurluk', 'Sağ Ön Çamurluk', 'Sağ Yan'),
    KontrolMaddesi('sagOnKapi', 'Sağ Ön Kapı', 'Sağ Yan'),
    KontrolMaddesi('sagArkaKapi', 'Sağ Arka Kapı', 'Sağ Yan'),
    KontrolMaddesi('sagArkaCamurluk', 'Sağ Arka Çamurluk', 'Sağ Yan'),
    KontrolMaddesi('sagAyna', 'Sağ Ayna', 'Sağ Yan'),
    // Arka
    KontrolMaddesi('arkaTampon', 'Arka Tampon', 'Arka', fotoIpucu: 'Araca 45° açıyla arkadan bakın'),
    KontrolMaddesi('bagajKapagi', 'Bagaj Kapağı', 'Arka'),
    KontrolMaddesi('stopLambalari', 'Stop Lambaları', 'Arka'),
    KontrolMaddesi('arkaCam', 'Arka Cam', 'Arka'),
    // Üst
    KontrolMaddesi('tavan', 'Tavan', 'Üst'),
    KontrolMaddesi('tavanTente', 'Sunroof / Tavan Tente', 'Üst'),
    // Alt ve şasi
    KontrolMaddesi('onSasi', 'Ön Şasi (Görsel)', 'Alt / Şasi'),
    KontrolMaddesi('arkaSasi', 'Arka Şasi (Görsel)', 'Alt / Şasi'),
    KontrolMaddesi('egzoz', 'Egzoz Sistemi', 'Alt / Şasi'),
    KontrolMaddesi('altKoruma', 'Alt Koruma / Karter Muhafazası', 'Alt / Şasi'),
    // Lastik ve jant
    KontrolMaddesi('onSolLastik', 'Sol Ön Lastik', 'Lastik / Jant', fotoIpucu: 'Diş derinliğini ve yanağı çekin'),
    KontrolMaddesi('onSagLastik', 'Sağ Ön Lastik', 'Lastik / Jant'),
    KontrolMaddesi('arkaSolLastik', 'Sol Arka Lastik', 'Lastik / Jant'),
    KontrolMaddesi('arkaSagLastik', 'Sağ Arka Lastik', 'Lastik / Jant'),
    KontrolMaddesi('jantlar', 'Jantlar', 'Lastik / Jant'),
    KontrolMaddesi('stepne', 'Stepne / Lastik Tamir Kiti', 'Lastik / Jant'),
    // Diğer
    KontrolMaddesi('kapiKollari', 'Kapı Kolları ve Kilitler', 'Diğer'),
    KontrolMaddesi('camFitilleri', 'Kapı / Cam Fitilleri', 'Diğer'),
  ];
}

/// Adım 3 – İç ekspertiz maddeleri.
class IcEkspertizListesi {
  static const List<KontrolMaddesi> maddeler = [
    // Kokpit
    KontrolMaddesi('direksiyon', 'Direksiyon (Boşluk/Kaplama)', 'Kokpit'),
    KontrolMaddesi('gostergePaneli', 'Gösterge Paneli', 'Kokpit'),
    KontrolMaddesi('uyariLambalari', 'Uyarı Lambaları (Motor/ABS/Airbag)', 'Kokpit',
        fotoIpucu: 'Kontak açıkken gösterge panelini çekin'),
    KontrolMaddesi('korna', 'Korna', 'Kokpit'),
    KontrolMaddesi('klima', 'Klima / Isıtma', 'Kokpit'),
    KontrolMaddesi('sesSistemi', 'Multimedya / Ses Sistemi', 'Kokpit'),
    KontrolMaddesi('torpido', 'Torpido ve Orta Konsol', 'Kokpit'),
    // Koltuklar
    KontrolMaddesi('onKoltuklar', 'Ön Koltuklar', 'Koltuklar'),
    KontrolMaddesi('arkaKoltuklar', 'Arka Koltuklar', 'Koltuklar'),
    KontrolMaddesi('koltukDosemesi', 'Koltuk Döşemesi (Yırtık/Leke)', 'Koltuklar'),
    KontrolMaddesi('koltukAyarlari', 'Koltuk Ayar Mekanizmaları', 'Koltuklar'),
    KontrolMaddesi('emniyetKemerleri', 'Emniyet Kemerleri', 'Koltuklar'),
    // Döşemeler
    KontrolMaddesi('dorseme', 'Taban Döşemesi / Paspas Altı', 'Döşemeler'),
    KontrolMaddesi('tavanDosemesi', 'Tavan Döşemesi', 'Döşemeler'),
    KontrolMaddesi('kapiDosemeleri', 'Kapı Döşemeleri', 'Döşemeler'),
    KontrolMaddesi('bagajIci', 'Bagaj İçi ve Havuzu', 'Döşemeler'),
    // Camlar
    KontrolMaddesi('onPencereler', 'Ön Kapı Camları', 'Camlar'),
    KontrolMaddesi('arkaPencereler', 'Arka Kapı Camları', 'Camlar'),
    KontrolMaddesi('camlar', 'Cam Yüzeyleri (Çizik/Çatlak)', 'Camlar'),
    // Elektronik
    KontrolMaddesi('merkeziKilit', 'Merkezi Kilit', 'Elektronik'),
    KontrolMaddesi('camKontrolleri', 'Elektrikli Cam Düğmeleri', 'Elektronik'),
    KontrolMaddesi('aynaKontrolleri', 'Ayna Ayar / Katlama', 'Elektronik'),
    KontrolMaddesi('icAydinlatma', 'İç Aydınlatma', 'Elektronik'),
    KontrolMaddesi('sunroofMekanizma', 'Sunroof Mekanizması', 'Elektronik'),
    // Genel
    KontrolMaddesi('kokuNem', 'Koku / Nem / Su Baskını İzi', 'Genel'),
  ];
}

/// Adım 4 – Boya / kaporta parçaları ve yapısal elemanlar.
class BoyaKaportaListesi {
  static const List<KontrolMaddesi> parcalar = [
    KontrolMaddesi('onTampon', 'Ön Tampon', 'Ön'),
    KontrolMaddesi('kaput', 'Motor Kaputu', 'Ön'),
    KontrolMaddesi('solOnCamurluk', 'Sol Ön Çamurluk', 'Sol'),
    KontrolMaddesi('solOnKapi', 'Sol Ön Kapı', 'Sol'),
    KontrolMaddesi('solArkaKapi', 'Sol Arka Kapı', 'Sol'),
    KontrolMaddesi('solArkaCamurluk', 'Sol Arka Çamurluk', 'Sol'),
    KontrolMaddesi('sagOnCamurluk', 'Sağ Ön Çamurluk', 'Sağ'),
    KontrolMaddesi('sagOnKapi', 'Sağ Ön Kapı', 'Sağ'),
    KontrolMaddesi('sagArkaKapi', 'Sağ Arka Kapı', 'Sağ'),
    KontrolMaddesi('sagArkaCamurluk', 'Sağ Arka Çamurluk', 'Sağ'),
    KontrolMaddesi('tavan', 'Tavan', 'Üst'),
    KontrolMaddesi('bagajKapagi', 'Bagaj Kapağı', 'Arka'),
    KontrolMaddesi('arkaTampon', 'Arka Tampon', 'Arka'),
  ];

  static const List<KontrolMaddesi> yapisal = [
    KontrolMaddesi('onSasi', 'Ön Şasi', 'Yapısal'),
    KontrolMaddesi('arkaSasi', 'Arka Şasi', 'Yapısal'),
    KontrolMaddesi('onDirekler', 'Ön (A) Direkler', 'Yapısal'),
    KontrolMaddesi('ortaDirekler', 'Orta (B) Direkler', 'Yapısal'),
    KontrolMaddesi('arkaDirekler', 'Arka (C) Direkler', 'Yapısal'),
    KontrolMaddesi('podye', 'Podyeler', 'Yapısal'),
    KontrolMaddesi('marsbiyel', 'Marşpiyeller', 'Yapısal'),
    KontrolMaddesi('bagajHavuzu', 'Bagaj Havuzu', 'Yapısal'),
  ];

  static String? etiket(String key) {
    for (final m in [...parcalar, ...yapisal]) {
      if (m.key == key) return m.label;
    }
    return null;
  }
}

/// Ortak yardımcılar.
Map<String, String> stringMap(dynamic value) {
  if (value is! Map) return <String, String>{};
  final result = <String, String>{};
  value.forEach((k, v) {
    if (v != null) result['$k'] = '$v';
  });
  return result;
}

Map<String, List<String>> stringListMap(dynamic value) {
  if (value is! Map) return <String, List<String>>{};
  final result = <String, List<String>>{};
  value.forEach((k, v) {
    if (v is List) result['$k'] = v.map((e) => '$e').toList();
  });
  return result;
}

List<String> stringList(dynamic value) => value is List ? value.map((e) => '$e').toList() : <String>[];

/// Rapor JSON'una gömülen, kendi kendini tanımlayan kontrol listesi.
/// Admin ve müşteri ekranları bu diziyi okuyarak etiketleri gösterir.
List<Map<String, dynamic>> kontrolListesiJson(
  List<KontrolMaddesi> maddeler,
  Map<String, String> durumlar,
  Map<String, String> notlar,
  String Function(String?) etiketFn,
  bool Function(String?) eksiklikFn,
) {
  return maddeler
      .map((m) => {
            'key': m.key,
            'label': m.label,
            'grup': m.grup,
            'durum': durumlar[m.key],
            'durumEtiket': etiketFn(durumlar[m.key]),
            'eksiklik': eksiklikFn(durumlar[m.key]),
            'not': notlar[m.key],
          })
      .toList();
}
