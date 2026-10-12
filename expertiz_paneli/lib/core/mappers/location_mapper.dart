import 'package:flutter/material.dart';
import '../../models/bolge_model.dart';
import '../../models/il_model.dart';

/// LocationMapper - Enterprise Grade Mapping Layer
/// 
/// CRITICAL COMPONENT - Single Source of Truth for Location Data
/// 
/// RESPONSIBILITIES:
/// - Convert ilId → ilAdi
/// - Convert bolgeId → bolgeAdi
/// - Centralized mapping logic
/// - UI MUST NEVER hardcode names
/// 
/// ARCHITECTURAL RULES:
/// - All ID-to-name conversions happen here
/// - UI components use ONLY this mapper for display
/// - No string-based logic in UI for region/city
/// - ilId and bolgeId are the ONLY source of truth
class LocationMapper {
  // Singleton pattern for consistency
  static final LocationMapper _instance = LocationMapper._internal();
  factory LocationMapper() => _instance;
  LocationMapper._internal();

  // ==================== REGION DATA ====================
  // Turkey's 7 Regions with their IDs and Colors
  static const Map<int, _RegionInfo> _regions = {
    1: _RegionInfo('Marmara', Colors.blue),
    2: _RegionInfo('İç Anadolu', Colors.brown),
    3: _RegionInfo('Ege', Colors.orange),
    4: _RegionInfo('Akdeniz', Colors.green),
    5: _RegionInfo('Karadeniz', Colors.teal),
    6: _RegionInfo('Doğu Anadolu', Colors.purple),
    7: _RegionInfo('Güneydoğu Anadolu', Colors.red),
  };

