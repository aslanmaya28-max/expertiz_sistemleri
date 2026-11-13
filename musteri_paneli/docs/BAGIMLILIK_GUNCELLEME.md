# Python bağımlılıkları

| Dosya | İçerik | Kim kullanır |
|---|---|---|
| `requirements.txt` | Doğrudan bağımlılıklar, tam sürüm (`==`) | Geliştirme; kilit üretimi |
| `requirements.lock` | Tüm alt bağımlılıklarla kilitli tam liste | **Dockerfile → Render (canlı)** |
| `requirements-dev.txt` | `requirements.txt` + pytest | Yerel testler |

Kilit, canlı imajla aynı ortamda (`python:3.11-slim`) üretilir; yerel Python (3.13) ile **üretmeyin**.
İlk kilit 13 Kasım 2026'da, o güne kadar canlıda kurulan sürümlerle birebir aynı alındı
(PyFPDF yok, yalnız fpdf2; sentry-sdk kurulu; google-auth kararlı sürüm).

## Sürüm yükseltme
1. `requirements.txt` içinde ilgili paketin sürümünü değiştirin.
2. Kilidi yeniden üretin (`musteri_paneli` içinde, Git Bash):
   ```sh
   MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W)/requirements.txt:/r.txt:ro" python:3.11-slim sh -c \
     'pip install -q --no-cache-dir --root-user-action=ignore -r /r.txt >/dev/null 2>&1; pip freeze' > freeze.txt
   ```
   Başlık yorumlarını koruyup `requirements.lock` gövdesini bu çıktıyla değiştirin.
3. İmajı kurun ve testleri imajın içinde çalıştırın (yb-test-db 55432 açık, `ybtest_kilit` veritabanı var):
   ```sh
   docker build -t yerimebak-api-kilit .
   MSYS_NO_PATHCONV=1 docker run --rm --user 0 -v "$(pwd -W):/src:ro" -e PYTHONPATH=/work \
     -e TEST_DATABASE_URL=postgresql://postgres:test@host.docker.internal:55432/ybtest_kilit \
     -e SECRET_KEY=test -e OPENROUTER_API_KEY= --entrypoint sh yerimebak-api-kilit -c \
     'mkdir /work && tar -C /src --exclude=./frontend/node_modules --exclude=./frontend/.next --exclude=./data -cf - . \
      | tar -C /work -xf - && cd /work && pip install -q pytest==9.2.0 && python -m pytest tests -q'
   ```

## Notlar
- Rapor PDF'i canlı imajda DejaVu, Windows'ta Arial yazı tipiyle üretilir; satırlar farklı yerden kırılır.
  PDF testleri bu yüzden boşluktan bağımsız karşılaştırır.
- Üretim imajında artık pytest yok (`requirements-dev.txt`).
- Geri alma: Dockerfile'da `requirements.lock` yerine `requirements.txt` kurmak yeterli (doğrudan sürümler yine sabit).
