import 'package:flutter/foundation.dart';
import '../models/expertiz/adim1_arac_satici_model.dart';
import '../models/expertiz/adim2_dis_ekspertiz_model.dart';
import '../models/expertiz/adim3_ic_ekspertiz_model.dart';
import '../models/expertiz/adim4_boya_kaporta_model.dart';
import '../models/expertiz/adim5_kurumsal_ekspertiz_model.dart';
import '../models/expertiz/tam_rapor_model.dart';
import '../services/rapor_service.dart';
import '../services/ai/ai_engine_service.dart';

/// Expertiz Akışı State Management Provider
/// Tüm 5 adımın state'ini yönetir
class ExpertizProvider extends ChangeNotifier {
  // Görev Bilgileri
  String? _gorevId;
  String? _personelId;
  String? _personelAdi;
  String? _musteriAdi;
  String? _aracPlakasi;

  // Mevcut Adım
  int _currentStep = 1;

  // Adım 1: Araç ve Satıcı
  Adim1AracSaticiModel? _adim1Model;

  // Adım 2: Dış Ekspertiz
  Adim2DisEkspertizModel? _adim2Model;

  // Adım 3: İç Ekspertiz
  Adim3IcEkspertizModel? _adim3Model;

  // Adım 4: Boya / Kaporta
  Adim4BoyaKaportaModel? _adim4Model;

  // Adım 5: Kurumsal Ekspertiz
  Adim5KurumsalEkspertizModel? _adim5Model;

  // Genel Durum
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  String? get gorevId => _gorevId;
  String? get personelId => _personelId;
  String? get personelAdi => _personelAdi;
  String? get musteriAdi => _musteriAdi;
  String? get aracPlakasi => _aracPlakasi;
  int get currentStep => _currentStep;
  Adim1AracSaticiModel? get adim1Model => _adim1Model;
  Adim2DisEkspertizModel? get adim2Model => _adim2Model;
  Adim3IcEkspertizModel? get adim3Model => _adim3Model;
  Adim4BoyaKaportaModel? get adim4Model => _adim4Model;
  Adim5KurumsalEkspertizModel? get adim5Model => _adim5Model;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Seçili donanımları MarketRadarService formatına döndürür
  /// Adim3IcEkspertizModel'deki donanım alanlarını `Map<String, bool>` formatına çevirir
  Map<String, bool> get selectedOptions {
    if (_adim3Model == null) return {};
    
    final Map<String, bool> options = {};
    
    // Koltuklar
    if (_adim3Model!.onKoltuklar != null) {
      options[_adim3Model!.onKoltuklar!] = true;
    }
    if (_adim3Model!.arkaKoltuklar != null) {
      options[_adim3Model!.arkaKoltuklar!] = true;
    }
    if (_adim3Model!.koltukDosemesi != null) {
      options[_adim3Model!.koltukDosemesi!] = true;
    }
    
    // Döşemeler
    if (_adim3Model!.dorseme != null) {
      options[_adim3Model!.dorseme!] = true;
    }
    if (_adim3Model!.tavanDosemesi != null) {
      options[_adim3Model!.tavanDosemesi!] = true;
    }
    
    // Pencereler
    if (_adim3Model!.onPencereler != null) {
      options[_adim3Model!.onPencereler!] = true;
    }
    if (_adim3Model!.arkaPencereler != null) {
      options[_adim3Model!.arkaPencereler!] = true;
    }
    if (_adim3Model!.camlar != null) {
      options[_adim3Model!.camlar!] = true;
    }
    
    // Elektronik
    if (_adim3Model!.direksiyon != null) {
      options[_adim3Model!.direksiyon!] = true;
    }
    if (_adim3Model!.gostergePaneli != null) {
      options[_adim3Model!.gostergePaneli!] = true;
    }
    if (_adim3Model!.klima != null) {
      options[_adim3Model!.klima!] = true;
    }
    if (_adim3Model!.sesSistemi != null) {
      options[_adim3Model!.sesSistemi!] = true;
    }
    if (_adim3Model!.merkeziKilit != null) {
      options[_adim3Model!.merkeziKilit!] = true;
    }
    if (_adim3Model!.camKontrolleri != null) {
      options[_adim3Model!.camKontrolleri!] = true;
    }
    if (_adim3Model!.aynaKontrolleri != null) {
      options[_adim3Model!.aynaKontrolleri!] = true;
    }
    
    return options;
  }

  /// Toplam dolum yüzdesi
  double get completionPercentage {
    int filled = 0;
    int total = 0;

    if (_adim1Model != null) {
      filled += _adim1Model!.durumSorular.where((s) => s.isFilled).length;
      total += _adim1Model!.durumSorular.length;
    }
    if (_adim2Model != null) {
      filled += _adim2Model!.filledFields;
      total += _adim2Model!.totalFields;
    }
    if (_adim3Model != null) {
      filled += _adim3Model!.filledFields;
      total += _adim3Model!.totalFields;
    }
    if (_adim4Model != null) {
      filled += _adim4Model!.filledFields;
      total += _adim4Model!.totalFields;
    }
    if (_adim5Model != null) {
      filled += _adim5Model!.filledFields;
      total += _adim5Model!.totalFields;
    }

    return total > 0 ? filled / total : 0.0;
  }

