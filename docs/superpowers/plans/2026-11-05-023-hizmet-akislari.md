# 023 — Hizmet tanıtımı ve kapalı talep akışı

Başlangıç45a2265;028/024 ve021/022 korunur. Şartname ana kök kopru/codex_icin/023-uygulama-ekspertiz-talebi-kapali.md ve TASARIM_SISTEMI.md.

- [x] Önce sözleşme ve davranış testleri: kapalı/açık kart, derin rota, sunucudan fiyat, güvenilir ödeme dönüşü, kimlikli dosya/oturum yarışı.
- [x] Hizmet repository/DTO sağlayıcıları; katalog/quote/talep/listeler/bildirimler. Fiyat hesaplama yok. Kapalı konfigürasyonda POST yok; gönderimde güncel sunucu ayarı yeniden doğrulanır.
- [x] Ortak tokenlarla Hizmetlerimiz kartları, Yerinde ekspertiz ve Uzaktan satın alma süreç sayfaları; mailto haber ver, anlaşma logosu yok.
- [x] Firma/paket öncelikli talep formu: araç,İstanbul ilçe/adres/zaman/not,quote ve sözleşmeler. Ödeme WebView yalnız fiziksel hizmet; dönüş işareti tek başına ödeme kanıtı sayılmaz, sunucu sipariş durumu doğrulanır.
- [x] Taleplerim, ekspertiz raporları/kontrol listeleri, kimlikli PDF/görsel/ZIP; bildirim/okundu. API ve oturum çekirdeğine dokunmadan api.request kullanılır.
- [x] Ana ekran/rapor Sonraki adım/profil/rotalar; varsayılan kapalıyken tanıtım görünür, ödeme/talep derin yolları kapalı.
- [x] Golden/p130 ve mevcut71testler,analyze. İnceleme,commit,köprü teslimi.

Sunucu sözleşmesi: /expertiz/notifications (genel /notifications değil); dosyalar /expertiz/media imzalı URL. Medya URLleri yalnız aynı API kökünden alınır, imzalı sorgu korunur; herhangi harici adrese oturum başlığı gönderilmez. Paket ZIP ve PDF MIME/magic doğrulanır. Request note alanı adres/zaman/notu içerir, sunucunun1000karakter sınırı doğrulanır. Ön doldurma rapor aracından gelir; rakamlar yeniden hesaplanmaz.

Eksik KDV dahil hizmet tutarı Claude009köprüsünde istendi. Alan yoksa hesaplanmış gibi gösterilmez; ilgi ucu yokken mailto taslağı yeterlidir.
