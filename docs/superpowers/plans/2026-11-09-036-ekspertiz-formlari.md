# 036 — Site ve uygulamada ekspertiz talebi

Şartname: `kopru/codex_icin/036-ekspertiz-talep-formlari.md`.
Bağlayıcı API sözleşmesi: `kopru/sozlesme-ekspertiz-2026-11-09.md` bölüm1,2,5.
Taban6a93f00; API kodu Claude'da. İstemciler API yanıtını sahteleyen testlerle geliştirilir.

## Tasarım ve sınırlar
İl yetkisini yalnız sunucunun `talep_acabilir` alanı belirler. Global bayrak kapalıyken
test hesabına açık bir il varsa form görünür; açık il yoksa mevcut yakında kartı.
Randevu İstanbul duvar saati; cihaz saat dilimi serileştirmeyi/gösterimi değiştirmez.
Ayrı bulunamama onayı metni aynen korunur. Müşteri ödemeli akışı kullanır; tester
seçeneği yalnız service-area tester:true yanıtında görünür. Sunucu hataları ilgili alanlarda.

## İş birimleri
1. Web: API modelleri/yetki sorgusu, form alanları + doğrulama + PayTR yönlendirmesi,
   panel randevu/durum gösterimi ve yanlış randevu vaatlerinin düzeltilmesi.
2. Flutter: aynı model/repo/provider, yönlendirme görünürlüğü, form ve alan hataları,
   mevcut WebView ödemesi, kayıt listesi/detayı ve metin düzeltmeleri.
3. Ortak doğrulama: kodlu422hatalar, kapalı ve test illeri, iki saat/30gün sınırı,
   cihazın farklı saat dilimi, ayrı onay, alınan randevunun aynen gösterilmesi.
4. Web390/1440 ve uygulama görsel kanıtı, tsc/node/flutter kapısı ve bağımsız inceleme.

Web ve Flutter dosyaları bağımsız yardımcı ajanlara ayrıldı; ana ajan API sözleşmesi,
test/görsel entegrasyonu ve teslimi yönetir. Ortak kaynak dosyaları yazılmaz.
Mevcut tasarım ve ödeme akışlarını genişletmek uygun yaklaşımdır; yeni form/ödeme
altyapısı veya istemcide il politikası yazılmaz. Yeni bağımlılık yok, server/panel yok.

## İnceleme odağı
APIhatanıncodealanıkaybolmasın; eskitest/listeverisinde randevuyoksa gizlensin;
manuelkapalıilURL/önbilgiyle gelirse ödemeengellensin; testbayrağından ilyetkisi
yerelhesaplanmasın; datetime-localtarayıcıtimezone bağlıgönderilmesin.
