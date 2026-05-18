/// MarketRadarService
/// Türk otomotiv piyasası dinamiklerine göre araç değerlemesi yapan servis
class MarketRadarService {
   /// Paket ağırlık çarpanı - Veritabanından gelen ağırlığı kullanır
   static double _getPackageWeightMultiplier(double packageWeight) {
     return packageWeight; // Doğrudan ağırlığı kullan (1.0 - 2.0 arası)
   }
   
   /// Paket ağırlığına göre etiket döndürür
   static String _getPackageTypeLabel(double packageWeight) {
     if (packageWeight >= 1.6) {
       return 'Spor/AMG/M';
     } else if (packageWeight >= 1.4) {
       return 'Premium/Lüks';
     } else if (packageWeight >= 1.2) {
       return 'Comfort/Advanced';
     } else if (packageWeight >= 1.1) {
       return 'Orta Seviye';
     } else {
       return 'Standart';
     }
   }

  /// Sport paket tespiti - Model isminden spor paket tespiti
  static bool isSportPackage(String? modelName) {
    final sportKeywords = [
      'AMG', 'M', 'RS', 'R-Line', 'ST', 'GTI', 'Cupra',
      'M-Sport', 'S-Line', 'TFSI', 'TDI', 'Quattro',
      'xDrive', '4MATIC', 'AMT', 'DCT'
    ];
    return sportKeywords.any((keyword) => 
      modelName?.toUpperCase().contains(keyword) ?? false
    );
  }

  /// Paket/Donanım Çakışma Kontrolü
  /// Eğer paket 'Standart' ama donanımlar dolu ise uyarı döndür
  static Map<String, dynamic>? _checkPackageEquipmentConflict({
    required String packageLevel,
    required Map<String, bool> selectedOptions,
  }) {
    // Standart paket seçili ama premium donanımlar var mı?
    if (packageLevel.toLowerCase() == 'standart' || packageLevel.isEmpty) {
      final premiumOptions = [
        'cam tavan', 'sunroof', 'led far', 'matrix far', 'laser far',
        'adaptif far', 'vakumlu kapı', 'soft close', 'head-up display',
        'hud', 'panoramik tavan', 'ısıtmalı koltuk', 'deri koltuk',
        'navigasyon', 'harita', 'gps'
      ];
      
      final selectedPremiumCount = premiumOptions.where((option) => 
        selectedOptions[option.toLowerCase()] ?? false
      ).length;

      if (selectedPremiumCount >= 3) {
        return {
          'hasConflict': true,
          'warning': 'Sonradan Eklenen Donanımlar Değeri Artırıyor',
          'premiumCount': selectedPremiumCount,
        };
      }
    }
    
    return null;
  }

