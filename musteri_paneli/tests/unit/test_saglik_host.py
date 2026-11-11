# -*- coding: utf-8 -*-
"""onrender.com doğrudan erişimi kapalı, Render sağlık kontrolü açık (042 sonrası Claude)."""
from fastapi.testclient import TestClient

from yerimebak_ai_v5.main import app


def test_onrender_hostu_yalniz_health_alir():
    with TestClient(app, base_url="https://yerimebak-api.onrender.com") as c:
        assert c.get("/health").status_code == 200
        assert c.post("/api/v1/auth/login", json={"email": "a@b.com", "password": "x"},
                      headers={"CF-Connecting-IP": "1.2.3.4"}).status_code == 400
        assert c.get("/api/v1/payments/packages").status_code == 400