  // ==================== PROVINCE DATA ====================
  // Türkiye'nin 81 ili, plaka kodu ve resmi 7 coğrafi bölge eşleşmesi.
  // Backend: musteri_paneli/yerimebak_ai_v5/core/turkey_regions.py ile birebir aynıdır.
  static const Map<int, _ProvinceInfo> _provinces = {
    // Marmara (bolgeId: 1)
    10: _ProvinceInfo('Balıkesir', 1),
    11: _ProvinceInfo('Bilecik', 1),
    16: _ProvinceInfo('Bursa', 1),
    17: _ProvinceInfo('Çanakkale', 1),
    22: _ProvinceInfo('Edirne', 1),
    34: _ProvinceInfo('İstanbul', 1),
    39: _ProvinceInfo('Kırklareli', 1),
    41: _ProvinceInfo('Kocaeli', 1),
    54: _ProvinceInfo('Sakarya', 1),
    59: _ProvinceInfo('Tekirdağ', 1),
    77: _ProvinceInfo('Yalova', 1),

    // İç Anadolu (bolgeId: 2)
    6: _ProvinceInfo('Ankara', 2),
    18: _ProvinceInfo('Çankırı', 2),
    26: _ProvinceInfo('Eskişehir', 2),
    38: _ProvinceInfo('Kayseri', 2),
    40: _ProvinceInfo('Kırşehir', 2),
    42: _ProvinceInfo('Konya', 2),
    50: _ProvinceInfo('Nevşehir', 2),
    51: _ProvinceInfo('Niğde', 2),
    58: _ProvinceInfo('Sivas', 2),
    66: _ProvinceInfo('Yozgat', 2),
    68: _ProvinceInfo('Aksaray', 2),
    70: _ProvinceInfo('Karaman', 2),
    71: _ProvinceInfo('Kırıkkale', 2),

    // Ege (bolgeId: 3)
    3: _ProvinceInfo('Afyonkarahisar', 3),
    9: _ProvinceInfo('Aydın', 3),
    20: _ProvinceInfo('Denizli', 3),
    35: _ProvinceInfo('İzmir', 3),
    43: _ProvinceInfo('Kütahya', 3),
    45: _ProvinceInfo('Manisa', 3),
    48: _ProvinceInfo('Muğla', 3),
    64: _ProvinceInfo('Uşak', 3),

    // Akdeniz (bolgeId: 4)
    1: _ProvinceInfo('Adana', 4),
    7: _ProvinceInfo('Antalya', 4),
    15: _ProvinceInfo('Burdur', 4),
    31: _ProvinceInfo('Hatay', 4),
    32: _ProvinceInfo('Isparta', 4),
    33: _ProvinceInfo('Mersin', 4),
    46: _ProvinceInfo('Kahramanmaraş', 4),
    80: _ProvinceInfo('Osmaniye', 4),

    // Karadeniz (bolgeId: 5)
    5: _ProvinceInfo('Amasya', 5),
    8: _ProvinceInfo('Artvin', 5),
    14: _ProvinceInfo('Bolu', 5),
    19: _ProvinceInfo('Çorum', 5),
    28: _ProvinceInfo('Giresun', 5),
    29: _ProvinceInfo('Gümüşhane', 5),
    37: _ProvinceInfo('Kastamonu', 5),
    52: _ProvinceInfo('Ordu', 5),
    53: _ProvinceInfo('Rize', 5),
    55: _ProvinceInfo('Samsun', 5),
    57: _ProvinceInfo('Sinop', 5),
    60: _ProvinceInfo('Tokat', 5),
    61: _ProvinceInfo('Trabzon', 5),
    67: _ProvinceInfo('Zonguldak', 5),
    69: _ProvinceInfo('Bayburt', 5),
    74: _ProvinceInfo('Bartın', 5),
    78: _ProvinceInfo('Karabük', 5),
    81: _ProvinceInfo('Düzce', 5),

    // Doğu Anadolu (bolgeId: 6)
    4: _ProvinceInfo('Ağrı', 6),
    12: _ProvinceInfo('Bingöl', 6),
    13: _ProvinceInfo('Bitlis', 6),
    23: _ProvinceInfo('Elazığ', 6),
    24: _ProvinceInfo('Erzincan', 6),
    25: _ProvinceInfo('Erzurum', 6),
    30: _ProvinceInfo('Hakkari', 6),
    36: _ProvinceInfo('Kars', 6),
    44: _ProvinceInfo('Malatya', 6),
    49: _ProvinceInfo('Muş', 6),
    62: _ProvinceInfo('Tunceli', 6),
    65: _ProvinceInfo('Van', 6),
    75: _ProvinceInfo('Ardahan', 6),
    76: _ProvinceInfo('Iğdır', 6),

    // Güneydoğu Anadolu (bolgeId: 7)
    2: _ProvinceInfo('Adıyaman', 7),
    21: _ProvinceInfo('Diyarbakır', 7),
    27: _ProvinceInfo('Gaziantep', 7),
    47: _ProvinceInfo('Mardin', 7),
    56: _ProvinceInfo('Siirt', 7),
    63: _ProvinceInfo('Şanlıurfa', 7),
    72: _ProvinceInfo('Batman', 7),
    73: _ProvinceInfo('Şırnak', 7),
    79: _ProvinceInfo('Kilis', 7),
  };

  // ==================== PUBLIC API ====================

  /// Get province name from ilId
  String getIlAdi(int ilId) {
    return _provinces[ilId]?.name ?? 'Bilinmiyor';
  }

  /// Get region name from bolgeId
  String getBolgeAdi(int bolgeId) {
    return _regions[bolgeId]?.name ?? 'Bilinmiyor';
  }

  /// Get region color from bolgeId
  Color getBolgeRenk(int bolgeId) {
    return _regions[bolgeId]?.color ?? Colors.blue;
  }

  /// Get bolgeId from ilId
  int getBolgeIdFromIlId(int ilId) {
    return _provinces[ilId]?.bolgeId ?? 0;
  }

