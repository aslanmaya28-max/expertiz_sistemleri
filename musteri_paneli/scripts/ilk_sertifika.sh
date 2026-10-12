#!/bin/sh
# Ilk Let's Encrypt sertifikasi (yerimebak.com.tr, www, admin).
# nginx sertifika olmadan acilamadigi icin ilk sertifika "standalone" modda,
# 80 portu bos iken alinir. Sonraki yenilemeleri compose'daki certbot servisi
# nginx uzerinden (webroot) otomatik yapar.
#
# Kullanim (musteri_paneli klasorunde, DNS kayitlari sunucuya yonlendikten sonra):
#   sh scripts/ilk_sertifika.sh eposta@yerimebak.com.tr
set -eu

EMAIL="${1:?Kullanim: sh scripts/ilk_sertifika.sh <eposta>}"

docker compose stop nginx 2>/dev/null || true

docker run --rm -p 80:80 \
  -v /etc/letsencrypt:/etc/letsencrypt \
  certbot/certbot certonly --standalone --non-interactive --agree-tos \
  --email "$EMAIL" \
  -d yerimebak.com.tr -d www.yerimebak.com.tr -d admin.yerimebak.com.tr

docker compose up -d
echo "Sertifika alindi; tum servisler baslatildi."
