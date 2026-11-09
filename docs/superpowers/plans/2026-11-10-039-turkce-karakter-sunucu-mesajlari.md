# 039 — Sunucu mesajları Türkçe yazım düzeltmesi

**Amaç:** Kullanıcıya görünen sunucu metinlerindeki Türkçe karakterleri düzeltmek; anlamı ve sözleşmeyi korumak.
**Şartname:** `kopru/codex_icin/039-turkce-karakter-sunucu-mesajlari.md` (kök köprü).
**Taban/dal:** `040622b` / `codex/039-turkce-karakter-sunucu-mesajlari`.

## Sınırlar
- Kod, JSON anahtarları, durumlar, URL, veritabanı değerleri ve loglar aynı kalır.
- `main.py` açılış kilidi, e-posta konuları, `core/ai/`, `workers/` değişmez.
- Ayrı iş kopyası; `.env` okunmaz. Testlerde `PYTHON_DOTENV_DISABLED=1` ve göreve özel PostgreSQL kullanılır.

## Uygulama
- [x] 1. AST ve kaynak taramasıyla görünen metin envanteri; üç istemcide metin bağımlılıklarını incele.
- [x] 2. `tests/unit/test_kullanici_mesajlari_turkce.py` kaynak denetimi ekle; mevcut ASCII mesajlarda kırmızı koşuyu doğrula.
- [x] 3. Yalnız belirlenen metin sabitlerini düzelt; kesin metin karşılaştıran testleri aynı kesinlikle güncelle.
- [x] 4. Birim ve tüm Python test kapısını çalıştır; istemci değişirse ilgili istemci kapılarını da çalıştır.
- [x] 5. Farkta kod/anahtar/log değişmediğini ve kapsam dışını doğrula; Türkçe commit ve dosya bazlı sayımlı köprü raporu.

## İnceleme odağı
- F-string içindeki ifadeler ve SQL/kalıcı veri değerleri değişmez.
- İngilizce sözcüklerdeki benzer parçalar otomatik çevrilmez.
- Hata kodları ASCII kalır; istemci dal seçimi değişmez.
- Yeni tarama testi kaynak bağlamını seçer; yorumları/logları yanlışlıkla kullanıcı metni saymaz.
- Test veritabanı başka görevden ayrıdır; canlı hesap veya ödeme çağrısı yapılmaz.

## Kararlar ve kanıt
- Kaynak denetimi: önce 16 dosya kırmızı, iki test yeşil; düzeltme sonrası 18/18.
- İlk test koşusunun sistem geçici klasör izni sorunu, çalışma kopyasında `--basetemp` kullanılarak giderildi; testler atlanmadı.
- Bağımsız inceleme: değişen mesajlarla kesişen istemci metin bağımlılığı yok. Mevcut `gecik`/`timeout`, `Too many dashboard requests` ve eski emsal uyarısı eşleştirmeleri etkilenmiyor.
- Karar: DB'deki `Odeme basarisiz` / `Simulasyon` sabitleri ve yazıcıları korunur; `get_order_status` yalnız sunumda Türkçe karşılık verir. Bilinmeyen sağlayıcı hataları ve `None` aynen döner. On testten dördü önce kırmızı, değişiklik sonrası 10/10.
- İncelemede saptanan `resmi` (resim sözcüğünün belirtme hâli) yanlış pozitifini önlemek için denetim `resmi rapor` kalıbıyla sınırlıdır; doğru Türkçe ve log/kod/SQL dışlama örnekleri sınanır.
- Son hedefli kapı: 62/62 geçti. İlk tüm paket koşusundaki yedi hata, değişen metinlere bağlı eski karşılaştırmalardı; aynı kesinlikle Türkçe karşılıklarına güncellendi.
- Son tam kapı: `PYTHON_DOTENV_DISABLED=1 SECRET_KEY=test OPENROUTER_API_KEY= TEST_DATABASE_URL=postgresql://postgres:test@localhost:55432/ybtest_039 python -m pytest tests -q --basetemp=../kopru/log/039-pytest-run2` → **1044 geçti**, 196,38 sn. Tek uyarı ortamda birlikte kurulu PyFPDF/fpdf2 paketlerinden geliyor; bu görevin değişikliği değil.
- AST fark denetimi: metin sabitleri ve açıkça tanımlanmış ödeme sunum adaptörü dışında yapı aynı; `main.py`, `core/ai`, `workers`, e-posta servisi ve üç istemci için fark yok. `git diff --check` temiz.
