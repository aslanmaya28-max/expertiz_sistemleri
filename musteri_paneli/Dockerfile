# YerimeBak API - hafif imaj (kaziyici / Chromium yok)
# Render, Railway veya docker compose ile ayni imaj calisir.
FROM python:3.11-slim

WORKDIR /app

# Saglik kontrolu icin curl
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY yerimebak_ai_v5/ /app/yerimebak_ai_v5/
COPY sql/ /app/sql/

# Uygulama kullanicisi. /app/data: fotograf / kurumsal rapor yuklemeleri (kalici disk baglanmali)
RUN groupadd --gid 1000 app && useradd --uid 1000 --gid 1000 --home-dir /app --no-create-home app \
    && mkdir -p /app/data/media /app/logs \
    && chown -R 1000:1000 /app
USER 1000:1000

ENV PYTHONPATH=/app \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

EXPOSE 8000

# PORT: Render/Railway verir (yoksa 8000). WEB_CONCURRENCY: calisan islem sayisi (varsayilan 2).
CMD ["sh", "-c", "exec python -m uvicorn yerimebak_ai_v5.main:app --host 0.0.0.0 --port ${PORT:-8000} --workers ${WEB_CONCURRENCY:-2} --no-access-log --timeout-keep-alive 30"]
