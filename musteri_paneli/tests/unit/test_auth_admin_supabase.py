import base64
import hashlib
import hmac
import json
import time
import unittest
from unittest.mock import patch

from fastapi import HTTPException

from yerimebak_ai_v5.api.v1.endpoints import auth
from yerimebak_ai_v5.core.infrastructure import supabase_auth


class FakeCursor:
    def __init__(self, rows):
        self.rows = list(rows)
        self.executed = []

    def execute(self, query, params=None):
        self.executed.append((query, params))

    def fetchone(self):
        if not self.rows:
            return None
        return self.rows.pop(0)


class FakeConnection:
    def __init__(self, rows):
        self.cursor_instance = FakeCursor(rows)

    def cursor(self):
        return self.cursor_instance


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _hs256_token(payload, secret: str) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    signing_input = f"{_b64url(json.dumps(header).encode())}.{_b64url(json.dumps(payload).encode())}"
    signature = hmac.new(secret.encode(), signing_input.encode(), hashlib.sha256).digest()
    return f"{signing_input}.{_b64url(signature)}"


class SupabaseAdminAuthTests(unittest.TestCase):
    def test_supabase_jwt_validates_without_python_jose(self):
        secret = "test-secret"
        token = _hs256_token(
            {
                "sub": "11111111-1111-1111-1111-111111111111",
                "email": "admin@yerimebak.ai",
                "role": "authenticated",
                "exp": int(time.time()) + 3600,
            },
            secret,
        )

        with patch.object(supabase_auth, "JOSE_AVAILABLE", False), \
             patch.object(supabase_auth, "SUPABASE_JWT_SECRET", secret):
            result = supabase_auth.validate_supabase_jwt(token)

        self.assertEqual(result["id"], "11111111-1111-1111-1111-111111111111")
        self.assertEqual(result["email"], "admin@yerimebak.ai")
        self.assertTrue(result["is_supabase"])

    def test_supabase_user_with_admin_role_in_database_is_admin(self):
        conn = FakeConnection([{"role": "admin"}])
        user = {
            "id": "11111111-1111-1111-1111-111111111111",
            "email": "admin@yerimebak.ai",
            "role": "authenticated",
            "is_supabase": True,
        }

        with patch.object(auth.DatabaseConfig, "get_connection", return_value=conn), \
             patch.object(auth.DatabaseConfig, "return_connection") as mock_return:
            result = auth.get_admin_user(user)

        self.assertEqual(result["role"], "admin")
        self.assertEqual(result["admin_role_source"], "database")
        self.assertTrue(any("FROM users" in query for query, _ in conn.cursor_instance.executed))
        mock_return.assert_called_once_with(conn)

    def test_non_admin_user_is_rejected(self):
        conn = FakeConnection([{"role": "user"}])
        user = {
            "id": "22222222-2222-2222-2222-222222222222",
            "email": "user@yerimebak.ai",
            "role": "authenticated",
            "is_supabase": True,
        }

        with patch.object(auth.DatabaseConfig, "get_connection", return_value=conn), \
             patch.object(auth.DatabaseConfig, "return_connection"):
            with self.assertRaises(HTTPException) as caught:
                auth.get_admin_user(user)

        self.assertEqual(caught.exception.status_code, 403)

    def test_user_metadata_admin_role_is_not_trusted(self):
        conn = FakeConnection([{"role": "user"}])
        user = {
            "id": "33333333-3333-3333-3333-333333333333",
            "email": "user-meta@yerimebak.ai",
            "role": "authenticated",
            "user_metadata": {"role": "admin"},
            "app_metadata": {},
            "is_supabase": True,
        }

        with patch.object(auth.DatabaseConfig, "get_connection", return_value=conn), \
             patch.object(auth.DatabaseConfig, "return_connection"):
            with self.assertRaises(HTTPException) as caught:
                auth.get_admin_user(user)

        self.assertEqual(caught.exception.status_code, 403)

    def test_app_metadata_admin_role_is_trusted(self):
        user = {
            "id": "44444444-4444-4444-4444-444444444444",
            "email": "app-meta-admin@yerimebak.ai",
            "role": "authenticated",
            "app_metadata": {"role": "admin"},
            "user_metadata": {},
            "is_supabase": True,
        }

        result = auth.get_admin_user(user)

        self.assertEqual(result["email"], "app-meta-admin@yerimebak.ai")

    def test_public_profile_maps_legacy_user_role_to_customer(self):
        profile = auth._public_profile({
            "id": "customer-1",
            "email": "customer@yerimebak.ai",
            "role": "user",
        })

        self.assertEqual(profile["role"], "customer")


if __name__ == "__main__":
    unittest.main()