  /// Entegre Değer Hesaplama
  /// Paket seçimi + opsiyonel donanımlar + borsa verilerini harmanlayan algoritma
  static Map<String, dynamic> calculateIntegratedValue({
    required String brand,
    required String model,
    required int year,
    required int km,
    required String color,
    required String packageLevel,
    double packageWeight = 1.0, // Paket ağırlığı (VehiclePackagesDatabase'den gelir)
    required Map<String, bool> selectedOptions,
    required List<String> paintedParts,
    required List<String> damagedParts,
    String? marketSource, // 'sahibinden' veya 'noter'
  }) {
    // 1. Temel piyasa değerini hesapla
    double basePrice = _getBaseMarketPrice(brand, model, year);
    
    // 2. Paket ağırlık çarpanını uygula (Hiyerarşik değerleme)
    bool isSport = isSportPackage(model);
    
    // Paket ağırlığını kullan (VehiclePackagesDatabase'den gelen değer)
    double packageMultiplier = _getPackageWeightMultiplier(packageWeight);
    double valueAfterSport = basePrice * packageMultiplier;
    
    // 3. Seçili opsiyonel donanımların değerini ekle
    final selectedOptionList = selectedOptions.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    
    double optionValue = 0.0;
    List<String> optionAdjustments = [];
    
    if (selectedOptionList.isNotEmpty) {
      for (String option in selectedOptionList) {
        final optionPrice = _getOptionPrice(option, basePrice);
        optionValue += optionPrice;
        optionAdjustments.add('$option: +${optionPrice.toStringAsFixed(0)} TL');
      }
    }
    
    double valueAfterOptions = valueAfterSport + optionValue;
    
    // 4. Boya/Hasar ayarlamalarını uygula
    double boyaIndirimi = _calculateBoyaIndirimiDetayli(paintedParts);
    double hasarIndirimi = _calculateHasarIndirimi(damagedParts);
    
    double valueAfterCondition = valueAfterOptions * (1.0 - boyaIndirimi - hasarIndirimi);
    
    // 5. KM/Yaş dengesini uygula
    int currentYear = DateTime.now().year;
    int yas = currentYear - year;
    int beklenenYillikKm = 15000;
    int beklenenToplamKm = yas * beklenenYillikKm;
    double kmYasiOrani = km / beklenenToplamKm;
    
    double kmYasAyarlama = 0.0;
    if (kmYasiOrani < 0.5) {
      double bonusOrani = (0.5 - kmYasiOrani) * 0.15;
      kmYasAyarlama = bonusOrani;
    } else if (kmYasiOrani > 1.5) {
      double dususOrani = (kmYasiOrani - 1.5) * 0.1;
      kmYasAyarlama = -dususOrani;
    }
    
    double valueAfterKm = valueAfterCondition * (1.0 + kmYasAyarlama);
    
    // 6. Borsa kaynağı ayarlaması (Sahibinden/Noter)
    double marketSourceMultiplier = 1.0;
    String? marketSourceAdjustment = '';
    
    if (marketSource != null && marketSource.toLowerCase() == 'sahibinden') {
      marketSourceMultiplier = 0.95; // %5 indirim
      marketSourceAdjustment = 'Sahibinden Satış: -%5';
    } else if (marketSource != null && marketSource.toLowerCase() == 'noter') {
      marketSourceMultiplier = 1.0; // Değişiklik yok
      marketSourceAdjustment = 'Noter Satış: %0';
    }
    
    double finalValue = valueAfterKm * marketSourceMultiplier;
    
    // 7. Paket/Donanım çakışma kontrolü
    final conflictCheck = _checkPackageEquipmentConflict(
      packageLevel: packageLevel,
      selectedOptions: selectedOptions,
    );
    
    // Tüm ayarlamaları birleştir
    List<String> allAdjustments = [];
    
    if (packageMultiplier > 1.0) {
      String packageType = _getPackageTypeLabel(packageWeight);
      allAdjustments.add('$packageType Ağırlığı: +%${((packageMultiplier - 1.0) * 100).toStringAsFixed(0)}%');
    }
    
    allAdjustments.addAll(optionAdjustments);
    
    if (boyaIndirimi > 0) {
      allAdjustments.add('Boya İndirimi: -%${(boyaIndirimi * 100).toStringAsFixed(1)}');
    }
    
    if (hasarIndirimi > 0) {
      allAdjustments.add('Hasar İndirimi: -%${(hasarIndirimi * 100).toStringAsFixed(1)}');
    }
    
    if (kmYasAyarlama != 0) {
      allAdjustments.add('KM/Yaş Dengesi: ${kmYasAyarlama > 0 ? '+' : ''}${(kmYasAyarlama * 100).toStringAsFixed(1)}%');
    }
    
    if (marketSourceAdjustment.isNotEmpty) {
      allAdjustments.add(marketSourceAdjustment);
    }
    
    return {
      'basePrice': basePrice,
      'sportMultiplier': isSport ? 1.2 : 1.0,
      'valueAfterSport': valueAfterSport,
      'optionValue': optionValue,
      'valueAfterOptions': valueAfterOptions,
      'boyaIndirimi': boyaIndirimi,
      'hasarIndirimi': hasarIndirimi,
      'kmYasAyarlama': kmYasAyarlama,
      'marketSourceMultiplier': marketSourceMultiplier,
      'finalValue': finalValue,
      'totalAdjustment': finalValue - basePrice,
      'adjustmentPercentage': ((finalValue - basePrice) / basePrice * 100).toStringAsFixed(2),
      'adjustments': allAdjustments,
      'conflict': conflictCheck,
      'vehicleInfo': {
        'brand': brand,
        'model': model,
        'year': year,
        'km': km,
        'color': color,
        'age': yas,
        'packageLevel': packageLevel,
        'isSportPackage': isSport,
        'selectedOptions': selectedOptionList,
        'paintedParts': paintedParts,
        'damagedParts': damagedParts,
      },
    };
  }

