#!/bin/sh
# Kopruda bekleyen isleri listeler (Claude her calisma basinda calistirir).
cd "$(git rev-parse --show-toplevel)" || exit 1
for klasor in kopru/claude_icin kopru/codex_icin; do
  echo "== $klasor"
  for f in "$klasor"/*.md; do
    [ -f "$f" ] || continue
    durum="$(sed -n 's/^Durum:[[:space:]]*//p' "$f" | head -1)"
    baslik="$(head -1 "$f" | sed 's/^# //')"
    printf '  %-12s %s  (%s)\n' "${durum:-?}" "$(basename "$f")" "$baslik"
  done
done
