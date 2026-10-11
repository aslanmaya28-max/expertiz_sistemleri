import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/talep_model.dart';
import '../services/talep_service.dart';
import '../services/finance_service.dart';
import '../models/finance/finance_model.dart';
import '../core/constants/roles.dart';

/// Nihai Ödeme Modeli (Checkout)
class CheckoutModel {
  final double expertizPaketFiyati;   // Kurumsal Firma Payı
  final double yerimeBakHizmetBedeli; // Bizim Gelirimiz (Baz)
  final double kdvTutari;             // Toplam KDV (%20)
  final double toplamTutar;           // Müşterinin Ödeyeceği
  final double personelHakedis;       // Personelin Payı (%25 - Hizmet Bedeli Üzerinden)
  final double sirketNetGelir;        // Şirket Kasa (Hizmet - Personel)

  CheckoutModel({
    required this.expertizPaketFiyati,
    required this.yerimeBakHizmetBedeli,
    required this.kdvTutari,
    required this.toplamTutar,
    required this.personelHakedis,
    required this.sirketNetGelir,
  });
}

/// Finansal Motor Yardımcı Sınıfı
/// Tüm finansal hesaplamalar burada merkezi olarak yapılır.
class FinancialEngine {
  static const double bazHizmetBedeli = 6500.0;
  static const double kdvOrani = 0.20;
  static const double personelPayiOrani = 0.25;

  /// İşlem maliyetlerini hesaplar (Eski metod - Geriye dönük uyumluluk için)
  static Map<String, double> hesaplaIslemMaliyetleri() {
     return hesaplaIslemMaliyetleriDetayli(0);
  }

  /// Detaylı Maliyet Hesaplama (Yeni Mimari)
  /// Müşterinin seçtiği paket fiyatını da dahile eder.
  static Map<String, double> hesaplaIslemMaliyetleriDetayli(double expertizPaketFiyati) {
    final checkout = hesaplaCheckout(expertizPaketFiyati);
    
    return {
      'bazUcret': checkout.yerimeBakHizmetBedeli,
      'expertizPaketFiyati': checkout.expertizPaketFiyati,
      'kdvTutari': checkout.kdvTutari,
      'personelPayi': checkout.personelHakedis,
      'toplamTutar': checkout.toplamTutar,
      'sirketPayi': checkout.sirketNetGelir,
    };
  }

  /// Checkout Modelini Oluştur
  static CheckoutModel hesaplaCheckout(double expertizPaketFiyati) {
    // 1. Ara Toplam (Paket + Hizmet)
    final araToplam = expertizPaketFiyati + bazHizmetBedeli;
    
    // 2. KDV Hesabı (Toplam üzerinden)
    final kdvTutari = araToplam * kdvOrani;
    
    // 3. Genel Toplam
    final toplamTutar = araToplam + kdvTutari;
    
    // 4. Personel Hakedişi (Sadece Hizmet Bedeli Üzerinden)
    // Not: Kurumsal ekspertiz ücreti "Pass-Through" maliyettir, personelle paylaşılmaz.
    final personelHakedis = bazHizmetBedeli * personelPayiOrani;
    
    // 5. Şirket Net Geliri
    final sirketNetGelir = bazHizmetBedeli - personelHakedis;

    return CheckoutModel(
      expertizPaketFiyati: expertizPaketFiyati,
      yerimeBakHizmetBedeli: bazHizmetBedeli,
      kdvTutari: kdvTutari,
      toplamTutar: toplamTutar,
      personelHakedis: personelHakedis,
      sirketNetGelir: sirketNetGelir,
    );
  }
}

