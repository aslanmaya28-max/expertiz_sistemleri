import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/expertiz/adim1_arac_satici_model.dart';
import '../../models/expertiz/adim2_dis_ekspertiz_model.dart';
import '../../models/expertiz/adim3_ic_ekspertiz_model.dart';
import '../../models/expertiz/adim4_boya_kaporta_model.dart';
import '../../models/expertiz/adim5_kurumsal_ekspertiz_model.dart';
import '../../models/expertiz/tam_rapor_model.dart';
import '../../models/arac_rapor_model.dart';
import '../../models/ai/ai_skor_model.dart';
import '../../models/ai/ai_oneri_model.dart';
import '../../models/ai/ai_analiz_sonucu_model.dart';
import '../../models/ai/ai_rapor_ozeti_model.dart';
import '../market_radar_service.dart';
import '../rapor_service.dart';
import '../../core/constants/vehicle_packages.dart';
import 'ai_oneri_service.dart';

/// AI ANALİZ SERVİS - TEK ÇATI ALTINDA TÜM AI FONKSİYONLARI
/// 
/// THE ROLEX TOTAL INTEGRATION PROTOCOL
/// 
/// Bu servis tüm AI analizlerini koordine eder:
/// 1. Fotoğraf Analizi (AIFotografAnalizService)
/// 2. Teknik Puanlama (AIPuanlamaService)
/// 3. Hüküm ve Tavsiye (AIOneriService & AIEngineService)
/// 4. Finansal Öngörü (AIEngineService - MarketRadar entegrasyonu)
/// 5. Görselleştirme (AIAnalizSonucu → AIWidget'lar)
/// 
/// KULLANIM:
/// final sonuc = await AIAnalizService.analizEt(rapor: tamRapor);
class AIAnalizService {
  
  // =====================================================
  // GLM-4.7 API CONFIGURATION
  // =====================================================
  static const String _glmApiUrl = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  static String? _apiKey; // Environment variable'dan alacak
  
  /// API Key'i ayarla (Çevre değişkenlerinden veya runtime'da)
  static void setApiKey(String apiKey) {
    _apiKey = apiKey;
    debugPrint('✅ GLM-4.7 API Key ayarlandı');
  }
  
  /// =====================================================
  // GLM-4.7 API CALL
  // =====================================================
  
  /// Gerçek GLM-4.7 API çağrısı yap
  /// 
  /// Prompt mühendisliği ile araç değerleme analizi
  static Future<Map<String, dynamic>> _callGLMAPI({
    required String marka,
    required String model,
    required String yil,
    required int km,
    required List<String> hasarKayitlar,
    required Map<String, bool> donanimlar,
    required List<String> boyaliParcalar,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('GLM-4.7 API Key ayarlanmadı. Lütfen setApiKey() çağırın.');
    }
    
    // Sistem prompt'u
    const systemPrompt = '''Sen uzman bir araç değerleme uzmanısın. Verilen araç bilgilerine analiz yaparak şu değerleri JSON formatında döndür:

{
  "piyasaDegeri": 350000,
  "onerilenAlimFiyati": 330000,
  "degerKaybiYuzde": 5.5,
  "altiAylikGetiri": 20000,
  "birYillikGetiri": 35000,
  "genelPuan": 85,
  "aracDurumuPuan": 88,
  "motorMekanikPuan": 82,
  "hasarPuan": 75,
  "onayRedOnerisi": "Alınması önerilir",
  "genelSonuc": "İyi",
  "anahtarBulgular": ["Bulg 1", "Bulg 2"],
  "ozetAciklama": "Detaylı açıklama"
}

Kurallar:
- Tüm değerler sayısal olmalı (int veya double)
- JSON formatı kesin olmalı
- Türk Lirası cinsinden değerler
- Puanlar 0-100 arası
- Değer kaybı yüzde olmalı''';

    // User prompt'u - araç bilgileri
    final userPrompt = '''Aşağıdaki aracı analiz et:
Marka: $marka
Model: $model
Yıl: $yil
KM: $km
Hasar Kayıtları: ${hasarKayitlar.isEmpty ? "Yok" : hasarKayitlar.join(", ")}
Boyalı Parçalar: ${boyaliParcalar.isEmpty ? "Yok" : boyaliParcalar.join(", ")}
Donanımlar: ${donanimlar.isEmpty ? "Standart" : donanimlar.keys.join(", ")}

JSON formatında değerleme yap.''';

    try {
      debugPrint('🔄 GLM-4.7 API çağrısı başlatılıyor...');
      
      final response = await http.post(
        Uri.parse(_glmApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'glm-4-flash', // veya 'glm-4-plus'
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.3,
          'top_p': 0.7,
          'max_tokens': 2000,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('API isteği zaman aşımına uğradı (30sn)');
        },
      );

      debugPrint('GLM-4.7 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final content = responseData['choices'][0]['message']['content'];
        
        // JSON içeriğini parse et
        String jsonContent = content;
        if (content.contains('```json')) {
          jsonContent = content.split('```json')[1].split('```')[0].trim();
        } else if (content.contains('```')) {
          jsonContent = content.split('```')[1].split('```')[0].trim();
        }
        
        final aiResult = jsonDecode(jsonContent) as Map<String, dynamic>;
        
        debugPrint('✅ GLM-4.7 API analizi tamamlandı');
        return aiResult;
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception('GLM-4.7 API Hatası: ${errorBody['error']['message']}');
      }
    } catch (e) {
      debugPrint('❌ GLM-4.7 API çağrısı başarısız: $e');
      rethrow;
    }
  }
  
