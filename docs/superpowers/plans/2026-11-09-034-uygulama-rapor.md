# 034 — Android rapor sunumu

Kaynak şartname: kökte `kopru/codex_icin/034-uygulama-rapor-tasarimi.md`.
Kullanıcı köprü görevini tamamlamayı istedi; referans ve sıra görevde belirlenmiş.
Mevcut Flutter widget yapısı korunacak; siteyi WebView olarak gömmek yeni bağımlılık
ve erişilebilirlik kaybı yaratacağı için uygun değil. Yerel widget sunumu uygulanacak.

## Sınırlar
Sadece rapor bileşenleri, ek tema tokenları ve rapor testleri. API, ekranlar,
kredi, sunucu, site ve PDF değişmez. Veriler sunucudan; tek izinli hesap eski
raporlarda aylık enflasyondan altı aylık oran türetme. Karar/güven verisi gizli kalır.

## 1. Davranış testleri
- Mesajın bağımsız bölüm olarak sırası, paragrafları, Clipboard verisi ve paylaşımı.
- Getiri oranları ve sunucudaki kazançlar; altı aylık eski rapor uyumu; veri yokken gizleme.
- Başlık/meta/çipler, fiyat aralığı, riskler ve sonraki adım sırası; karar verisi görünmez.
- `flutter test test/report_view_test.dart`: önce eksik sunum nedeniyle kırmızı, sonra yeşil.

## 2. Yerel rapor bileşenleri
- `rapor_karti.dart`: ReportCard(title, children, {icon, dark, warning}), başlık semantiği.
- `rapor_basligi.dart`: ReportHeader(snapshot,onLink), VehicleChips(snapshot).
- `enflasyon_karti.dart`: InflationSection(Json data).
- Özet/fiyat/pazarlık/model/piyasa/kaynak/kayıp bölümleri aynı yeşil kart diline taşınır.
- Satıcı mesajı plan içinden ayrı bölüme alınır; mevcut paylaşım ve kopyalama korunur.
- `ReportView` yalnız sıra ve sunumun birleşimidir; son çağrı koyu banttır.

## 3. Görsel doğrulama ve teslim
- Açık/koyu ve 360/412dp, %130 ölçek rapor goldenları; üst/orta/alt görüntüler.
- Mevcut rapor ekranı goldenları yeni sunum için yenilenir; diğer ekranlar değişmez.
- `flutter analyze`, `flutter test`; çıktı köprü loguna.
- Bağımsız inceleme, Türkçe commit, sonuç raporu ve Claude test kapısı teslimi.

## İnceleme odağı
Eksik getiri alanları, uzun araç adı/mesaj ve %130 taşma, koyu bant kontrastı,
aynı mesajın iki paylaşım düğmesinde korunması, düşük güvenli risklerin gizlenmesi.

## Uygulama kaydı
Ön kontrol: Header ve Inflation yalnız yeni dosyalarda; ReportCard arayüzü ortak.
Tema ve ReportView entegrasyonunu ana ajan yapar; yardımcılar ortak dosyalara yazmaz.

Tamamlandı: mesaj/paragraf/Clipboard/WhatsApp, enflasyon oranları ve kazançları,
eksik dönem uyumu, eski kayıt, düşük güven gizleme ve %130 taşma testleri yeşil.
İlk üç yeni davranış testi önce kırmızı görüldü (`034-red-elevated.log`).
Bağımsız incelemenin eksik yıllık dönem bulgusu ek beklentiyle kırmızı görüldü
(`034-missing-horizon-red.log`), boş dönemler gizlenerek düzeltildi.
Mevcut `app_flow_test.dart` içindeki eski Özet başlığı beklentisi yeni risk başlığına
uyarlandı; akış/assertion kaldırılmadı. Diğer ekran/API dosyaları değişmedi.
Son doğrulama: `flutter analyze` temiz, `flutter test` 100/100 (18 saniye).
28 yeni rapor goldenı ve iki mevcut rapor goldenı; 360dp/%130 ve412dp/%100,
açık/koyu, üst/orta/alt/fiyat/pazarlık/yıllık kazanç/model bulguları.
Bağımsız inceleme sonrası açık önemli bulgu yok. Birleştirme Claude test kapısına
bırakılır; çalışma dalı ve çalışma kopyası korunur, push yapılmaz.
