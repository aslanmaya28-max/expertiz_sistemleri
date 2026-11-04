"""Web'deki ARAC_KATALOGU'nu (aracFormu.ts) Dart'a aktarır; tek kaynak web olarak kalır."""
import json
import re
import sys

ts = open(sys.argv[1], encoding="utf-8").read()
govde = ts[ts.index("ARAC_KATALOGU"):]
govde = govde[govde.index("{") + 1: govde.index("};")]
katalog = {}
for satir in govde.splitlines():
    satir = satir.strip().rstrip(",")
    if not satir or satir.startswith("//"):
        continue
    m = re.match(r'^("?)([^":]+)\1\s*:\s*(\[.*\])$', satir)
    if not m:
        raise SystemExit(f"çözülemedi: {satir}")
    katalog[m.group(2)] = json.loads(m.group(3))

out = ["// ÜRETİLDİ: musteri_paneli/frontend/src/lib/aracFormu.ts → ARAC_KATALOGU. Elle değiştirmeyin;",
       "// web kataloğu değişince `python tool/katalog_uret.py ../musteri_paneli/frontend/src/lib/aracFormu.ts lib/analiz/arac_katalogu.dart`.",
       "const Map<String, List<String>> aracKatalogu = {"]
for marka, modeller in katalog.items():
    out.append(f"  {json.dumps(marka, ensure_ascii=False)}: {json.dumps(modeller, ensure_ascii=False)},")
out.append("};")
open(sys.argv[2], "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
print(len(katalog), "marka")
