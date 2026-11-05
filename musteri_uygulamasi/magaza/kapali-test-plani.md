# Kapalı test ve üretime geçiş

5 Kasım 2026: yeni kişisel geliştirici hesaplarında **en az 12 testçi, kesintisiz en az 14 gün katılım** şartı geçerlidir. Güvenlik payı için 15–20 gerçek testçi bulun. Bu süreyi kodla veya simülasyonla kısaltma yolu yoktur. [Resmî şartlar](https://support.google.com/googleplay/android-developer/answer/14151465?hl=tr).

## Kurucu için sıra

1. Play Console geliştirici hesabını açın; kimlik, iletişim ve cihaz doğrulamalarını tamamlayın. Gerçek kişi/kuruluş türünü doğru seçin.
2. Kredi satışı için ödeme profilini, satıcı/vergi bilgilerini ve banka hesabını tamamlayın.
3. Yeni uygulama oluşturun: YerimeBak, Türkçe, uygulama, ücretsiz indirme; paket `com.yerimebak.app`. Bu paketin sunucu Play ayarıyla aynı olduğunu doğrulayın.
4. Play App Signing'i açın. Kendi yükleme anahtarınızla AAB üretin; anahtarı ve şifreyi güvenli iki yerde yedekleyin. Geçici doğrulama anahtarını kullanmayın.
5. Ürünler: `paket1`, `paket5`, `paket10` tek seferlik/tüketilebilir ürünlerini sunucudaki ürün kimlikleriyle birebir eşleyin; fiyatları girip etkinleştirin. Play hizmet hesabının sunucu erişimi 019 dağıtımı kapsamında hazır olmalı.
6. `listeleme.md`, `veri-guvenligi.md`, `icerik-derecelendirme.md`, `hedef-kitle.md`, `uygulama-erisimi.md` alanlarını doldurun; gerçek erişim hesabını ekleyin. Gizlilik/silme bağlantılarını telefonda açıp kontrol edin.
7. Test ve yayın → Kapalı test → bir kanal oluşturun. E-posta listesine testçilerin Play Store'da kullandığı Google hesaplarını ekleyin veya bir Google Grubu seçin. Listeye eklemek katılım sayılmaz.
8. İmzalı `.aab` dosyasını bu kanala yükleyin; sürüm notu: “YerimeBak ilk kapalı test sürümü: araç analizi, kayıtlı raporlar ve Google Play kredi paketleri.” Uyarıları çözün, incelemeye gönderin ve test kanalını yayınlayın.
9. Console'daki katılım bağlantısını testçilere iletin. Her biri doğru Google hesabıyla bağlantıyı açıp **teste katılmalı**, ardından Play Store'dan yüklemelidir. Katılım tarihlerini takip edin; ortak 14 günlük pencereyi en son gerekli testçi katıldığında başlatın.
10. Gün 1–14: giriş/kayıt, ilan/elle form, analiz, PDF, kredi ve geri yükleme, tema, bağlantı kopması ve hesap silme akışlarını gerçek cihazlarda deneyin. Her geri bildirimi tarih/cihaz/sonuçla kaydedin. En az 12 kişi kesintisiz katılımcı kalsın; ayrılıp yeniden katılanın sayacı yeniden başlar.
11. Console uygunluk gösterince üretim erişimine başvurun. Gerçek test sonuçlarıyla cevaplayın. Erişim onayı otomatik garanti değildir; ardından üretim sürümünü ayrıca incelemeye gönderirsiniz.

## Testçiye gönderilecek mesaj

```text
Merhaba, YerimeBak'ın Android kapalı testine katılmanızı rica ediyorum.
Play Store'da kullandığınız Google hesabıyla şu bağlantıdan teste katılın:
[CONSOLE KATILIM BAĞLANTISI]
Ardından Play Store'dan uygulamayı yükleyin. En az 14 gün boyunca testten ayrılmayın.
İlan ekleme, araç analizi, rapor/PDF ve görünüm seçeneklerini deneyip sorunları
cihaz modeli ve kısa açıklamayla destek@yerimebak.com.tr adresine iletebilirsiniz.
Ödeme gerektiren bir adımı denemeden önce bize haber verin; gerçek ödeme yapmanız beklenmiyor.
Teşekkürler.
```

Mesaj bu görevde kimseye gönderilmedi. Google Play lisans testçileri için Console → Ayarlar → Lisans testi bölümünü ayrıca ayarlayın; normal kapalı test katılımı her satın alımı otomatik ücretsiz yapmaz.

## Takip tablosu

| Testçi takma adı | Katılım tarihi | 14. gün | Cihaz/Android | Denenen akış | Geri bildirim ve çözüm |
|---|---|---|---|---|---|
| Doldurulacak | | | | | |

## Üretim erişimi cevap taslakları

Henüz test yapılmadığından aşağıdaki köşeli alanlar gerçek verilerle doldurulmalı:

- Testçileri nasıl buldunuz? “Araç alım sürecindeki gönüllü kullanıcılar ve farklı Android cihaz kullanan tanıdıklarımızdan [SAYI] kişiyi davet ettik; [SAYI] kişi kesintisiz katıldı.”
- Kullanım/etkileşim: “Katılımcılar [GERÇEKTEN DENENEN AKIŞLAR] akışlarını denedi. Geri bildirimleri [KANAL] üzerinden topladık.”
- Geri bildirim: “[SOMUT SORUN], [CİHAZ/SÜRÜM], [DÜZELTME], [TEKRAR TEST SONUCU].”
- Hedef kullanıcı/değer: “İkinci el araç almadan önce fiyat, hasar ve pazarlık bilgisine ulaşmak isteyen kullanıcılar. YerimeBak bu bilgileri kaynaklı bir analiz raporunda birleştirir.”
- Hazır olduğuna nasıl karar verdiniz? “[GERÇEK KAPALI TEST SONUÇLARI], kritik hata kalmadığına dair [KAYITLAR] ve güncel politika/form kontrolleriyle.”

Bu cümleleri test yapılmış gibi boşlukları uydurarak göndermeyin.
