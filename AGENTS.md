# Ajan kuralları (Codex ve diğer yapay zekâ ajanları)

Bu depoda Claude ve Codex birlikte çalışır. Genel anlatım: `README.md`. Görev alışverişi: `kopru/README.md`.

## Dil
Kullanıcıyla, commit mesajlarında ve raporlarda Türkçe yaz (Türkçe karakterlerle). Kod tanımlayıcıları olduğu gibi kalır.

## Köprü
- Claude'dan gelen görev `kopru/codex_icin/` altındadır; sana `kopru/codex_gorev.sh` ile ayrı bir çalışma kopyasında verilir. Yalnızca o klasörde ve o dalda çalış.
- **Görev sahipliği (çakışmayı önler):** Görev dosyasındaki `Atanan:` satırına uy. `Atanan: codex-exec` olan görevi VS Code oturumunda **alma** (betik yapıyor). VS Code'da yalnızca `Atanan: vscode` olan ya da kullanıcının sohbette açıkça istediği görevi yap. `Durum: calisiyor` olan göreve başka oturum başlamaz. Bir göreve başlarken `Durum: calisiyor` yap.
- Claude'a iş bırakmak istersen `kopru/claude_icin/NNN-ad.md` dosyası yaz (şablon `kopru/README.md`), `Durum: bekliyor` yap. Cevap `kopru/claude_sonuc/` altına gelir.
- Claude'un üzerinde çalıştığı dosyaları aynı anda değiştirme. Emin değilsen görevi `claude_icin/` üzerinden sor.
- Teslimden önce testleri çalıştır; kırmızı test varsa düzelt; testler geçmeden 'bitti' deme (ayrıntı: kopru/README.md → Test kapısı).

## Sınırlar
- `main` dalına commit etme, `push` yapma, geçmişi yeniden yazma (`rebase`, `reset --hard`, `push --force`) — kullanıcı açıkça istemedikçe.
- `.env` dosyalarını okuma, yazdırma, commit etme. Anahtar gerekiyorsa `.env.example` dosyasına boş satır ekle.
- Kazıyıcı, Chrome eklentisi, vitrin ve Streamlit paneli bilerek kaldırıldı (`git tag arsiv/docker-surum`). Geri getirme.

## Yapı
- API: `musteri_paneli/yerimebak_ai_v5/` (FastAPI, PostgreSQL). Yapay zekâ değerlemesi: `workers/ai_analysis_worker.py`, `services/web_market_reference.py`, `core/ai/inspection_valuation.py`.
- Müşteri sitesi: `musteri_paneli/frontend/` (Next.js; önce `frontend/AGENTS.md`).
- Admin/personel paneli: `expertiz_paneli/` (Flutter web).

## Testler (teslimden önce ilgili olanları çalıştır)
```sh
cd musteri_paneli && python -m pytest tests/unit -q
# Uçtan uca: boş bir PostgreSQL ister, her çalıştırmada sıfırlanır
TEST_DATABASE_URL=postgresql://postgres:test@localhost:55432/ybtest SECRET_KEY=test OPENROUTER_API_KEY= python -m pytest tests -q
cd musteri_paneli/frontend && npx tsc --noEmit && node --test tests/*.test.mjs
cd expertiz_paneli && flutter analyze --no-pub && flutter test --no-pub
```
Test veritabanı yoksa: `docker run -d --rm --name yb-test-db -e POSTGRES_PASSWORD=test -e POSTGRES_DB=ybtest -p 55432:5432 postgres:16-alpine`
