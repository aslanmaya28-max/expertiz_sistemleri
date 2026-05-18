/// Türkiye Araç Paketleri Veritabanı
/// 
/// Türkiye'de en çok işlem gören 20 markanın son 10 yıla ait
/// spesifik paket isimlerini içeren kapsamlı kütüphane.
/// 
/// Her paket, marka ve modele özgü ağırlık değerine sahiptir.
/// Bu ağırlıklar, MarketRadarService'te hiyerarşik değerleme için kullanılır.
library;

/// Araç Paketi Modeli
class VehiclePackage {
  final String id;
  final String name;
  final double weight; // Paket ağırlığı (1.0 - 2.0 arası)
  final String? description;

  const VehiclePackage({
    required this.id,
    required this.name,
    required this.weight,
    this.description,
  });

  /// JSON'dan paket oluşturur
  factory VehiclePackage.fromJson(Map<String, dynamic> json) {
    return VehiclePackage(
      id: json['id'] as String,
      name: json['name'] as String,
      weight: (json['weight'] as num).toDouble(),
      description: json['description'] as String?,
    );
  }

  /// Paketi JSON'a dönüştürür
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'weight': weight,
      'description': description,
    };
  }
}

/// Araç Modeli ve Paketleri
class VehicleModelPackages {
  final String modelName;
  final List<VehiclePackage> packages;
  final int startYear; // Bu modelin paketlerinin başlangıç yılı
  final int endYear; // Bu modelin paketlerinin bitiş yılı

  const VehicleModelPackages({
    required this.modelName,
    required this.packages,
    required this.startYear,
    required this.endYear,
  });

  /// Belirli bir yıla göre paketleri döndürür
  List<VehiclePackage> getPackagesForYear(int year) {
    if (year < startYear || year > endYear) {
      return [];
    }
    return packages;
  }
}

/// Marka ve Modelleri
class BrandPackages {
  final String brandName;
  final Map<String, VehicleModelPackages> models;

  const BrandPackages({
    required this.brandName,
    required this.models,
  });

  /// Belirli bir model için paketleri döndürür
  List<VehiclePackage> getPackagesForModel(String modelName, int year) {
    final model = models[modelName];
    if (model == null) return [];
    return model.getPackagesForYear(year);
  }

  /// Tüm modellerin isimlerini döndürür
  List<String> getModelNames() {
    return models.keys.toList();
  }
}

