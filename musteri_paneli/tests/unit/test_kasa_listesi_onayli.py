# -*- coding: utf-8 -*-
"""Kasa listesi kullanıcı onayıyla açıldı (07.11.2026); ⚠ maddeler kaynaklarla düzeltildi."""
import json

from yerimebak_ai_v5.services import vehicle_generation as vg


def _kasalar(marka, model):
    return {k["kasa"]: (k["baslangic"], k["bitis"], k["makyaj"])
            for k in vg.curated_generations({"brand": marka, "model": model, "year": 2020})}


def test_tum_liste_onayli_ve_tutarli():
    veri = json.loads(vg.LIST_PATH.read_text(encoding="utf-8"))["modeller"]
    assert veri and all(m["onayli"] for m in veri)
    for m in veri:
        for k in m["kasalar"]:
            assert k["baslangic"] <= k["bitis"], (m["model"], k["kasa"])
            assert k["makyaj"] is None or k["baslangic"] <= k["makyaj"] <= k["bitis"], (m["model"], k["kasa"])
            assert "kontrol edilmeli" not in (k.get("not") or "")


def test_kaynakla_duzeltilen_maddeler():
    a6 = _kasalar("Audi", "A6")
    assert a6["C8"] == (2018, 2025, 2024) and a6["C9"][:2] == (2025, 2026)
    caddy = _kasalar("Volkswagen", "Caddy")
    assert caddy["Caddy III"] == (2004, 2015, 2010) and caddy["Caddy IV"][:2] == (2015, 2020)
    zs = _kasalar("MG", "ZS")
    assert zs["ZS I"] == (2021, 2025, 2022) and zs["ZS II"][0] == 2026
    assert _kasalar("MG", "HS")["AS23 (HS I)"][0] == 2022
    assert _kasalar("Renault", "Megane")["Megane IV"][1] == 2026
    assert _kasalar("Hyundai", "Accent Blue")["RB"][2] is None