  /// =====================================================
  // MASTER ANALİZ METODU (GLM-4.7 + Supabase Entegrasyonlu)
  // =====================================================
  
  /// ✅ REAL GLM-4.7 API ANALİZİ
  /// 
  /// Tam analiz yapar ve sonucu Supabase'e kaydeder
  static Future<AIAnalizSonucu> analizEtVeKaydet({
    required String raporId, // AracRapor ID
    required String marka,
    required String model,
    required String yil,
    required int km,
    required List<String> hasarKayitlar,
    required Map<String, bool> donanimlar,
    required List<String> boyaliParcalar,
  }) async {
    try {
      debugPrint('🔄 GLM-4.7 AI analizi başlatılıyor...');
      
      // 1. GLM-4.7 API çağrısı yap
      final aiResult = await _callGLMAPI(
        marka: marka,
        model: model,
        yil: yil,
        km: km,
        hasarKayitlar: hasarKayitlar,
        donanimlar: donanimlar,
        boyaliParcalar: boyaliParcalar,
      );
      
      // 2. AIAnalizSonucu oluştur
      final analizSonucu = AIAnalizSonucu(
        gorevId: raporId,
        skorlar: AISkorModel(
          genelPuan: (aiResult['genelPuan'] as num).toDouble(),
          aracDurumuPuan: (aiResult['aracDurumuPuan'] as num).toDouble(),
          motorMekanikPuan: (aiResult['motorMekanikPuan'] as num).toDouble(),
          hasarPuan: (aiResult['hasarPuan'] as num).toDouble(),
          detayliPuanlar: {},
        ),
        oneriler: [],
        raporOzeti: AIRaporOzetiModel(
          genelSonuc: aiResult['genelSonuc'] as String,
          anahtarBulgular: List<String>.from(aiResult['anahtarBulgular'] as List),
          ozetAciklama: aiResult['ozetAciklama'] as String,
          onayRedOnerisi: aiResult['onayRedOnerisi'] as String,
          tahminiDeger: (aiResult['piyasaDegeri'] as num).toDouble(),
          degerKaybiYuzde: (aiResult['degerKaybiYuzde'] as num).toDouble(),
          degerProjeksiyonu1Yil: (aiResult['birYillikGetiri'] as num).toDouble(),
          altiAylikGetiri: (aiResult['altiAylikGetiri'] as num).toDouble(),
        ),
        kritikSorunlar: [],
        fotografAnalizi: {},
        tamamlandiMi: true,
        analizZamani: DateTime.now(),
        finansalProjeksiyonlar: {
          'ai_piyasa_degeri': aiResult['piyasaDegeri'],
          'ai_onerilen_alim_fiyati': aiResult['onerilenAlimFiyati'],
          'ai_alti_aylik_getiri': aiResult['altiAylikGetiri'],
          'ai_bir_yillik_getiri': aiResult['birYillikGetiri'],
          'ai_deger_kaybi': aiResult['degerKaybiYuzde'],
        },
      );
      
      // 3. ✅ SUPABASE'E KAYDET
      if (RaporService.isSupabaseAvailable) {
        await _kaydetSupabaseye(raporId, analizSonucu);
      }
      
      return analizSonucu;
    } catch (e) {
      debugPrint('❌ AI analizi başarısız: $e');
      
      // Hata durumunda boş sonuç döndür
      return AIAnalizSonucu(
        gorevId: raporId,
        skorlar: AISkorModel(
          genelPuan: 0.0,
          aracDurumuPuan: 0.0,
          motorMekanikPuan: 0.0,
          hasarPuan: 0.0,
          detayliPuanlar: {},
        ),
        oneriler: [],
        raporOzeti: AIRaporOzetiModel(
          genelSonuc: 'Hata',
          anahtarBulgular: ['AI analizi başarısız'],
          ozetAciklama: e.toString(),
          onayRedOnerisi: 'Tekrar deneyin',
          tahminiDeger: 0.0,
          degerKaybiYuzde: 0.0,
          degerProjeksiyonu1Yil: 0.0,
          altiAylikGetiri: 0.0,
        ),
        kritikSorunlar: ['AI Hatası'],
        fotografAnalizi: {},
        tamamlandiMi: false,
        hataMesaji: e.toString(),
      );
    }
  }
  
