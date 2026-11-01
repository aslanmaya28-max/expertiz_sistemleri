#!/bin/sh
# Claude -> Codex: bir gorev dosyasini Codex'e ayri bir git calisma kopyasinda yaptirir.
# Kullanim: sh kopru/codex_gorev.sh kopru/codex_icin/003-ad.md [ek codex exec secenekleri]
set -eu

GOREV="$1"; shift || true
[ -f "$GOREV" ] || { echo "Gorev dosyasi yok: $GOREV" >&2; exit 1; }

KOK="$(git rev-parse --show-toplevel)"
cd "$KOK"
AD="$(basename "$GOREV" .md)"
DAL_KAYNAK="$(sed -n 's/^Dal:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$GOREV" | head -1)"
DAL_KAYNAK="${DAL_KAYNAK:-$(git rev-parse --abbrev-ref HEAD)}"
CALISMA=".worktrees/codex-$AD"
DAL="codex/$AD"
SONUC="kopru/codex_sonuc/$AD.md"
LOG="kopru/log/$AD-$(date +%Y%m%d-%H%M%S).log"
mkdir -p kopru/codex_sonuc kopru/log

if [ ! -d "$CALISMA" ]; then
  if git show-ref --verify --quiet "refs/heads/$DAL"; then
    git worktree add "$CALISMA" "$DAL"
  else
    git worktree add -b "$DAL" "$CALISMA" "$DAL_KAYNAK"
  fi
fi

sed -i 's/^Durum:.*/Durum: calisiyor/' "$GOREV"

TALIMAT="Sen Codex'sin ve Claude'dan gelen bir gorevi yapiyorsun (kopru protokolu: kopru/README.md, kurallar: AGENTS.md).
Calisma klasorun: $CALISMA (dal: $DAL). Yalnizca bu klasorde degisiklik yap.
Isin bitince degisiklikleri bu dala Turkce bir commit mesajiyla commit et; push yapma, baska dala gecme.
Son mesajin Claude'a giden rapordur. Su basliklarla, kisa ve Turkce yaz:
## Sonuc (bitti / kismen / yapilamadi)
## Yapilanlar (dosya: ne degisti)
## Test sonuclari (calistirdigin komutlar ve ciktilari)
## Acik kalanlar / sorular

--- GOREV ---
$(cat "$GOREV")"

set +e
printf '%s' "$TALIMAT" | codex exec -C "$CALISMA" -s workspace-write -o "$SONUC" "$@" - >"$LOG" 2>&1
CIKIS=$?
set -e

if [ $CIKIS -eq 0 ]; then
  sed -i 's/^Durum:.*/Durum: bitti/' "$GOREV"
else
  sed -i 's/^Durum:.*/Durum: hata/' "$GOREV"
fi
echo "Codex cikis kodu: $CIKIS"
echo "Sonuc: $SONUC"
echo "Kayit: $LOG"
echo "Dal:   $DAL ($(git -C "$CALISMA" log --oneline -1 2>/dev/null || echo 'commit yok'))"
exit $CIKIS
