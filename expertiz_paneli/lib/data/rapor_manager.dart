import '../models/ekspertiz_model.dart';

class RaporManager {
  static final RaporManager _instance = RaporManager._internal();
  factory RaporManager() => _instance;
  RaporManager._internal();

  EkspertizRapor? _mevcutRapor;
  final Map<String, dynamic> _kaportaData = {};
  final Map<String, dynamic> _elektronikData = {};
  final Map<String, dynamic> _icEkspertizData = {};
  final List<String> _yuklenenDosyalar = [];

  EkspertizRapor? get mevcutRapor => _mevcutRapor;

  void yeniRaporBaslat({
    required String talepId,
    required String personelId,
    required String personelAd,
    required String musteriAd,
    required String aracPlaka,
    required String aracMarka,
    required String aracModel,
    required int aracYil,
  }) {
    _mevcutRapor = EkspertizRapor(
      raporId: _generateRaporId(),
      talepId: talepId,
      personelId: personelId,
      personelAd: personelAd,
      musteriAd: musteriAd,
      aracPlaka: aracPlaka,
      aracMarka: aracMarka,
      aracModel: aracModel,
      aracYil: aracYil,
      tarih: DateTime.now(),
      kaportaData: _kaportaData,
      elektronikData: _elektronikData,
      icEkspertizData: _icEkspertizData,
      yuklenenDosyalar: _yuklenenDosyalar,
      durum: 'Tamamlanmadi',
    );
  }

  // Veri güncelleme metodları
  void kaportaVerisiGuncelle(Map<String, dynamic> yeniData) {
    _kaportaData.addAll(yeniData);
    _guncelleMevcutRapor();
  }

  void elektronikVerisiGuncelle(Map<String, dynamic> yeniData) {
    _elektronikData.addAll(yeniData);
    _guncelleMevcutRapor();
  }

  void icEkspertizVerisiGuncelle(Map<String, dynamic> yeniData) {
    _icEkspertizData.addAll(yeniData);
    _guncelleMevcutRapor();
  }

  void dosyaEkle(String dosyaPath) {
    _yuklenenDosyalar.add(dosyaPath);
    _guncelleMevcutRapor();
  }

  void dosyaSil(int index) {
    if (index >= 0 && index < _yuklenenDosyalar.length) {
      _yuklenenDosyalar.removeAt(index);
      _guncelleMevcutRapor();
    }
  }

  void raporNotuEkle(String not) {
    if (_mevcutRapor != null) {
      _mevcutRapor = _mevcutRapor!.copyWith(raporNotu: not);
    }
  }

  void raporuGonder() {
    if (_mevcutRapor != null) {
      _mevcutRapor = _mevcutRapor!.copyWith(
        durum: 'Gonderildi',
        gonderilmeTarihi: DateTime.now(),
      );
    }
  }

  void raporuSifirla() {
    _mevcutRapor = null;
    _kaportaData.clear();
    _elektronikData.clear();
    _icEkspertizData.clear();
    _yuklenenDosyalar.clear();
  }

  // İstatistikler
  bool get raporTamamlandiMi {
    return _kaportaData.isNotEmpty && 
           _elektronikData.isNotEmpty && 
           _icEkspertizData.isNotEmpty;
  }

  int get toplamKontrolNoktasi {
    return _kaportaData.length + _elektronikData.length + _icEkspertizData.length;
  }

  int get tamamlananKontrolNoktasi {
    int tamamlanan = 0;
    
    void kontrolEt(Map<String, dynamic> data) {
      data.forEach((key, value) {
        if (value is Map && value['durum'] != null && value['durum'].toString().isNotEmpty) {
          tamamlanan++;
        }
      });
    }
    
    kontrolEt(_kaportaData);
    kontrolEt(_elektronikData);
    kontrolEt(_icEkspertizData);
    
    return tamamlanan;
  }

  double get ilerlemeOrani {
    if (toplamKontrolNoktasi == 0) return 0.0;
    return tamamlananKontrolNoktasi / toplamKontrolNoktasi;
  }

  Map<String, int> get durumIstatistikleri {
    Map<String, int> istatistikler = {
      'Orjinal': 0, 'Boyali': 0, 'Lokal Boyali': 0, 'Cizik': 0, 'Gocuk': 0, 'Degisen': 0,
      'Iyi': 0, 'Orta': 0, 'Kotu': 0, 'Yok': 0,
    };

    void say(Map<String, dynamic> data) {
      data.forEach((key, value) {
        if (value is Map && value['durum'] != null) {
          String durum = value['durum'].toString();
          if (istatistikler.containsKey(durum)) {
            istatistikler[durum] = istatistikler[durum]! + 1;
          }
        }
      });
    }

    say(_kaportaData);
    say(_elektronikData);
    say(_icEkspertizData);

    return istatistikler;
  }

  void _guncelleMevcutRapor() {
    if (_mevcutRapor != null) {
      _mevcutRapor = _mevcutRapor!.copyWith(
        kaportaData: Map.from(_kaportaData),
        elektronikData: Map.from(_elektronikData),
        icEkspertizData: Map.from(_icEkspertizData),
        yuklenenDosyalar: List.from(_yuklenenDosyalar),
      );
    }
  }

  String _generateRaporId() {
    final now = DateTime.now();
    return 'RAP${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }
}
