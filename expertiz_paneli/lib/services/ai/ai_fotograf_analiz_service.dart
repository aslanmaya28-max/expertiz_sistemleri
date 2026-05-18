/// AI Fotograf Analiz Servisi
/// Araç fotoğraflarını analiz eder
class AIFotografAnalizService {
  /// Desteklenen fotograf uzantıları
  static const List<String> _desteklenenUzantilar = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
  ];

  /// Fotograf uzantısı kontrolü
  static bool isValidFotografUzantisi(String dosyaYolu) {
    String uzanti = dosyaYolu.toLowerCase();
    return _desteklenenUzantilar.any((u) => uzanti.endsWith(u));
  }

  /// Dosya boyutunu hesapla (KB cinsinden)
  static double hesaplaDosyaBoyutu(String dosyaYolu) {
    // Bu metod gerçek bir dosya sistemi erişimi gerektirir
    // Şimdilik mock bir değer döndürüyoruz
    // Gerçek uygulamada: File(dosyaYolu).lengthSync() / 1024
    return 500.0; // Mock: 500 KB
  }

  /// Fotograf kalitesini değerlendir
  static String degerlendirFotografKalitesi({
    required double dosyaBoyutuKB,
    required int genislik,
    required int yukseklik,
  }) {
    // Dosya boyutu kontrolü
    if (dosyaBoyutuKB < 50) {
      return 'Çok Düşük';
    } else if (dosyaBoyutuKB < 200) {
      return 'Düşük';
    } else if (dosyaBoyutuKB < 500) {
      return 'Orta';
    } else if (dosyaBoyutuKB < 2000) {
      return 'İyi';
    } else {
      return 'Çok İyi';
    }
  }

  /// Fotograf kategorizasyonu
  static String kategorizeFotograf(String dosyaAdi) {
    String kucukDosyaAdi = dosyaAdi.toLowerCase();

    if (kucukDosyaAdi.contains('on') && kucukDosyaAdi.contains('tampon')) {
      return 'Ön Tampon';
    } else if (kucukDosyaAdi.contains('on') && kucukDosyaAdi.contains('far')) {
      return 'Ön Farlar';
    } else if (kucukDosyaAdi.contains('on') && kucukDosyaAdi.contains('camurluk')) {
      return 'Ön Çamurluklar';
    } else if (kucukDosyaAdi.contains('kaput')) {
      return 'Ön Kaput';
    } else if (kucukDosyaAdi.contains('arka') && kucukDosyaAdi.contains('tampon')) {
      return 'Arka Tampon';
    } else if (kucukDosyaAdi.contains('arka') && kucukDosyaAdi.contains('camurluk')) {
      return 'Arka Çamurluklar';
    } else if (kucukDosyaAdi.contains('bagaj')) {
      return 'Bagaj Kapak';
    } else if (kucukDosyaAdi.contains('sol') && kucukDosyaAdi.contains('on') && kucukDosyaAdi.contains('kapi')) {
      return 'Sol Ön Kapı';
    } else if (kucukDosyaAdi.contains('sag') && kucukDosyaAdi.contains('on') && kucukDosyaAdi.contains('kapi')) {
      return 'Sağ Ön Kapı';
    } else if (kucukDosyaAdi.contains('sol') && kucukDosyaAdi.contains('arka') && kucukDosyaAdi.contains('kapi')) {
      return 'Sol Arka Kapı';
    } else if (kucukDosyaAdi.contains('sag') && kucukDosyaAdi.contains('arka') && kucukDosyaAdi.contains('kapi')) {
      return 'Sağ Arka Kapı';
    } else if (kucukDosyaAdi.contains('tavan')) {
      return 'Tavan';
    } else if (kucukDosyaAdi.contains('on') && kucukDosyaAdi.contains('lastik')) {
      return 'Ön Lastikler';
    } else if (kucukDosyaAdi.contains('arka') && kucukDosyaAdi.contains('lastik')) {
      return 'Arka Lastikler';
    } else if (kucukDosyaAdi.contains('direksiyon')) {
      return 'Direksiyon';
    } else if (kucukDosyaAdi.contains('gosterge') || kucukDosyaAdi.contains('gösterge')) {
      return 'Gösterge Paneli';
    } else if (kucukDosyaAdi.contains('klima')) {
      return 'Klima';
    } else if (kucukDosyaAdi.contains('ses') || kucukDosyaAdi.contains('radio')) {
      return 'Ses Sistemi';
    } else if (kucukDosyaAdi.contains('on') && kucukDosyaAdi.contains('koltuk')) {
      return 'Ön Koltuklar';
    } else if (kucukDosyaAdi.contains('arka') && kucukDosyaAdi.contains('koltuk')) {
      return 'Arka Koltuklar';
    } else if (kucukDosyaAdi.contains('doseme') || kucukDosyaAdi.contains('döşeme')) {
      return 'Koltuk Döşemesi';
    } else if (kucukDosyaAdi.contains('dorseme') || kucukDosyaAdi.contains('dörseme')) {
      return 'Dörseme';
    } else if (kucukDosyaAdi.contains('tavan') && (kucukDosyaAdi.contains('doseme') || kucukDosyaAdi.contains('döşeme'))) {
      return 'Tavan Döşemesi';
    } else if (kucukDosyaAdi.contains('on') && kucukDosyaAdi.contains('pencere')) {
      return 'Ön Pencereler';
    } else if (kucukDosyaAdi.contains('arka') && kucukDosyaAdi.contains('pencere')) {
      return 'Arka Pencereler';
    } else if (kucukDosyaAdi.contains('cam')) {
      return 'Camlar';
    } else if (kucukDosyaAdi.contains('merkezi') && kucukDosyaAdi.contains('kilit')) {
      return 'Merkezi Kilit';
    } else if (kucukDosyaAdi.contains('cam') && kucukDosyaAdi.contains('kontrol')) {
      return 'Cam Kontrolleri';
    } else if (kucukDosyaAdi.contains('ayna') && kucukDosyaAdi.contains('kontrol')) {
      return 'Ayna Kontrolleri';
    } else if (kucukDosyaAdi.contains('on') && kucukDosyaAdi.contains('kapi') && kucukDosyaAdi.contains('boya')) {
      return 'Ön Kapı Boya';
    } else if (kucukDosyaAdi.contains('arka') && kucukDosyaAdi.contains('kapi') && kucukDosyaAdi.contains('boya')) {
      return 'Arka Kapı Boya';
    } else if (kucukDosyaAdi.contains('kaput') && kucukDosyaAdi.contains('boya')) {
      return 'Kaput Boya';
    } else if (kucukDosyaAdi.contains('tampon') && kucukDosyaAdi.contains('boya')) {
      return 'Tampon Boya';
    } else if (kucukDosyaAdi.contains('tavan') && kucukDosyaAdi.contains('boya')) {
      return 'Tavan Boya';
    } else if (kucukDosyaAdi.contains('on') && kucukDosyaAdi.contains('kapi') && kucukDosyaAdi.contains('kaporta')) {
      return 'Ön Kapı Kaporta';
    } else if (kucukDosyaAdi.contains('arka') && kucukDosyaAdi.contains('kapi') && kucukDosyaAdi.contains('kaporta')) {
      return 'Arka Kapı Kaporta';
    } else if (kucukDosyaAdi.contains('kaput') && kucukDosyaAdi.contains('kaporta')) {
      return 'Kaput Kaporta';
    } else if (kucukDosyaAdi.contains('tampon') && kucukDosyaAdi.contains('kaporta')) {
      return 'Tampon Kaporta';
    } else if (kucukDosyaAdi.contains('on') && kucukDosyaAdi.contains('sasi')) {
      return 'Ön Şasi';
    } else if (kucukDosyaAdi.contains('arka') && kucukDosyaAdi.contains('sasi')) {
      return 'Arka Şasi';
    } else if (kucukDosyaAdi.contains('on') && kucukDosyaAdi.contains('direk')) {
      return 'Ön Direkler';
    } else if (kucukDosyaAdi.contains('arka') && kucukDosyaAdi.contains('direk')) {
      return 'Arka Direkler';
    } else if (kucukDosyaAdi.contains('podye')) {
      return 'Podye';
    } else if (kucukDosyaAdi.contains('marsbiyel')) {
      return 'Marsbiyel';
    } else if (kucukDosyaAdi.contains('motor')) {
      return 'Motor';
    } else if (kucukDosyaAdi.contains('sanziman')) {
      return 'Şanziman';
    } else if (kucukDosyaAdi.contains('fren')) {
      return 'Fren Sistemi';
    } else if (kucukDosyaAdi.contains('direksiyon') && kucukDosyaAdi.contains('sistem')) {
      return 'Direksiyon Sistemi';
    } else if (kucukDosyaAdi.contains('elektrik') && kucukDosyaAdi.contains('sistem')) {
      return 'Elektrik Sistemi';
    } else if (kucukDosyaAdi.contains('hasar')) {
      return 'Hasar Fotoğrafı';
    } else {
      return 'Diğer';
    }
  }

  /// Hasar fotoğraflarını tespit et
  static List<String> tespitHasarFotograflari(List<String> fotografUrlListesi) {
    List<String> hasarFotograflari = [];

    for (final url in fotografUrlListesi) {
      String dosyaAdi = url.split('/').last.toLowerCase();

      if (dosyaAdi.contains('hasar') ||
          dosyaAdi.contains('cizik') ||
          dosyaAdi.contains('cokme') ||
          dosyaAdi.contains('gokuk') ||
          dosyaAdi.contains('deformasyon') ||
          dosyaAdi.contains('paslanma') ||
          dosyaAdi.contains('kirik') ||
          dosyaAdi.contains('catlak')) {
        hasarFotograflari.add(url);
      }
    }

    return hasarFotograflari;
  }

  /// Fotoğraf analiz sonucu
  static Map<String, dynamic> analizEt(String fotografYolu) {
    Map<String, dynamic> sonuc = {
      'isValid': false,
      'dosyaBoyutuKB': 0.0,
      'kalite': '',
      'kategori': '',
      'hasarMi': false,
    };

    // Dosya uzantısı kontrolü
    if (!isValidFotografUzantisi(fotografYolu)) {
      return sonuc;
    }

    // Dosya adını al
    String dosyaAdi = fotografYolu.split('/').last;

    // Dosya boyutunu hesapla
    double dosyaBoyutuKB = hesaplaDosyaBoyutu(fotografYolu);

    // Kaliteyi değerlendir
    String kalite = degerlendirFotografKalitesi(
      dosyaBoyutuKB: dosyaBoyutuKB,
      genislik: 1920, // Mock değer
      yukseklik: 1080, // Mock değer
    );

    // Kategorizasyon yap
    String kategori = kategorizeFotograf(dosyaAdi);

    // Hasar fotoğrafı mı kontrol et
    bool hasarMi = tespitHasarFotograflari([fotografYolu]).isNotEmpty;

    sonuc = {
      'isValid': true,
      'dosyaBoyutuKB': dosyaBoyutuKB,
      'kalite': kalite,
      'kategori': kategori,
      'hasarMi': hasarMi,
    };

    return sonuc;
  }

  /// Çoklu fotoğraf analizi
  static Map<String, dynamic> analizEtCoklu(List<String> fotografYollari) {
    Map<String, dynamic> sonuc = {
      'toplamFotoğraf': 0,
      'gecerliFotoğraf': 0,
      'hasarFotoğraf': 0,
      'ortalamaDosyaBoyutuKB': 0.0,
      'kaliteDagilimi': <String, int>{},
      'kategoriDagilimi': <String, int>{},
      'detayliSonuclar': <String, dynamic>{},
    };

    int toplam = fotografYollari.length;
    int gecerli = 0;
    int hasar = 0;
    double toplamBoyut = 0.0;
    Map<String, int> kaliteDagilimi = {};
    Map<String, int> kategoriDagilimi = {};
    Map<String, dynamic> detayliSonuclar = {};

    for (final yol in fotografYollari) {
      Map<String, dynamic> analizSonucu = analizEt(yol);

      if (analizSonucu['isValid']) {
        gecerli++;
        toplamBoyut += analizSonucu['dosyaBoyutuKB'];

        // Kalite dağılımı
        String kalite = analizSonucu['kalite'];
        kaliteDagilimi[kalite] = (kaliteDagilimi[kalite] ?? 0) + 1;

        // Kategori dağılımı
        String kategori = analizSonucu['kategori'];
        kategoriDagilimi[kategori] = (kategoriDagilimi[kategori] ?? 0) + 1;

        // Hasar fotoğrafı mı
        if (analizSonucu['hasarMi']) {
          hasar++;
        }

        // Detaylı sonuçlar
        detayliSonuclar[yol] = analizSonucu;
      }
    }

    double ortalamaBoyut = gecerli > 0 ? (toplamBoyut / gecerli) : 0.0;

    sonuc = {
      'toplamFotoğraf': toplam,
      'gecerliFotoğraf': gecerli,
      'hasarFotoğraf': hasar,
      'ortalamaDosyaBoyutuKB': ortalamaBoyut,
      'kaliteDagilimi': kaliteDagilimi,
      'kategoriDagilimi': kategoriDagilimi,
      'detayliSonuclar': detayliSonuclar,
    };

    return sonuc;
  }

  /// Fotograf eksikliklerini kontrol et
  static List<String> kontrolFotografEksiklikleri({
    required Map<String, String> beklenenFotograflar,
    required Map<String, String> mevcutFotograflar,
  }) {
    List<String> eksikler = [];

    for (final entry in beklenenFotograflar.entries) {
      String anahtar = entry.key;
      String beklenenKategori = entry.value;

      if (!mevcutFotograflar.containsKey(anahtar) ||
          mevcutFotograflar[anahtar]!.isEmpty) {
        eksikler.add(beklenenKategori);
      }
    }

    return eksikler;
  }
}