  /// Mevcut adımın geçerli olup olmadığını kontrol eder
  bool get currentStepValid {
    switch (_currentStep) {
      case 1:
        return _adim1Model?.isValid ?? false;
      case 2:
        return _adim2Model?.isValid ?? false;
      case 3:
        return _adim3Model?.isValid ?? false;
      case 4:
        return _adim4Model?.isValid ?? false;
      case 5:
        return _adim5Model?.isValid ?? false;
      default:
        return false;
    }
  }

  /// Tüm adımların geçerli olup olmadığını kontrol eder
  bool get allStepsValid {
    return (_adim1Model?.isValid ?? false) &&
        (_adim2Model?.isValid ?? false) &&
        (_adim3Model?.isValid ?? false) &&
        (_adim4Model?.isValid ?? false) &&
        (_adim5Model?.isValid ?? false);
  }

  /// Görev başlat (Varsa taslağı yükle)
  Future<void> startGorev({
    required String gorevId,
    required String personelId,
    required String personelAdi,
    required String musteriAdi,
    required String aracPlakasi,
  }) async {
    _gorevId = gorevId;
    _personelId = personelId;
    _personelAdi = personelAdi;
    _musteriAdi = musteriAdi;
    _aracPlakasi = aracPlakasi;
    
    // Taslak Yükleme Denemesi
    setLoading(true);
    try {
      final result = await RaporService.getReportById(gorevId);
      if (result.isSuccess && result.data != null) {
        final draft = result.data!;
        _adim1Model = draft.adim1;
        _adim2Model = draft.adim2;
        _adim3Model = draft.adim3;
        _adim4Model = draft.adim4;
        _adim5Model = draft.adim5;
        // Hangi adımda kaldığını bul (Basit mantık: ilk boş olmayan son adım)
        if (!draft.adim5.isEmpty) {
          _currentStep = 5;
        } else if (!draft.adim4.isEmpty) {
          _currentStep = 4;
        } else if (!draft.adim3.isEmpty) {
          _currentStep = 3;
        } else if (!draft.adim2.isEmpty) {
          _currentStep = 2;
        } else {
          _currentStep = 1;
        }

        debugPrint("Taslak yüklendi: $gorevId, Adım: $_currentStep");
      } else {
        // Yeni Başlangıç
        _initializeEmptyModels(gorevId, personelId, aracPlakasi);
      }
    } catch (e) {
      debugPrint("Taslak yükleme hatası: $e");
      _initializeEmptyModels(gorevId, personelId, aracPlakasi);
    } finally {
      setLoading(false);
      notifyListeners();
    }
  }

  void _initializeEmptyModels(String gorevId, String personelId, String plaka) {
    _currentStep = 1;
    _adim1Model = Adim1AracSaticiModel(
      gorevId: gorevId,
      personelId: personelId,
      marka: '',
      model: '',
      yakitTuru: 'Benzin',
      plaka: plaka,
      saseNo: '',
      guncelKm: 0,
      ruhsatSahibiAdSoyad: '',
      iletisimTelefon: '',
      motorNo: '',
    );
    _adim2Model = Adim2DisEkspertizModel.empty(gorevId: gorevId, personelId: personelId);
    _adim3Model = Adim3IcEkspertizModel.empty(gorevId: gorevId, personelId: personelId);
    _adim4Model = Adim4BoyaKaportaModel.empty(gorevId: gorevId, personelId: personelId);
    _adim5Model = Adim5KurumsalEkspertizModel.empty(gorevId: gorevId, personelId: personelId);
  }

  /// Mevcut modeli taslak olarak kaydet
  Future<void> _saveDraft() async {
    if (_gorevId == null || _personelId == null) return;
    
    // Eksik modelleri doldur (Null safety için)
    final tempRapor = TamRaporModel(
      gorevId: _gorevId!,
      personelId: _personelId!,
      adim1: _adim1Model ?? Adim1AracSaticiModel.empty(gorevId: _gorevId!, personelId: _personelId!),
      adim2: _adim2Model ?? Adim2DisEkspertizModel.empty(gorevId: _gorevId!, personelId: _personelId!),
      adim3: _adim3Model ?? Adim3IcEkspertizModel.empty(gorevId: _gorevId, personelId: _personelId),
      adim4: _adim4Model ?? Adim4BoyaKaportaModel.empty(gorevId: _gorevId!, personelId: _personelId!),
      adim5: _adim5Model ?? Adim5KurumsalEkspertizModel.empty(gorevId: _gorevId!, personelId: _personelId!),
      durum: 'Taslak',
      baslangicZamani: DateTime.now(), // Basitlik için
    );

    // Arka planda kaydet (UI bloklamasın)
    RaporService.saveReport(tempRapor).then((result) {
      if(!result.isSuccess) debugPrint("Taslak kayıt hatası: ${result.error}");
    });
  }