  /// Temel piyasa fiyatını marka/model/yıla göre hesapla
  static double _getBaseMarketPrice(String brand, String model, int year) {
    // Basit algoritma - gerçek hayata API entegrasyonu gerekir
    int currentYear = DateTime.now().year;
    int yas = currentYear - year;
    
    // Marka bazlı çarpanlar
    double brandMultiplier = 1.0;
    switch (brand.toLowerCase()) {
      case 'mercedes-benz':
      case 'bmw':
      case 'audi':
      case 'porsche':
        brandMultiplier = 1.25;
        break;
      case 'volkswagen':
      case 'skoda':
      case 'seat':
        brandMultiplier = 1.15;
        break;
      case 'toyota':
      case 'lexus':
        brandMultiplier = 1.20;
        break;
      default:
        brandMultiplier = 1.10;
    }
    
    // Yıl bazlı baz fiyat (basit formül)
    double basePrice = 500000.0 * brandMultiplier;
    
    // Yaş bazlı amortisman
    double yasIndirimi = yas * 0.05; // Yıla göre %5 düşüş
    basePrice = basePrice * (1.0 - yasIndirimi.clamp(0.0, 0.5));
    
    return basePrice;
  }

  /// Opsiyonel donanım fiyatını hesapla
  static double _getOptionPrice(String option, double basePrice) {
    String optionLower = option.toLowerCase();
    
    // Premium donanımlar - %5-10 arası
    if (optionLower.contains('cam tavan') || optionLower.contains('sunroof') ||
        optionLower.contains('panoramik tavan')) {
      return basePrice * 0.08;
    }
    if (optionLower.contains('head-up display') || optionLower.contains('hud')) {
      return basePrice * 0.06;
    }
    if (optionLower.contains('ısıtmalı koltuk') || optionLower.contains('deri koltuk')) {
      return basePrice * 0.07;
    }
    if (optionLower.contains('vakumlu kapı') || optionLower.contains('soft close')) {
      return basePrice * 0.05;
    }
    if (optionLower.contains('led far') || optionLower.contains('matrix far') ||
        optionLower.contains('laser far') || optionLower.contains('adaptif far')) {
      return basePrice * 0.04;
    }
    if (optionLower.contains('navigasyon') || optionLower.contains('harita') ||
        optionLower.contains('gps')) {
      return basePrice * 0.05;
    }
    
    return basePrice * 0.02; // Standart donanımlar
  }

  /// Hasar indirim oranını hesapla
  static double _calculateHasarIndirimi(List<String> damagedParts) {
    if (damagedParts.isEmpty) return 0.0;
    
    // Hasarlı parça sayısına göre indirim
    double hasarOrani = damagedParts.length * 0.02; // Her parça için %2
    return hasarOrani.clamp(0.0, 0.3); // Maksimum %30
  }

  /// Araç için adil piyasa değerini hesaplar
  /// 
  /// [basePrice] - Araç taban fiyatı
  /// [year] - Araç üretim yılı
  /// [km] - Araç kilometresi
  /// [color] - Araç rengi
  /// [boyaliParcalar] - Boyalı parça listesi
  /// [ekstraOpsiyonlar] - Ekstra donanım listesi
  static double calculateFairValue({
    required double basePrice,
    required int year,
    required int km,
    required String color,
    required List<String> boyaliParcalar,
    required List<String> ekstraOpsiyonlar,
  }) {
    double fairValue = basePrice;
    
    // 1. Parça Katsayıları - Boyalı parçalara göre fiyat düşüşü
    fairValue = _applyBoyaIndirimi(fairValue, boyaliParcalar);
    
    // 2. Donanım Primi - Ekstra donanımlara göre fiyat artışı
    fairValue = _applyDonanimPrimi(fairValue, ekstraOpsiyonlar);
    
    // 3. KM vs Yaş Dengesi - Koleksiyon değeri bonusu
    fairValue = _applyKmYasDengesi(fairValue, year, km);
    
    // 4. Renk Faktörü - Renk bazlı fiyat optimizasyonu
    fairValue = _applyRenkFaktoru(fairValue, color);
    
    return fairValue;
  }
  
