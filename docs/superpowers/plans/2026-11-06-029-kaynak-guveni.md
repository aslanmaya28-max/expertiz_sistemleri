# 029 Kaynak güveni uygulama planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Bağımsız kaynak yardımcı modülü dispatching-parallel-agents ile ayrılmıştır.

**Goal:** Kullanıcı kararı B uyarınca kapsamı açık, iki bağımsız teknik kaynakla desteklenen kontrol konularını orta güvenle göstermek.
**Architecture:** risk_sources tek gerekçeli kaynak sicili, ağsız PSL ve bağımsızlık grafiğini sağlar. vehicle_risk araç/konu kapsamını doğrular, resmî kayıtları yüksek, iki bağımsız teknik kaynağı orta sayar. Ham önbellek ve smoke tanısı aynı doğrulayıcıdan geçer.
**Tech Stack:** Python, tldextract paketinin gömülü PSL anlık görüntüsü, pytest; mevcut Next.js/PDF tüketicileri.
**Spec:** kopru/codex_icin/029-kaynak-guveni-genisletme.md (kullanıcı kararı B).

## Global Constraints
- Masraf/km yalnız açık kaynakta; değer kaybı/pazarlık hesabına dokunulmaz.
- Forum/şikâyet/engelli kaynak güven yükseltmez. Gizli dosya okunmaz.
- Ana dal/push yok. Taban 026 c232c96; yalnız görev çalışma kopyası.
- Yeni orta etiketi iki kaynak taahhüdüdür: tek tanımlı teknik kaynak da düşük kalır; eski raporlar okunabilir.

## Review Focus
- co.uk, com.tr, özel PSL alt alanları ve IP adresleri: gerçek eTLD+1, ağ yok.
- Aynı yayıncının farklı alanları, ortak uzun cümle, kopya ve atıf zinciri tek sayılır.
- Model sayfa girişinde, motor/konu başka cümledeyse yükselmez.
- Forum yolu veya alt alanı teknik alan üstünde olsa da yükselmez.
- Önbellek ve canlı doğrulama aynı politikayı kullanır; kaynak olmayan eski önbellek yeni anahtarla devralınmaz.

### 1 — Kaynak yardımcı modülü
- [ ] risk_sources.py ve test_risk_sources.py: root_domain, source_kind, is_same_publisher, independent_count. Önce kırmızı test, sonra gömülü PSL ve birleşik bileşen uygulaması.
- [ ] Tek gerekçeli sicile üretici/kurum/teknik/kullanıcı/engelli ve yayıncı kimliği taşınır; requirements'a tldextract eklenir.

### 2 — Araç kapsamı ve toplam güven
- [ ] test_risk_confidence_policy.py: iki farklı teknik metin orta; aynı kök, kopya, forum, belirsiz kapsam düşük; NHTSA/KBA kayıtları yüksek. Yanlış motor/yıl ve ilgili olmayan konu olumsuz testleri.
- [ ] vehicle_risk.py: _scoped_evidence aynı cümlede model + motor veya özel şanzıman + konu ister; _confidence_details tek resmî kayıt için yüksek, _verify bağımsızlık sayısıyla orta verir. Etiketler Resmî kayıt / İki bağımsız teknik kaynak / Kullanıcı deneyimi.
- [ ] Güven için sayılmayan metin görünür riskin fiyat/km kanıtına taşınmaz. Önbellek v6.

### 3 — Teslim
- [ ] Smoke iki komutunu 026 tabanıyla aynı ham kaynaklarda kıyaslayacak şekilde güncelle; kaynak/kanıt etiketlerini çıktıya ekle.
- [ ] Ağsız odaklı testler, tam Python kapısı, site testleri ve tsc; bağımsız inceleme ve gerekli düzeltmeler.
- [ ] Türkçe commit, köprü raporu ve Claude 010 canlı ölçüm isteği; canlı sonuç yoksa bunu açıkça belirt.
