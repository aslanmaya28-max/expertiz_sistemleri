# 038 — Panel tasarım yenileme uygulama planı

**Amaç:** Yönetim ve saha panelini 038 köprü tasarımına taşımak; iş akışlarını korumak.
**Mimari:** Uygulamadaki tema tokenları kopyalanır; ortak bileşenler ve duyarlı kabuk mevcut modülleri sarar. Ana sayfa yalnız sunucudaki `ozet` verisini sunar. API ve izinler değişmez.
**Teknolojiler:** Flutter, Inter, Lucide, fl_chart, shared_preferences.
**Şartname:** Kök `kopru/codex_icin/038-panel-tasarim-yenileme.md`, `docs/TASARIM_SISTEMI.md`.

## Sınırlar ve kararlar
- Yalnız bu iş kopyasında panel ve plan değişir. Kök sunucu değişikliklerine dokunulmaz.
- Varsayılan koyu tema; açık tema tercihi saklanır. Tokenlar müşteri uygulamasıyla aynıdır.
- Sahada kontrol merkezi iletişimi korunur. Canlı API'ye yazılmaz.
- Kullanıcı köprü görevlerini tamamlamayı istedi; ayrıntılı 038 şartnamesi uygulama yetkisidir.

## Aşamalar
- [ ] 1. Tema, gömülü fontlar, Lucide, ortak bileşenler, kabuk, giriş. Tema kalıcılığı ve 760/1100/1440 kabuk testleri; analyze + tüm testler; ayrı commit.
- [ ] 2. `DashboardStats` içinde `ozet`, animasyonlu sayaçlar, günlük grafik, halka, dikkat listesi, son işlemler. Eksik özet, sıfır veri, e-posta adı, hareket azaltma ve iki tema testleri; tüm kapı; ayrı commit.
- [ ] 3. Kontrol merkezi, talepler, müşteriler ortak tasarıma taşınır; mevcut davranış testleri korunur; tüm kapı; ayrı commit.
- [ ] 4. Kalan yönetim ekranları, saha, müşteri yönlendirmesi; kullanılmayan cyber/neon kodu temizlenir. Tüm kapı; ayrı commit.
- [ ] 5. Yerel sahte API ile açık/koyu 1440 ekran kanıtları, ana sayfa 760; bağımsız inceleme; sonuç ve Claude teslim notu.

## İnceleme odağı
- Eski sunucuda özet yokluğu sıfırmış gibi gösterilmez.
- Yetki denetimi ve mevcut API gövdeleri korunur.
- Dar ekran ve %130 metinde taşma olmaz.
- Hareket azaltma sayaçları son değerde gösterir; sonsuz animasyon yoktur.
- Saha müşteri/satıcıyı doğrudan aramaz; iade tamamlanmadan tamamlandı denmez.

## Kayıt
- Başlangıç: `85a5c8b`, `codex/038-panel-tasarim-yenileme`. Kök sunucu dosyaları Claude tarafından değiştirilmiş.
