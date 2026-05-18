import unittest
from unittest.mock import patch

from yerimebak_ai_v5.workers.maintenance.cleanup_worker import DataCleanupWorker


class FakeCursor:
    rowcount = 4

    def __init__(self):
        self.queries = []

    def execute(self, query, params=None):
        self.queries.append((query, params))

    def fetchone(self):
        return [4]


class FakeConnection:
    def __init__(self):
        self.cursor_instance = FakeCursor()
        self.committed = False
        self.closed = False

    def cursor(self):
        return self.cursor_instance

    def commit(self):
        self.committed = True

    def rollback(self):
        pass

    def close(self):
        self.closed = True


class CleanupWorkerTests(unittest.TestCase):
    def test_default_retention_is_27_days_and_commits_delete(self):
        conn = FakeConnection()
        worker = DataCleanupWorker()
        with patch("yerimebak_ai_v5.workers.maintenance.cleanup_worker.DatabaseConfig.get_connection", return_value=conn):
            result = worker.cleanup_old_data()
        self.assertEqual(worker.retention_days, 27)
        self.assertEqual(result["deleted_listings"], 4)
        self.assertTrue(conn.committed)
        self.assertTrue(conn.closed)


if __name__ == "__main__":
    unittest.main()
