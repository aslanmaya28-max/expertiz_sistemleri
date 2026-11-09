# -*- coding: utf-8 -*-
"""Kontrol merkezi (9 Kasım 2026, kullanıcı kararı).

Saha personeli müşteriye ya da satıcıya doğrudan bağlanmaz; yalnız kontrol merkezine bağlanır. Müşteri ve satıcıyla
bağlantıyı kontrol merkezi kurar. Bu yüzden personele giden görev yanıtlarında müşteri/satıcı telefonu ve e-postası
yoktur (``personel_gorunumu``); numaraları yalnız yönetici görür. Her arama/not ``control_center_logs``'a yazılır.
Sözleşme: ``kopru/sozlesme-ekspertiz-2026-11-09.md`` bölüm 7.
"""
import copy
from typing import Any, Dict, List, Optional

from psycopg2.extras import Json

from yerimebak_ai_v5.core.database_config import DatabaseConfig

SETTING_KEY = "kontrol_merkezi"
HEDEFLER = ("musteri", "satici", "personel")
SONUCLAR = ("ulasildi", "ulasilamadi", "mesaj_birakildi", "baglandi")
ACIK_DURUMLAR = ("draft", "rejected")


def ensure_schema(cursor: Any) -> None:
    """Yalnız sunucu açılışında (istekte DDL yok)."""
    cursor.execute("SET LOCAL lock_timeout = '10s'")
    cursor.execute("SELECT to_regclass('public.control_center_logs') IS NOT NULL AS var")
    if not cursor.fetchone()["var"]:
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS control_center_logs (
                id BIGSERIAL PRIMARY KEY,
                report_id TEXT NOT NULL,
                actor_id TEXT, actor_name TEXT, actor_role TEXT,
                hedef TEXT NOT NULL, sonuc TEXT NOT NULL, note TEXT,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())""")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_control_center_report ON control_center_logs(report_id, created_at DESC)")
        cursor.execute("ALTER TABLE control_center_logs ENABLE ROW LEVEL SECURITY")


def _hata(mesaj: str, status: int, code: str) -> Dict[str, Any]:
    return {"error": mesaj, "http_status": status, "code": code}


def ayarlar() -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT value FROM system_settings WHERE key = %s", (SETTING_KEY,))
        row = cursor.fetchone()
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    deger = row["value"] if row and isinstance(row["value"], dict) else {}
    telefon = str(deger.get("telefon") or "")
    return {"telefon": telefon, "calisma_saatleri": str(deger.get("calisma_saatleri") or ""), "tanimli": bool(telefon)}


def ayarlari_guncelle(payload: Dict[str, Any], admin: Dict[str, Any]) -> Dict[str, Any]:
    from yerimebak_ai_v5.services.service_area import _telefon

    telefon = _telefon(payload.get("telefon"))
    if not telefon:
        return _hata("Kontrol merkezi telefonunu girin (05xx… ya da 0850…)", 422, "telefon_gecersiz")
    saatler = " ".join(str(payload.get("calisma_saatleri") or "").split())[:120]
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """INSERT INTO system_settings (key, value, updated_at, updated_by) VALUES (%s, %s, NOW(), %s)
               ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW(), updated_by = EXCLUDED.updated_by""",
            (SETTING_KEY, Json({"telefon": telefon, "calisma_saatleri": saatler}), str(admin.get("email") or admin.get("id"))))
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    return {"success": True, **ayarlar()}


def personel_gorunumu(sonuc: Dict[str, Any]) -> Dict[str, Any]:
    """Personele giden yanıttan müşteri/satıcı iletişim bilgisini çıkarır (görev / görev listesi)."""
    if not isinstance(sonuc, dict):
        return sonuc
    temiz = copy.deepcopy(sonuc)

    def gorev(t: Any) -> None:
        if not isinstance(t, dict):
            return
        musteri = t.get("customer")
        if isinstance(musteri, dict):
            ad = str(musteri.get("name") or "").split()
            t["customer"] = {"name": (ad[0] + (" " + ad[-1][0] + "." if len(ad) > 1 else "")) if ad else "Müşteri"}
        randevu = t.get("randevu")
        if isinstance(randevu, dict):
            t["randevu"] = {k: v for k, v in randevu.items() if k != "satici_telefon"}

    gorev(temiz.get("task"))
    for t in temiz.get("tasks") or []:
        gorev(t)
    return temiz


def _kayit_ekle(cursor: Any, report_id: str, actor: Dict[str, Any], rol: str, hedef: str, sonuc: str, note: str) -> Dict[str, Any]:
    cursor.execute(
        """INSERT INTO control_center_logs (report_id, actor_id, actor_name, actor_role, hedef, sonuc, note)
           VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id, created_at""",
        (report_id, str(actor.get("id") or ""), actor.get("full_name") or actor.get("email") or "", rol, hedef, sonuc, note))
    row = cursor.fetchone()
    return {"id": row["id"], "created_at": row["created_at"].isoformat(), "actor_name": actor.get("full_name") or actor.get("email") or "",
            "actor_role": rol, "hedef": hedef, "sonuc": sonuc, "note": note}


def personel_notu(report_id: str, user: Dict[str, Any], note: str) -> Dict[str, Any]:
    """Saha personeli kontrol merkezine not bırakır (ör. 'satıcı açmıyor', '15 dk gecikeceğim')."""
    from yerimebak_ai_v5.services import dispatch_service, notification_service

    note = " ".join(str(note or "").split())[:500]
    if len(note) < 3:
        return _hata("Notu yazın", 422, "not_gerekli")
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        gorev = dispatch_service._load_owned_task(cursor, report_id, user)
        if "error" in gorev:
            return gorev
        kayit = _kayit_ekle(cursor, str(gorev["row"]["id"]), user, "personel", "kontrol_merkezi", "not", note)
        kim = user.get("full_name") or user.get("email") or "Saha personeli"
        notification_service.notify_admins(cursor, "control_center_note", "Kontrol merkezine saha notu",
                                           f"{kim}: {note}", str(gorev["row"]["id"]))
        conn.commit()
        return {"success": True, "kayit": kayit}
    except Exception:
        conn.rollback()
        raise
    finally:
        DatabaseConfig.return_connection(conn)


def yonetim_kaydi(report_id: str, admin: Dict[str, Any], payload: Dict[str, Any]) -> Dict[str, Any]:
    hedef, sonuc = payload.get("hedef"), payload.get("sonuc")
    if hedef not in HEDEFLER or sonuc not in SONUCLAR:
        return _hata("Arama hedefi ya da sonucu geçersiz", 422, "gecersiz")
    note = " ".join(str(payload.get("note") or "").split())[:500]
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT id FROM reports WHERE id::text = %s", (str(report_id),))
        if not cursor.fetchone():
            return _hata("Talep bulunamadı", 404, "bulunamadi")
        kayit = _kayit_ekle(cursor, str(report_id), admin, "kontrol_merkezi", hedef, sonuc, note)
        conn.commit()
        return {"success": True, "kayit": kayit}
    finally:
        DatabaseConfig.return_connection(conn)


def _kayitlar(cursor: Any, report_ids: List[str], limit_each: Optional[int] = None) -> Dict[str, List[Dict[str, Any]]]:
    if not report_ids:
        return {}
    cursor.execute(
        """SELECT id, report_id, actor_name, actor_role, hedef, sonuc, note, created_at FROM control_center_logs
           WHERE report_id = ANY(%s) ORDER BY created_at DESC, id DESC""", (report_ids,))
    sonuc: Dict[str, List[Dict[str, Any]]] = {}
    for row in cursor.fetchall():
        liste = sonuc.setdefault(row["report_id"], [])
        if limit_each is None or len(liste) < limit_each:
            liste.append({k: (row[k].isoformat() if k == "created_at" else row[k])
                          for k in ("id", "actor_name", "actor_role", "hedef", "sonuc", "note", "created_at")})
    return sonuc


def kayitlar(report_id: str) -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        liste = _kayitlar(cursor, [str(report_id)]).get(str(report_id), [])
        conn.commit()
        return {"success": True, "kayitlar": liste}
    finally:
        DatabaseConfig.return_connection(conn)


def gunun_gorevleri(limit: int = 200) -> Dict[str, Any]:
    """Kontrol merkezi ekranı: açık görevler randevu saatine göre; müşteri, satıcı ve personel numaraları,
    son iletişim kaydı. Randevusu olmayan eski talepler sonda."""
    from yerimebak_ai_v5.services import dispatch_service

    dispatch_service.ensure_workflow_schema_once()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM reports WHERE status = ANY(%s) ORDER BY created_at DESC LIMIT %s",
                       (list(ACIK_DURUMLAR), limit))
        gorevler = [dispatch_service._admin_request(dict(row)) for row in cursor.fetchall()]
        son = _kayitlar(cursor, [g["id"] for g in gorevler], limit_each=1)
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    for g in gorevler:
        g["son_iletisim"] = (son.get(g["id"]) or [None])[0]
    gorevler.sort(key=lambda g: ((g.get("randevu") or {}).get("tarih_saat") or "9999", g.get("created_at") or ""))
    return {"success": True, "ayarlar": ayarlar(), "gorevler": gorevler}
