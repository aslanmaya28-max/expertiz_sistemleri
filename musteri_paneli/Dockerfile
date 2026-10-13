# YERIMEBAK AI v8.1 - Production Docker Image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libwayland-client0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xdg-utils \
    curl \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install Playwright browsers
# Tarayici root'un ev dizinine degil, uygulama kullanicisinin (1000) de
# okuyabilecegi sabit bir dizine kurulur; aksi halde kaziyici canlida acilamaz.
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN playwright install chromium --with-deps && chmod -R a+rX /ms-playwright

# Copy application code
COPY yerimebak_ai_v5/ /app/yerimebak_ai_v5/
COPY sql/ /app/sql/

# Uygulama kullanicisi (docker-compose'da user: "1000:1000").
# /app (kod, kaziyici PID dosyalari), /app/data (fotograf / kurumsal rapor
# yuklemeleri, kalici volume) ve /app/logs bu kullaniciya ait olmali;
# root'a ait kalirsa yuklemeler "Permission denied" ile basarisiz olur.
RUN groupadd --gid 1000 app && useradd --uid 1000 --gid 1000 --home-dir /app --no-create-home app \
    && mkdir -p /app/data/media /app/logs \
    && chown -R 1000:1000 /app
USER 1000:1000

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Expose ports
EXPOSE 8000

# Calisan islem sayisi: WEB_CONCURRENCY (varsayilan 2). Sunucudaki vCPU basina 1-2 onerilir.
# Erisim kayitlari nginx'te tutulur (uygulamada kapali: hiz icin).
CMD ["sh", "-c", "exec python -m uvicorn yerimebak_ai_v5.main:app --host 0.0.0.0 --port 8000 --workers ${WEB_CONCURRENCY:-2} --no-access-log --timeout-keep-alive 30"]