  /// ✅ SUPABASE'E KAYDETME DÖNGÜSÜ
  /// 
  /// AI analiz sonucunu Supabase reports tablosuna yazar
  static Future<void> _kaydetSupabaseye(String raporId, AIAnalizSonucu analizSonucu) async {
    try {
      // 1. Raporu getir
      final raporResult = await RaporService.getReportByIdFromSupabase(raporId);
      if (!raporResult.isSuccess) {
        throw Exception('Rapor bulunamadı: ${raporResult.error}');
      }
      
      final rapor = raporResult.data!;
      
      // 2. AI analiz alanlarını güncelle
      final updatedRapor = AracRapor(
        id: rapor.id,
        musteriId: rapor.musteriId,
        personelId: rapor.personelId,
        olusturmaTarihi: rapor.olusturmaTarihi,
        guncellemeTarihi: DateTime.now(),
        durum: rapor.durum,
        status: 'pending_admin',
        isPaid: rapor.isPaid,
        vehicleId: rapor.vehicleId,
        ilanLinki: rapor.ilanLinki,
        plaka: rapor.plaka,
        marka: rapor.marka,
        model: rapor.model,
        yil: rapor.yil,
        renk: rapor.renk,
        km: rapor.km,
        sehir: rapor.sehir,
        ilce: rapor.ilce,
        ekspertizFirmasi: rapor.ekspertizFirmasi,
        secilenPaket: rapor.secilenPaket,
        hizmetBedeli: rapor.hizmetBedeli,
        paketFiyati: rapor.paketFiyati,
        toplamTutar: rapor.toplamTutar,
        hasarTutar: rapor.hasarTutar,
        olusturanKullanici: rapor.olusturanKullanici,
        
        // ✅ AI ANALİZ SONUÇLARI
        aiAnaliziYapildiMi: true,
        aiPiyasaDegeri: analizSonucu.raporOzeti.tahminiDeger,
        aiOnerilenAlimFiyati: analizSonucu.raporOzeti.tahminiDeger * 0.95, // %5 altı
        aiAltiAylikGetiri: analizSonucu.raporOzeti.altiAylikGetiri,
        aiBirYillikGetiri: analizSonucu.raporOzeti.degerProjeksiyonu1Yil,
        aiYorumu: analizSonucu.raporOzeti.ozetAciklama,
        aiDegerKaybi: analizSonucu.raporOzeti.degerKaybiYuzde,
        aiEnflasyonTahmini12Ay: 10.0, // Varsayılan
        aiNetKarPotansiyeli: analizSonucu.raporOzeti.degerProjeksiyonu1Yil,
        
        // ✅ JSONB ALANLAR
        data: rapor.data,
        aiAnalizDetay: analizSonucu.toJson(), // JSONB olarak kaydet
        aiAnalizSonucu: analizSonucu,
        
        piyasaDegeriSistem: rapor.piyasaDegeriSistem,
        piyasaDegeriAyarlamalar: rapor.piyasaDegeriAyarlamalar,
      );
      
      // 3. Supabase'e kaydet
      final saveResult = await RaporService.saveReportToSupabase(updatedRapor);
      if (!saveResult.isSuccess) {
        throw Exception('Supabase kayıt hatası: ${saveResult.error}');
      }
      
      debugPrint('✅ AI analizi Supabase\'e kaydedildi: $raporId');
    } catch (e) {
      debugPrint('❌ Supabase kayıt hatası: $e');
      rethrow;
    }
  }
  
