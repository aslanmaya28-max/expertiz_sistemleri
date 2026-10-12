import unittest
from unittest.mock import patch

from yerimebak_ai_v5.services import customer_service


class FakeCursor:
    def __init__(self, rows=None):
        self.rows = list(rows or [])
        self.executed = []

    def execute(self, query, params=None):
        self.executed.append((" ".join(query.split()), params))

    def fetchone(self):
        return self.rows.pop(0) if self.rows else None

    def fetchall(self):
        rows, self.rows = self.rows, []
        return rows


class FakeConnection:
    def __init__(self, rows=None):
        self.cursor_instance = FakeCursor(rows)
        self.committed = False

    def cursor(self):
        return self.cursor_instance

    def commit(self):
        self.committed = True


ADMIN = {"id": 1, "email": "admin@yerimebak.ai", "role": "admin"}


class AdminCustomerTests(unittest.TestCase):
    def _patch_db(self, conn):
        for target, value in (
            ("get_connection", conn),
            ("return_connection", None),
        ):
            p = patch.object(customer_service.DatabaseConfig, target, return_value=value)
            p.start()
            self.addCleanup(p.stop)

    def test_list_excludes_staff_roles_and_searches(self):
        conn = FakeConnection(rows=[{
            "id": 5, "email": "musteri@x.com", "full_name": "Ali Veli", "credits": 3,
            "is_active": 1, "request_count": 2, "total_spent_tl": 24000.0,
        }])
        self._patch_db(conn)

        result = customer_service.list_customers(search="ali", limit=10_000)

        self.assertEqual(result["total"], 1)
        self.assertEqual(result["customers"][0]["total_spent_tl"], 24000.0)
        query, params = conn.cursor_instance.executed[-1]
        self.assertIn("NOT IN %s", query)
        self.assertIn("admin", params[0])
        self.assertIn("field_staff", params[0])
        self.assertEqual(params[1], "%ali%")
        self.assertEqual(params[-1], customer_service.MAX_LIMIT)

    def test_deactivate_requires_reason(self):
        result = customer_service.set_customer_active(5, False, "  ", ADMIN)
        self.assertEqual(result["http_status"], 400)

    def test_deactivate_updates_user_and_writes_audit(self):
        conn = FakeConnection(rows=[{"id": 5, "email": "musteri@x.com", "is_active": 1}])
        self._patch_db(conn)

        result = customer_service.set_customer_active(5, False, "Sahte hesap", ADMIN)

        self.assertTrue(result["success"])
        self.assertFalse(result["customer"]["is_active"])
        executed = [q for q, _ in conn.cursor_instance.executed]
        self.assertTrue(any(q.startswith("UPDATE users SET is_active") for q in executed))
        self.assertTrue(any("INSERT INTO audit_logs" in q for q in executed))
        self.assertTrue(conn.committed)

    def test_unknown_customer_is_404(self):
        conn = FakeConnection(rows=[])
        self._patch_db(conn)
        self.assertEqual(customer_service.get_customer(99)["http_status"], 404)
        self.assertEqual(customer_service.set_customer_active(99, True, "", ADMIN)["http_status"], 404)

    def test_routes_registered(self):
        from yerimebak_ai_v5.api.v1.endpoints.expertiz import router

        paths = {r.path for r in router.routes}
        self.assertIn("/admin/customers", paths)
        self.assertIn("/admin/customers/{customer_id}", paths)
        self.assertIn("/admin/customers/{customer_id}/status", paths)


if __name__ == "__main__":
    unittest.main()