  /// Adım 1 güncelle
  void updateAdim1(Adim1AracSaticiModel model) {
    _adim1Model = model;
    _saveDraft();
    
    notifyListeners();
  }

  /// Adım 2 güncelle
  void updateAdim2(Adim2DisEkspertizModel model) {
    _adim2Model = model;
    _saveDraft();
    
    notifyListeners();
  }

  /// Adım 3 güncelle
  void updateAdim3(Adim3IcEkspertizModel model) {
    _adim3Model = model;
    _saveDraft();
    
    notifyListeners();
  }

  /// Adım 4 güncelle
  void updateAdim4(Adim4BoyaKaportaModel model) {
    _adim4Model = model;
    _saveDraft();
    
    notifyListeners();
  }

  /// Adım 5 güncelle
  void updateAdim5(Adim5KurumsalEkspertizModel model) {
    _adim5Model = model;
    _saveDraft();
    
    notifyListeners();
  }

  /// Sonraki adıma geç
  void nextStep() {
    if (_currentStep < 5) {
      _currentStep++;
      notifyListeners();
    }
  }

  /// Önceki adıma geç
  void previousStep() {
    if (_currentStep > 1) {
      _currentStep--;
      notifyListeners();
    }
  }

  /// Belirli bir adıma geç
  void goToStep(int step) {
    if (step >= 1 && step <= 5) {
      _currentStep = step;
      notifyListeners();
    }
  }
  
  /// Görevi Tamamla ve Gönder
  Future<bool> completeGorev() async {
    if (!allStepsValid) {
      setError("Lütfen tüm zorunlu alanları doldurunuz.");
      return false;
    }
    
    setLoading(true);
    try {
      
      // 1. Ham Raporu Oluştur
      var finalRapor = TamRaporModel(
        gorevId: _gorevId!,
        personelId: _personelId!,
        adim1: _adim1Model!,
        adim2: _adim2Model!,
        adim3: _adim3Model!,
        adim4: _adim4Model!,
        adim5: _adim5Model!,
        durum: 'Onay Bekliyor',
        bitisZamani: DateTime.now(),
      );

      // 2. AI Analizini Başlat
      debugPrint("🤖 AI Analizi Başlatılıyor...");
      final aiResult = await AIEngineService.analyzeReport(finalRapor);
      
      // 3. Raporu AI Sonucu ile Güncelle
      finalRapor = finalRapor.copyWith(
        aiAnalizSonucu: aiResult,
        durum: 'Onay Bekliyor'
      );

      // 4. Kalıcı Olarak Kaydet (Persistence)
      final saveResult = await RaporService.saveReport(finalRapor);
      if (!saveResult.isSuccess) throw Exception(saveResult.error);

      // Başarılı
      debugPrint("✅ Görev başarıyla tamamlandı ve kaydedildi.");
      return true;

    } catch (e) {
      setError("Görev tamamlama hatası: $e");
      return false;
    } finally {
      setLoading(false);
    }
  }

  /// Loading durumunu güncelle
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Hata mesajını ayarla
  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Hata mesajını temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Tam rapor modeli oluştur
  TamRaporModel? get tamRaporModel {
    if (_gorevId == null || _personelId == null) return null;
    if (!allStepsValid) return null;

    return TamRaporModel(
      gorevId: _gorevId!,
      personelId: _personelId!,
      adim1: _adim1Model!,
      adim2: _adim2Model!,
      adim3: _adim3Model!,
      adim4: _adim4Model!,
      adim5: _adim5Model!,
      durum: 'Onay Bekliyor',
    );
  }

  /// Tam rapor oluştur (Adım5Sayfasi için)
  TamRaporModel? tamRaporOlustur() {
    return tamRaporModel;
  }

  /// Tam raporu güncelle (Adım5Sayfasi için)
  Future<void> updateTamRapor(TamRaporModel rapor) async {
    _adim1Model = rapor.adim1;
    _adim2Model = rapor.adim2;
    _adim3Model = rapor.adim3;
    _adim4Model = rapor.adim4;
    _adim5Model = rapor.adim5;
    notifyListeners();
  }

  /// Tüm verileri sıfırla
  void reset() {
    _gorevId = null;
    _personelId = null;
    _personelAdi = null;
    _musteriAdi = null;
    _aracPlakasi = null;
    _currentStep = 1;
    _adim1Model = null;
    _adim2Model = null;
    _adim3Model = null;
    _adim4Model = null;
    _adim5Model = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Adım başlıkları
  static List<String> get stepTitles => [
        '1️⃣ Araç & Satıcı Bilgileri',
        '2️⃣ Dış Ekspertiz',
        '3️⃣ İç Ekspertiz',
        '4️⃣ Boya / Kaporta',
        '5️⃣ Kurumsal Ekspertiz',
      ];

  /// Adım ikonları
  static List<String> get stepIcons => [
        '🚗',
        '🔍',
        '💺',
        '🎨',
        '🏢',
      ];
}
