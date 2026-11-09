# -*- coding: utf-8 -*-
"""Yerinde ekspertiz hizmet bölgesi ve talep ayrıntıları (9 Kasım 2026).

Kullanıcı kararı: hizmet 81 ilde açılabilir; pilot il İstanbul; testler başka illerden de yapılabilmeli.
Her il için durum: ``acik`` (herkes), ``test`` (yalnız yönetici ve test kullanıcısı), ``kapali``.
Genel anahtar ``APP_EXPERTIZ_ENABLED`` kapalıyken yalnız yönetici/test kullanıcısı talep açabilir.
Sözleşme: ``kopru/sozlesme-ekspertiz-2026-11-09.md``.
"""
import json
import os
import re
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple
from zoneinfo import ZoneInfo

from yerimebak_ai_v5.core import turkey_regions
from psycopg2.extras import Json

from yerimebak_ai_v5.core.database_config import DatabaseConfig

SETTING_KEY = "expertiz_service_area"
PILOT = "İstanbul"
DURUMLAR = ("acik", "test", "kapali")
VARSAYILAN = {PILOT: "acik"}  # diğer iller kapalı
ISTANBUL = ZoneInfo("Europe/Istanbul")
RANDEVU_EN_ERKEN = timedelta(hours=2)
RANDEVU_EN_GEC = timedelta(days=30)
BULUNAMAMA_METNI = ("Araç belirtilen adreste bulunamazsa hizmet bedeli iade edilmez; "
                    "kurumsal ekspertiz paket ücreti iade edilir.")

_TR_SIRA = "abcçdefgğhıijklmnoöprsştuüvyz"


def _tr_key(ad: str) -> List[int]:
    kucuk = ad.replace("I", "ı").replace("İ", "i").lower()
    return [_TR_SIRA.index(c) if c in _TR_SIRA else 100 + ord(c) for c in kucuk]


ILLER: List[str] = sorted((ad for ad, _bolge in turkey_regions.PROVINCES.values()), key=_tr_key)


def genel_acik() -> bool:
    return os.getenv("APP_EXPERTIZ_ENABLED", "false").lower() in ("true", "1", "yes")


def il_adi(value: Any) -> Optional[str]:
    """Serbest yazımı resmi il adına çevirir ('istanbul kadıköy' -> 'İstanbul'); tanınmazsa None."""
    plate = turkey_regions.province_plate(str(value or "").split("/")[0].strip())
    return turkey_regions.province_name(plate) if plate else None


def ensure_schema(cursor: Any) -> None:
    """Yalnız sunucu açılışında çağrılır. İstek sırasında DDL yok: ödeme akışı kullanıcı satırını kilitli tutarken
    ALTER TABLE users onu sonsuza dek bekliyordu (9 Kasım 2026, testte kilitlendi)."""
    cursor.execute("SET LOCAL lock_timeout = '10s'")
    cursor.execute("SELECT column_name FROM information_schema.columns "
                   "WHERE table_schema = current_schema() AND table_name = 'users' AND column_name = 'is_tester'")
    if not cursor.fetchone():
        cursor.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_tester BOOLEAN NOT NULL DEFAULT FALSE")


def _durumlar(cursor: Any) -> Dict[str, str]:
    cursor.execute("SELECT value FROM system_settings WHERE key = %s", (SETTING_KEY,))
    row = cursor.fetchone()
    kayit = row["value"] if row else None
    if isinstance(kayit, str):
        kayit = json.loads(kayit)
    kayit = kayit if isinstance(kayit, dict) else dict(VARSAYILAN)
    return {il: (kayit.get(il) if kayit.get(il) in DURUMLAR else "kapali") for il in ILLER}


def _test_yetkisi(cursor: Any, user: Optional[Dict[str, Any]]) -> bool:
    if not user:
        return False
    if str(user.get("role") or "").lower() == "admin":
        return True
    # to_jsonb: sütun henüz yoksa da hata vermez (DDL yalnız açılışta)
    cursor.execute("SELECT to_jsonb(u)->>'is_tester' AS t FROM users u WHERE u.id::text = %s", (str(user.get("id")),))
    row = cursor.fetchone()
    return bool(row and row["t"] == "true")


def _talep_acabilir(durum: str, tester: bool) -> bool:
    if tester:
        return durum in ("acik", "test")
    return genel_acik() and durum == "acik"


