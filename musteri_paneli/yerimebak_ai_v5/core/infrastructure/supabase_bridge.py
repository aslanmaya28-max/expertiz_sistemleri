# -*- coding: utf-8 -*-
"""
Supabase Bridge Module
Reads/writes Supabase reports table, manages AI analysis lifecycle.
Uses service_role key to bypass RLS for backend operations.
"""
import os
import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional

from psycopg2.extras import Json as PgJson

from yerimebak_ai_v5.core.database_config import DatabaseConfig

logger = logging.getLogger(__name__)

SUPABASE_URL = os.getenv("SUPABASE_URL", "")


class SupabaseBridge:
    """
    Bridge between Python AI backend and Supabase reports table.
    Handles: pending_ai reads, AI result writes, status transitions, audit logs.
    """

    def get_pending_ai_reports(self, limit: int = 50) -> List[Dict[str, Any]]:
        """
        Fetch reports with status='pending_ai' from the reports table.
        These are reports ready for AI analysis.
        """
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT id, user_id, data, plaka, firma, sehir, created_at,
                       ekspertiz_firmasi, secilen_paket, ai_analizi_yapildi_mi
                FROM reports
                WHERE status = 'pending_ai'
                  AND ai_analizi_yapildi_mi = FALSE
                ORDER BY status_updated_at ASC
                LIMIT %s
            """, (limit,))
            rows = cursor.fetchall()
            return [dict(row) for row in rows]
        except Exception as e:
            logger.error(f"[SUPABASE BRIDGE] get_pending_ai_reports failed: {e}")
            return []
        finally:
            DatabaseConfig.return_connection(conn)

    def read_report_data(self, report_id: str) -> Optional[Dict[str, Any]]:
        """
        Read full report data including the JSONB data column.
        """
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT id, user_id, data, ai_analiz_detay, ai_analysis_result,
                       ai_analizi_yapildi_mi, status, durum, plaka, firma,
                       ekspertiz_firmasi, secilen_paket, created_at, updated_at
                FROM reports
                WHERE id = %s
                LIMIT 1
            """, (report_id,))
            row = cursor.fetchone()
            return dict(row) if row else None
        except Exception as e:
            logger.error(f"[SUPABASE BRIDGE] read_report_data failed: {e}")
            return None
        finally:
            DatabaseConfig.return_connection(conn)

    def read_tam_rapor(self, report_id: str) -> Optional[Dict[str, Any]]:
        """
        Parse the tam_rapor from the data JSONB column.
        Returns the tam_rapor dict or None.
        """
        report = self.read_report_data(report_id)
        if not report:
            return None

        data = report.get("data")
        if isinstance(data, str):
            try:
                data = json.loads(data)
            except Exception:
                data = {}
        if not isinstance(data, dict):
            return None

        return data.get("tam_rapor")

    def extract_vehicle_info(self, report_id: str) -> Optional[Dict[str, Any]]:
        """
        Extract vehicle info from report's data JSONB.
        Combines vehicle_snapshot and tam_rapor data for AI analysis.
        """
        report = self.read_report_data(report_id)
        if not report:
            return None

        data = report.get("data")
        if isinstance(data, str):
            try:
                data = json.loads(data)
            except Exception:
                data = {}
        if not isinstance(data, dict):
            data = {}

        vehicle_snapshot = data.get("vehicle_snapshot", {})
        tam_rapor = data.get("tam_rapor", {})

        vehicle_info = {
            "report_id": report_id,
            "user_id": str(report.get("user_id", "")),
            "brand": vehicle_snapshot.get("marka", ""),
            "model": vehicle_snapshot.get("model", ""),
            "year": vehicle_snapshot.get("yil"),
            "km": vehicle_snapshot.get("km"),
            "price": vehicle_snapshot.get("price"),
            "plaka": report.get("plaka") or vehicle_snapshot.get("plaka", ""),
            "firma": report.get("firma") or report.get("ekspertiz_firmasi", ""),
            "location": vehicle_snapshot.get("location", ""),
        }

        if tam_rapor and isinstance(tam_rapor, dict):
            adim4 = tam_rapor.get("adim4", {})
            if isinstance(adim4, dict):
                vehicle_info["boyali_parcalar"] = adim4.get("boyaliParcalar", [])
                vehicle_info["degisen_parcalar"] = adim4.get("degisenParcalar", [])
                vehicle_info["hasar_kayitlari"] = adim4.get("hasarKayitlari", [])

            adim1 = tam_rapor.get("adim1", {})
            if isinstance(adim1, dict):
                vehicle_info["marka"] = adim1.get("marka", vehicle_info["brand"])
                vehicle_info["model"] = adim1.get("model", vehicle_info["model"])
                vehicle_info["yil"] = adim1.get("yil", vehicle_info["year"])
                vehicle_info["km"] = adim1.get("guncelKm", vehicle_info["km"])
                vehicle_info["paket"] = adim1.get("paket", "")
                vehicle_info["yakit"] = adim1.get("yakit", "")
                vehicle_info["sanziman"] = adim1.get("sanziman", "")
                vehicle_info["renk"] = adim1.get("renk", "")

            adim5 = tam_rapor.get("adim5", {})
            if isinstance(adim5, dict):
                vehicle_info["genel_not"] = adim5.get("genelNot", "")
                vehicle_info["oneriler"] = adim5.get("oneriler", [])

        return vehicle_info

    def write_ai_results(
        self,
        report_id: str,
        ai_analiz_sonucu: Dict[str, Any],
        market_reference: Optional[Dict[str, Any]] = None,
        source: str = "central_ai",
    ) -> bool:
        """
        Write AI analysis results to the reports table.
        Updates: ai_analiz_detay (JSONB), flat ai_* columns, status, ai_analizi_yapildi_mi.
        Preserves all existing data JSONB keys.
        """
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()

            cursor.execute("SELECT data FROM reports WHERE id = %s", (report_id,))
            row = cursor.fetchone()
            existing_data = dict(row)["data"] if row else {}
            if isinstance(existing_data, str):
                try:
                    existing_data = json.loads(existing_data)
                except Exception:
                    existing_data = {}
            if not isinstance(existing_data, dict):
                existing_data = {}

            market_reference = market_reference or {}
            ai_meta = {
                "source": source,
                "official": source == "central_ai",
                "ready": source == "central_ai" and bool(ai_analiz_sonucu.get("tamamlandiMi", True)),
                "reference_found": bool(market_reference.get("found", False)),
                "reference_source": market_reference.get("source"),
                "reference_count": int(market_reference.get("count") or 0),
                "reference_raw_count": int(market_reference.get("raw_count") or 0),
                "confidence": int(market_reference.get("confidence") or 0),
                "generated_at": datetime.now(timezone.utc).isoformat(),
            }

            enriched_ai_result = dict(ai_analiz_sonucu)
            enriched_ai_result.update({
                "source": source,
                "official": ai_meta["official"],
                "temporary": False,
                "marketReference": market_reference,
            })

            existing_data["ai_meta"] = ai_meta
            existing_data["market_reference"] = market_reference
            existing_data["ai_analiz_sonucu"] = enriched_ai_result

            rapor_ozeti = enriched_ai_result.get("raporOzeti", {})
            finansal = enriched_ai_result.get("finansalProjeksiyonlar", {})

            cursor.execute("""
                UPDATE reports SET
                    ai_analiz_detay = %s,
                    ai_analysis_result = %s,
                    data = %s,
                    ai_analizi_yapildi_mi = TRUE,
                    status = 'pending_admin',
                    status_updated_at = NOW(),
                    updated_at = NOW()
                WHERE id = %s
            """, (
                PgJson(enriched_ai_result),
                PgJson(enriched_ai_result),
                PgJson(existing_data),
                report_id,
            ))

            logger.info(f"[SUPABASE BRIDGE] AI results written for report {report_id}")
            conn.commit()
            return True
        except Exception as e:
            logger.error(f"[SUPABASE BRIDGE] write_ai_results failed: {e}")
            try:
                conn.rollback()
            except Exception:
                pass
            return False
        finally:
            DatabaseConfig.return_connection(conn)

    def update_report_status(
        self,
        report_id: str,
        new_status: str,
        old_status: Optional[str] = None,
    ) -> bool:
        """
        Transition report status with optional optimistic locking.
        Valid transitions: draft -> pending_ai -> pending_admin -> published/rejected
        """
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()

            if old_status:
                cursor.execute("""
                    UPDATE reports
                    SET status = %s, status_updated_at = NOW(), updated_at = NOW()
                    WHERE id = %s AND status = %s
                """, (new_status, report_id, old_status))
            else:
                cursor.execute("""
                    UPDATE reports
                    SET status = %s, status_updated_at = NOW(), updated_at = NOW()
                    WHERE id = %s
                """, (new_status, report_id))

            updated = cursor.rowcount > 0
            if updated:
                logger.info(f"[SUPABASE BRIDGE] Status: {old_status or '?'} -> {new_status} for {report_id}")
            return updated
        except Exception as e:
            logger.error(f"[SUPABASE BRIDGE] update_report_status failed: {e}")
            return False
        finally:
            DatabaseConfig.return_connection(conn)

    def write_audit_log(
        self,
        action: str,
        entity_type: str,
        entity_id: str,
        metadata: Optional[Dict[str, Any]] = None,
        user_id: Optional[str] = None,
    ) -> bool:
        """
        Write an entry to the audit_logs table.
        """
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS audit_logs (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    user_id UUID,
                    user_email TEXT,
                    user_name TEXT,
                    action TEXT NOT NULL,
                    entity_type TEXT NOT NULL,
                    entity_id TEXT NOT NULL,
                    metadata JSONB DEFAULT '{}'::jsonb,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """)

            cursor.execute("""
                INSERT INTO audit_logs (user_id, action, entity_type, entity_id, metadata)
                VALUES (%s, %s, %s, %s, %s)
            """, (
                user_id,
                action,
                entity_type,
                entity_id,
                PgJson(metadata or {}),
            ))

            return True
        except Exception as e:
            logger.error(f"[SUPABASE BRIDGE] write_audit_log failed: {e}")
            return False
        finally:
            DatabaseConfig.return_connection(conn)

    def get_report_by_id(self, report_id: str) -> Optional[Dict[str, Any]]:
        """Get a single report with all fields."""
        return self.read_report_data(report_id)

    def list_reports(
        self,
        user_id: Optional[str] = None,
        status: Optional[str] = None,
        limit: int = 100,
        offset: int = 0,
    ) -> Dict[str, Any]:
        """List reports with optional filtering and pagination."""
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            conditions = []
            params = []

            if user_id:
                conditions.append("user_id = %s")
                params.append(user_id)
            if status:
                conditions.append("status = %s")
                params.append(status)

            where = " AND ".join(conditions) if conditions else "TRUE"

            cursor.execute(f"""
                SELECT COUNT(*) as total FROM reports WHERE {where}
            """, tuple(params))
            total = cursor.fetchone()["total"]

            cursor.execute(f"""
                SELECT id, user_id, status, durum, plaka, firma, sehir,
                       ekspertiz_firmasi, secilen_paket, ai_analizi_yapildi_mi,
                       created_at, updated_at, status_updated_at
                FROM reports
                WHERE {where}
                ORDER BY created_at DESC
                LIMIT %s OFFSET %s
            """, tuple(params + [limit, offset]))

            rows = [dict(row) for row in cursor.fetchall()]

            return {
                "success": True,
                "total": total,
                "limit": limit,
                "offset": offset,
                "reports": rows,
            }
        except Exception as e:
            logger.error(f"[SUPABASE BRIDGE] list_reports failed: {e}")
            return {"success": False, "error": str(e), "reports": []}
        finally:
            DatabaseConfig.return_connection(conn)


_bridge = None


def get_supabase_bridge() -> SupabaseBridge:
    global _bridge
    if _bridge is None:
        _bridge = SupabaseBridge()
    return _bridge