  /// Get all provinces in a region
  List<int> getIlIdsByBolgeId(int bolgeId) {
    return _provinces.entries
        .where((entry) => entry.value.bolgeId == bolgeId)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get all provinces as BolgeModel list
  List<BolgeModel> getAllBolgeModels() {
    return _regions.entries.map((regionEntry) {
      final ilIds = getIlIdsByBolgeId(regionEntry.key);
      final iller = ilIds.map((ilId) {
        final province = _provinces[ilId];
        if (province == null) return null;
        
        return IlModel(
          id: ilId.toString(),
          ad: province.name,
          plaka: ilId.toString(),
          bolgeId: regionEntry.key,
          bolge: regionEntry.value.name,
          ilceler: [],
          renk: Colors.grey[300]!,
        );
      }).whereType<IlModel>().toList();
      
      return BolgeModel(
        id: regionEntry.key.toString(),
        ad: regionEntry.value.name,
        renk: regionEntry.value.color,
        iller: iller,
      );
    }).toList();
  }

  /// Get BolgeModel by bolgeId
  BolgeModel? getBolgeModelById(int bolgeId) {
    final regionInfo = _regions[bolgeId];
    if (regionInfo == null) return null;

    final ilIds = getIlIdsByBolgeId(bolgeId);
    final iller = ilIds.map((ilId) {
      final province = _provinces[ilId];
      if (province == null) return null;
      
      return IlModel(
        id: ilId.toString(),
        ad: province.name,
        plaka: ilId.toString(),
        bolgeId: bolgeId,
        bolge: regionInfo.name,
        ilceler: [],
        renk: Colors.grey[300]!,
      );
    }).whereType<IlModel>().toList();
    
    return BolgeModel(
      id: bolgeId.toString(),
      ad: regionInfo.name,
      renk: regionInfo.color,
      iller: iller,
    );
  }

  /// Get IlModel by ilId
  IlModel? getIlModelById(int ilId) {
    final province = _provinces[ilId];
    if (province == null) return null;

    return IlModel(
      id: ilId.toString(),
      ad: province.name,
      plaka: ilId.toString(),
      bolgeId: province.bolgeId,
      bolge: _regions[province.bolgeId]?.name ?? '',
      ilceler: [],
      renk: Colors.grey[300]!,
    );
  }

  /// Get ilId from ilAdi (reverse mapping)
  ///
  /// Büyük/küçük harf ve Türkçe karakter farklarını tolere eder:
  /// 'İstanbul', 'ISTANBUL', 'istanbul', 'İstanbul / Kadıköy' → 34
  int getIlId(String ilAdi) {
    final raw = ilAdi.trim();
    if (raw.isEmpty) return 0;
    final asNumber = int.tryParse(raw);
    if (asNumber != null) return _provinces.containsKey(asNumber) ? asNumber : 0;

    final candidates = <String>{raw};
    for (final separator in ['/', ',', '-', '(', ' ']) {
      if (raw.contains(separator)) {
        candidates.addAll(
          raw.split(separator).map((p) => p.replaceAll(')', '').trim()).where((p) => p.isNotEmpty),
        );
      }
    }
    for (final candidate in candidates) {
      final folded = _fold(candidate);
      for (final entry in _provinces.entries) {
        if (_fold(entry.value.name) == folded) {
          return entry.key;
        }
      }
    }
    return 0;
  }

  static String _fold(String value) {
    const map = {
      'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u', 'â': 'a', 'î': 'i', 'û': 'u',
    };
    final lowered = value.trim().replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
    final buffer = StringBuffer();
    for (final char in lowered.split('')) {
      buffer.write(map[char] ?? char);
    }
    return buffer.toString();
  }

  /// Get bolgeId from bolgeAdi (reverse mapping)
  int getBolgeId(String bolgeAdi) {
    for (final entry in _regions.entries) {
      if (entry.value.name == bolgeAdi) {
        return entry.key;
      }
    }
    return 0;
  }

  /// Check if ilId is valid
  bool isValidIlId(int ilId) {
    return _provinces.containsKey(ilId);
  }

  /// Check if bolgeId is valid
  bool isValidBolgeId(int bolgeId) {
    return _regions.containsKey(bolgeId);
  }

  /// Get all valid ilIds
  List<int> getAllIlIds() {
    return _provinces.keys.toList()..sort();
  }

  /// Get all valid bolgeIds
  List<int> getAllBolgeIds() {
    return _regions.keys.toList()..sort();
  }

  /// Format location for display
  String formatLocation(int ilId) {
    final ilAdi = getIlAdi(ilId);
    final bolgeId = getBolgeIdFromIlId(ilId);
    final bolgeAdi = getBolgeAdi(bolgeId);
    
    if (ilAdi == 'Bilinmiyor') return 'Bilinmiyor';
    if (bolgeAdi == 'Bilinmiyor') return ilAdi;
    
    return '$ilAdi, $bolgeAdi';
  }

  /// Get districts for a given ilId
  List<String> getIlceler(int ilId) {
    return _ilceler[ilId] ?? [];
  }
}

// ==================== DISTRICT DATA ====================
const Map<int, List<String>> _ilceler = {
  34: ['Adalar', 'Arnavutköy', 'Ataşehir', 'Avcılar', 'Bağcılar', 'Bahçelievler', 'Bakırköy', 'Başakşehir', 'Bayrampaşa', 'Beşiktaş', 'Beykoz', 'Beylikdüzü', 'Beyoğlu', 'Büyükçekmece', 'Çatalca', 'Çekmeköy', 'Esenler', 'Esenyurt', 'Eyüpsultan', 'Fatih', 'Gaziosmanpaşa', 'Güngören', 'Kadıköy', 'Kağıthane', 'Kartal', 'Küçükçekmece', 'Maltepe', 'Pendik', 'Sancaktepe', 'Sarıyer', 'Silivri', 'Sultanbeyli', 'Sultangazi', 'Şile', 'Şişli', 'Tuzla', 'Ümraniye', 'Üsküdar', 'Zeytinburnu'],
  6: ['Altındağ', 'Çankaya', 'Etimesgut', 'Gölbaşı', 'Keçiören', 'Mamak', 'Sincan', 'Yenimahalle', 'Pursaklar', 'Akyurt', 'Bala', 'Beypazarı', 'Çamlıdere', 'Evren', 'Güdül', 'Haymana', 'Kalecik', 'Kızılcahamam', 'Nallıhan', 'Polatlı', 'Şereflikoçhisar'],
  35: ['Aliağa', 'Balçova', 'Bayındır', 'Bayraklı', 'Bergama', 'Beydağ', 'Bornova', 'Buca', 'Çeşme', 'Çiğli', 'Dikili', 'Foça', 'Gaziemir', 'Güzelbahçe', 'Karabağlar', 'Karaburun', 'Karşıyaka', 'Kemalpaşa', 'Kınık', 'Kiraz', 'Konak', 'Menderes', 'Menemen', 'Narlıdere', 'Ödemiş', 'Seferihisar', 'Selçuk', 'Tire', 'Torbalı', 'Urla'],
  16: ['Gemlik', 'Gürsu', 'Kestel', 'Mudanya', 'Nilüfer', 'Osmangazi', 'Yıldırım', 'Büyükorhan', 'Harmancık', 'İnegöl', 'İznik', 'Karacabey', 'Keles', 'Orhaneli', 'Orhangazi', 'Yenişehir'],
  7: ['Akseki', 'Aksu', 'Alanya', 'Demre', 'Döşemealtı', 'Elmalı', 'Finike', 'Gazipaşa', 'Gündoğmuş', 'İbradı', 'Kaş', 'Kemer', 'Kepez', 'Konyaaltı', 'Korkuteli', 'Kumluca', 'Manavgat', 'Muratpaşa', 'Serik'],
  27: ['Araban', 'İslahiye', 'Karkamış', 'Nizip', 'Nurdağı', 'Oğuzeli', 'Şahinbey', 'Şehitkamil', 'Yavuzeli'],
  21: ['Bağlar', 'Bismil', 'Çermik', 'Çınar', 'Çüngüş', 'Dicle', 'Eğil', 'Ergani', 'Hani', 'Hazro', 'Kayapınar', 'Kocaköy', 'Kulp', 'Lice', 'Silvan', 'Sur', 'Yenişehir'],
  1: ['Aladağ', 'Ceyhan', 'Çukurova', 'Feke', 'İmamoğlu', 'Karaisalı', 'Karataş', 'Kozan', 'Pozantı', 'Saimbeyli', 'Sarıçam', 'Seyhan', 'Tufanbeyli', 'Yumurtalık', 'Yüreğir'],
  33: ['Akdeniz', 'Anamur', 'Aydıncık', 'Bozyazı', 'Çamlıyayla', 'Erdemli', 'Gülnar', 'Mezitli', 'Mut', 'Silifke', 'Tarsus', 'Toroslar', 'Yenişehir'],
  41: ['Başiskele', 'Çayırova', 'Darıca', 'Dilovası', 'Gebze', 'Gölcük', 'İzmit', 'Kandıra', 'Karamürsel', 'Kartepe', 'Körfez'],
  55: ['19 Mayıs', 'Alaçam', 'Asarcık', 'Atakum', 'Ayvacık', 'Bafra', 'Canik', 'Çarşamba', 'Havza', 'İlkadım', 'Kavak', 'Ladik', 'Salıpazarı', 'Tekkeköy', 'Terme', 'Vezirköprü', 'Yakakent'],
  59: ['Çerkezköy', 'Çorlu', 'Ergene', 'Hayrabolu', 'Kapaklı', 'Malkara', 'Marmara Ereğlisi', 'Muratlı', 'Saray', 'Süleymanpaşa', 'Şarköy'],
  9: ['Bozdoğan', 'Buharkent', 'Çine', 'Didim', 'Efeler', 'Germencik', 'İncirliova', 'Karacasu', 'Karpuzlu', 'Koçarlı', 'Köşk', 'Kuşadası', 'Kuyucak', 'Nazilli', 'Söke', 'Sultanhisar', 'Yenipazar'],
  20: ['Acıpayam', 'Babadağ', 'Baklan', 'Bekilli', 'Beyağaç', 'Bozkurt', 'Buldan', 'Çal', 'Çameli', 'Çardak', 'Çivril', 'Güney', 'Honaz', 'Kale', 'Merkezefendi', 'Pamukkale', 'Sarayköy', 'Serinhisar', 'Tavas'],
  45: ['Ahmetli', 'Akhisar', 'Alaşehir', 'Demirci', 'Gölmarmara', 'Gördes', 'Kırkağaç', 'Köprübaşı', 'Kula', 'Salihli', 'Sarıgöl', 'Saruhanlı', 'Selendi', 'Soma', 'Şehzadeler', 'Turgutlu', 'Yunusemre'],
  48: ['Bodrum', 'Dalaman', 'Datça', 'Fethiye', 'Kavaklıdere', 'Köyceğiz', 'Marmaris', 'Menteşe', 'Milas', 'Ortaca', 'Seydikemer', 'Ula', 'Yatağan'],
  31: ['Altınözü', 'Antakya', 'Arsuz', 'Belen', 'Defne', 'Dörtyol', 'Erzin', 'Hassa', 'İskenderun', 'Kırıkhan', 'Kumlu', 'Payas', 'Reyhanlı', 'Samandağ', 'Yayladağı'],
  32: ['Aksu', 'Atabey', 'Eğirdir', 'Gelendost', 'Gönen', 'Keçiborlu', 'Merkez', 'Senirkent', 'Sütçüler', 'Şarkikaraağaç', 'Uluborlu', 'Yalvaç', 'Yenişarbademli'],
  26: ['Alpu', 'Beylikova', 'Çifteler', 'Günyüzü', 'Han', 'İnönü', 'Mahmudiye', 'Mihalgazi', 'Mihalıççık', 'Odunpazarı', 'Sarıcakaya', 'Seyitgazi', 'Sivrihisar', 'Tepebaşı'],
  38: ['Akkışla', 'Bünyan', 'Develi', 'Felahiye', 'Hacılar', 'İncesu', 'Kocasinan', 'Melikgazi', 'Özvatan', 'Pınarbaşı', 'Sarıoğlan', 'Sarız', 'Talas', 'Tomarza', 'Yahyalı', 'Yeşilhisar'],
  42: ['Ahırlı', 'Akören', 'Akşehir', 'Altınekin', 'Beyşehir', 'Bozkır', 'Cihanbeyli', 'Çeltik', 'Çumra', 'Derbent', 'Derebucak', 'Doğanhisar', 'Emirgazi', 'Ereğli', 'Güneysınır', 'Hadim', 'Halkapınar', 'Hüyük', 'Ilgın', 'Kadınhanı', 'Karapınar', 'Karatay', 'Kulu', 'Meram', 'Sarayönü', 'Selçuklu', 'Seydişehir', 'Taşkent', 'Tuzlukçu', 'Yalıhüyük', 'Yunak'],
  52: ['Akkuş', 'Altınordu', 'Aybastı', 'Çamaş', 'Çatalpınar', 'Çaybaşı', 'Fatsa', 'Gölköy', 'Gülyalı', 'Gürgentepe', 'İkizce', 'Kabadüz', 'Kabataş', 'Korgan', 'Kumru', 'Mesudiye', 'Perşembe', 'Ulubey', 'Ünye'],
  61: ['Akçaabat', 'Araklı', 'Arsin', 'Beşikdüzü', 'Çarşıbaşı', 'Çaykara', 'Dernekpazarı', 'Düzköy', 'Hayrat', 'Köprübaşı', 'Maçka', 'Of', 'Ortahisar', 'Sürmene', 'Şalpazarı', 'Tonya', 'Vakfıkebir', 'Yomra'],
  63: ['Akçakale', 'Birecik', 'Bozova', 'Ceylanpınar', 'Eyyübiye', 'Halfeti', 'Haliliye', 'Harran', 'Hilvan', 'Karaköprü', 'Siverek', 'Suruç', 'Viranşehir'],
  47: ['Artuklu', 'Dargeçit', 'Derik', 'Kızıltepe', 'Mazıdağı', 'Midyat', 'Nusaybin', 'Ömerli', 'Savur', 'Yeşilli'],
  23: ['Ağın', 'Alacakaya', 'Arıcak', 'Baskil', 'Karakoçan', 'Keban', 'Kovancılar', 'Maden', 'Merkez', 'Palu', 'Sivrice'],
  44: ['Akçadağ', 'Arapgir', 'Arguvan', 'Battalgazi', 'Darende', 'Doğanşehir', 'Doğanyol', 'Hekimhan', 'Kale', 'Kuluncak', 'Pütürge', 'Yazıhan', 'Yeşilyurt'],
  10: ['Altıeylül', 'Ayvalık', 'Balya', 'Bandırma', 'Bigadiç', 'Burhaniye', 'Dursunbey', 'Edremit', 'Erdek', 'Gömeç', 'Gönen', 'Havran', 'İvrindi', 'Karesi', 'Kepsut', 'Manyas', 'Marmara', 'Savaştepe', 'Sındırgı', 'Susurluk'],
  54: ['Adapazarı', 'Akyazı', 'Arifiye', 'Erenler', 'Ferizli', 'Geyve', 'Hendek', 'Karapürçek', 'Karasu', 'Kaynarca', 'Kocaali', 'Pamukova', 'Sapanca', 'Serdivan', 'Söğütlü', 'Taraklı'],
  17: ['Ayvacık', 'Bayramiç', 'Biga', 'Bozcaada', 'Çan', 'Eceabat', 'Ezine', 'Gelibolu', 'Gökçeada', 'Lapseki', 'Merkez', 'Yenice'],
  22: ['Edirne Merkez', 'Enez', 'Havsa', 'İpsala', 'Keşan', 'Lalapaşa', 'Meriç', 'Süloğlu', 'Uzunköprü'],
  39: ['Babaeski', 'Demirköy', 'Kırklareli Merkez', 'Kofçaz', 'Lüleburgaz', 'Pehlivanköy', 'Pınarhisar', 'Vize'],
  77: ['Altınova', 'Armutlu', 'Çiftlikköy', 'Çınarcık', 'Termal', 'Yalova Merkez'],
  11: ['Bozüyük', 'Gölpazarı', 'İnhisar', 'Merkez', 'Osmaneli', 'Pazaryeri', 'Söğüt', 'Yenipazar'],
  58: ['Akıncılar', 'Altınyayla', 'Divriği', 'Doğanşar', 'Gemerek', 'Gölova', 'Gürün', 'Hafik', 'İmranlı', 'Kangal', 'Koyulhisar', 'Merkez', 'Suşehri', 'Şarkışla', 'Ulaş', 'Yıldızeli', 'Zara'],
  66: ['Akdağmadeni', 'Aydıncık', 'Boğazlıyan', 'Çandır', 'Çayıralan', 'Çekerek', 'Kadışehri', 'Merkez', 'Saraykent', 'Sarıkaya', 'Sorgun', 'Şefaatli', 'Yenifakılı', 'Yerköy'],
  68: ['Ağaçören', 'Eskil', 'Gülağaç', 'Güzelyurt', 'Merkez', 'Ortaköy', 'Sarıyahşi'],
  70: ['Ayrancı', 'Başyayla', 'Ermenek', 'Kazımkarabekir', 'Merkez', 'Sarıveliler'],
  71: ['Bahşılı', 'Balışeyh', 'Çelebi', 'Delice', 'Karakeçili', 'Keskin', 'Merkez', 'Sulakyurt', 'Yahşihan'],
  78: ['Eflani', 'Eskipazar', 'Merkez', 'Ovacık', 'Safranbolu', 'Yenice'],
  3: ['Başmakçı', 'Bayat', 'Bolvadin', 'Çay', 'Çobanlar', 'Dazkırı', 'Dinar', 'Emirdağ', 'Evciler', 'Hocalar', 'İhsaniye', 'İscehisar', 'Kızılören', 'Merkez', 'Sandıklı', 'Sinanpaşa', 'Sultandağı', 'Şuhut'],
  43: ['Altıntaş', 'Aslanapa', 'Çavdarhisar', 'Domaniç', 'Dumlupınar', 'Emet', 'Gediz', 'Hisarcık', 'Merkez', 'Pazarlar', 'Şaphane', 'Simav', 'Tavşanlı'],
  64: ['Banaz', 'Eşme', 'Karahallı', 'Merkez', 'Sivaslı', 'Ulubey'],
  15: ['Ağlasun', 'Altınyayla', 'Bucak', 'Çavdır', 'Çeltikçi', 'Gölhisar', 'Karamanlı', 'Kemer', 'Merkez', 'Tefenni', 'Yeşilova'],
  46: ['Afşin', 'Andırın', 'Çağlayancerit', 'Dulkadiroğlu', 'Ekinözü', 'Elbistan', 'Göksun', 'Nurhak', 'Onikişubat', 'Pazarcık', 'Türkoğlu'],
  80: ['Bahçe', 'Düziçi', 'Hasanbeyli', 'Kadirli', 'Merkez', 'Sumbas', 'Toprakkale'],
  53: ['Ardeşen', 'Çamlıhemşin', 'Çayeli', 'Derepazarı', 'Fındıklı', 'Güneysu', 'Hemşin', 'İkizdere', 'İyidere', 'Kalkandere', 'Merkez', 'Pazar'],
  28: ['Alucra', 'Bulancak', 'Çamoluk', 'Çanakçı', 'Dereli', 'Doğankent', 'Espiye', 'Eynesil', 'Görele', 'Güce', 'Keşap', 'Merkez', 'Piraziz', 'Şebinkarahisar', 'Tirebolu', 'Yağlıdere'],
  29: ['Kelkit', 'Köse', 'Kürtün', 'Merkez', 'Şiran', 'Torul'],
  36: ['Akyaka', 'Arpaçay', 'Digor', 'Kağızman', 'Merkez', 'Sarıkamış', 'Selim', 'Susuz'],
  37: ['Abana', 'Ağlı', 'Araç', 'Azdavay', 'Bozkurt', 'Cide', 'Çatalzeytin', 'Daday', 'Devrekani', 'Doğanyurt', 'Hanönü', 'İhsangazi', 'İnebolu', 'Küre', 'Merkez', 'Pınarbaşı', 'Seydiler', 'Şenpazar', 'Taşköprü', 'Tosya'],
  57: ['Ayancık', 'Boyabat', 'Dikmen', 'Durağan', 'Erfelek', 'Gerze', 'Merkez', 'Saraydüzü', 'Türkeli'],
  74: ['Amasra', 'Kurucaşile', 'Merkez', 'Ulus'],
  75: ['Çıldır', 'Damal', 'Göle', 'Hanak', 'Merkez', 'Posof'],
  76: ['Aralık', 'Karakoyunlu', 'Merkez', 'Tuzluca'],
  8: ['Ardanuç', 'Arhavi', 'Borçka', 'Hopa', 'Kemalpaşa', 'Merkez', 'Murgul', 'Şavşat', 'Yusufeli'],
  69: ['Aydıntepe', 'Demirözü', 'Merkez'],
  81: ['Akçakoca', 'Cumayeri', 'Çilimli', 'Gölyaka', 'Gümüşova', 'Kaynaşlı', 'Merkez', 'Yığılca'],
  30: ['Çukurca', 'Derecik', 'Merkez', 'Şemdinli', 'Yüksekova'],
  49: ['Bulanık', 'Hasköy', 'Korkut', 'Malazgirt', 'Merkez', 'Varto'],
  62: ['Çemişgezek', 'Hozat', 'Mazgirt', 'Merkez', 'Nazımiye', 'Ovacık', 'Pertek', 'Pülümür'],
  65: ['Bahçesaray', 'Başkale', 'Çaldıran', 'Çatak', 'Edremit', 'Erciş', 'Gevaş', 'Gürpınar', 'İpekyolu', 'Muradiye', 'Özalp', 'Saray', 'Tuşba'],
  4: ['Diyadin', 'Doğubayazıt', 'Eleşkirt', 'Hamur', 'Merkez', 'Patnos', 'Taşlıçay', 'Tutak'],
  12: ['Adaklı', 'Genç', 'Karlıova', 'Kiğı', 'Merkez', 'Solhan', 'Yayladere', 'Yedisu'],
  13: ['Adilcevaz', 'Ahlat', 'Güroymak', 'Hizan', 'Merkez', 'Mutki', 'Tatvan'],
  19: ['Alaca', 'Bayat', 'Boğazkale', 'Dodurga', 'İskilip', 'Kargı', 'Laçin', 'Mecitözü', 'Merkez', 'Oğuzlar', 'Ortaköy', 'Osmancık', 'Sungurlu', 'Uğurludağ'],
  2: ['Adıyaman Merkez', 'Besni', 'Çelikhan', 'Gerger', 'Gölbaşı', 'Kâhta', 'Samsat', 'Sincik', 'Tut'],
  72: ['Beşiri', 'Gercüş', 'Hasankeyf', 'Kozluk', 'Merkez', 'Sason'],
  73: ['Beytüşşebap', 'Cizre', 'Güçlükonak', 'İdil', 'Merkez', 'Silopi', 'Uludere'],
  79: ['Elbeyli', 'Merkez', 'Musabeyli', 'Polateli'],
  5: ['Göynücek', 'Gümüşhacıköy', 'Hamamözü', 'Merkez', 'Merzifon', 'Suluova', 'Taşova'],
  14: ['Dörtdivan', 'Gerede', 'Göynük', 'Kıbrıscık', 'Mengen', 'Merkez', 'Mudurnu', 'Seben', 'Yeniçağa'],
  18: ['Atkaracalar', 'Bayramören', 'Çerkeş', 'Eldivan', 'Ilgaz', 'Kızılırmak', 'Korgun', 'Kurşunlu', 'Merkez', 'Orta', 'Şabanözü', 'Yapraklı'],
  24: ['Çayırlı', 'İliç', 'Kemah', 'Kemaliye', 'Merkez', 'Otlukbeli', 'Refahiye', 'Tercan', 'Üzümlü'],
  25: ['Aşkale', 'Aziziye', 'Çat', 'Hınıs', 'Horasan', 'İspir', 'Karaçoban', 'Karayazı', 'Köprüköy', 'Narman', 'Oltu', 'Palandöken', 'Pasinler', 'Pazaryolu', 'Şenkaya', 'Tekman', 'Tortum', 'Uzundere', 'Yakutiye'],
  40: ['Çelebi', 'Merkez', 'Mucur'],
  50: ['Acıgöl', 'Avanos', 'Derinkuyu', 'Gülşehir', 'Hacıbektaş', 'Kozaklı', 'Merkez', 'Ürgüp'],
  51: ['Altunhisar', 'Bor', 'Çamardı', 'Çiftlik', 'Merkez', 'Ulukışla'],
  56: ['Baykan', 'Eruh', 'Kurtalan', 'Merkez', 'Pervari', 'Şirvan', 'Tillo'],
  60: ['Artova', 'Başçiftlik', 'Erbaa', 'Merkez', 'Niksar', 'Pazar', 'Reşadiye', 'Sulusaray', 'Tokat Merkez', 'Turhal', 'Yeşilyurt', 'Zile'],
  67: ['Alaplı', 'Çaycuma', 'Devrek', 'Ereğli', 'Gökçebey', 'Kilimli', 'Kozlu', 'Merkez'],
};

// ==================== PRIVATE HELPERS ====================
class _RegionInfo {
  final String name;
  final Color color;

  const _RegionInfo(this.name, this.color);
}

class _ProvinceInfo {
  final String name;
  final int bolgeId;

  const _ProvinceInfo(this.name, this.bolgeId);
}