def bolge_durumu(user: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        durumlar = _durumlar(cursor)
        tester = _test_yetkisi(cursor, user)
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    return {
        "pilot": PILOT,
        "tester": tester,
        "cities": [{"il": il, "durum": durumlar[il], "talep_acabilir": _talep_acabilir(durumlar[il], tester)}
                   for il in ILLER],
    }


def talep_il_kontrolu(user: Dict[str, Any], city: Any) -> Optional[Dict[str, Any]]:
    """Talep açılabilir mi? Hata sözlüğü ya da None."""
    il = il_adi(city)
    if not il:
        return _hata("Aracın bulunduğu il tanınamadı", 422, "il_kapali")
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        acabilir = _talep_acabilir(_durumlar(cursor).get(il, "kapali"), _test_yetkisi(cursor, user))
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    if not acabilir:
        return _hata(f"{il} ilinde yerinde inceleme henüz hizmet vermiyor", 422, "il_kapali")
    return None


def talep_dogrula(payload: Dict[str, Any], user: Dict[str, Any]
                  ) -> Tuple[Optional[Dict[str, Any]], Optional[Dict[str, Any]]]:
    """Ödemeli ve ödemesiz talebin ortak kontrolü: il durumu + randevu alanları -> (ek alanlar, hata)."""
    hata = talep_il_kontrolu(user, payload.get("city"))
    if hata:
        return None, hata
    randevu, hata = randevu_ayrintilari(payload)
    if hata:
        return None, hata
    return {"city": il_adi(payload.get("city")), "randevu": randevu, "bulunamama_onayi": True}, None


def test_yetkisi_var_mi(user: Dict[str, Any]) -> bool:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        sonuc = _test_yetkisi(cursor, user)
        conn.commit()
        return sonuc
    finally:
        DatabaseConfig.return_connection(conn)


def bolgeleri_guncelle(payload: Dict[str, Any], admin: Dict[str, Any]) -> Dict[str, Any]:
    degisiklik = payload.get("cities") if isinstance(payload, dict) else None
    if not isinstance(degisiklik, list) or not degisiklik:
        return _hata("Güncellenecek il yok", 422, "gecersiz")
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        durumlar = _durumlar(cursor)
        for satir in degisiklik:
            il = il_adi((satir or {}).get("il"))
            durum = (satir or {}).get("durum")
            if not il or il != (satir or {}).get("il") or durum not in DURUMLAR:
                return _hata(f"Geçersiz il ya da durum: {satir}", 422, "gecersiz")
            durumlar[il] = durum
        kayit = {il: d for il, d in durumlar.items() if d != "kapali"}
        cursor.execute(
            """INSERT INTO system_settings (key, value, updated_at, updated_by) VALUES (%s, %s, NOW(), %s)
               ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW(),
               updated_by = EXCLUDED.updated_by""",
            (SETTING_KEY, Json(kayit), str(admin.get("email") or admin.get("id"))))
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    return {**bolge_durumu(admin), "success": True}


def test_kullanicisi_yap(customer_id: Any, tester: bool) -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("UPDATE users SET is_tester = %s WHERE id::text = %s RETURNING id",
                       (bool(tester), str(customer_id)))
        if not cursor.fetchone():
            return _hata("Müşteri bulunamadı", 404, "bulunamadi")
        conn.commit()
        return {"success": True, "tester": bool(tester)}
    finally:
        DatabaseConfig.return_connection(conn)


def _telefon(value: Any) -> Optional[str]:
    rakam = re.sub(r"\D", "", str(value or ""))
    if rakam.startswith("90") and len(rakam) == 12:
        rakam = "0" + rakam[2:]
    elif len(rakam) == 10 and not rakam.startswith("0"):
        rakam = "0" + rakam
    return rakam if len(rakam) == 11 and rakam.startswith("0") else None


def randevu_ayrintilari(payload: Dict[str, Any], simdi: Optional[datetime] = None
                        ) -> Tuple[Optional[Dict[str, Any]], Optional[Dict[str, Any]]]:
    """Talep formundaki randevu alanları -> (talep.randevu, hata). Sözleşme bölüm 2."""
    simdi = simdi or datetime.now(ISTANBUL)
    try:
        zaman = datetime.strptime(str(payload.get("appointment_at") or "")[:16], "%Y-%m-%dT%H:%M").replace(tzinfo=ISTANBUL)
    except ValueError:
        return None, _hata("Randevu tarihi ve saati girin", 422, "randevu_gecersiz")
    if zaman < simdi + RANDEVU_EN_ERKEN or zaman > simdi + RANDEVU_EN_GEC:
        return None, _hata("Randevu en erken 2 saat, en geç 30 gün sonrası için olmalı", 422, "randevu_gecersiz")
    adres = " ".join(str(payload.get("address") or "").split())
    if not 10 <= len(adres) <= 300:
        return None, _hata("Aracın bulunduğu açık adresi ya da buluşma noktasını yazın", 422, "adres_eksik")
    telefon = _telefon(payload.get("seller_phone"))
    if not telefon:
        return None, _hata("Satıcının telefon numarasını girin (05xx xxx xx xx)", 422, "satici_telefon_gecersiz")
    if payload.get("not_found_accepted") is not True:
        return None, _hata(BULUNAMAMA_METNI + " Bu koşulu onaylayın.", 422, "bulunamama_onayi_gerekli")
    return {
        "tarih_saat": zaman.strftime("%Y-%m-%dT%H:%M"),
        "adres": adres,
        "satici_adi": " ".join(str(payload.get("seller_name") or "").split())[:80],
        "satici_telefon": telefon,
    }, None


def _hata(mesaj: str, status: int, code: str) -> Dict[str, Any]:
    return {"error": mesaj, "http_status": status, "code": code}
