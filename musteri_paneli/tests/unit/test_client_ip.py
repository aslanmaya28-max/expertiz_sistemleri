# -*- coding: utf-8 -*-
"""Vekil basligindan istemci IP'si (nginx / Render-Cloudflare)."""
from yerimebak_ai_v5.core.client_ip import client_ip


def test_varsayilan_sira_nginx_cloudflare_forwarded(monkeypatch):
    monkeypatch.delenv("CLIENT_IP_HEADERS", raising=False)
    assert client_ip({"x-real-ip": "1.1.1.1", "cf-connecting-ip": "2.2.2.2"}, None) == "1.1.1.1"
    assert client_ip({"cf-connecting-ip": "2.2.2.2", "x-forwarded-for": "6.6.6.6, 3.3.3.3"}, None) == "2.2.2.2"
    assert client_ip({"x-forwarded-for": "3.3.3.3, 10.0.0.1"}, None) == "3.3.3.3"
    assert client_ip({}, "9.9.9.9") == "9.9.9.9"


def test_sira_ortam_degiskeniyle_degisir(monkeypatch):
    monkeypatch.setenv("CLIENT_IP_HEADERS", "cf-connecting-ip")
    # Yalnizca Cloudflare basligina guvenilir; sahte X-Real-IP / X-Forwarded-For yok sayilir
    assert client_ip({"x-real-ip": "6.6.6.6", "x-forwarded-for": "6.6.6.6", "cf-connecting-ip": "2.2.2.2"}, None) == "2.2.2.2"
    assert client_ip({"x-real-ip": "6.6.6.6"}, "10.0.0.5") == "10.0.0.5"
