# Kayıt → talep → müşteri panelinde takip

Kullanıcı düzeltmesi: önce müşteri kimliği/iletişim bilgileriyle kayıt, sonra aynı
hesaptan talep ve takip. Anonim talep izlenimi veren bağlantılar düzeltilir.

Bulgu: API zaten get_authenticated_user gerektiriyor; arayüz doğrudan talep
bağlantıları gösteriyor, guest talep sayfası kimlik kontrolünden önce paket yüklüyor,
kayıt/giriş dönüşünde seçilen talep bağlamı kayboluyordu.

- Ana sayfa/alt bilgi/hakkımızda talep CTA oturuma göre kayıt veya talebe gider.
- Doğrudan talep URL'si de guest için kayıt sayfasına gider; araç seçimi korunur.
- Oturum yokken form/paket yükleme/POST yapılmaz.
- Kayıt ve giriş ekranları arasında geçişte dönüş adresi korunur; yeni kayıt
  sonrası inceleme talebine devam ve müşteri paneli bağlantıları gösterilir.
- Üye kullanıcıya yeniden kayıt çağrısı yerine müşteri paneli sunulur.
- API'nin anonim çağrıyı servis/DB'ye ulaşmadan reddettiği ve talep sahibinin
  müşteri gövdesinden değil oturumdan geldiği mock testlerle doğrulanır.

Kanıt: yeni guest testi önce FAIL sonra PASS. 10 tarayıcı senaryosu içinde
kayıt → authenticated mock talep gönderimi → panelde aynı talebin görülmesi var.
14 backend testi (tamamı mock) PASS. SECRET_KEY yalnız test sürecinde sahte bir
değerle sağlandı; üretim anahtarı veya gerçek kayıt kullanılmadı.

Bağımsız incelemede site içi dönüş yardımcısında normalize edilmiş çift slash
kenar durumu bulundu. Node testi önce FAIL, normalize path denetimiyle PASS.
Dış URL, ters slash, kontrol karakteri ve noktalı yol dönüşleri engellenir.
Veritabanına gerçek yazım, ücretli çağrı, push veya Vercel yayını yok.
