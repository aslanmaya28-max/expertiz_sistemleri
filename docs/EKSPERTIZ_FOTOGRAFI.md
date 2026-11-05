# Ekspertiz raporu fotoğrafı (025)

Müşteri sitesinde Araç Değerleme → “Ekspertiz raporunuz var mı? Fotoğrafını yükleyin”. Okunan bilgiler önce listelenir; müşteri onaylayınca kaporta şemasına/tramer alanına aktarılır. Okunmayan parça “Belirtilmedi” kalır. Müşteri eksik parçaları ve trameri kendisi doğrulamadan analiz gönderilmez. Fotoğraftan okunan ciddi bulgular ayrıca uyarılır.

## API

`POST /api/v1/valuation/inspection-photo`: Bearer oturumu; multipart dosya alanı `files` (1–4 dosya). Her dosya en fazla8MiB, JPEG/PNG/HEIC; en fazla40MP. Metadata atılır, uzun kenar2000px'e küçültülür ve JPEG olarak modele gönderilir. Akış bellekte sınırlandırılır; UploadFile/spool, görsel arşivi veya görüntü önbelleği kullanılmaz. Boş/yanlış biçim422, büyük413, kotada429, model yapılandırılmamışsa503, sağlayıcı hatasında502. Günlük20çıkarım kotası ilan/metin çıkarımıyla ortaktır.

Yanıt: `success`, `found`, `parts`, `tramer_amount`, `tramer_count`, `bulgular`, `firma_adi`, `rapor_tarihi`, `okunamayan_alanlar`, `message`, `scope`. Bulunmayan alan null/boş kalır; bilinmeyen parça eklenmez. Plaka/kişi alanları istenmez, çıktı beyaz listeyle sınırlanır; bilinen kişisel etiketler, VIN/plaka/telefon/e-posta çıktı sınırında ayıklanır. Müşteri yüklemeden önce kişisel alanları kapatmalıdır. Görüntü okuma için OpenRouter/model sağlayıcısına aktarılır; uygulamanın kalıcı görsel saklamaması sağlayıcının kendi veri şartları yerine geçmez.

`OPENROUTER_API_KEY` yetkili süreç ortamından sağlanır. `EKSPERTIZ_OKUMA_MODEL` isteğe bağlı; varsayılan `google/gemini-3.5-flash-lite`. `scope.cost_usd` sağlayıcının bildirdiği kullanım maliyetidir; sağlayıcı vermezse null olur, tahmini ücret gerçek ölçüm diye sunulmaz. Next yerel vekilinin tampon sınırı33MB; API kendi daha sıkı toplam/dosya sınırlarını uygular. Üretimde tarayıcı doğrudan API alanına bağlanabilir.

## Değerleme ve rapor

`/valuation/analyze` isteğine isteğe bağlı `kaynak_turu` (`ekspertiz_raporu|ilan|musteri`), `bulgular`, `ekspertiz_firma_adi`, `ekspertiz_rapor_tarihi` eklenmiştir. Eski istekler değişmez. Bulgular sunucuda tekrar temizlenir; motor/şanzıman/şasi/hava yastığı/ağır hasar ciddi olarak ele alınır. Yalnız `pazarlik` bulguları gerekçelere girer; ciddi bulgu varsa ilk adım yerinde doğrulamadır. Oranlar, tramer hesabı ve fiyatlar değiştirilmez; yeni bulgudan ek parasal indirim hesaplanmaz. Kalıcı tek rapor JSON'u web/PDF için aynı kaynak açıklaması ve bulguları taşır.

## Doğrulama

`PYTHON_DOTENV_DISABLED=1` ile ağsız birim/entegrasyon testleri; ayrı ybtest_025 veritabanında tüm test kapısı. Gerçek model denemesi için, anahtar zaten süreçte tanımlıyken `musteri_paneli` içinde `python -m tools.inspection_photo_smoke`. Betik kişisel verisiz sentetik raporu bellekte üretir ve teknik çıktı/maliyeti yazdırır; gizli dosya okumaz, fotoğrafı diske yazmaz.