/// AdminProvider: Uygulamanın Merkezi Sinir Sistemi
/// 
/// Bu provider, Müşteri (TalepService) ve Personel (RaporService) arasındaki
/// tüm iletişimi yönetir, finansal operasyonları tetikler ve admin paneline
/// anlık veri akışı sağlar.
/// 
/// Görevleri:
/// 1. Talep ve Rapor süreçlerini senkronize etmek.
/// 2. Finansal motoru tetikleyerek hakediş ve ödemeleri hesaplamak.
/// 3. Hata yönetimi ve asenkron veri akışını sağlamak.
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

  /// Admin bir talebi/raporu onayladığında FİNANSAL MOTOR devreye girer.
  Future<bool> talepOnaylaVeFinansallastir(String talepId) async {
    _setLoading(true);
    try {
      final talep = _talepler.firstWhere((t) => t.id == talepId);
      
      // 1. Finansal Hesaplamalar (Helper Class)
      // Yeni: Paketin fiyatını modele göre çekiyoruz (Varsayılan 0 olabilir)
      final maliyetler = FinancialEngine.hesaplaIslemMaliyetleriDetayli(talep.paketFiyati);

      debugPrint("--- FİNANSAL İŞLEM MOTORU (DETAYLI) ---");
      debugPrint("Baz Hizmet Bedeli: ${maliyetler['bazUcret']} TL");
      debugPrint("Ekspertiz Paketi: ${maliyetler['expertizPaketFiyati']} TL");
      debugPrint("KDV (%20): ${maliyetler['kdvTutari']} TL");
      debugPrint("TOPLAM TAHSİLAT: ${maliyetler['toplamTutar']} TL");
      debugPrint("Personel Payı: ${maliyetler['personelPayi']} TL");
      debugPrint("-------------------------------");

      // 2. Ödeme Kaydı (FinanceService Entegrasyonu)
      final odeme = Odeme(
        id: "payment_${DateTime.now().millisecondsSinceEpoch}",
        amount: maliyetler['toplamTutar']!, // Müşteriden Çekilen Toplam
        customerID: talep.musteriAdi,
        staffID: talep.atananPersonel ?? "Bilinmiyor",
        reportID: talepId,
        // Komisyon oranı: (Sirket Net + Personel Payi) / Toplam Tutar.
        // Veya basitleştirilmiş bir oran verebiliriz.
        // Burada FinanceService'in otomatik hesaplamaları için yüzdesel bir değer girmek gerekebilir
        // Ancak tutar bazlı çalıştığımız için yüzdeyi hesaplayıp gönderelim.
        commission: 0, // Mock, veya hesaplanabilir
        status: "Beklemede",
        olusturmaTarihi: DateTime.now(),
        odemeYontemi: "Kredi Kartı", 
      );
      
      await FinanceService().odemeEkle(odeme);

      // 3. Personel Hakediş Kaydı
      final hakedis = PersonelHakedis(
        id: "hakedis_${DateTime.now().millisecondsSinceEpoch}",
        personelID: talep.atananPersonel ?? "Sistem",
        odemeID: odeme.id,
        reportID: talepId,
        hakedisTutari: maliyetler['personelPayi']!,
        kazanimTarihi: DateTime.now(),
        durum: "bekleniyor",
      );

      await FinanceService().hakedisEkle(hakedis);

      // 4. Talep Durumunu Güncelle
      final onayliTalep = TalepModel(
        id: talep.id,
        musteriAdi: talep.musteriAdi,
        musteriId: talep.musteriId, // Yeni: musteriId
        telefon: talep.telefon,
        aracPlaka: talep.aracPlaka,
        aracMarka: talep.aracMarka,
        aracModel: talep.aracModel,
        durum: "Tamamlandi", // Yeni: "Tamamlandi" → Müşteri erişimi açılacak
        olusturulma: talep.olusturulma,
        atananPersonel: talep.atananPersonel,
        aciklama: talep.aciklama,
        sehir: talep.sehir,
        expertizFirmasi: talep.expertizFirmasi,
        expertizPaketi: talep.expertizPaketi,
        paketFiyati: talep.paketFiyati,
        motorNo: talep.motorNo,
        hizmetBedeli: talep.hizmetBedeli, // Yeni
        toplamTutar: talep.toplamTutar, // Yeni
        hasarTutar: talep.hasarTutar, // Yeni
        isPaid: talep.isPaid, // Yeni
        // AI verileri: Admin onayı ile birlikte yapılmış varsayalım
        aiAnaliziYapildiMi: true, // Yeni
        aiPiyasaDegeri: talep.aiPiyasaDegeri, // Yeni
        aiOnerilenAlimFiyati: talep.aiOnerilenAlimFiyati, // Yeni
        aiAltiAylikGetiri: talep.aiAltiAylikGetiri, // Yeni
        aiBirYillikGetiri: talep.aiBirYillikGetiri, // Yeni
        aiYorumu: talep.aiYorumu, // Yeni
        aiDegerKaybi: talep.aiDegerKaybi, // Yeni
        aiNetKarPotansiyeli: talep.aiNetKarPotansiyeli, // Yeni
        aiAnalizSonucu: talep.aiAnalizSonucu, // Yeni
      );
      
      await _talepService.talepGuncelle(talepId, onayliTalep);
      
      _bildirimEkle("✅ TAMAMLANDI: ${talep.aracPlaka} için rapor tamamlandı, müşteri erişimi açıldı");
      _bildirimEkle("FİNANS ONAYI: ${talep.aracPlaka} için ${maliyetler['toplamTutar']!.toStringAsFixed(2)} TL faturalandırıldı.");
      debugPrint("✅ Step 4 (Admin → Customer): Durum 'Tamamlandi', AI sonuçları dahil edildi, müşteri erişimi açık");
      await loadTalepler();
      return true;

    } catch (e) {
      _error = "Finansal işlem hatası: $e";
      debugPrint(_error);
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