  /// @deprecated Use [analizEtVeKaydet] instead.
  /// Legacy metod — sadece geriye dönük uyumluluk için tutuluyor.
  @Deprecated('Use analizEtVeKaydet() instead')
  static Future<AIAnalizSonucu> analizEt({
    required String gorevId,
    required Adim1AracSaticiModel adim1,
    required Adim2DisEkspertizModel adim2,
    required Adim3IcEkspertizModel adim3,
    required Adim4BoyaKaportaModel adim4,
    required Adim5KurumsalEkspertizModel adim5,
  }) async {
    // Legacy metod — analizEtVeKaydet'e yönlendir
    return analizEtVeKaydet(
      raporId: gorevId,
      marka: adim1.marka,
      model: adim1.model,
      yil: DateTime.now().year.toString(),
      km: adim1.guncelKm,
      hasarKayitlar: adim4.hasarKayitlari.map((h) => h.konum).toList(),
      donanimlar: {},
      boyaliParcalar: adim4.boyaliParcalar,
    );
  }

  /// @deprecated Use [analizEtVeKaydet] instead.
  @Deprecated('Use analizEtVeKaydet() instead')
  static Future<AIAnalizSonucu> analizEtTamRapor(TamRaporModel tamRapor) async {
    if (!tamRapor.isValid) {
      return AIAnalizSonucu.empty(gorevId: tamRapor.gorevId);
    }
    return analizEtVeKaydet(
      raporId: tamRapor.gorevId,
      marka: tamRapor.adim1.marka,
      model: tamRapor.adim1.model,
      yil: DateTime.now().year.toString(),
      km: tamRapor.adim1.guncelKm,
      hasarKayitlar: tamRapor.adim4.hasarKayitlari.map((h) => h.konum).toList(),
      donanimlar: {},
      boyaliParcalar: tamRapor.adim4.boyaliParcalar,
    );
  }


  /// Fotoğrafları adımlardan çıkar
  // ignore: unused_element
  static List<String> _extractPhotographs(
    Adim2DisEkspertizModel adim2,
    Adim3IcEkspertizModel adim3,
  ) {
    List<String> fotografListesi = [];
    
    if (adim2.fotografUrl != null) {
      for (final urlListesi in adim2.fotografUrl!.values) {
        fotografListesi.addAll(urlListesi.where((url) => url.isNotEmpty));
      }
    }
    
    if (adim3.fotografUrl != null) {
      for (final urlListesi in adim3.fotografUrl!.values) {
        fotografListesi.addAll(urlListesi.where((url) => url.isNotEmpty));
      }
    }
    
    return fotografListesi;
  }

