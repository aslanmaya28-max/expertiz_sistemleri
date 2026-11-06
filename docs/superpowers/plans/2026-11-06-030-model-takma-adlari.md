# 030 — Model takma adları uygulama planı

> Uygulama: superpowers:executing-plans ile bu oturumda; testler önce yazılır.

**Amaç:** Aynı aracın doğrulanmış yurt dışı adını yıl ve motor sınırlarıyla risk kanıtında kullanmak.
**Dayanak:** `kopru/codex_icin/030-model-takma-adlari-ve-iki-kaynak.md`.
**Mimari:** Bağımlılık eklemeden, kaynak ve gerekçe taşıyan değişmez sicil. Mevcut Python/FastAPI doğrulayıcısı sicili model eşleştirmesinde kullanır; yayıncı bağımsızlığı 029 servisinde kalır.

## Kararlar ve sınırlar
- Serbest metin/LLM eşanlamlısı yerine yalnız belgeli sicil; aksi halde yanlış kasa riski var.
- Fiat Egea/Tipo 2015+, Egea Cross/Tipo Cross 2021+; ilk motor kapsamı belgelerdeki 1.3/1.6 Multijet, Cross için 1.6 Multijet. Diğer adaylar teknik eşleşme belgesi tamamlanmadığı için ertelenir. C-HR aynı addır, alias gerektirmez.
- 029'un resmî tek kayıt yüksek ve doğrudan modelde tanımlı teknik tek kaynak orta davranışı korunur. Alias ile gelen sıradan tek kaynak düşük kalır.
- Alias kanıtında model, motor/şanzıman ve konu aynı cümlede olmalı; cümlede farklı motor, tarih veya şanzıman varsa reddedilir.
- Değerleme, mobil/personel uygulamaları, fiyat kanıtı kuralları değişmez. Anahtar ve `.env` okunmaz.

## İnceleme odağı
Eksik yıl/motor, eski Tipo, Cross/sedan veya Wagon adının kısa modelle eşleşmesi, başka motorun aynı paragrafta saklanması, cache yıl sınırı, kopya/aynı yayıncı kanıtı.

## Adımlar
- [x] `tests/unit/test_model_aliases.py`: aynı cümlede Tipo 1.3 Multijet, ters yön, Cross, iki bağımsız kaynak, eski yıl, bilinmeyen ad, motor/şanzıman uyuşmazlığı, ayrı cümle ve kopya ret testlerini yaz; kırmızıyı gör.
- [x] `services/model_aliases.py`: `aliases(vehicle)`, `matches(text, vehicle, aliases_only=False)` ve `incompatible(text, vehicle)`; sicil marka, yıl, motor, kasa, gerekçe ve birincil URL taşır. `vehicle_risk.py` kapsam ve güven denetimlerine bağla; testleri yeşile getir.
- [x] Gerçek istek gövdesinde iki bağımsız kaynak talebi, yerel/yurt dışı adları, v7 cache ve maliyet toplamı testlerini yaz; kırmızıyı gör. Sorguyu ve cache'i değiştir.
- [x] `tools/risk_evidence_smoke.py` varsayılan beş aracı çalıştırır; `risk_smoke_diagnostics.py` yalnız alias sayesinde kapsam kazanan benzersiz URL sayısını üretir. Davranış testleriyle doğrula.
- [x] Tüm Python testleri ayrı `ybtest_030` DB'de; site testleri ve tsc. Son farkı incele, Türkçe commit, köprü raporu ve Claude canlı ölçüm isteği.

## Uygulama kaydı
- Başlangıç: `1701e1c`; ayrı `codex/030-model-takma-adlari-ve-iki-kaynak` dalı.
- Taban: 029'un 57 testi geçti (`kopru/log/030-baseline.log`).
- Kırmızı kanıtları: alias 6 başarısız/18 geçti; sorgu/cache/smoke 3 başarısız/24 geçti.
- İnceleme düzeltmeleri: gövde motor sonrasında (4 kırmızı), farklı riskten resmî kapsam alma ve karma motor (3 kırmızı), eski yılın güncelleme tarihiyle maskelenmesi (1 kırmızı). Her biri düzeltmeden önce yeniden üretildi.
- Karar: eski yıl veya karma motor içeren alias cümlesi belirsiz sayılır; daha yeni tarih veya hedef motorun ayrıca anılması bu cümleyi geçerli kılmaz.
- Son dar doğrulama: 94 geçti; 35 yeni senaryo + 029'un 57 testi + 2 mevcut smoke testi.
- Bağımsız salt okunur inceleme: bildirilen önemli bulgular kapandı, açık önemli bulgu yok.
- Site 46/46; tsc temiz. Son tam Python paketi 966/966, 235,74 sn (`030-python-delivery.log`); ybtest_030. Önceki tam koşular 958 ve 965 geçti. Ortamda mevcut PyFPDF/fpdf2 birlikte kurulum uyarısı var; test hatası yok.
