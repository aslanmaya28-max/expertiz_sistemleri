# Müşteri yolculuğu ve JSON dayanıklılığı uygulama planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox syntax.

**Goal:** Bozuk model yanıtında doğrulanabilen tamamlanmış veriyi korumak ve aynı istek numarasında tek rapor/tek kredi düşümünü test etmek.
**Architecture:** llm_json.oku(content, listeler=()) JSON nesnesi döndürür veya ValueError verir. Tam yanıt, kod bloğu ve bozuk nesnede kapanmış alanlar okunur; yalnız adı belirtilen kök dizilerde kapanmış nesneler kurtarılır. Tüketicilerin doğrulamaları ve veri yok sözleşmeleri korunur; listing_extract mevcut web._search üzerinden aynı okuyucuyu kullanır.
**Tech Stack:** Python/FastAPI, httpx MockTransport, PostgreSQL test veritabanı, Next.js/TypeScript ve node:test.
**Spec:** Ana çalışma kopyası kopru/codex_icin/017-musteri-yolculugu-dayaniklilik-testleri.md.

## Global Constraints
- Yalnız görev dalı/worktree; ana kopya, 8000/3000 demo sunucuları ve ybdemo veritabanı yok.
- Gerçek yapay zekâ/site çağrısı, .env, main/push yok; bütün ilan/kimlikler sentetik.
- Kaynak fiyatı, yıl/kasa, km, aykırı fiyat ve minimum emsal kuralları değiştirilmez.
- Kesik nesne veya kesilmiş olabilecek sayı uydurulmaz; günlükler yanıt içeriği taşımaz.

## Review Focus
- Liste adı bir metnin içinde veya iç nesnedeyse kök liste sayılmaması.
- Tamamlanmış kaynak URL dizisinin korunması, kaynaksız kasanın reddi.
- Düz fiyat alanlarında eksik virgül; yarım sayılar ve sonlu olmayan değerler.
- Ağ/5xx tekrarlarında request_id'nin değişmemesi; eşzamanlı request_guard kilidi.
- Tam rapor, PDF, bakiye ve hareketler: iki istekte tek rapor/tek ödeme düşümü.

## Adımlar
- [x] Başlangıç 49 ilgili test ve yeni testlerde gerçek kırmızı kanıtı.
- [x] Ortak okuyucu, beş okuma yolunda dört bozuk yanıt biçimi ve doğrulama sınırları.
- [x] Test ödemeli iki müşteri yolculuğu ve site aynı-ID tekrar kaynak testi.
- [ ] Geri alma/kırmızı/geri yükleme deneyini, bağımsız incelemeyi ve tam test paketini tamamla.
- [ ] Köprü test kapısı, Türkçe commit ve sonuç raporu.