  /// Rapor özeti üret (AIEngine ile zenginleştirilmiş)
  // ignore: unused_element
  static AIRaporOzetiModel _uretRaporOzeti({
    required Adim1AracSaticiModel adim1,
    required Adim2DisEkspertizModel adim2,
    required Adim3IcEkspertizModel adim3,
    required Adim4BoyaKaportaModel adim4,
    required Adim5KurumsalEkspertizModel adim5,
    required AISkorModel skorlar,
    required List<AIOneriModel> oneriler,
    required String onayRedOnerisi,
    required Map<String, dynamic> fotografAnalizi,
    required AIAnalizSonucu aiEngineSonuc,
  }) {
    // Genel sonucu belirle
    String genelSonuc = aiEngineSonuc.raporOzeti.genelSonuc;
    List<String> anahtarBulgular = List.from(aiEngineSonuc.raporOzeti.anahtarBulgular);
    String ozetAciklama = aiEngineSonuc.raporOzeti.ozetAciklama;

    // Ek bulgular ekle
    if (skorlar.genelPuan >= 90) {
      genelSonuc = 'Mükemmel';
    } else if (skorlar.genelPuan >= 80) {
      genelSonuc = 'Çok İyi';
    } else if (skorlar.genelPuan >= 70) {
      genelSonuc = 'İyi';
    } else if (skorlar.genelPuan >= 60) {
      genelSonuc = 'Orta';
    } else if (skorlar.genelPuan >= 50) {
      genelSonuc = 'Yeterli';
    } else {
      genelSonuc = 'Yetersiz';
    }

    // Puan detayları
    anahtarBulgular.add('Genel Puan: ${skorlar.genelPuan.toStringAsFixed(1)}/100');
    anahtarBulgular.add('Araç Durumu Puanı: ${skorlar.aracDurumuPuan.toStringAsFixed(1)}/100');
    anahtarBulgular.add('Motor/Mekanik Puanı: ${skorlar.motorMekanikPuan.toStringAsFixed(1)}/100');
    anahtarBulgular.add('Hasar Puanı: ${skorlar.hasarPuan.toStringAsFixed(1)}/100');

    if (adim4.hasarSayisi > 0) {
      anahtarBulgular.add('Hasar Sayısı: ${adim4.hasarSayisi}');
    }

    if (adim1.hasarKayitAdet != null && adim1.hasarKayitAdet! > 0) {
      anahtarBulgular.add('Hasar Kaydı: ${adim1.hasarKayitAdet} adet');
    }

    // Önerileri ekle
    int kritikOneriSayisi = oneriler.where((o) => o.kategori == 'Kritik').length;
    int onemliOneriSayisi = oneriler.where((o) => o.kategori == 'Önemli').length;

    if (kritikOneriSayisi > 0) {
      anahtarBulgular.add('$kritikOneriSayisi adet kritik öneri');
    }

    if (onemliOneriSayisi > 0) {
      anahtarBulgular.add('$onemliOneriSayisi adet önemli öneri');
    }

    // Tahmini piyasa fiyatı hesapla (MarketRadarService ile senkronize)
    double tahminiDeger = _hesaplaTahminiDeger(adim1, adim3, adim4, skorlar);

    // Değer kaybı hesapla
    double degerKaybiYuzde = AIOneriService.hesaplaDegerKaybi(
      adim4: adim4,
      piyasaFiyati: tahminiDeger,
    );

    // 1 yıllık değer projeksiyonu hesapla (%10 enflasyon korumalı)
    double degerProjeksiyonu1Yil = AIOneriService.hesaplaDegerProjeksiyonu(
      mevcutDeger: tahminiDeger,
      enflasyonOrani: 10.0,
      yilSayisi: 1,
    );

    return AIRaporOzetiModel(
      genelSonuc: genelSonuc,
      anahtarBulgular: anahtarBulgular,
      ozetAciklama: ozetAciklama,
      onayRedOnerisi: onayRedOnerisi,
      tahminiDeger: tahminiDeger,
      degerKaybiYuzde: degerKaybiYuzde,
      degerProjeksiyonu1Yil: degerProjeksiyonu1Yil,
      altiAylikGetiri: degerProjeksiyonu1Yil / 2, // 6 ay ≈ yarısı
    );
  }

