import unittest
from unittest.mock import patch

from yerimebak_ai_v5.services import auth_service
from yerimebak_ai_v5.services.auth_service import _hash_password, _verify_password, get_auth_service


class FakeCursor:
    def __init__(self, rows=None):
        self.rows = list(rows or [])
        self.executed = []

    def execute(self, query, params=None):
        self.executed.append((" ".join(query.split()), params))

    def fetchone(self):
        return self.rows.pop(0) if self.rows else None


class FakeConnection:
    def __init__(self, rows=None):
        self.cursor_instance = FakeCursor(rows)
        self.committed = False

    def cursor(self):
        return self.cursor_instance

    def commit(self):
        self.committed = True


class ChangePasswordTests(unittest.TestCase):
    def _run(self, rows, current, new):
        conn = FakeConnection(rows)
        with patch.object(auth_service.DatabaseConfig, "get_connection", return_value=conn), \
                patch.object(auth_service.DatabaseConfig, "return_connection"):
            return get_auth_service().change_password(7, current, new), conn

    def test_changes_password_when_current_matches(self):
        result, conn = self._run([{"id": 7, "password": _hash_password("EskiSifre1")}], "EskiSifre1", "YeniSifre2")

        self.assertTrue(result["success"])
        query, params = conn.cursor_instance.executed[-1]
        self.assertTrue(query.startswith("UPDATE users SET password"))
        self.assertTrue(_verify_password("YeniSifre2", params[0]))
        self.assertTrue(conn.committed)

    def test_wrong_current_password_is_rejected(self):
        result, conn = self._run([{"id": 7, "password": _hash_password("EskiSifre1")}], "Yanlis123A", "YeniSifre2")

        self.assertEqual(result["http_status"], 403)
        self.assertFalse(conn.committed)

    def test_weak_or_same_password_is_rejected_without_db(self):
        result, conn = self._run([], "EskiSifre1", "kisa")
        self.assertIn("8 karakter", result["error"])
        result, _ = self._run([], "EskiSifre1", "EskiSifre1")
        self.assertIn("farkli", result["error"])
        self.assertEqual(conn.cursor_instance.executed, [])

    def test_route_registered(self):
        from yerimebak_ai_v5.api.v1.endpoints.auth import router

        self.assertIn("/change-password", {r.path for r in router.routes})


if __name__ == "__main__":
    unittest.main()
