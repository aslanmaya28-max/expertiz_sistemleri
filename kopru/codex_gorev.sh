#!/bin/sh
# Claude -> Codex: bir gorev dosyasini Codex'e ayri bir git calisma kopyasinda yaptirir.
# Codex testleri kendisi calistirip hatalari duzeltir; ardindan bu betik testleri tekrar
# calistirir (test kapisi). Kirmizi test varsa cikti Codex'e geri gonderilir (en fazla
# KOPRU_TUR, varsayilan 3 tur). Testler yesil olmadan gorev "bitti" olmaz.
#
# Kullanim: sh kopru/codex_gorev.sh kopru/codex_icin/003-ad.md [ek codex exec secenekleri]
# Gorev dosyasinda istege bagli satir:  Test: <kabuk komutu>   (calisma kopyasinin kokunden)
set -eu

GOREV="$1"; shift || true
EK_SECENEK="$*"   # codex exec'e aynen gecer (bosluksuz degerler)
[ -f "$GOREV" ] || { echo "Gorev dosyasi yok: $GOREV" >&2; exit 1; }

KOK="$(git rev-parse --show-toplevel)"
cd "$KOK"
KOK_W="$(pwd -W 2>/dev/null || pwd)"          # Codex Windows yolu ister (C:/...)
AD="$(basename "$GOREV" .md)"
DAL_KAYNAK="$(sed -n 's/^Dal:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$GOREV" | head -1)"
DAL_KAYNAK="${DAL_KAYNAK:-$(git rev-parse --abbrev-ref HEAD)}"
CALISMA=".worktrees/codex-$AD"
DAL="codex/$AD"
SONUC="kopru/codex_sonuc/$AD.md"
DAMGA="$(date +%Y%m%d-%H%M%S)"
LOG="kopru/log/$AD-$DAMGA.log"
TUR_SINIRI="${KOPRU_TUR:-3}"
mkdir -p kopru/codex_sonuc kopru/log

PY="$(python -c 'import sys; print(sys.executable)' 2>/dev/null || true)"
PY="$(printf '%s' "$PY" | tr '\\' '/')"
PY_DIR="$(dirname "$PY")"
TEST_DB="postgresql://postgres:test@localhost:55432/ybtest"
VARSAYILAN_TEST="cd musteri_paneli && TEST_DATABASE_URL=$TEST_DB SECRET_KEY=test OPENROUTER_API_KEY= \"$PY\" -m pytest tests -q -p no:cacheprovider -W ignore"
TEST_KOMUTU="$(sed -n 's/^Test:[[:space:]]*//p' "$GOREV" | head -1)"
TEST_KOMUTU="${TEST_KOMUTU:-$VARSAYILAN_TEST}"

# Uctan uca testler icin bos PostgreSQL (yoksa baslatilir; her test calismasinda sifirlanir)
if command -v docker >/dev/null 2>&1 && ! docker ps --format '{{.Names}}' | grep -qx yb-test-db; then
  docker run -d --rm --name yb-test-db -e POSTGRES_PASSWORD=test -e POSTGRES_DB=ybtest \
    -p 55432:5432 postgres:16-alpine >/dev/null && sleep 6 || echo "Uyari: test veritabani baslatilamadi" >&2
fi

if [ ! -d "$CALISMA" ]; then
  if git show-ref --verify --quiet "refs/heads/$DAL"; then
    git worktree add "$CALISMA" "$DAL"
  else
    git worktree add -b "$DAL" "$CALISMA" "$DAL_KAYNAK"
  fi
fi

sed -i 's/^Durum:.*/Durum: calisiyor/' "$GOREV"

KURALLAR="Sen Codex'sin ve Claude'dan gelen bir gorevi yapiyorsun (kopru protokolu: kopru/README.md, kurallar: AGENTS.md).
Calisma klasorun: $CALISMA (dal: $DAL). Yalnizca bu klasorde degisiklik yap; push yapma, baska dala gecme.
Kabuk PowerShell: komutlari '&&' ile zincirleme, tek tek calistir.
Python: $PY  (pytest kurulu). Uctan uca test veritabani hazir: $TEST_DB

