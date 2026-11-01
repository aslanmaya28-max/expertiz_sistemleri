"""Canliya cikis oncesi bulunan hatalarin geri gelmemesi icin regresyon testleri."""
import re
import subprocess
import sys
import time
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

ROOT = Path(__file__).resolve().parents[2]


def _route(router, path, method):
    for route in router.routes:
        if getattr(route, "path", None) == path and method in getattr(route, "methods", set()):
            return route
    raise AssertionError(f"{method} {path} bulunamadi")


def _dependency_calls(route):
    return {dep.call for dep in route.dependant.dependencies}


class AdminOnlyRouteTests(unittest.TestCase):
    def test_frontend_valuation_paths_exist_in_backend(self):
        from tests.unit.route_paths import api_paths
        from yerimebak_ai_v5.api.v1.router import api_router

        paths = api_paths(api_router)
        api_ts = (ROOT / "frontend/src/lib/api.ts").read_text(encoding="utf-8")
        for path in ("/valuation/analyze", "/valuation/prefill", "/valuation/parts", "/payments/checkout/credits"):
            self.assertIn(f'"{path}', api_ts.replace("`", '"'))
            self.assertIn(path, paths)
        # Onceki 404: frontend'in var olmayan /analysis/analyze adresini cagirmasi
        for page in (ROOT / "frontend/src").rglob("*.ts*"):
            self.assertNotIn("/api/v1/analysis/analyze", page.read_text(encoding="utf-8"), str(page))


class ConnectionPoolTests(unittest.TestCase):
    def test_return_connection_rolls_back_open_transaction(self):
        from yerimebak_ai_v5.core.infrastructure import database_config

        pool = MagicMock()
        conn = MagicMock()
        conn.closed = 0
        with patch.object(database_config, "_pool", pool):
            database_config.DatabaseConfig.return_connection(conn)

        conn.rollback.assert_called_once()
        pool.putconn.assert_called_once_with(conn)

    def test_return_connection_discards_broken_connection(self):
        from yerimebak_ai_v5.core.infrastructure import database_config

        pool = MagicMock()
        conn = MagicMock()
        conn.closed = 0
        conn.rollback.side_effect = Exception("server closed the connection")
        with patch.object(database_config, "_pool", pool):
            database_config.DatabaseConfig.return_connection(conn)

        pool.putconn.assert_called_once_with(conn, close=True)


class SchemaAndConfigTests(unittest.TestCase):
    def test_tables_with_updated_at_trigger_have_the_column(self):
        sql = (ROOT / "sql/init.sql").read_text(encoding="utf-8")
        triggered = re.findall(r"BEFORE UPDATE ON (\w+)\s+FOR EACH ROW EXECUTE FUNCTION update_updated_at_column", sql)
        self.assertIn("users", triggered)
        for table in triggered:
            body = re.search(rf"CREATE TABLE IF NOT EXISTS {table} \((.*?)\n\);", sql, re.S)
            self.assertIsNotNone(body, table)
            self.assertRegex(body.group(1), r"\n\s*updated_at\s", table)

    def test_nginx_upstreams_are_in_http_context(self):
        conf = (ROOT / "nginx.conf").read_text(encoding="utf-8")
        depth_stack = []
        for line in conf.splitlines():
            code = line.split("#", 1)[0]
            match = re.match(r"\s*(\w+)[^{;]*\{", code)
            if match:
                if match.group(1) == "upstream":
                    self.assertEqual(depth_stack, ["http"], "upstream sadece http blogunda olabilir")
                depth_stack.append(match.group(1))
            depth_stack = depth_stack[: max(0, len(depth_stack) - code.count("}"))]


class ExpertizCatalogSeedTests(unittest.TestCase):
    def test_seed_contains_requested_firms_without_invented_prices(self):
        from yerimebak_ai_v5.services.pricing_service import SEED_FIRMS

        ids = [firm["id"] for firm in SEED_FIRMS]
        self.assertEqual(len(ids), len(set(ids)))
        for firm_id in ("yamanlar", "dynobil", "umran", "tarcanlar", "auto-king"):
            self.assertIn(firm_id, ids)
        # Fiyati kaynaktan dogrulanamayan firmalar paketsiz gelir; fiyatlari admin girer.
        for firm in SEED_FIRMS:
            if firm["source_url"] is None:
                self.assertEqual(firm["packages"], [], firm["id"])


if __name__ == "__main__":
    unittest.main()
