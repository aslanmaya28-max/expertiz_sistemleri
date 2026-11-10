# 040 — Flutter panel taşma denetimi

**Amaç:** 038 tasarımını ve iş kurallarını koruyarak bütün ana panel/modüllerindeki taşmaları gidermek.
**Şartname:** Kök `kopru/codex_icin/040-panel-tasma-denetimi.md`.
**Taban/dal:** `2b62f9f` / `codex/040-panel-tasma-denetimi`.

## Sınırlar
- Yalnız `expertiz_paneli/`, bu plan ve köprü kanıtları değişir; sunucu/site/Android okunur.
- API yolları/gövdeleri ve yetkiler korunur. Saha yalnız kontrol merkezini arar.
- 360×800, 768×1024, 1280×800, 1920×1080; açık+koyu; uzun Türkçe metin/büyük sayı/dolu+boş veriler.
- Testler sabit pump döngüleriyle çalışır, FlutterError/RenderFlex taşması başarısız sayılır.
- Golden dosyaları gerekçesiz güncellenmez. `.env` okunmaz; canlı API'ye yazılmaz.

## Uygulama ve kanıt
- [x] 1. Mevcut web derlemesi ve yerel sahte API ile 390/1440 önce ekran görüntüleri (72 PNG).
- [x] 2. Ortak test desteği ve dört boyut/iki tema denetimleri; bulunan kusurları kırmızı testle kaydet.
- [x] 3. Kabuk/ana sayfa, operasyon modülleri, diğer yönetim modülleri, saha ve müşteri/giriş ekranlarında dar alan/uzun içerik düzenlemeleri.
- [x] 4. Analyze temiz; 574 Flutter testi geçti; aynı veriyle 72 sonra PNG ve görsel inceleme tamamlandı. Golden değişikliği yok.
- [x] 5. Bağımsız incelemenin iki piyasa bulgusu giderildi ve tekrar incelendi; Türkçe commit ve sorun-boyut-neden-çözüm tablosuyla köprü teslimi.

## İnceleme odağı
- Metin sadece gizlenmez: uzun önemli bilgi sarılır ya da ayrıntı/tooltip ile erişilir.
- Yatay tablolar dar ekranda okunabilir kart/yerleşime geçer; eylemler erişilebilir kalır.
- Diyaloglar klavye/açık hata ve kısa ekran altında da kaydırılabilir.
- Test sağlayıcıları izinleri gevşetmez; yalnız yerel veri enjekte eder.
- Gerçek tarayıcı kanıtları her ekranın başlığıyla doğrulanır; boş/hata ekranı başarı diye kaydedilmez.
