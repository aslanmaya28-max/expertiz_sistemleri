#!/bin/bash
# Vercel derlemesi: Flutter SDK indirilir, web surumu derlenir (cikti: build/web).
# API adresi Vercel proje ayarindaki YERIMEBAK_API_BASE_URL'den gelir.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.7}"
API_URL="${YERIMEBAK_API_BASE_URL:-https://api.yerimebak.com.tr/api/v1}"
SDK_DIR="${HOME:-/tmp}/flutter-sdk"

if [ ! -x "$SDK_DIR/flutter/bin/flutter" ]; then
  mkdir -p "$SDK_DIR"
  curl -fsSL -o /tmp/flutter.tar.xz \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  # xz araci her derleme imajinda olmayabilir: Python ile ac
  python3 - "$SDK_DIR" <<'PY'
import sys, tarfile
with tarfile.open("/tmp/flutter.tar.xz") as t:
    try:
        t.extractall(sys.argv[1], filter="tar")  # izinler ve ic baglantilar korunur
    except TypeError:  # filter parametresi olmayan eski Python
        t.extractall(sys.argv[1])
PY
  rm -f /tmp/flutter.tar.xz
fi

export PATH="$SDK_DIR/flutter/bin:$PATH"
export FLUTTER_SUPPRESS_ANALYTICS=true CI=true
git config --global --add safe.directory "$SDK_DIR/flutter" || true

flutter config --no-analytics >/dev/null
flutter pub get
flutter build web --release --no-web-resources-cdn \
  --dart-define=YERIMEBAK_API_BASE_URL="$API_URL"
