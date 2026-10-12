import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/talep_model.dart';
import '../services/talep_service.dart';
import '../core/constants/roles.dart';

/// AdminProvider: Uygulamanın Merkezi Sinir Sistemi
/// 
/// Bu provider, Müşteri (TalepService) ve Personel (RaporService) arasındaki
/// tüm iletişimi yönetir ve admin paneline
/// anlık veri akışı sağlar.
/// 
/// Görevleri:
/// 1. Talep ve Rapor süreçlerini senkronize etmek.
/// 2. Hata yönetimi ve asenkron veri akışını sağlamak.
class AdminProvider with ChangeNotifier {
  final TalepService _talepService = TalepService();
  
  // State
  List<TalepModel> _talepler = [];
  final List<String> _bildirimler = [];
  bool _isLoading = false;
  String? _error;
  
  // Görev İlerleme Takibi (talepId -> ilerlemeYuzdesi)
  final Map<String, double> _gorevIlerleme = {};

  // Getters
  List<TalepModel> get talepler => _talepler;
  List<String> get bildirimler => _bildirimler;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, double> get gorevIlerleme => _gorevIlerleme;

  /// Uygulama başlatıldığında verileri yükler
  Future<void> init() async {
    await loadTalepler();
  }

  /// Talepleri asenkron olarak çeker ve state'i günceller
  Future<void> loadTalepler() async {
    _setLoading(true);
    try {
      _talepler = await _talepService.getTalepler();
      _error = null;
    } catch (e) {
      _error = "Talepler yüklenirken hata oluştu: $e";
      debugPrint(_error);
    } finally {
      _setLoading(false);
    }
  }

  /// Müşteri yeni bir talep oluşturduğunda çağrılır
  /// Step 1: Customer → Admin (Real-time update ve notifyListeners)
  Future<bool> yeniTalepOlustur(TalepModel talep) async {
    try {
      final success = await _talepService.talepEkle(talep);
      if (success) {
        await loadTalepler(); // Listeyi anlık yenile
        _bildirimEkle("YENİ TALEP: ${talep.musteriAdi} - ${talep.aracPlaka} (${talep.musteriId})");
        notifyListeners(); // Critical: Tüm UI'ları güncelle
        debugPrint("✅ Step 1 (Customer → Admin): Talep başarıyla oluşturuldu ve notifyListeners() çağrıldı");
        return true;
      }
      return false;
    } catch (e) {
      _error = "Talep oluşturma hatası: $e";
      notifyListeners();
      debugPrint("❌ Step 1 Hatası: $e");
      return false;
    }
  }