  /// Boyalı parçalara göre fiyat düşüşü uygular
  static double _applyBoyaIndirimi(double price, List<String> boyaliParcalar) {
    if (boyaliParcalar.isEmpty) return price;
    
    double toplamIndirimOrani = 0.0;
    
    for (String parca in boyaliParcalar) {
      String parcaLower = parca.toLowerCase();
      
      // Kritik parçalar (Tavan, Direk, Şasi) - %20-30 arası düşüş
      if (parcaLower.contains('tavan') || 
          parcaLower.contains('direk') || 
          parcaLower.contains('şasi')) {
        toplamIndirimOrani += 0.25; // Ortalama %25
      }
      // Orta seviye parçalar (Kaput, Bağaj) - %5-8 arası düşüş
      else if (parcaLower.contains('kaput') || 
                parcaLower.contains('bağaj') || 
                parcaLower.contains('bagaj')) {
        toplamIndirimOrani += 0.065; // Ortalama %6.5
      }
      // Düşük seviye parçalar (Çamurluk, Kapı) - %2-3 arası düşüş
      else if (parcaLower.contains('çamurluk') || 
                parcaLower.contains('kapı') || 
                parcaLower.contains('kapi')) {
        toplamIndirimOrani += 0.025; // Ortalama %2.5
      }
    }
    
    // Maksimum indirim %50 ile sınırla
    toplamIndirimOrani = toplamIndirimOrani.clamp(0.0, 0.5);
    
    return price * (1.0 - toplamIndirimOrani);
  }
  
  /// Ekstra donanımlara göre fiyat artışı uygular
  static double _applyDonanimPrimi(double price, List<String> ekstraOpsiyonlar) {
    if (ekstraOpsiyonlar.isEmpty) return price;
    
    double toplamPrimOrani = 0.0;
    
    for (String opsiyon in ekstraOpsiyonlar) {
      String opsiyonLower = opsiyon.toLowerCase();
      
      // Premium donanımlar - +%5-10 arası prim
      if (opsiyonLower.contains('cam tavan') || 
          opsiyonLower.contains('sunroof') ||
          opsiyonLower.contains('led far') ||
          opsiyonLower.contains('matrix far') ||
          opsiyonLower.contains('laser far') ||
          opsiyonLower.contains('adaptif far') ||
          opsiyonLower.contains('vakumlu kapı') ||
          opsiyonLower.contains('soft close') ||
          opsiyonLower.contains('head-up display') ||
          opsiyonLower.contains('hud') ||
          opsiyonLower.contains('panoramik tavan')) {
        toplamPrimOrani += 0.075; // Ortalama %7.5
      }
      // Orta seviye donanımlar - +%3-5 arası prim
      else if (opsiyonLower.contains('deri koltuk') || 
                opsiyonLower.contains('elektrikli koltuk') ||
                opsiyonLower.contains('ısıtmalı koltuk') ||
                opsiyonLower.contains('ventilasyonlu koltuk') ||
                opsiyonLower.contains('navigasyon') ||
                opsiyonLower.contains('harita') ||
                opsiyonLower.contains('gps')) {
        toplamPrimOrani += 0.04; // Ortalama %4
      }
      // Standart donanımlar - +%1-3 arası prim
      else if (opsiyonLower.contains('bi-xenon far') ||
                  opsiyonLower.contains('xenon') ||
                  opsiyonLower.contains('park sensörü') ||
                  opsiyonLower.contains('geri görüş kamerası') ||
                  opsiyonLower.contains('kamera') ||
                  opsiyonLower.contains('bluetooth') ||
                  opsiyonLower.contains('usb')) {
        toplamPrimOrani += 0.02; // Ortalama %2
      }
    }
    
    // Maksimum prim %20 ile sınırla
    toplamPrimOrani = toplamPrimOrani.clamp(0.0, 0.2);
    
    return price * (1.0 + toplamPrimOrani);
  }
  
  /// KM ve Yaş dengesine göre koleksiyon değeri bonusu uygular
  static double _applyKmYasDengesi(double price, int year, int km) {
    int currentYear = DateTime.now().year;
    int yas = currentYear - year;
    
    if (yas <= 0) return price;
    
    // Yıla göre beklenen ortalama km
    int beklenenYillikKm = 15000; // Türkiye ortalaması
    int beklenenToplamKm = yas * beklenenYillikKm;
    
    double kmYasiOrani = km / beklenenToplamKm;
    
    // Çok düşük km - Koleksiyon değeri bonusu
    if (kmYasiOrani < 0.5) {
      // Yılına göre çok düşük km olan araçlara bonus
      double bonusOrani = (0.5 - kmYasiOrani) * 0.15; // Maksimum %7.5 bonus
      return price * (1.0 + bonusOrani);
    }
    // Çok yüksek km - Fiyat düşüşü
    else if (kmYasiOrani > 1.5) {
      double dususOrani = (kmYasiOrani - 1.5) * 0.1; // Maksimum %10 düşüş
      return price * (1.0 - dususOrani);
    }
    
    return price;
  }
  