/// Türkiye Araç Paketleri Veritabanı
class VehiclePackagesDatabase {
  static const List<BrandPackages> brands = [
    // 1. VOLKSWAGEN
    BrandPackages(
      brandName: 'Volkswagen',
      models: {
        'Golf': VehicleModelPackages(
          modelName: 'Golf',
          packages: [
            VehiclePackage(id: 'vw_golf_trend', name: 'Trendline', weight: 1.0),
            VehiclePackage(id: 'vw_golf_comfort', name: 'Comfortline', weight: 1.15),
            VehiclePackage(id: 'vw_golf_high', name: 'Highline', weight: 1.3),
            VehiclePackage(id: 'vw_golf_rline', name: 'R-Line', weight: 1.4),
            VehiclePackage(id: 'vw_golf_gti', name: 'GTI', weight: 1.6),
            VehiclePackage(id: 'vw_golf_r', name: 'R', weight: 1.8),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'Passat': VehicleModelPackages(
          modelName: 'Passat',
          packages: [
            VehiclePackage(id: 'vw_passat_trend', name: 'Trendline', weight: 1.0),
            VehiclePackage(id: 'vw_passat_comfort', name: 'Comfortline', weight: 1.15),
            VehiclePackage(id: 'vw_passat_elegance', name: 'Elegance', weight: 1.25),
            VehiclePackage(id: 'vw_passat_high', name: 'Highline', weight: 1.3),
            VehiclePackage(id: 'vw_passat_rline', name: 'R-Line', weight: 1.4),
            VehiclePackage(id: 'vw_passat_4motion', name: '4MOTION', weight: 1.5),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'Tiguan': VehicleModelPackages(
          modelName: 'Tiguan',
          packages: [
            VehiclePackage(id: 'vw_tiguan_life', name: 'Life', weight: 1.1),
            VehiclePackage(id: 'vw_tiguan_eline', name: 'Elegance', weight: 1.25),
            VehiclePackage(id: 'vw_tiguan_rline', name: 'R-Line', weight: 1.4),
            VehiclePackage(id: 'vw_tiguan_sport', name: 'Sport', weight: 1.5),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Polo': VehicleModelPackages(
          modelName: 'Polo',
          packages: [
            VehiclePackage(id: 'vw_polo_trend', name: 'Trendline', weight: 1.0),
            VehiclePackage(id: 'vw_polo_comfort', name: 'Comfortline', weight: 1.15),
            VehiclePackage(id: 'vw_polo_high', name: 'Highline', weight: 1.3),
            VehiclePackage(id: 'vw_polo_gti', name: 'GTI', weight: 1.6),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'Jetta': VehicleModelPackages(
          modelName: 'Jetta',
          packages: [
            VehiclePackage(id: 'vw_jetta_trend', name: 'Trendline', weight: 1.0),
            VehiclePackage(id: 'vw_jetta_comfort', name: 'Comfortline', weight: 1.15),
            VehiclePackage(id: 'vw_jetta_high', name: 'Highline', weight: 1.3),
          ],
          startYear: 2018,
          endYear: 2024,
        ),
      },
    ),

    // 2. RENAULT
    BrandPackages(
      brandName: 'Renault',
      models: {
        'Megane': VehicleModelPackages(
          modelName: 'Megane',
          packages: [
            VehiclePackage(id: 'ren_megane_joy', name: 'Joy', weight: 1.0),
            VehiclePackage(id: 'ren_megane_touch', name: 'Touch', weight: 1.15),
            VehiclePackage(id: 'ren_megane_icon', name: 'Icon', weight: 1.3),
            VehiclePackage(id: 'ren_megane_business', name: 'Business', weight: 1.25),
            VehiclePackage(id: 'ren_megane_zen', name: 'Zen', weight: 1.2),
            VehiclePackage(id: 'ren_megane_rsline', name: 'R.S. Line', weight: 1.5),
            VehiclePackage(id: 'ren_megane_gt', name: 'GT', weight: 1.6),
          ],
          startYear: 2016,
          endYear: 2024,
        ),
        'Clio': VehicleModelPackages(
          modelName: 'Clio',
          packages: [
            VehiclePackage(id: 'ren_clio_joy', name: 'Joy', weight: 1.0),
            VehiclePackage(id: 'ren_clio_touch', name: 'Touch', weight: 1.15),
            VehiclePackage(id: 'ren_clio_icon', name: 'Icon', weight: 1.3),
            VehiclePackage(id: 'ren_clio_zen', name: 'Zen', weight: 1.2),
            VehiclePackage(id: 'ren_clio_rst', name: 'R.S.', weight: 1.5),
          ],
          startYear: 2016,
          endYear: 2024,
        ),
        'Fluence': VehicleModelPackages(
          modelName: 'Fluence',
          packages: [
            VehiclePackage(id: 'ren_fluence_auth', name: 'Authentique', weight: 1.0),
            VehiclePackage(id: 'ren_fluence_expr', name: 'Expression', weight: 1.15),
            VehiclePackage(id: 'ren_fluence_priv', name: 'Privilege', weight: 1.3),
          ],
          startYear: 2014,
          endYear: 2020,
        ),
        'Captur': VehicleModelPackages(
          modelName: 'Captur',
          packages: [
            VehiclePackage(id: 'ren_captur_joy', name: 'Joy', weight: 1.0),
            VehiclePackage(id: 'ren_captur_touch', name: 'Touch', weight: 1.15),
            VehiclePackage(id: 'ren_captur_icon', name: 'Icon', weight: 1.3),
            VehiclePackage(id: 'ren_captur_zen', name: 'Zen', weight: 1.2),
            VehiclePackage(id: 'ren_captur_rst', name: 'R.S. Line', weight: 1.5),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Kadjar': VehicleModelPackages(
          modelName: 'Kadjar',
          packages: [
            VehiclePackage(id: 'ren_kadjar_life', name: 'Life', weight: 1.1),
            VehiclePackage(id: 'ren_kadjar_zen', name: 'Zen', weight: 1.25),
            VehiclePackage(id: 'ren_kadjar_business', name: 'Business', weight: 1.3),
            VehiclePackage(id: 'ren_kadjar_rst', name: 'R.S. Line', weight: 1.5),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
      },
    ),

    // 3. FIAT
    BrandPackages(
      brandName: 'Fiat',
      models: {
        'Egea': VehicleModelPackages(
          modelName: 'Egea',
          packages: [
            VehiclePackage(id: 'fia_egea_easy', name: 'Easy', weight: 1.0),
            VehiclePackage(id: 'fia_egea_street', name: 'Street', weight: 1.1),
            VehiclePackage(id: 'fia_egea_lounge', name: 'Lounge', weight: 1.25),
            VehiclePackage(id: 'fia_egea_cross', name: 'Cross', weight: 1.3),
            VehiclePackage(id: 'fia_egea_dolce', name: 'Dolcevita', weight: 1.35),
            VehiclePackage(id: 'fia_egea_sport', name: 'Sport', weight: 1.4),
          ],
          startYear: 2016,
          endYear: 2024,
        ),
        '500': VehicleModelPackages(
          modelName: '500',
          packages: [
            VehiclePackage(id: 'fia_500_pop', name: 'Pop', weight: 1.0),
            VehiclePackage(id: 'fia_500_lounge', name: 'Lounge', weight: 1.2),
            VehiclePackage(id: 'fia_500_sport', name: 'Sport', weight: 1.3),
            VehiclePackage(id: 'fia_500_abyarth', name: 'Abarth', weight: 1.6),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        '500X': VehicleModelPackages(
          modelName: '500X',
          packages: [
            VehiclePackage(id: 'fia_500x_pop', name: 'Pop', weight: 1.0),
            VehiclePackage(id: 'fia_500x_popstar', name: 'Pop Star', weight: 1.15),
            VehiclePackage(id: 'fia_500x_lounge', name: 'Lounge', weight: 1.3),
            VehiclePackage(id: 'fia_500x_cross', name: 'Cross', weight: 1.35),
            VehiclePackage(id: 'fia_500x_sport', name: 'Sport', weight: 1.4),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'Tipo': VehicleModelPackages(
          modelName: 'Tipo',
          packages: [
            VehiclePackage(id: 'fia_tipo_easy', name: 'Easy', weight: 1.0),
            VehiclePackage(id: 'fia_tipo_street', name: 'Street', weight: 1.1),
            VehiclePackage(id: 'fia_tipo_lounge', name: 'Lounge', weight: 1.25),
          ],
          startYear: 2016,
          endYear: 2024,
        ),
        'Doblo': VehicleModelPackages(
          modelName: 'Doblo',
          packages: [
            VehiclePackage(id: 'fia_doblo_easy', name: 'Easy', weight: 1.0),
            VehiclePackage(id: 'fia_doblo_street', name: 'Street', weight: 1.1),
            VehiclePackage(id: 'fia_doblo_lounge', name: 'Lounge', weight: 1.25),
          ],
          startYear: 2016,
          endYear: 2024,
        ),
      },
    ),

    // 4. FORD
    BrandPackages(
      brandName: 'Ford',
      models: {
        'Focus': VehicleModelPackages(
          modelName: 'Focus',
          packages: [
            VehiclePackage(id: 'for_focus_trend', name: 'Trend', weight: 1.0),
            VehiclePackage(id: 'for_focus_titanium', name: 'Titanium', weight: 1.2),
            VehiclePackage(id: 'for_focus_stline', name: 'ST-Line', weight: 1.35),
            VehiclePackage(id: 'for_focus_active', name: 'Active', weight: 1.25),
            VehiclePackage(id: 'for_focus_vignale', name: 'Vignale', weight: 1.45),
            VehiclePackage(id: 'for_focus_st', name: 'ST', weight: 1.6),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'Fiesta': VehicleModelPackages(
          modelName: 'Fiesta',
          packages: [
            VehiclePackage(id: 'for_fiesta_trend', name: 'Trend', weight: 1.0),
            VehiclePackage(id: 'for_fiesta_titanium', name: 'Titanium', weight: 1.2),
            VehiclePackage(id: 'for_fiesta_stline', name: 'ST-Line', weight: 1.35),
            VehiclePackage(id: 'for_fiesta_active', name: 'Active', weight: 1.25),
            VehiclePackage(id: 'for_fiesta_st', name: 'ST', weight: 1.6),
          ],
          startYear: 2015,
          endYear: 2023,
        ),
        'Mondeo': VehicleModelPackages(
          modelName: 'Mondeo',
          packages: [
            VehiclePackage(id: 'for_mondeo_trend', name: 'Trend', weight: 1.0),
            VehiclePackage(id: 'for_mondeo_titanium', name: 'Titanium', weight: 1.2),
            VehiclePackage(id: 'for_mondeo_vignale', name: 'Vignale', weight: 1.45),
          ],
          startYear: 2015,
          endYear: 2022,
        ),
        'Kuga': VehicleModelPackages(
          modelName: 'Kuga',
          packages: [
            VehiclePackage(id: 'for_kuga_trend', name: 'Trend', weight: 1.0),
            VehiclePackage(id: 'for_kuga_titanium', name: 'Titanium', weight: 1.2),
            VehiclePackage(id: 'for_kuga_stline', name: 'ST-Line', weight: 1.35),
            VehiclePackage(id: 'for_kuga_vignale', name: 'Vignale', weight: 1.45),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Ranger': VehicleModelPackages(
          modelName: 'Ranger',
          packages: [
            VehiclePackage(id: 'for_ranger_xl', name: 'XL', weight: 1.0),
            VehiclePackage(id: 'for_ranger_xlt', name: 'XLT', weight: 1.15),
            VehiclePackage(id: 'for_ranger_wildtrak', name: 'Wildtrak', weight: 1.4),
            VehiclePackage(id: 'for_ranger_raptor', name: 'Raptor', weight: 1.7),
          ],
          startYear: 2016,
          endYear: 2024,
        ),
      },
    ),

    // 5. BMW
    BrandPackages(
      brandName: 'BMW',
      models: {
        '1 Serisi': VehicleModelPackages(
          modelName: '1 Serisi',
          packages: [
            VehiclePackage(id: 'bmw_1_116i', name: '116i', weight: 1.0),
            VehiclePackage(id: 'bmw_1_118i', name: '118i', weight: 1.15),
            VehiclePackage(id: 'bmw_1_120i', name: '120i', weight: 1.25),
            VehiclePackage(id: 'bmw_1_m135i', name: 'M135i', weight: 1.6),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        '2 Serisi': VehicleModelPackages(
          modelName: '2 Serisi',
          packages: [
            VehiclePackage(id: 'bmw_2_218i', name: '218i', weight: 1.0),
            VehiclePackage(id: 'bmw_2_220i', name: '220i', weight: 1.15),
            VehiclePackage(id: 'bmw_2_m235i', name: 'M235i', weight: 1.5),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        '3 Serisi': VehicleModelPackages(
          modelName: '3 Serisi',
          packages: [
            VehiclePackage(id: 'bmw_3_318i', name: '318i', weight: 1.0),
            VehiclePackage(id: 'bmw_3_320i', name: '320i', weight: 1.15),
            VehiclePackage(id: 'bmw_3_330i', name: '330i', weight: 1.3),
            VehiclePackage(id: 'bmw_3_m340i', name: 'M340i', weight: 1.6),
            VehiclePackage(id: 'bmw_3_m3', name: 'M3', weight: 1.8),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        '5 Serisi': VehicleModelPackages(
          modelName: '5 Serisi',
          packages: [
            VehiclePackage(id: 'bmw_5_520i', name: '520i', weight: 1.0),
            VehiclePackage(id: 'bmw_5_530i', name: '530i', weight: 1.2),
            VehiclePackage(id: 'bmw_5_540i', name: '540i', weight: 1.35),
            VehiclePackage(id: 'bmw_5_m550i', name: 'M550i', weight: 1.6),
            VehiclePackage(id: 'bmw_5_m5', name: 'M5', weight: 1.9),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'X3': VehicleModelPackages(
          modelName: 'X3',
          packages: [
            VehiclePackage(id: 'bmw_x3_sdrive', name: 'sDrive20i', weight: 1.0),
            VehiclePackage(id: 'bmw_x3_xdrive', name: 'xDrive30i', weight: 1.2),
            VehiclePackage(id: 'bmw_x3_m40i', name: 'M40i', weight: 1.5),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'X5': VehicleModelPackages(
          modelName: 'X5',
          packages: [
            VehiclePackage(id: 'bmw_x5_xdrive', name: 'xDrive40i', weight: 1.1),
            VehiclePackage(id: 'bmw_x5_m50i', name: 'M50i', weight: 1.5),
          ],
          startYear: 2018,
          endYear: 2024,
        ),
      },
    ),

    // 6. MERCEDES-BENZ
    BrandPackages(
      brandName: 'Mercedes-Benz',
      models: {
        'A Serisi': VehicleModelPackages(
          modelName: 'A Serisi',
          packages: [
            VehiclePackage(id: 'mb_a180', name: 'A180', weight: 1.0),
            VehiclePackage(id: 'mb_a200', name: 'A200', weight: 1.1),
            VehiclePackage(id: 'mb_a220', name: 'A220', weight: 1.2),
            VehiclePackage(id: 'mb_a35', name: 'A35 AMG', weight: 1.5),
            VehiclePackage(id: 'mb_a45', name: 'A45 AMG', weight: 1.7),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'C Serisi': VehicleModelPackages(
          modelName: 'C Serisi',
          packages: [
            VehiclePackage(id: 'mb_c180', name: 'C180', weight: 1.0),
            VehiclePackage(id: 'mb_c200', name: 'C200', weight: 1.1),
            VehiclePackage(id: 'mb_c300', name: 'C300', weight: 1.25),
            VehiclePackage(id: 'mb_c43', name: 'C43 AMG', weight: 1.5),
            VehiclePackage(id: 'mb_c63', name: 'C63 AMG', weight: 1.8),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'E Serisi': VehicleModelPackages(
          modelName: 'E Serisi',
          packages: [
            VehiclePackage(id: 'mb_e200', name: 'E200', weight: 1.0),
            VehiclePackage(id: 'mb_e300', name: 'E300', weight: 1.2),
            VehiclePackage(id: 'mb_e350', name: 'E350', weight: 1.35),
            VehiclePackage(id: 'mb_e43', name: 'E43 AMG', weight: 1.5),
            VehiclePackage(id: 'mb_e63', name: 'E63 AMG', weight: 1.8),
          ],
          startYear: 2016,
          endYear: 2024,
        ),
        'S Serisi': VehicleModelPackages(
          modelName: 'S Serisi',
          packages: [
            VehiclePackage(id: 'mb_s350', name: 'S350', weight: 1.1),
            VehiclePackage(id: 'mb_s450', name: 'S450', weight: 1.25),
            VehiclePackage(id: 'mb_s560', name: 'S560', weight: 1.4),
            VehiclePackage(id: 'mb_s63', name: 'S63 AMG', weight: 1.7),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'GLC': VehicleModelPackages(
          modelName: 'GLC',
          packages: [
            VehiclePackage(id: 'mb_glc200', name: 'GLC200', weight: 1.0),
            VehiclePackage(id: 'mb_glc300', name: 'GLC300', weight: 1.2),
            VehiclePackage(id: 'mb_glc43', name: 'GLC43 AMG', weight: 1.5),
            VehiclePackage(id: 'mb_glc63', name: 'GLC63 AMG', weight: 1.7),
          ],
          startYear: 2016,
          endYear: 2024,
        ),
        'GLE': VehicleModelPackages(
          modelName: 'GLE',
          packages: [
            VehiclePackage(id: 'mb_gle300', name: 'GLE300', weight: 1.0),
            VehiclePackage(id: 'mb_gle450', name: 'GLE450', weight: 1.2),
            VehiclePackage(id: 'mb_gle53', name: 'GLE53 AMG', weight: 1.5),
            VehiclePackage(id: 'mb_gle63', name: 'GLE63 AMG', weight: 1.7),
          ],
          startYear: 2019,
          endYear: 2024,
        ),
      },
    ),

    // 7. AUDI
    BrandPackages(
      brandName: 'Audi',
      models: {
        'A1': VehicleModelPackages(
          modelName: 'A1',
          packages: [
            VehiclePackage(id: 'au_a1_30tfsi', name: '30 TFSI', weight: 1.0),
            VehiclePackage(id: 'au_a1_35tfsi', name: '35 TFSI', weight: 1.1),
            VehiclePackage(id: 'au_a1_40tfsi', name: '40 TFSI', weight: 1.2),
            VehiclePackage(id: 'au_a1_sline', name: 'S-Line', weight: 1.3),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'A3': VehicleModelPackages(
          modelName: 'A3',
          packages: [
            VehiclePackage(id: 'au_a3_30tfsi', name: '30 TFSI', weight: 1.0),
            VehiclePackage(id: 'au_a3_35tfsi', name: '35 TFSI', weight: 1.1),
            VehiclePackage(id: 'au_a3_40tfsi', name: '40 TFSI', weight: 1.2),
            VehiclePackage(id: 'au_a3_sline', name: 'S-Line', weight: 1.3),
            VehiclePackage(id: 'au_a3_s3', name: 'S3', weight: 1.6),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'A4': VehicleModelPackages(
          modelName: 'A4',
          packages: [
            VehiclePackage(id: 'au_a4_30tfsi', name: '30 TFSI', weight: 1.0),
            VehiclePackage(id: 'au_a4_35tfsi', name: '35 TFSI', weight: 1.1),
            VehiclePackage(id: 'au_a4_40tfsi', name: '40 TFSI', weight: 1.2),
            VehiclePackage(id: 'au_a4_45tfsi', name: '45 TFSI', weight: 1.35),
            VehiclePackage(id: 'au_a4_sline', name: 'S-Line', weight: 1.3),
            VehiclePackage(id: 'au_a4_s4', name: 'S4', weight: 1.6),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'A5': VehicleModelPackages(
          modelName: 'A5',
          packages: [
            VehiclePackage(id: 'au_a5_40tfsi', name: '40 TFSI', weight: 1.0),
            VehiclePackage(id: 'au_a5_45tfsi', name: '45 TFSI', weight: 1.2),
            VehiclePackage(id: 'au_a5_sline', name: 'S-Line', weight: 1.3),
            VehiclePackage(id: 'au_a5_s5', name: 'S5', weight: 1.6),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'A6': VehicleModelPackages(
          modelName: 'A6',
          packages: [
            VehiclePackage(id: 'au_a6_35tfsi', name: '35 TFSI', weight: 1.0),
            VehiclePackage(id: 'au_a6_40tfsi', name: '40 TFSI', weight: 1.1),
            VehiclePackage(id: 'au_a6_45tfsi', name: '45 TFSI', weight: 1.25),
            VehiclePackage(id: 'au_a6_sline', name: 'S-Line', weight: 1.3),
            VehiclePackage(id: 'au_a6_s6', name: 'S6', weight: 1.6),
          ],
          startYear: 2018,
          endYear: 2024,
        ),
        'Q3': VehicleModelPackages(
          modelName: 'Q3',
          packages: [
            VehiclePackage(id: 'au_q3_30tfsi', name: '30 TFSI', weight: 1.0),
            VehiclePackage(id: 'au_q3_35tfsi', name: '35 TFSI', weight: 1.1),
            VehiclePackage(id: 'au_q3_40tfsi', name: '40 TFSI', weight: 1.2),
            VehiclePackage(id: 'au_q3_sline', name: 'S-Line', weight: 1.3),
            VehiclePackage(id: 'au_q3_rs', name: 'RS Q3', weight: 1.7),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'Q5': VehicleModelPackages(
          modelName: 'Q5',
          packages: [
            VehiclePackage(id: 'au_q5_40tfsi', name: '40 TFSI', weight: 1.0),
            VehiclePackage(id: 'au_q5_45tfsi', name: '45 TFSI', weight: 1.2),
            VehiclePackage(id: 'au_q5_sline', name: 'S-Line', weight: 1.3),
            VehiclePackage(id: 'au_q5_sq5', name: 'SQ5', weight: 1.6),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Q7': VehicleModelPackages(
          modelName: 'Q7',
          packages: [
            VehiclePackage(id: 'au_q7_45tfsi', name: '45 TFSI', weight: 1.0),
            VehiclePackage(id: 'au_q7_55tfsi', name: '55 TFSI', weight: 1.2),
            VehiclePackage(id: 'au_q7_sq7', name: 'SQ7', weight: 1.6),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
      },
    ),

    // 8. TOYOTA
    BrandPackages(
      brandName: 'Toyota',
      models: {
        'Corolla': VehicleModelPackages(
          modelName: 'Corolla',
          packages: [
            VehiclePackage(id: 'toy_corolla_dream', name: 'Dream', weight: 1.0),
            VehiclePackage(id: 'toy_corolla_touch', name: 'Touch', weight: 1.1),
            VehiclePackage(id: 'toy_corolla_flame', name: 'Flame', weight: 1.2),
            VehiclePackage(id: 'toy_corolla_adv', name: 'Advance', weight: 1.35),
            VehiclePackage(id: 'toy_corolla_prem', name: 'Premium', weight: 1.4),
            VehiclePackage(id: 'toy_corolla_gr', name: 'GR Sport', weight: 1.5),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'Camry': VehicleModelPackages(
          modelName: 'Camry',
          packages: [
            VehiclePackage(id: 'toy_camry_25', name: '2.5', weight: 1.0),
            VehiclePackage(id: 'toy_camry_hybrid', name: 'Hybrid', weight: 1.2),
          ],
          startYear: 2019,
          endYear: 2024,
        ),
        'RAV4': VehicleModelPackages(
          modelName: 'RAV4',
          packages: [
            VehiclePackage(id: 'toy_rav4_25', name: '2.5', weight: 1.0),
            VehiclePackage(id: 'toy_rav4_hybrid', name: 'Hybrid', weight: 1.2),
            VehiclePackage(id: 'toy_rav4_adv', name: 'Adventure', weight: 1.3),
          ],
          startYear: 2019,
          endYear: 2024,
        ),
        'C-HR': VehicleModelPackages(
          modelName: 'C-HR',
          packages: [
            VehiclePackage(id: 'toy_chr_dream', name: 'Dream', weight: 1.0),
            VehiclePackage(id: 'toy_chr_adv', name: 'Advance', weight: 1.25),
            VehiclePackage(id: 'toy_chr_gr', name: 'GR Sport', weight: 1.4),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Yaris': VehicleModelPackages(
          modelName: 'Yaris',
          packages: [
            VehiclePackage(id: 'toy_yaris_joy', name: 'Joy', weight: 1.0),
            VehiclePackage(id: 'toy_yaris_flame', name: 'Flame', weight: 1.15),
            VehiclePackage(id: 'toy_yaris_gr', name: 'GR Yaris', weight: 1.6),
          ],
          startYear: 2020,
          endYear: 2024,
        ),
        'Auris': VehicleModelPackages(
          modelName: 'Auris',
          packages: [
            VehiclePackage(id: 'toy_auris_touch', name: 'Touch', weight: 1.0),
            VehiclePackage(id: 'toy_auris_flame', name: 'Flame', weight: 1.15),
            VehiclePackage(id: 'toy_auris_prem', name: 'Premium', weight: 1.3),
          ],
          startYear: 2015,
          endYear: 2020,
        ),
      },
    ),

    // 9. HYUNDAI
    BrandPackages(
      brandName: 'Hyundai',
      models: {
        'i20': VehicleModelPackages(
          modelName: 'i20',
          packages: [
            VehiclePackage(id: 'hyu_i20_imotion', name: 'iMotion', weight: 1.0),
            VehiclePackage(id: 'hyu_i20_istyle', name: 'iStyle', weight: 1.15),
            VehiclePackage(id: 'hyu_i20_iselect', name: 'iSelect', weight: 1.25),
            VehiclePackage(id: 'hyu_i20_nline', name: 'N Line', weight: 1.4),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'i30': VehicleModelPackages(
          modelName: 'i30',
          packages: [
            VehiclePackage(id: 'hyu_i30_imotion', name: 'iMotion', weight: 1.0),
            VehiclePackage(id: 'hyu_i30_istyle', name: 'iStyle', weight: 1.15),
            VehiclePackage(id: 'hyu_i30_iselect', name: 'iSelect', weight: 1.25),
            VehiclePackage(id: 'hyu_i30_nline', name: 'N Line', weight: 1.4),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Elantra': VehicleModelPackages(
          modelName: 'Elantra',
          packages: [
            VehiclePackage(id: 'hyu_elantra_ess', name: 'Essential', weight: 1.0),
            VehiclePackage(id: 'hyu_elantra_adv', name: 'Advance', weight: 1.2),
            VehiclePackage(id: 'hyu_elantra_prem', name: 'Premium', weight: 1.35),
            VehiclePackage(id: 'hyu_elantra_nline', name: 'N Line', weight: 1.45),
          ],
          startYear: 2016,
          endYear: 2024,
        ),
        'Tucson': VehicleModelPackages(
          modelName: 'Tucson',
          packages: [
            VehiclePackage(id: 'hyu_tucson_go', name: 'Go', weight: 1.0),
            VehiclePackage(id: 'hyu_tucson_live', name: 'Live', weight: 1.15),
            VehiclePackage(id: 'hyu_tucson_adv', name: 'Advance', weight: 1.3),
            VehiclePackage(id: 'hyu_tucson_nline', name: 'N Line', weight: 1.45),
          ],
          startYear: 2021,
          endYear: 2024,
        ),
        'Santa Fe': VehicleModelPackages(
          modelName: 'Santa Fe',
          packages: [
            VehiclePackage(id: 'hyu_santafe_go', name: 'Go', weight: 1.0),
            VehiclePackage(id: 'hyu_santafe_live', name: 'Live', weight: 1.15),
            VehiclePackage(id: 'hyu_santafe_adv', name: 'Advance', weight: 1.3),
            VehiclePackage(id: 'hyu_santafe_prem', name: 'Premium', weight: 1.4),
          ],
          startYear: 2018,
          endYear: 2024,
        ),
      },
    ),

    // 10. HONDA
    BrandPackages(
      brandName: 'Honda',
      models: {
        'Civic': VehicleModelPackages(
          modelName: 'Civic',
          packages: [
            VehiclePackage(id: 'hon_civic_eleg', name: 'Elegance', weight: 1.0),
            VehiclePackage(id: 'hon_civic_sport', name: 'Sport', weight: 1.2),
            VehiclePackage(id: 'hon_civic_adv', name: 'Advance', weight: 1.3),
            VehiclePackage(id: 'hon_civic_type_r', name: 'Type R', weight: 1.7),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Accord': VehicleModelPackages(
          modelName: 'Accord',
          packages: [
            VehiclePackage(id: 'hon_accord_eleg', name: 'Elegance', weight: 1.0),
            VehiclePackage(id: 'hon_accord_sport', name: 'Sport', weight: 1.2),
            VehiclePackage(id: 'hon_accord_adv', name: 'Advance', weight: 1.3),
          ],
          startYear: 2015,
          endYear: 2022,
        ),
        'CR-V': VehicleModelPackages(
          modelName: 'CR-V',
          packages: [
            VehiclePackage(id: 'hon_crv_eleg', name: 'Elegance', weight: 1.0),
            VehiclePackage(id: 'hon_crv_sport', name: 'Sport', weight: 1.2),
            VehiclePackage(id: 'hon_crv_adv', name: 'Advance', weight: 1.3),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'HR-V': VehicleModelPackages(
          modelName: 'HR-V',
          packages: [
            VehiclePackage(id: 'hon_hrv_eleg', name: 'Elegance', weight: 1.0),
            VehiclePackage(id: 'hon_hrv_sport', name: 'Sport', weight: 1.2),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'Jazz': VehicleModelPackages(
          modelName: 'Jazz',
          packages: [
            VehiclePackage(id: 'hon_jazz_comf', name: 'Comfort', weight: 1.0),
            VehiclePackage(id: 'hon_jazz_eleg', name: 'Elegance', weight: 1.15),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
      },
    ),

    // 11. PEUGEOT
    BrandPackages(
      brandName: 'Peugeot',
      models: {
        '208': VehicleModelPackages(
          modelName: '208',
          packages: [
            VehiclePackage(id: 'peu_208_acc', name: 'Access', weight: 1.0),
            VehiclePackage(id: 'peu_208_act', name: 'Active', weight: 1.1),
            VehiclePackage(id: 'peu_208_all', name: 'Allure', weight: 1.25),
            VehiclePackage(id: 'peu_208_gt', name: 'GT Line', weight: 1.4),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        '308': VehicleModelPackages(
          modelName: '308',
          packages: [
            VehiclePackage(id: 'peu_308_acc', name: 'Access', weight: 1.0),
            VehiclePackage(id: 'peu_308_act', name: 'Active', weight: 1.1),
            VehiclePackage(id: 'peu_308_all', name: 'Allure', weight: 1.25),
            VehiclePackage(id: 'peu_308_gt', name: 'GT Line', weight: 1.4),
            VehiclePackage(id: 'peu_308_gt', name: 'GT', weight: 1.5),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        '508': VehicleModelPackages(
          modelName: '508',
          packages: [
            VehiclePackage(id: 'peu_508_act', name: 'Active', weight: 1.0),
            VehiclePackage(id: 'peu_508_all', name: 'Allure', weight: 1.2),
            VehiclePackage(id: 'peu_508_gt', name: 'GT Line', weight: 1.4),
            VehiclePackage(id: 'peu_508_gt', name: 'GT', weight: 1.5),
          ],
          startYear: 2018,
          endYear: 2024,
        ),
        '2008': VehicleModelPackages(
          modelName: '2008',
          packages: [
            VehiclePackage(id: 'peu_2008_act', name: 'Active', weight: 1.0),
            VehiclePackage(id: 'peu_2008_all', name: 'Allure', weight: 1.2),
            VehiclePackage(id: 'peu_2008_gt', name: 'GT Line', weight: 1.4),
          ],
          startYear: 2020,
          endYear: 2024,
        ),
        '3008': VehicleModelPackages(
          modelName: '3008',
          packages: [
            VehiclePackage(id: 'peu_3008_act', name: 'Active', weight: 1.0),
            VehiclePackage(id: 'peu_3008_all', name: 'Allure', weight: 1.2),
            VehiclePackage(id: 'peu_3008_gt', name: 'GT Line', weight: 1.4),
            VehiclePackage(id: 'peu_3008_gt', name: 'GT', weight: 1.5),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
      },
    ),

    // 12. OPEL
    BrandPackages(
      brandName: 'Opel',
      models: {
        'Astra': VehicleModelPackages(
          modelName: 'Astra',
          packages: [
            VehiclePackage(id: 'ope_astra_ed', name: 'Essential', weight: 1.0),
            VehiclePackage(id: 'ope_astra_eco', name: 'Eco', weight: 1.1),
            VehiclePackage(id: 'ope_astra_sport', name: 'Sport', weight: 1.25),
            VehiclePackage(id: 'ope_astra_ult', name: 'Ultimate', weight: 1.4),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'Corsa': VehicleModelPackages(
          modelName: 'Corsa',
          packages: [
            VehiclePackage(id: 'ope_corsa_ed', name: 'Essential', weight: 1.0),
            VehiclePackage(id: 'ope_corsa_eco', name: 'Eco', weight: 1.1),
            VehiclePackage(id: 'ope_corsa_sport', name: 'Sport', weight: 1.25),
            VehiclePackage(id: 'ope_corsa_ult', name: 'Ultimate', weight: 1.4),
            VehiclePackage(id: 'ope_corsa_gsi', name: 'GSi', weight: 1.5),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'Insignia': VehicleModelPackages(
          modelName: 'Insignia',
          packages: [
            VehiclePackage(id: 'ope_insi_ed', name: 'Essential', weight: 1.0),
            VehiclePackage(id: 'ope_insi_eco', name: 'Eco', weight: 1.1),
            VehiclePackage(id: 'ope_insi_sport', name: 'Sport', weight: 1.25),
            VehiclePackage(id: 'ope_insi_ult', name: 'Ultimate', weight: 1.4),
          ],
          startYear: 2017,
          endYear: 2023,
        ),
        'Mokka': VehicleModelPackages(
          modelName: 'Mokka',
          packages: [
            VehiclePackage(id: 'ope_mokka_ed', name: 'Essential', weight: 1.0),
            VehiclePackage(id: 'ope_mokka_eco', name: 'Eco', weight: 1.1),
            VehiclePackage(id: 'ope_mokka_sport', name: 'Sport', weight: 1.25),
            VehiclePackage(id: 'ope_mokka_ult', name: 'Ultimate', weight: 1.4),
          ],
          startYear: 2021,
          endYear: 2024,
        ),
        'Grandland': VehicleModelPackages(
          modelName: 'Grandland',
          packages: [
            VehiclePackage(id: 'ope_grand_ed', name: 'Essential', weight: 1.0),
            VehiclePackage(id: 'ope_grand_eco', name: 'Eco', weight: 1.1),
            VehiclePackage(id: 'ope_grand_sport', name: 'Sport', weight: 1.25),
            VehiclePackage(id: 'ope_grand_ult', name: 'Ultimate', weight: 1.4),
          ],
          startYear: 2018,
          endYear: 2024,
        ),
      },
    ),

    // 13. NISSAN
    BrandPackages(
      brandName: 'Nissan',
      models: {
        'Qashqai': VehicleModelPackages(
          modelName: 'Qashqai',
          packages: [
            VehiclePackage(id: 'nis_qash_vis', name: 'Visia', weight: 1.0),
            VehiclePackage(id: 'nis_qash_acen', name: 'Acenta', weight: 1.1),
            VehiclePackage(id: 'nis_qash_ncon', name: 'N-Connecta', weight: 1.2),
            VehiclePackage(id: 'nis_qash_tek', name: 'Tekna', weight: 1.3),
            VehiclePackage(id: 'nis_qash_npl', name: 'N-Sport', weight: 1.4),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Juke': VehicleModelPackages(
          modelName: 'Juke',
          packages: [
            VehiclePackage(id: 'nis_juke_vis', name: 'Visia', weight: 1.0),
            VehiclePackage(id: 'nis_juke_acen', name: 'Acenta', weight: 1.1),
            VehiclePackage(id: 'nis_juke_ncon', name: 'N-Connecta', weight: 1.2),
            VehiclePackage(id: 'nis_juke_tek', name: 'Tekna', weight: 1.3),
            VehiclePackage(id: 'nis_juke_npl', name: 'N-Sport', weight: 1.4),
          ],
          startYear: 2020,
          endYear: 2024,
        ),
        'X-Trail': VehicleModelPackages(
          modelName: 'X-Trail',
          packages: [
            VehiclePackage(id: 'nis_xtrail_acen', name: 'Acenta', weight: 1.0),
            VehiclePackage(id: 'nis_xtrail_ncon', name: 'N-Connecta', weight: 1.15),
            VehiclePackage(id: 'nis_xtrail_tek', name: 'Tekna', weight: 1.25),
            VehiclePackage(id: 'nis_xtrail_npl', name: 'N-Sport', weight: 1.4),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Micra': VehicleModelPackages(
          modelName: 'Micra',
          packages: [
            VehiclePackage(id: 'nis_micra_vis', name: 'Visia', weight: 1.0),
            VehiclePackage(id: 'nis_micra_acen', name: 'Acenta', weight: 1.1),
            VehiclePackage(id: 'nis_micra_ncon', name: 'N-Connecta', weight: 1.2),
            VehiclePackage(id: 'nis_micra_npl', name: 'N-Sport', weight: 1.3),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Leaf': VehicleModelPackages(
          modelName: 'Leaf',
          packages: [
            VehiclePackage(id: 'nis_leaf_acen', name: 'Acenta', weight: 1.0),
            VehiclePackage(id: 'nis_leaf_ncon', name: 'N-Connecta', weight: 1.15),
            VehiclePackage(id: 'nis_leaf_tek', name: 'Tekna', weight: 1.25),
          ],
          startYear: 2018,
          endYear: 2024,
        ),
      },
    ),

    // 14. SKODA
    BrandPackages(
      brandName: 'Skoda',
      models: {
        'Octavia': VehicleModelPackages(
          modelName: 'Octavia',
          packages: [
            VehiclePackage(id: 'sko_oct_amb', name: 'Ambiente', weight: 1.0),
            VehiclePackage(id: 'sko_oct_com', name: 'Comfort', weight: 1.15),
            VehiclePackage(id: 'sko_oct_sport', name: 'Sport', weight: 1.3),
            VehiclePackage(id: 'sko_oct_style', name: 'Style', weight: 1.25),
            VehiclePackage(id: 'sko_oct_lk', name: 'L&K', weight: 1.4),
            VehiclePackage(id: 'sko_oct_rs', name: 'RS', weight: 1.6),
          ],
          startYear: 2016,
          endYear: 2024,
        ),
        'Fabia': VehicleModelPackages(
          modelName: 'Fabia',
          packages: [
            VehiclePackage(id: 'sko_fab_amb', name: 'Ambiente', weight: 1.0),
            VehiclePackage(id: 'sko_fab_com', name: 'Comfort', weight: 1.15),
            VehiclePackage(id: 'sko_fab_sport', name: 'Sport', weight: 1.3),
            VehiclePackage(id: 'sko_fab_style', name: 'Style', weight: 1.25),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'Superb': VehicleModelPackages(
          modelName: 'Superb',
          packages: [
            VehiclePackage(id: 'sko_sup_amb', name: 'Ambiente', weight: 1.0),
            VehiclePackage(id: 'sko_sup_com', name: 'Comfort', weight: 1.15),
            VehiclePackage(id: 'sko_sup_sport', name: 'Sport', weight: 1.3),
            VehiclePackage(id: 'sko_sup_style', name: 'Style', weight: 1.25),
            VehiclePackage(id: 'sko_sup_lk', name: 'L&K', weight: 1.4),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'Kodiaq': VehicleModelPackages(
          modelName: 'Kodiaq',
          packages: [
            VehiclePackage(id: 'sko_kod_amb', name: 'Ambiente', weight: 1.0),
            VehiclePackage(id: 'sko_kod_com', name: 'Comfort', weight: 1.15),
            VehiclePackage(id: 'sko_kod_sport', name: 'Sport', weight: 1.3),
            VehiclePackage(id: 'sko_kod_style', name: 'Style', weight: 1.25),
            VehiclePackage(id: 'sko_kod_lk', name: 'L&K', weight: 1.4),
            VehiclePackage(id: 'sko_kod_rs', name: 'RS', weight: 1.6),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Karoq': VehicleModelPackages(
          modelName: 'Karoq',
          packages: [
            VehiclePackage(id: 'sko_kar_amb', name: 'Ambiente', weight: 1.0),
            VehiclePackage(id: 'sko_kar_com', name: 'Comfort', weight: 1.15),
            VehiclePackage(id: 'sko_kar_sport', name: 'Sport', weight: 1.3),
            VehiclePackage(id: 'sko_kar_style', name: 'Style', weight: 1.25),
          ],
          startYear: 2018,
          endYear: 2024,
        ),
      },
    ),

    // 15. SEAT
    BrandPackages(
      brandName: 'Seat',
      models: {
        'Ibiza': VehicleModelPackages(
          modelName: 'Ibiza',
          packages: [
            VehiclePackage(id: 'sea_ibi_ref', name: 'Reference', weight: 1.0),
            VehiclePackage(id: 'sea_ibi_sty', name: 'Style', weight: 1.15),
            VehiclePackage(id: 'sea_ibi_fri', name: 'FR', weight: 1.35),
            VehiclePackage(id: 'sea_ibi_xcl', name: 'Xcellence', weight: 1.25),
            VehiclePackage(id: 'sea_ibi_cup', name: 'Cupra', weight: 1.5),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Leon': VehicleModelPackages(
          modelName: 'Leon',
          packages: [
            VehiclePackage(id: 'sea_leo_ref', name: 'Reference', weight: 1.0),
            VehiclePackage(id: 'sea_leo_sty', name: 'Style', weight: 1.15),
            VehiclePackage(id: 'sea_leo_fri', name: 'FR', weight: 1.35),
            VehiclePackage(id: 'sea_leo_xcl', name: 'Xcellence', weight: 1.25),
            VehiclePackage(id: 'sea_leo_cup', name: 'Cupra', weight: 1.5),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Arona': VehicleModelPackages(
          modelName: 'Arona',
          packages: [
            VehiclePackage(id: 'sea_aro_ref', name: 'Reference', weight: 1.0),
            VehiclePackage(id: 'sea_aro_sty', name: 'Style', weight: 1.15),
            VehiclePackage(id: 'sea_aro_fri', name: 'FR', weight: 1.35),
            VehiclePackage(id: 'sea_aro_xcl', name: 'Xcellence', weight: 1.25),
          ],
          startYear: 2018,
          endYear: 2024,
        ),
        'Ateca': VehicleModelPackages(
          modelName: 'Ateca',
          packages: [
            VehiclePackage(id: 'sea_ate_ref', name: 'Reference', weight: 1.0),
            VehiclePackage(id: 'sea_ate_sty', name: 'Style', weight: 1.15),
            VehiclePackage(id: 'sea_ate_fri', name: 'FR', weight: 1.35),
            VehiclePackage(id: 'sea_ate_xcl', name: 'Xcellence', weight: 1.25),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Tarraco': VehicleModelPackages(
          modelName: 'Tarraco',
          packages: [
            VehiclePackage(id: 'sea_tar_ref', name: 'Reference', weight: 1.0),
            VehiclePackage(id: 'sea_tar_sty', name: 'Style', weight: 1.15),
            VehiclePackage(id: 'sea_tar_fri', name: 'FR', weight: 1.35),
            VehiclePackage(id: 'sea_tar_xcl', name: 'Xcellence', weight: 1.25),
          ],
          startYear: 2018,
          endYear: 2024,
        ),
      },
    ),

    // 16. DACIA
    BrandPackages(
      brandName: 'Dacia',
      models: {
        'Sandero': VehicleModelPackages(
          modelName: 'Sandero',
          packages: [
            VehiclePackage(id: 'dac_san_acc', name: 'Access', weight: 1.0),
            VehiclePackage(id: 'dac_san_ess', name: 'Essential', weight: 1.1),
            VehiclePackage(id: 'dac_san_comf', name: 'Comfort', weight: 1.2),
            VehiclePackage(id: 'dac_san_prest', name: 'Prestige', weight: 1.3),
            VehiclePackage(id: 'dac_san_step', name: 'Stepway', weight: 1.25),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Duster': VehicleModelPackages(
          modelName: 'Duster',
          packages: [
            VehiclePackage(id: 'dac_dus_acc', name: 'Access', weight: 1.0),
            VehiclePackage(id: 'dac_dus_ess', name: 'Essential', weight: 1.1),
            VehiclePackage(id: 'dac_dus_comf', name: 'Comfort', weight: 1.2),
            VehiclePackage(id: 'dac_dus_prest', name: 'Prestige', weight: 1.3),
          ],
          startYear: 2018,
          endYear: 2024,
        ),
        'Logan': VehicleModelPackages(
          modelName: 'Logan',
          packages: [
            VehiclePackage(id: 'dac_log_acc', name: 'Access', weight: 1.0),
            VehiclePackage(id: 'dac_log_ess', name: 'Essential', weight: 1.1),
            VehiclePackage(id: 'dac_log_comf', name: 'Comfort', weight: 1.2),
            VehiclePackage(id: 'dac_log_prest', name: 'Prestige', weight: 1.3),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Lodgy': VehicleModelPackages(
          modelName: 'Lodgy',
          packages: [
            VehiclePackage(id: 'dac_lod_acc', name: 'Access', weight: 1.0),
            VehiclePackage(id: 'dac_lod_ess', name: 'Essential', weight: 1.1),
            VehiclePackage(id: 'dac_lod_comf', name: 'Comfort', weight: 1.2),
            VehiclePackage(id: 'dac_lod_step', name: 'Stepway', weight: 1.25),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
      },
    ),

    // 17. KIA
    BrandPackages(
      brandName: 'Kia',
      models: {
        'Rio': VehicleModelPackages(
          modelName: 'Rio',
          packages: [
            VehiclePackage(id: 'kia_rio_lx', name: 'LX', weight: 1.0),
            VehiclePackage(id: 'kia_rio_ex', name: 'EX', weight: 1.15),
            VehiclePackage(id: 'kia_rio_sx', name: 'SX', weight: 1.3),
            VehiclePackage(id: 'kia_rio_gt', name: 'GT-Line', weight: 1.4),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'Ceed': VehicleModelPackages(
          modelName: 'Ceed',
          packages: [
            VehiclePackage(id: 'kia_ceed_lx', name: 'LX', weight: 1.0),
            VehiclePackage(id: 'kia_ceed_ex', name: 'EX', weight: 1.15),
            VehiclePackage(id: 'kia_ceed_sx', name: 'SX', weight: 1.3),
            VehiclePackage(id: 'kia_ceed_gt', name: 'GT-Line', weight: 1.4),
            VehiclePackage(id: 'kia_ceed_gt', name: 'GT', weight: 1.5),
          ],
          startYear: 2018,
          endYear: 2024,
        ),
        'Cerato': VehicleModelPackages(
          modelName: 'Cerato',
          packages: [
            VehiclePackage(id: 'kia_cer_lx', name: 'LX', weight: 1.0),
            VehiclePackage(id: 'kia_cer_ex', name: 'EX', weight: 1.15),
            VehiclePackage(id: 'kia_cer_sx', name: 'SX', weight: 1.3),
            VehiclePackage(id: 'kia_cer_gt', name: 'GT-Line', weight: 1.4),
          ],
          startYear: 2019,
          endYear: 2024,
        ),
        'Sportage': VehicleModelPackages(
          modelName: 'Sportage',
          packages: [
            VehiclePackage(id: 'kia_spo_lx', name: 'LX', weight: 1.0),
            VehiclePackage(id: 'kia_spo_ex', name: 'EX', weight: 1.15),
            VehiclePackage(id: 'kia_spo_sx', name: 'SX', weight: 1.3),
            VehiclePackage(id: 'kia_spo_gt', name: 'GT-Line', weight: 1.4),
          ],
          startYear: 2016,
          endYear: 2024,
        ),
        'Sorento': VehicleModelPackages(
          modelName: 'Sorento',
          packages: [
            VehiclePackage(id: 'kia_sor_lx', name: 'LX', weight: 1.0),
            VehiclePackage(id: 'kia_sor_ex', name: 'EX', weight: 1.15),
            VehiclePackage(id: 'kia_sor_sx', name: 'SX', weight: 1.3),
            VehiclePackage(id: 'kia_sor_gt', name: 'GT-Line', weight: 1.4),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
      },
    ),

    // 18. CITROEN
    BrandPackages(
      brandName: 'Citroen',
      models: {
        'C3': VehicleModelPackages(
          modelName: 'C3',
          packages: [
            VehiclePackage(id: 'cit_c3_live', name: 'Live', weight: 1.0),
            VehiclePackage(id: 'cit_c3_feel', name: 'Feel', weight: 1.15),
            VehiclePackage(id: 'cit_c3_shine', name: 'Shine', weight: 1.3),
          ],
          startYear: 2016,
          endYear: 2024,
        ),
        'C4': VehicleModelPackages(
          modelName: 'C4',
          packages: [
            VehiclePackage(id: 'cit_c4_live', name: 'Live', weight: 1.0),
            VehiclePackage(id: 'cit_c4_feel', name: 'Feel', weight: 1.15),
            VehiclePackage(id: 'cit_c4_shine', name: 'Shine', weight: 1.3),
          ],
          startYear: 2021,
          endYear: 2024,
        ),
        'C5': VehicleModelPackages(
          modelName: 'C5',
          packages: [
            VehiclePackage(id: 'cit_c5_feel', name: 'Feel', weight: 1.0),
            VehiclePackage(id: 'cit_c5_shine', name: 'Shine', weight: 1.15),
            VehiclePackage(id: 'cit_c5_shinep', name: 'Shine Plus', weight: 1.25),
          ],
          startYear: 2015,
          endYear: 2022,
        ),
        'C3 Aircross': VehicleModelPackages(
          modelName: 'C3 Aircross',
          packages: [
            VehiclePackage(id: 'cit_c3a_live', name: 'Live', weight: 1.0),
            VehiclePackage(id: 'cit_c3a_feel', name: 'Feel', weight: 1.15),
            VehiclePackage(id: 'cit_c3a_shine', name: 'Shine', weight: 1.3),
          ],
          startYear: 2018,
          endYear: 2024,
        ),
        'C5 Aircross': VehicleModelPackages(
          modelName: 'C5 Aircross',
          packages: [
            VehiclePackage(id: 'cit_c5a_feel', name: 'Feel', weight: 1.0),
            VehiclePackage(id: 'cit_c5a_shine', name: 'Shine', weight: 1.15),
            VehiclePackage(id: 'cit_c5a_shinep', name: 'Shine Plus', weight: 1.25),
          ],
          startYear: 2018,
          endYear: 2024,
        ),
      },
    ),

    // 19. VOLVO
    BrandPackages(
      brandName: 'Volvo',
      models: {
        'XC40': VehicleModelPackages(
          modelName: 'XC40',
          packages: [
            VehiclePackage(id: 'vol_xc40_mom', name: 'Momentum', weight: 1.0),
            VehiclePackage(id: 'vol_xc40_insc', name: 'Inscription', weight: 1.2),
            VehiclePackage(id: 'vol_xc40_rdes', name: 'R-Design', weight: 1.35),
            VehiclePackage(id: 'vol_xc40_ppro', name: 'Pro', weight: 1.4),
          ],
          startYear: 2018,
          endYear: 2024,
        ),
        'XC60': VehicleModelPackages(
          modelName: 'XC60',
          packages: [
            VehiclePackage(id: 'vol_xc60_mom', name: 'Momentum', weight: 1.0),
            VehiclePackage(id: 'vol_xc60_insc', name: 'Inscription', weight: 1.2),
            VehiclePackage(id: 'vol_xc60_rdes', name: 'R-Design', weight: 1.35),
            VehiclePackage(id: 'vol_xc60_ppro', name: 'Pro', weight: 1.4),
          ],
          startYear: 2017,
          endYear: 2024,
        ),
        'XC90': VehicleModelPackages(
          modelName: 'XC90',
          packages: [
            VehiclePackage(id: 'vol_xc90_mom', name: 'Momentum', weight: 1.0),
            VehiclePackage(id: 'vol_xc90_insc', name: 'Inscription', weight: 1.2),
            VehiclePackage(id: 'vol_xc90_rdes', name: 'R-Design', weight: 1.35),
            VehiclePackage(id: 'vol_xc90_ppro', name: 'Pro', weight: 1.4),
          ],
          startYear: 2015,
          endYear: 2024,
        ),
        'S60': VehicleModelPackages(
          modelName: 'S60',
          packages: [
            VehiclePackage(id: 'vol_s60_mom', name: 'Momentum', weight: 1.0),
            VehiclePackage(id: 'vol_s60_insc', name: 'Inscription', weight: 1.2),
            VehiclePackage(id: 'vol_s60_rdes', name: 'R-Design', weight: 1.35),
          ],
          startYear: 2019,
          endYear: 2024,
        ),
        'V60': VehicleModelPackages(
          modelName: 'V60',
          packages: [
            VehiclePackage(id: 'vol_v60_mom', name: 'Momentum', weight: 1.0),
            VehiclePackage(id: 'vol_v60_insc', name: 'Inscription', weight: 1.2),
            VehiclePackage(id: 'vol_v60_rdes', name: 'R-Design', weight: 1.35),
          ],
          startYear: 2019,
          endYear: 2024,
        ),
      },
    ),

    // 20. TESLA
    BrandPackages(
      brandName: 'Tesla',
      models: {
        'Model 3': VehicleModelPackages(
          modelName: 'Model 3',
          packages: [
            VehiclePackage(id: 'tes_m3_std', name: 'Standard Range', weight: 1.0),
            VehiclePackage(id: 'tes_m3_lrd', name: 'Long Range', weight: 1.3),
            VehiclePackage(id: 'tes_m3_perf', name: 'Performance', weight: 1.5),
          ],
          startYear: 2019,
          endYear: 2024,
        ),
        'Model Y': VehicleModelPackages(
          modelName: 'Model Y',
          packages: [
            VehiclePackage(id: 'tes_my_std', name: 'Standard Range', weight: 1.0),
            VehiclePackage(id: 'tes_my_lrd', name: 'Long Range', weight: 1.3),
            VehiclePackage(id: 'tes_my_perf', name: 'Performance', weight: 1.5),
          ],
          startYear: 2020,
          endYear: 2024,
        ),
        'Model S': VehicleModelPackages(
          modelName: 'Model S',
          packages: [
            VehiclePackage(id: 'tes_ms_lrd', name: 'Long Range', weight: 1.2),
            VehiclePackage(id: 'tes_ms_plaid', name: 'Plaid', weight: 1.6),
          ],
          startYear: 2016,
          endYear: 2024,
        ),
        'Model X': VehicleModelPackages(
          modelName: 'Model X',
          packages: [
            VehiclePackage(id: 'tes_mx_lrd', name: 'Long Range', weight: 1.2),
            VehiclePackage(id: 'tes_mx_plaid', name: 'Plaid', weight: 1.6),
          ],
          startYear: 2016,
          endYear: 2024,
        ),
      },
    ),
  ];

  /// Belirli bir marka için paketleri döndürür
  static BrandPackages? getBrand(String brandName) {
    try {
      return brands.firstWhere(
        (brand) => brand.brandName.toLowerCase() == brandName.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Belirli bir marka ve model için paketleri döndürür
  static List<VehiclePackage> getPackages(String brandName, String modelName, int year) {
    final brand = getBrand(brandName);
    if (brand == null) return [];
    return brand.getPackagesForModel(modelName, year);
  }

  /// Tüm marka isimlerini döndürür
  static List<String> getAllBrandNames() {
    return brands.map((brand) => brand.brandName).toList();
  }

  /// Belirli bir marka için tüm model isimlerini döndürür
  static List<String> getModelNamesForBrand(String brandName) {
    final brand = getBrand(brandName);
    if (brand == null) return [];
    return brand.getModelNames();
  }

  /// Paket ağırlığını döndürür
  static double getPackageWeight(String packageId) {
    for (final brand in brands) {
      for (final model in brand.models.values) {
        for (final pkg in model.packages) {
          if (pkg.id == packageId) {
            return pkg.weight;
          }
        }
      }
    }
    return 1.0; // Varsayılan ağırlık
  }

  /// "Diğer" seçeneği için paket listesi
  static const List<VehiclePackage> otherPackages = [
    VehiclePackage(id: 'other_std', name: 'Standart', weight: 1.0),
    VehiclePackage(id: 'other_comf', name: 'Comfort', weight: 1.15),
    VehiclePackage(id: 'other_prem', name: 'Premium', weight: 1.3),
    VehiclePackage(id: 'other_lux', name: 'Lüks', weight: 1.45),
    VehiclePackage(id: 'other_sport', name: 'Spor', weight: 1.5),
  ];
}