  /// Personel bir raporu tamamladığında çağrılır (Real-time update)
  /// Bu metod 'RaporService' yerine kullanılarak merkezi yönetim sağlanır.
  /// Step 3: Personel → AI (Rapor tamamlama ve AI tetikleme)
  Future<bool> raporTamamlandi(String talepId, String personelId) async {
    _setLoading(true);
    try {
      // 1. Talebi bul ve güncelle
      final talepIndex = _talepler.indexWhere((t) => t.id == talepId);
      if (talepIndex == -1) throw Exception("Talep bulunamadı");

      final guncelTalep = TalepModel(
        id: _talepler[talepIndex].id,
        musteriAdi: _talepler[talepIndex].musteriAdi,
        musteriId: _talepler[talepIndex].musteriId, // Yeni: musteriId
        telefon: _talepler[talepIndex].telefon,
        aracPlaka: _talepler[talepIndex].aracPlaka,
        aracMarka: _talepler[talepIndex].aracMarka,
        aracModel: _talepler[talepIndex].aracModel,
        durum: "Raporlandı", // Durum güncellemesi
        olusturulma: _talepler[talepIndex].olusturulma,
        atananPersonel: personelId,
        aciklama: _talepler[talepIndex].aciklama,
        sehir: _talepler[talepIndex].sehir,
        expertizFirmasi: _talepler[talepIndex].expertizFirmasi,
        expertizPaketi: _talepler[talepIndex].expertizPaketi,
        paketFiyati: _talepler[talepIndex].paketFiyati,
        motorNo: _talepler[talepIndex].motorNo,
        hizmetBedeli: _talepler[talepIndex].hizmetBedeli, // Yeni
        toplamTutar: _talepler[talepIndex].toplamTutar, // Yeni
        hasarTutar: _talepler[talepIndex].hasarTutar, // Yeni
        isPaid: _talepler[talepIndex].isPaid, // Yeni
        // AI verileri: Henüz yapılmadı
        aiAnaliziYapildiMi: false,
        aiAnalizSonucu: null,
      );

      final updateSuccess = await _talepService.talepGuncelle(talepId, guncelTalep);
      if (!updateSuccess) throw Exception("Talep durumu güncellenemedi");

      // 2. Admin'e Anlık Bildirim Düşür
      _bildirimEkle("RAPOR GELDİ: ${guncelTalep.aracPlaka} plakalı araç için rapor tamamlandı.");
      debugPrint("✅ Step 3 (Personel → Admin): Rapor tamamlandı, AI bekleniyor");

      // Listeyi güncelle
      await loadTalepler();
      notifyListeners(); // Critical: Tüm UI'ları güncelle
      return true;

    } catch (e) {
      _error = "Rapor tamamlama işlemi başarısız: $e";
      debugPrint("❌ Step 3 Hatası: $e");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // --- Personel Yönetimi ---

  /// Yeni Personel Kaydı ve Sisteme Dahil Etme
  Future<bool> personelKaydet(String adSoyad, String email, String password) async {
    _setLoading(true);
    try {
      // AuthRepository üzerinden kayıt
      final result = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': adSoyad,
          'role': UserRole.fieldStaff.name,
        },
      );
      
      if (result.user == null) throw Exception("Kimlik sistemi kaydı başarısız.");

      // 2. Admin Bildirimi
      _bildirimEkle("YENİ PERSONEL: $adSoyad sisteme eklendi.");
      
      return true;
    } catch (e) {
      _error = "Personel kayıt hatası: $e";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // --- Görev İlerleme Takibi ---

  /// Personel formda ilerledikçe çağrılır
  /// Admin panelindeki 'İşlemdekiler' sekmesine anlık '%' ilerleme bilgisini gönderir.
  ///
  /// İlerleme Yüzdeleri:
  /// - Adım 1: 20%
  /// - Adım 2: 40%
  /// - Adım 3: 60%
  /// - Adım 4: 80%
  /// - Adım 5: 100%
  void updateGorevIlerleme(String talepId, int adim, String adimAdi) {
    final ilerlemeYuzdesi = _adimdanIlerlemeHesapla(adim);
    _gorevIlerleme[talepId] = ilerlemeYuzdesi;
    
    // Admin'e bildirim gönder
    _bildirimEkle("İLERLEME: $adimAdi tamamlandı ($ilerlemeYuzdesi%)");
    
    notifyListeners();
  }

  /// Adım numarasından ilerleme yüzdesini hesaplar
  double _adimdanIlerlemeHesapla(int adim) {
    switch (adim) {
      case 1:
        return 20.0;
      case 2:
        return 40.0;
      case 3:
        return 60.0;
      case 4:
        return 80.0;
      case 5:
        return 100.0;
      default:
        return 0.0;
    }
  }

  /// Belirli bir görevin ilerleme yüzdesini döndürür
  double? getGorevIlerleme(String talepId) {
    return _gorevIlerleme[talepId];
  }

  /// Tüm görevlerin ilerleme durumunu sıfırlar (yeni görev başladığında)
  void resetGorevIlerleme(String talepId) {
    _gorevIlerleme.remove(talepId);
    notifyListeners();
  }

  // --- Personel Atama Metodları ---

  /// Personel atama - ID Based Assignment
  /// Talepe personel atar ve listeyi günceller (Safe UI Feedback)
  Future<bool> atananPersonelGuncelle(String talepId, String personelId) async {
    _setLoading(true);
    try {
      // Atama merkezi API üzerinden yapılır; personel panelinde anında görünür.
      await _talepService.personelAta(talepId, personelId);
      await loadTalepler();
      _bildirimEkle("PERSONEL ATANDI: Talep $talepId için personel $personelId atandı");
      return true;
    } catch (e) {
      _error = "Personel atama hatası: $e";
      debugPrint(_error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // --- Yardımcı Metodlar ---

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _bildirimEkle(String mesaj) {
    // Listeye en başa ekle
    _bildirimler.insert(0, "${DateTime.now().hour}:${DateTime.now().minute} - $mesaj");
    // Sadece son 50 bildirimi tut
    if (_bildirimler.length > 50) {
      _bildirimler.removeLast();
    }
    notifyListeners();
  }
}
