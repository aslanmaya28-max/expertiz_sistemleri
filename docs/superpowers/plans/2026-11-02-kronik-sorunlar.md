# Kronik sorun kaynakları ve sunumu uygulama planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox syntax.

**Goal:** 013 köprü görevindeki kaynak, yakıt, kategori ve önem kurallarını mevcut tek araştırmaya ve rapor görünümlerine eklemek.
**Architecture:** `vehicle_risk` doğrulanmış her maddeye kategori/önem ekler ve önbelleği sürümler. PDF ile site aynı veri sözleşmesini, eski kayıt görünümünü ve öncelik sırasını uygular; ek araştırma yapılmaz.
**Tech Stack:** Python/FastAPI, fpdf2, Next.js/React/TypeScript, pytest ve node:test.
**Spec:** Ana çalışma kopyası `kopru/codex_icin/013-kronik-sorun-kaynaklari.md` (012, `87a7025` ile birleşti).

## Global Constraints

- Yalnız `codex/013-kronik-sorun-kaynaklari` ve kendi worktree'si; `.env` yok, gerçek dış servis/site isteği yok, main/push yok.
- Mevcut tek `_search` ve kredi/ödeme akışı korunur.
- `kategori`: mekanik_motor / elektronik / trim_kasa; `onem`: yuksek / orta / dusuk.
- Kritik kutu en fazla iki yüksek madde: doğrulanmış model sorunları önce, kalan yerler kaynak sayısına göre yüksek şikâyetler. Ayrıntı maddelerinde uzman satırı yüksek önem için tüm raporda en fazla üç; kritik özet kutusunda tekrar yok.
- Kategori eksik eski liste grupsuz kalır; önem eksikse rozet/kritik kutu/uzman satırı üretilmez.

## Review Focus

- Alan adı son ekini taklit eden yasak kaynaklar ve alt alanlar: gerçek alan adı sınırıyla kontrol.
- Yakıt terimlerinin açıklama/belirti içinde bulunması ve önbellek: her doğrulamada güncel araca göre filtre.
- Kaynakta bulunmayan tahmini maliyet: yüksek masraf eşiğini doğrulanmış maliyetle değerlendir.
- Eski/kısmi kategorili kayıtlar: hiçbir madde kaybolmadan grupsuz görünüm.
- Kritik özet ve iki ayrıntı bölümünde aynı maddenin tekrarı: global en fazla üç uzman satırı.

## 1. Kaynak ve madde doğrulaması

Files: `services/vehicle_risk.py`, `tests/unit/test_vehicle_risk.py` (musteri_paneli altında).
Interfaces: Mevcut `get_model_risks(vehicle)` imzası değişmez; riskler/şikâyetler kategori ve önem taşır. Şikâyetlerde maliyet bulunmaz.
- [ ] Önce kaynak tercihi, yasak kaynak, bağımsız forum, kategori/önem, yakıt ve önbellek testlerini yaz; kırmızı çalıştır.
- [ ] Tek çağrı istemini ve doğrulama yolunu güncelle; önbelleği sürümle. Uyumlu maddeleri koru, çelişenleri ele.
- [ ] `python -m pytest tests/unit/test_vehicle_risk.py -q` yeşil; diff incele.

## 2. Site görünümü

Files: `frontend/src/bilesenler/AkilliAliciBolumleri.tsx`, `frontend/src/lib/api.ts`, `frontend/tests/degerleme-sunum.test.mjs`.
Interfaces: Yukarıdaki iki opsiyonel alan; mevcut `ekspertizTalepAdresi(sonuc.arac)` bağlantısı.
- [ ] Üç grup sırası/boş grup yok, önem sırası/etiket, kritik kutu önceliği/yokluğu, üç uzman linki sınırı, eski kayıt testleri önce kırmızı.
- [ ] Mevcut bileşende aynı kuralları uygula; güvenli kaynak bağlantılarını koru.
- [ ] `npx tsc --noEmit` ve `node --test tests/*.test.mjs` yeşil.

## 3. PDF görünümü

Files: `services/valuation_report_pdf.py`, `tests/unit/test_valuation_pdf_layout.py`.
Interfaces: Siteyle aynı kategori/önem ve sıralama; uzman satırı düz metin.
- [ ] Grup başlıkları/sırası, etiketler, kritik kutu ve global üç satır sınırı, eski kayıt ve girdi değişmezliği testleri önce kırmızı.
- [ ] Var olan kart/tablo/footer stilinde uygula; PDF üret, render et ve görsel incele.
- [ ] İlgili PDF testleri yeşil; görüntü taşmasız.

## 4. Bütünleştirme ve teslim

- [ ] Birleşik API/arşiv sözleşmesi entegrasyon testini ve bağımsız kod incelemesini tamamla.
- [ ] İzole ybtest_013 ile tüm Python testleri, TypeScript ve site testleri yeşil.
- [ ] Bağımsız `kopru/kapi.sh` kapısı yeşil; görev dalına Türkçe commit, sonuç raporu ve `Durum: bitti`.