  /// Renk faktörüne göre fiyat optimizasyonu uygular
  static double _applyRenkFaktoru(double price, String color) {
    String colorLower = color.toLowerCase();
    
    // Popüler renkler - Satış hızı artışı (fiyat artışı)
    if (colorLower.contains('beyaz') || 
        colorLower.contains('gümüş') || 
        colorLower.contains('gri') ||
        colorLower.contains('silver') ||
        colorLower.contains('gray') ||
        colorLower.contains('siyah') ||
        colorLower.contains('black')) {
      // Popüler renkler daha hızlı satılır, bu da fiyata yansır
      return price * 1.03; // +%3 prim
    }
    // Özel renkler - Hedef kitleye göre optimizasyon
    else if (colorLower.contains('turuncu') || 
             colorLower.contains('kırmızı') ||
             colorLower.contains('mavi') ||
             colorLower.contains('yeşil') ||
             colorLower.contains('sarı') ||
             colorLower.contains('mor') ||
             colorLower.contains('metalik')) {
      // Özel renkler daha dar bir kitleye hitap eder
      return price * 0.97; // -%3 indirim
    }
    
    return price;
  }
  
  /// Detaylı değerleme raporu oluşturur
  static Map<String, dynamic> generateValuationReport({
    required double basePrice,
    required int year,
    required int km,
    required String color,
    required List<String> boyaliParcalar,
    required List<String> ekstraOpsiyonlar,
  }) {
    double fairValue = basePrice;
    List<String> adjustments = [];
    
    // Boya indirimi hesapla
    if (boyaliParcalar.isNotEmpty) {
      double boyaIndirimi = _calculateBoyaIndirimiDetayli(boyaliParcalar);
      double indirimTutari = fairValue * boyaIndirimi;
      fairValue -= indirimTutari;
      adjustments.add('Boyalı Parça İndirimi: -%${(boyaIndirimi * 100).toStringAsFixed(1)} (-${indirimTutari.toStringAsFixed(0)} TL)');
    }
    
    // Donanım primi hesapla
    if (ekstraOpsiyonlar.isNotEmpty) {
      double donanimPrimi = _calculateDonanimPrimiDetayli(ekstraOpsiyonlar);
      double primTutari = fairValue * donanimPrimi;
      fairValue += primTutari;
      adjustments.add('Donanım Primi: +%${(donanimPrimi * 100).toStringAsFixed(1)} (+${primTutari.toStringAsFixed(0)} TL)');
    }
    
    // KM/Yaş dengesi
    int currentYear = DateTime.now().year;
    int yas = currentYear - year;
    if (yas > 0) {
      int beklenenYillikKm = 15000;
      int beklenenToplamKm = yas * beklenenYillikKm;
      double kmYasiOrani = km / beklenenToplamKm;
      
      if (kmYasiOrani < 0.5) {
        double bonusOrani = (0.5 - kmYasiOrani) * 0.15;
        double bonusTutari = fairValue * bonusOrani;
        fairValue += bonusTutari;
        adjustments.add('Koleksiyon Değeri Bonusu: +%${(bonusOrani * 100).toStringAsFixed(1)} (+${bonusTutari.toStringAsFixed(0)} TL)');
      } else if (kmYasiOrani > 1.5) {
        double dususOrani = (kmYasiOrani - 1.5) * 0.1;
        double dususTutari = fairValue * dususOrani;
        fairValue -= dususTutari;
        adjustments.add('Yüksek KM Düşüşü: -%${(dususOrani * 100).toStringAsFixed(1)} (-${dususTutari.toStringAsFixed(0)} TL)');
      }
    }
    
    // Renk faktörü
    String colorLower = color.toLowerCase();
    if (colorLower.contains('beyaz') || 
        colorLower.contains('gümüş') || 
        colorLower.contains('gri') ||
        colorLower.contains('siyah')) {
      double renkPrimi = 0.03;
      double primTutari = fairValue * renkPrimi;
      fairValue += primTutari;
      adjustments.add('Popüler Renk Primi: +%${(renkPrimi * 100).toStringAsFixed(1)} (+${primTutari.toStringAsFixed(0)} TL)');
    } else if (colorLower.contains('turuncu') || 
               colorLower.contains('kırmızı') ||
               colorLower.contains('mavi') ||
               colorLower.contains('yeşil') ||
               colorLower.contains('sarı')) {
      double renkIndirimi = 0.03;
      double indirimTutari = fairValue * renkIndirimi;
      fairValue -= indirimTutari;
      adjustments.add('Özel Renk İndirimi: -%${(renkIndirimi * 100).toStringAsFixed(1)} (-${indirimTutari.toStringAsFixed(0)} TL)');
    }
    
    return {
      'basePrice': basePrice,
      'fairValue': fairValue,
      'totalAdjustment': fairValue - basePrice,
      'adjustmentPercentage': ((fairValue - basePrice) / basePrice * 100).toStringAsFixed(2),
      'adjustments': adjustments,
      'vehicleInfo': {
        'year': year,
        'km': km,
        'color': color,
        'age': currentYear - year,
      },
      'boyaliParcalar': boyaliParcalar,
      'ekstraOpsiyonlar': ekstraOpsiyonlar,
    };
  }
  
