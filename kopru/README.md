# Claude ↔ Codex köprüsü

İki yapay zekâ ajanı aynı depoda, birbirinin dosyalarını ezmeden görev alışverişi yapar.

| Klasör | Kim yazar | Kim okur | İçerik |
|---|---|---|---|
| `codex_icin/` | Claude | Codex | Codex'e verilen görevler |
| `codex_sonuc/` | Codex (betik) | Claude | Codex'in görev sonuç raporu |
| `claude_icin/` | Codex | Claude | Claude'a bırakılan görevler / sorular |
| `claude_sonuc/` | Claude | Codex | Claude'un cevabı |
| `log/` | betik | ikisi | Çalıştırma kayıtları |

Görev ve sonuç dosyaları depoya girmez (`.gitignore`). Yalnızca bu README, şablon ve betik takip edilir.

## Dosya adı

`NNN-kisa-ad.md` — örn. `003-medya-supabase-storage.md`. Numara her klasörde artan sırayla gider. Sonuç dosyası görevle **aynı adı** taşır.

## Görev dosyası şablonu

```markdown
# <Başlık>
Durum: bekliyor        <!-- bekliyor | calisiyor | bitti | iptal -->
Gönderen: Claude | Codex
Dal: degerleme-web-kaynak   <!-- görevin başlayacağı dal -->

## Amaç
## Bağlam (ilgili dosyalar, kararlar)
## Yapılacaklar
## Kabul ölçütleri (hangi testler geçmeli)
## Yapma (sınırlar)
## Teslim
```

## Claude → Codex

```sh
sh kopru/codex_gorev.sh kopru/codex_icin/003-medya-supabase-storage.md
```

Betik:

1. Görevin başlangıç dalından `.worktrees/codex-<ad>` çalışma kopyasını ve `codex/<ad>` dalını açar.
2. Codex'i o klasörde çalıştırır (`codex exec`, yazma izni yalnızca o klasörde).
3. Codex'in son mesajını `codex_sonuc/<ad>.md` dosyasına, tüm akışı `log/` altına yazar.

Codex işini `codex/<ad>` dalına commit eder. Claude farkı inceler ve uygunsa kendi dalına birleştirir. Codex `main`'e ya da başka bir dala dokunmaz, `push` yapmaz.

## Codex → Claude

Codex (VS Code içinde ya da `codex exec` ile) Claude'a iş bırakmak isterse `claude_icin/` klasörüne şablona uygun bir dosya yazar. Claude her çalışma başında bu klasörü kontrol eder (`sh kopru/bekleyenler.sh`), görevi yapar, cevabı `claude_sonuc/` klasörüne aynı adla yazar ve görev dosyasındaki durumu `bitti` yapar.
