# -*- coding: utf-8 -*-
"""Istemcinin gercek IP adresi (hiz siniri, giris kaydi, PayTR).

Uygulama bir vekil sunucunun arkasinda calisir; IP, vekilin yazdigi basliktan okunur:
- nginx ile kendi sunucu: X-Real-IP (nginx yazar, istemci degistiremez)
- Render / Cloudflare: CF-Connecting-IP (Cloudflare yazar)
- X-Forwarded-For en sonda: istemci kendi degerini ekleyebildigi icin sahte olabilir; ilk deger alinir.

Sira CLIENT_IP_HEADERS ile degistirilebilir (virgulle, kucuk harf), ör. "cf-connecting-ip,x-forwarded-for".
"""
from __future__ import annotations

import os
from typing import Mapping, Optional

DEFAULT_HEADERS = "x-real-ip,cf-connecting-ip,x-forwarded-for"


def _headers() -> list[str]:
    raw = os.getenv("CLIENT_IP_HEADERS") or DEFAULT_HEADERS
    return [h.strip().lower() for h in raw.split(",") if h.strip()]


def client_ip(headers: Mapping[str, str], fallback: Optional[str]) -> str:
    """headers: kucuk harf anahtarli basliklar (Starlette Headers da olur)."""
    for key in _headers():
        value = headers.get(key)
        if value:
            return value.split(",")[0].strip()
    return fallback or "127.0.0.1"