  /// Detaylı boya indirim oranı hesaplar
  static double _calculateBoyaIndirimiDetayli(List<String> boyaliParcalar) {
    double toplamIndirimOrani = 0.0;
    
    for (String parca in boyaliParcalar) {
      String parcaLower = parca.toLowerCase();
      
      // Kritik parçalar (Tavan, Direk, Şasi) - %20-30 arası düşüş
      if (parcaLower.contains('tavan') || 
          parcaLower.contains('direk') || 
          parcaLower.contains('şasi')) {
        toplamIndirimOrani += 0.25;
      }
      // Orta seviye parçalar (Kaput, Bağaj) - %5-8 arası düşüş
      else if (parcaLower.contains('kaput') || 
                  parcaLower.contains('bağaj') || 
                  parcaLower.contains('bagaj')) {
        toplamIndirimOrani += 0.065;
      }
      // Düşük seviye parçalar (Çamurluk, Kapı) - %2-3 arası düşüş
      else if (parcaLower.contains('çamurluk') || 
                  parcaLower.contains('kapı') || 
                  parcaLower.contains('kapi')) {
        toplamIndirimOrani += 0.025;
      }
    }
    
    return toplamIndirimOrani.clamp(0.0, 0.5);
  }
  
  /// Detaylı donanım primi oranı hesaplar
  static double _calculateDonanimPrimiDetayli(List<String> ekstraOpsiyonlar) {
    double toplamPrimOrani = 0.0;
    
    for (String opsiyon in ekstraOpsiyonlar) {
      String opsiyonLower = opsiyon.toLowerCase();
      
      // Premium donanımlar - +%5-10 arası prim
      if (opsiyonLower.contains('cam tavan') || 
          opsiyonLower.contains('sunroof') ||
          opsiyonLower.contains('led far') ||
          opsiyonLower.contains('matrix far') ||
          opsiyonLower.contains('laser far') ||
          opsiyonLower.contains('adaptif far') ||
          opsiyonLower.contains('vakumlu kapı') ||
          opsiyonLower.contains('soft close') ||
          opsiyonLower.contains('head-up display') ||
          opsiyonLower.contains('hud') ||
          opsiyonLower.contains('panoramik tavan')) {
        toplamPrimOrani += 0.075;
      }
      // Orta seviye donanımlar - +%3-5 arası prim
      else if (opsiyonLower.contains('deri koltuk') || 
                  opsiyonLower.contains('elektrikli koltuk') ||
                  opsiyonLower.contains('ısıtmalı koltuk') ||
                  opsiyonLower.contains('ventilasyonlu koltuk') ||
                  opsiyonLower.contains('navigasyon') ||
                  opsiyonLower.contains('harita') ||
                  opsiyonLower.contains('gps')) {
        toplamPrimOrani += 0.04;
      }
      // Standart donanımlar - +%1-3 arası prim
      else if (opsiyonLower.contains('bi-xenon far') ||
                  opsiyonLower.contains('xenon') ||
                  opsiyonLower.contains('park sensörü') ||
                  opsiyonLower.contains('geri görüş kamerası') ||
                  opsiyonLower.contains('kamera') ||
                  opsiyonLower.contains('bluetooth') ||
                  opsiyonLower.contains('usb')) {
        toplamPrimOrani += 0.02;
      }
    }
    
    return toplamPrimOrani.clamp(0.0, 0.2);
  }
}