  /// Tahmini piyasa fiyatı hesapla (MarketRadarService ile senkronize)
  static double _hesaplaTahminiDeger(
    Adim1AracSaticiModel adim1,
    Adim3IcEkspertizModel adim3,
    Adim4BoyaKaportaModel adim4,
    AISkorModel skorlar,
  ) {
    // Donanım seçeneklerini oluştur (Adim3IcEkspertizModel'den)
    Map<String, bool> selectedOptions = {};
    
    // Koltuklar
    if (adim3.onKoltuklar != null) {
      selectedOptions[adim3.onKoltuklar!] = true;
    }
    if (adim3.arkaKoltuklar != null) {
      selectedOptions[adim3.arkaKoltuklar!] = true;
    }
    // Pencereler
    if (adim3.onPencereler != null) {
      selectedOptions[adim3.onPencereler!] = true;
    }
    if (adim3.arkaPencereler != null) {
      selectedOptions[adim3.arkaPencereler!] = true;
    }
    // Camlar
    if (adim3.camlar != null) {
      selectedOptions[adim3.camlar!] = true;
    }
    // Elektronik donanımlar
    if (adim3.klima != null) {
      selectedOptions[adim3.klima!] = true;
    }
    if (adim3.sesSistemi != null) {
      selectedOptions[adim3.sesSistemi!] = true;
    }
    if (adim3.gostergePaneli != null) {
      selectedOptions[adim3.gostergePaneli!] = true;
    }
    if (adim3.merkeziKilit != null) {
      selectedOptions[adim3.merkeziKilit!] = true;
    }
    if (adim3.camKontrolleri != null) {
      selectedOptions[adim3.camKontrolleri!] = true;
    }
    if (adim3.aynaKontrolleri != null) {
      selectedOptions[adim3.aynaKontrolleri!] = true;
    }

    // Boyalı ve hasarlı parçaları oluştur (Adim4BoyaKaportaModel'den)
    List<String> paintedParts = adim4.boyaliParcalar;
    List<String> damagedParts = adim4.hasarKayitlari.map((h) => h.konum).toList();

    // Paket ağırlığını al (varsayılan 1.0)
    double packageWeight = 1.0;
    String packageLevel = 'Standart';
    
    if (adim1.paket != null && adim1.paket!.isNotEmpty) {
      packageWeight = VehiclePackagesDatabase.getPackageWeight(adim1.paket!);
      packageLevel = adim1.paket!;
    }

    // MarketRadarService ile entegre fiyat hesapla
    final piyasaRaporu = MarketRadarService.calculateIntegratedValue(
      brand: adim1.marka,
      model: adim1.model,
      year: 2020,
      km: adim1.guncelKm,
      color: 'Beyaz',
      packageLevel: packageLevel,
      packageWeight: packageWeight,
      selectedOptions: selectedOptions,
      paintedParts: paintedParts,
      damagedParts: damagedParts,
      marketSource: null,
    );

    // AI puanına göre fiyat ayarı yap
    double aiFiyatAyarlamasi = (skorlar.genelPuan / 100.0) * (piyasaRaporu['basePrice'] as double);
    double tahminiDeger = (piyasaRaporu['finalPrice'] as double) + aiFiyatAyarlamasi;

    return tahminiDeger.clamp(0.0, double.infinity);
  }

  /// Analiz durumunu kontrol et
  static bool analizTamamlandiMi(TamRaporModel tamRapor) {
    return tamRapor.aiAnalizSonucu?.tamamlandiMi ?? false;
  }

  /// Analiz sonucunu rapora kaydet
  static TamRaporModel kaydetAnalizSonucu(TamRaporModel tamRapor, AIAnalizSonucu analizSonucu) {
    return tamRapor.copyWith(
      aiAnalizSonucu: analizSonucu,
    );
  }

  /// Analiz sonucunu rapordan sil
  static TamRaporModel silAnalizSonucu(TamRaporModel tamRapor) {
    return tamRapor.copyWith(
      aiAnalizSonucu: null,
    );
  }

  /// Analiz sonucunu güncelle
  static TamRaporModel guncelleAnalizSonucu(TamRaporModel tamRapor, AIAnalizSonucu analizSonucu) {
    return tamRapor.copyWith(
      aiAnalizSonucu: analizSonucu,
    );
  }
}
