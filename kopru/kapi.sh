#!/bin/sh
# Test kapisi (tek basina): gorev VS Code'daki Codex'te ya da elle yapildiginda kullanilir.
# Gorevin calisma kopyasinda (.worktrees/codex-<ad>) Test: komutunu calistirir; yesilse ve
# commit edilmemis degisiklik varsa Codex adina commit eder; Durum'u gunceller.
# Codex'in calisma kopyasina biraktigi Claude notlarini ana kopru/claude_icin/ klasorune tasir.
#
# Kullanim: sh kopru/kapi.sh kopru/codex_icin/005-ad.md
set -eu

GOREV="$1"
[ -f "$GOREV" ] || { echo "Gorev dosyasi yok: $GOREV" >&2; exit 1; }
KOK="$(git rev-parse --show-toplevel)"; cd "$KOK"
AD="$(basename "$GOREV" .md)"
CALISMA=".worktrees/codex-$AD"
[ -d "$CALISMA" ] || { echo "Calisma kopyasi yok: $CALISMA" >&2; exit 1; }
DAMGA="$(date +%Y%m%d-%H%M%S)"
mkdir -p kopru/log kopru/claude_icin kopru/codex_sonuc

PY="$(python -c 'import sys; print(sys.executable)' | tr '\\' '/')"
DB_ADI="ybtest_$(printf '%s' "$AD" | cut -d- -f1)"
export TEST_DATABASE_URL="postgresql://postgres:test@localhost:55432/$DB_ADI" KOPRU_TEST_DB
KOPRU_TEST_DB="$TEST_DATABASE_URL"
export SECRET_KEY="${SECRET_KEY:-test}" OPENROUTER_API_KEY=""
if command -v docker >/dev/null 2>&1 && ! docker ps --format '{{.Names}}' | grep -qx yb-test-db; then
  docker run -d --rm --name yb-test-db -e POSTGRES_PASSWORD=test -e POSTGRES_DB=ybtest \
    -p 55432:5432 postgres:16-alpine >/dev/null && sleep 6
fi
docker exec yb-test-db psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_ADI'" 2>/dev/null | grep -q 1 \
  || docker exec yb-test-db psql -U postgres -c "CREATE DATABASE $DB_ADI" >/dev/null 2>&1 || true

# Codex'in calisma kopyasina biraktigi notlar (sandbox ana klasore yazamaz)
for not_dosyasi in "$CALISMA"/kopru/claude_icin/*.md; do
  [ -f "$not_dosyasi" ] || continue
  hedef="kopru/claude_icin/$(basename "$not_dosyasi")"
  [ -f "$hedef" ] || { cp "$not_dosyasi" "$hedef"; echo "Claude'a not tasindi: $hedef"; }
done

TEST_KOMUTU="$(sed -n 's/^Test:[[:space:]]*//p' "$GOREV" | head -1)"
TEST_KOMUTU="${TEST_KOMUTU:-cd musteri_paneli && \"$PY\" -m pytest tests -q -p no:cacheprovider -W ignore}"
CIKTI="kopru/log/$AD-$DAMGA-kapi.txt"
set +e
( cd "$CALISMA" && sh -c "$TEST_KOMUTU" ) >"$CIKTI" 2>&1
KOD=$?
set -e
KIRLI="$(git -C "$CALISMA" status --porcelain -- . ':!kopru' | head -5)"
if [ $KOD -eq 0 ] && [ -n "$KIRLI" ]; then
  git -C "$CALISMA" add -A -- . ':!kopru'
  git -C "$CALISMA" commit -q -m "$(head -1 "$GOREV" | sed 's/^# //')" \
    -m "Kopru gorevi $AD (Codex). Testler gectikten sonra kopru kapisi commit etti." \
    -m "Co-Authored-By: Codex <noreply@openai.com>"
  KIRLI=""
fi
if [ $KOD -eq 0 ]; then DURUM="bitti"; else DURUM="test-basarisiz"; fi
sed -i "s/^Durum:.*/Durum: $DURUM/" "$GOREV"
echo "Kapi: $DURUM (test cikis kodu $KOD)"
echo "Test ciktisi: $CIKTI"
tail -3 "$CIKTI"
echo "Dal: codex/$AD ($(git -C "$CALISMA" log --oneline -1))"
[ "$DURUM" = "bitti" ]
