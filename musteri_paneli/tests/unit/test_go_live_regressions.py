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
    def test_scraper_control_requires_admin(self):
        from yerimebak_ai_v5.api.v1.endpoints import scrapers
        from yerimebak_ai_v5.api.v1.endpoints.auth import get_admin_user

        for method, path in (
            ("GET", "/status"),
            ("POST", "/start/{source}"),
            ("POST", "/stop/{source}"),
            ("GET", "/config"),
        ):
            self.assertIn(get_admin_user, _dependency_calls(_route(scrapers.router, path, method)), path)

    def test_vitrin_writes_require_admin(self):
        from yerimebak_ai_v5.api.v1.endpoints import vitrin
        from yerimebak_ai_v5.api.v1.endpoints.auth import get_admin_user

        for method, path in (("PATCH", "/{vehicle_id}/status"), ("POST", "/{vehicle_id}/analyze")):
            self.assertIn(get_admin_user, _dependency_calls(_route(vitrin.router, path, method)), path)

    def test_manual_analysis_path_matches_frontend(self):
        from yerimebak_ai_v5.api.v1.router import api_router  # noqa: F401  (yonlendirici kurulur)
        from yerimebak_ai_v5.api.v1.endpoints import analysis

        _route(analysis.router, "/analyze", "POST")
        page = (ROOT / "frontend/src/app/arac-analiz/page.tsx").read_text(encoding="utf-8")
        # analysis router'i /api/v1 altina oneksiz baglanir
        self.assertIn('fetch("/api/v1/analyze"', page)


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


class ScraperStopTests(unittest.TestCase):
    @unittest.skipIf(sys.platform == "win32", "POSIX surec grubu")
    def test_stop_kills_process_that_ignores_sigterm(self):
        from yerimebak_ai_v5.workers.scraper_manager import ScraperManager

        child = subprocess.Popen(
            [sys.executable, "-c", "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(60)"],
            start_new_session=True,
        )
        try:
            time.sleep(0.3)
            started = time.time()
            self.assertTrue(ScraperManager._terminate_posix(child.pid, timeout=1.0))
            self.assertLess(time.time() - started, 5)
            self.assertIsNotNone(child.poll())
        finally:
            if child.poll() is None:
                child.kill()

    def test_worker_stop_cancels_running_cycle(self):
        import asyncio

        from yerimebak_ai_v5.workers import scraper_worker

        with patch.object(scraper_worker, "get_repository", return_value=MagicMock()):
            worker = scraper_worker.ScraperWorker(planner=MagicMock(build_jobs=MagicMock(return_value=[])))
        worker._init_scrapers = lambda: None

        async def scenario():
            task = asyncio.ensure_future(worker.run())
            await asyncio.sleep(0.2)  # dongu 300 sn uykuda
            worker.stop()
            with self.assertRaises(asyncio.CancelledError):
                await asyncio.wait_for(task, timeout=2)

        asyncio.run(scenario())


if __name__ == "__main__":
    unittest.main()