TESLIM KURALI (zorunlu):
1. Isin bitince su test komutunu calistir (bash sozdizimi; PowerShell'de ortam degiskenlerini \$env: ile ver):
   $TEST_KOMUTU
   Ayrica degistirdigin bolumun testleri (site: npx tsc --noEmit; Flutter: flutter analyze --no-pub ve flutter test --no-pub).
2. Basarisiz test varsa nedenini bul ve DUZELT; testi gevsetme, atlama, silme. Tum testler gecene kadar tekrarla.
3. Testler gectikten sonra degisiklikleri bu dala Turkce bir commit mesajiyla commit et.
4. Bir testi calistiramiyorsan bunu acikca yaz; 'bitti' deme.
Son mesajin Claude'a giden rapordur. Su basliklarla, kisa ve Turkce:
## Sonuc (bitti / kismen / yapilamadi)
## Yapilanlar (dosya: ne degisti)
## Test sonuclari (calistirdigin komutlar ve ozet ciktilari)
## Acik kalanlar / sorular"

codex_calistir() {
  # $1: talimat metni, $2: cikti dosyasi
  printf '%s' "$1" | codex exec -C "$KOK_W/$CALISMA" -s workspace-write \
    --add-dir "$KOK_W/.git" ${PY_DIR:+--add-dir "$PY_DIR"} \
    -c sandbox_workspace_write.network_access=true \
    -o "$2" $EK_SECENEK - >>"$LOG" 2>&1
}

TALIMAT="$KURALLAR

--- GOREV ---
$(cat "$GOREV")"

TUR=1
DURUM="hata"
while :; do
  echo "== Codex turu $TUR ($(date +%H:%M:%S))" >>"$LOG"
  set +e
  codex_calistir "$TALIMAT" "$SONUC"
  CIKIS=$?
  set -e
  [ $CIKIS -eq 0 ] || { echo "Codex hata kodu: $CIKIS" >>"$LOG"; break; }

  # Test kapisi: Codex'ten bagimsiz olarak testleri bu betik calistirir
  TEST_CIKTI="kopru/log/$AD-$DAMGA-test-$TUR.txt"
  set +e
  ( cd "$CALISMA" && sh -c "$TEST_KOMUTU" ) >"$TEST_CIKTI" 2>&1
  TEST_KODU=$?
  set -e
  KIRLI="$(git -C "$CALISMA" status --porcelain | head -5)"
  echo "== Test kapisi turu $TUR: kod=$TEST_KODU, commit edilmemis: ${KIRLI:-yok}" >>"$LOG"

  if [ $TEST_KODU -eq 0 ] && [ -z "$KIRLI" ]; then
    DURUM="bitti"; break
  fi
  if [ $TUR -ge "$TUR_SINIRI" ]; then
    DURUM="test-basarisiz"; break
  fi
  TUR=$((TUR + 1))
  SORUN=""
  [ $TEST_KODU -ne 0 ] && SORUN="Testler basarisiz (cikis kodu $TEST_KODU). Ciktinin sonu:
$(tail -60 "$TEST_CIKTI")"
  [ -n "$KIRLI" ] && SORUN="$SORUN
Commit edilmemis degisiklikler var:
$KIRLI"
  TALIMAT="$KURALLAR

--- DUZELTME TURU $TUR / $TUR_SINIRI ---
Teslim ettigin is Claude'un test kapisindan gecmedi. Ayni gorevin devamidir; onceki degisikliklerin calisma klasorunde duruyor.
Sorunu duzelt, testleri tekrar calistir, gecince commit et ve raporu yeniden yaz.
$SORUN

--- GOREV (hatirlatma) ---
$(cat "$GOREV")"
done

sed -i "s/^Durum:.*/Durum: $DURUM/" "$GOREV"
{
  echo ""
  echo "## Köprü test kapısı"
  echo "- Sonuç: $DURUM (tur: $TUR / $TUR_SINIRI)"
  echo "- Test komutu: \`$TEST_KOMUTU\`"
  echo "- Son test çıktısı: kopru/log/$AD-$DAMGA-test-$TUR.txt"
} >>"$SONUC"

echo "Durum: $DURUM (tur $TUR)"
echo "Sonuc: $SONUC"
echo "Kayit: $LOG"
echo "Dal:   $DAL ($(git -C "$CALISMA" log --oneline -1 2>/dev/null || echo 'commit yok'))"
[ "$DURUM" = "bitti" ]
