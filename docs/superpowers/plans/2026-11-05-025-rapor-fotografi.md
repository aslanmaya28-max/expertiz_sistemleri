# 025 — Ekspertiz fotoğrafından doğrulanabilir form girdisi

> Uygulayıcı: superpowers:executing-plans ile sırayla uygula; şartname kök kopru/codex_icin/025-ekspertiz-raporu-fotografi-okuma.md.

Amaç: müşterinin rapor fotoğrafını geçici bellekte okuyup kontrol edebileceği kaporta/tramer ve teknik bulgulara dönüştürmek; değerleme oranlarını değiştirmeden web/PDF raporunda kaynağı ve öncelikli uyarıyı göstermek.

Mimari: ayrı inspection_photo servisi görüntü doğrulama/dönüştürme ve sınırlı model çıktısından sorumludur. Kimlikli endpoint multipart akışını sınırlandırarak yalnız bellekte okur (UploadFile'ın diske taşan spool'u kullanılmaz). Web bileşeni sonucu müşteri onayına sunar; istek isteğe bağlı kaynak ve bulgu alanlarını taşır. Rapor zenginleştirme tek sunucu fonksiyonunda web/PDF için aynı sonucu üretir.

Sınırlar: 1–4 JPEG/PNG/HEIC, dosya başına8MB, uzun kenar2000px; günlük mevcut20çıkarım kotası; kalıcı görüntü yok; plaka/kişi çıktısı yok; bilinmeyen parça orijinal sayılmaz; oran/tramer hesabı ve uygulama/admin klasörleri değişmez. Gizli dosyalar okunmaz. Testler ybtest_025; ybapp/ybdemo'ya dokunulmaz, yerel sunucu başlatılıp durdurulmaz.

- [x] Servis: bellek içi görüntü doğrulama, küçültme, HEIC desteği; OpenRouter modeli EKSPERTIZ_OKUMA_MODEL; dayanıklı JSON + alan beyaz listesi ve Türkçe hata. Önce sahte model ve geçersiz dosya testleri.
- [x] Kimlikli multipart uç, akış ve dosya sınırları, ortak kota. Sınırlı kaynak/bulgular istek modeli; entegrasyon testleri.
- [x] Tek rapor zenginleştirme: ciddi önce doğrulama; yalnız kozmetik pazarlık; firma/tarih ve doğrulanmadı kaynağı. Değişmez senaryo ve PDF eşlik testi.
- [x] Web fotoğraf bileşeni/API tipleri, sonuç kontrol/onay, kaporta/tramer ön dolumu ve uyarılar. Next yerel rehberi, tsc ve site testleri.
- [ ] Tam Python testleri, kod incelemesi, sentetik gerçek model denemesi/maliyet, Türkçe commit ve köprü teslimi.

Karar: güncel resmi OpenRouter model sayfasına göre google/gemini-3.5-flash-lite varsayılanı kullanılacak; girdi0.30$/M, çıktı2.50$/M (5Kasım2026 inceleme). Gerçek maliyet API usage.cost alanından alınacak, tahmin gerçek ölçüm diye yazılmayacak. Kaynaklar: https://openrouter.ai/google/gemini-3.5-flash-lite ve https://openrouter.ai/docs/guides/overview/multimodal/image-understanding .

İnceleme: iki P2 doğrulandı ve kırmızı→yeşil testlerle düzeltildi. Genel olumlu alt dize filtresi olumsuz/karma ciddi bulguyu siliyordu; artık yalnız bütün cümlesi açık olumlu ifadeler elenir. Şasi numarası/VIN etiket ve değerleri tüm serbest metin çıkışlarında temizlenir. Kod incelemesi review_025 tarafından salt okunur yapıldı. Oran/tramer modülü ve uygulama/admin klasörleri değişmedi.

Canlı deneme: süreç/kullanıcı/sistem ortamında model anahtarı yok. Gizli dosya okunmadı. Hazır tools.inspection_photo_smoke betiğinin gerçek sonuç/maliyet ölçümü Claude010 köprüsünde istendi; kullanıcı010'u Claude'a yaptıracağını bildirdi. Bu bağımlılık çözülmeden gerçek model denemesi bitti denmez.
