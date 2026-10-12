#!/bin/sh
# Ilk Let's Encrypt sertifikasi.
# nginx sertifika olmadan acilamadigi icin ilk sertifika "standalone" modda,
# 80 portu bos iken alinir. Sonraki yenilemeleri compose'daki certbot servisi
# nginx uzerinden (webroot) otomatik yapar.
#
# Kullanim (musteri_paneli klasorunde, DNS kayitlari sunucuya yonlendikten sonra):
#   sh scripts/ilk_sertifika.sh eposta@yerimebak.com.tr api   # site + panel Vercel'de (varsayilan)
#   sh scripts/ilk_sertifika.sh eposta@yerimebak.com.tr tek   # hepsi bu sunucuda
set -eu

EMAIL="${1:?Kullanim: sh scripts/ilk_sertifika.sh <eposta> [api|tek]}"
MOD="${2:-api}"

case "$MOD" in
  api) DOMAINS="-d api.yerimebak.com.tr" ;;
  tek) DOMAINS="-d yerimebak.com.tr -d www.yerimebak.com.tr -d admin.yerimebak.com.tr" ;;
  *) echo "Mod 'api' ya da 'tek' olmali" >&2; exit 1 ;;
esac

docker compose stop nginx 2>/dev/null || true

# shellcheck disable=SC2086
docker run --rm -p 80:80 \
  -v /etc/letsencrypt:/etc/letsencrypt \
  certbot/certbot certonly --standalone --non-interactive --agree-tos \
  --email "$EMAIL" $DOMAINS

docker compose up -d
echo "Sertifika alindi; servisler baslatildi."
