# -*- coding: utf-8 -*-
"""
PayTR iFrame API entegrasyonu.

Akis:
  1. Sunucu `get-token` ile odeme token'i alir (siparis + tutar imzalanir).
  2. Musteri PayTR iframe'inde (https://www.paytr.com/odeme/guvenli/<token>) oder.
  3. PayTR, panelde tanimli "Bildirim URL"sine (POST /api/v1/payments/paytr/callback)
     sonucu yollar; imza dogrulanir, siparis tamamlanir, cevap olarak duz "OK" doner.

Ortam degiskenleri:
  PAYTR_MERCHANT_ID, PAYTR_MERCHANT_KEY, PAYTR_MERCHANT_SALT  (zorunlu)
  PAYTR_TEST_MODE        "1" test, "0" canli (varsayilan 1)
  PAYTR_OK_URL / PAYTR_FAIL_URL  odeme sonrasi musterinin yonlenecegi sayfalar
  PAYMENT_SIMULATION     "true" ise PayTR yerine yerel simulasyon (SADECE gelistirme)
"""
import base64
import hashlib
import hmac
import json
import logging
import os
from typing import Any, Dict, List, Optional, Sequence, Tuple

import requests

logger = logging.getLogger(__name__)

GET_TOKEN_URL = "https://www.paytr.com/odeme/api/get-token"
IFRAME_URL = "https://www.paytr.com/odeme/guvenli/{token}"


class PaytrError(Exception):
    pass


def _env(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


def simulation_enabled() -> bool:
    return _env("PAYMENT_SIMULATION").lower() in ("1", "true", "yes")


def is_configured() -> bool:
    return all(_env(k) for k in ("PAYTR_MERCHANT_ID", "PAYTR_MERCHANT_KEY", "PAYTR_MERCHANT_SALT"))


def provider_status() -> Dict[str, Any]:
    return {
        "provider": "simulation" if simulation_enabled() else "paytr",
        "configured": simulation_enabled() or is_configured(),
        "test_mode": simulation_enabled() or _env("PAYTR_TEST_MODE", "1") != "0",
    }


def to_kurus(amount_tl: float) -> int:
    return int(round(float(amount_tl) * 100))


def _sign(message: str) -> str:
    key = _env("PAYTR_MERCHANT_KEY").encode("utf-8")
    return base64.b64encode(hmac.new(key, message.encode("utf-8"), hashlib.sha256).digest()).decode("ascii")


def build_token_request(
    merchant_oid: str,
    email: str,
    amount_tl: float,
    basket: Sequence[Tuple[str, float, int]],
    user_ip: str,
    user_name: str,
    user_phone: str,
    user_address: str = "Turkiye",
) -> Dict[str, str]:
    """get-token istegi govdesini (imzali) olusturur; saf fonksiyon, test edilebilir."""
    if not merchant_oid.isalnum():
        raise PaytrError("merchant_oid sadece harf/rakam icerebilir")
    merchant_id = _env("PAYTR_MERCHANT_ID")
    salt = _env("PAYTR_MERCHANT_SALT")
    payment_amount = str(to_kurus(amount_tl))
    user_basket = base64.b64encode(
        json.dumps([[name, f"{price:.2f}", qty] for name, price, qty in basket], ensure_ascii=False).encode("utf-8")
    ).decode("ascii")
    no_installment = "1"
    max_installment = "0"
    currency = "TL"
    test_mode = "0" if _env("PAYTR_TEST_MODE", "1") == "0" else "1"

    hash_str = f"{merchant_id}{user_ip}{merchant_oid}{email}{payment_amount}{user_basket}{no_installment}{max_installment}{currency}{test_mode}"
    return {
        "merchant_id": merchant_id,
        "user_ip": user_ip,
        "merchant_oid": merchant_oid,
        "email": email,
        "payment_amount": payment_amount,
        "paytr_token": _sign(hash_str + salt),
        "user_basket": user_basket,
        "debug_on": "1" if test_mode == "1" else "0",
        "no_installment": no_installment,
        "max_installment": max_installment,
        "user_name": (user_name or email)[:60],
        "user_address": (user_address or "Turkiye")[:400],
        "user_phone": (user_phone or "05000000000")[:20],
        "merchant_ok_url": _env("PAYTR_OK_URL", "https://www.yerimebak.com.tr/odeme/sonuc?durum=basarili"),
        "merchant_fail_url": _env("PAYTR_FAIL_URL", "https://www.yerimebak.com.tr/odeme/sonuc?durum=basarisiz"),
        "timeout_limit": _env("PAYTR_TIMEOUT_MIN", "30"),
        "currency": currency,
        "test_mode": test_mode,
        "lang": "tr",
    }


def create_payment(merchant_oid: str, email: str, amount_tl: float, basket: Sequence[Tuple[str, float, int]],
                   user_ip: str, user_name: str = "", user_phone: str = "") -> Dict[str, Any]:
    """Odeme baslatir: PayTR token + iframe adresi (veya simulasyon bilgisi) doner."""
    if simulation_enabled():
        return {"provider": "simulation", "merchant_oid": merchant_oid, "iframe_url": None}
    if not is_configured():
        raise PaytrError("Odeme altyapisi yapilandirilmamis (PAYTR_MERCHANT_ID/KEY/SALT)")

    body = build_token_request(merchant_oid, email, amount_tl, basket, user_ip, user_name, user_phone)
    try:
        response = requests.post(GET_TOKEN_URL, data=body, timeout=20)
        result = response.json()
    except Exception as exc:  # ag / json hatasi
        logger.error("[PAYTR] get-token istegi basarisiz: %s", exc)
        raise PaytrError("Odeme sayfasi olusturulamadi, lutfen tekrar deneyin") from exc
    if result.get("status") != "success" or not result.get("token"):
        logger.error("[PAYTR] get-token reddedildi: %s", result.get("reason"))
        raise PaytrError(f"Odeme baslatilamadi: {result.get('reason') or 'bilinmeyen hata'}")
    token = result["token"]
    return {"provider": "paytr", "merchant_oid": merchant_oid, "token": token, "iframe_url": IFRAME_URL.format(token=token)}


REFUND_URL = "https://www.paytr.com/odeme/iade"


def build_refund_request(merchant_oid: str, amount_tl: float) -> Dict[str, str]:
    """Iade API istegi (imzali); saf fonksiyon, test edilebilir.

    paytr_token = base64(hmac_sha256(merchant_id + merchant_oid + return_amount + salt, merchant_key))
    return_amount TL cinsinden, nokta ondalikli ("150.00").
    """
    merchant_id = _env("PAYTR_MERCHANT_ID")
    return_amount = f"{float(amount_tl):.2f}"
    return {
        "merchant_id": merchant_id,
        "merchant_oid": merchant_oid,
        "return_amount": return_amount,
        "paytr_token": _sign(f"{merchant_id}{merchant_oid}{return_amount}{_env('PAYTR_MERCHANT_SALT')}"),
    }


def refund(merchant_oid: str, amount_tl: float) -> Dict[str, Any]:
    """PayTR uzerinden iade. Simulasyonda ag cagrisi yapilmaz."""
    if simulation_enabled():
        return {"status": "success", "simulated": True, "return_amount": f"{float(amount_tl):.2f}"}
    if not is_configured():
        raise PaytrError("Odeme altyapisi yapilandirilmamis; iade yapilamadi")
    body = build_refund_request(merchant_oid, amount_tl)
    try:
        response = requests.post(REFUND_URL, data=body, timeout=30)
        result = response.json()
    except Exception as exc:
        logger.error("[PAYTR] iade istegi basarisiz: %s", exc)
        raise PaytrError("PayTR'ye ulasilamadi; iade yapilamadi, tekrar deneyin") from exc
    if result.get("status") != "success":
        logger.error("[PAYTR] iade reddedildi: %s", result)
        raise PaytrError(f"PayTR iadeyi reddetti: {result.get('err_msg') or result.get('err_no') or 'bilinmeyen hata'}")
    return result


def callback_hash(merchant_oid: str, status: str, total_amount: str) -> str:
    return _sign(f"{merchant_oid}{_env('PAYTR_MERCHANT_SALT')}{status}{total_amount}")


def verify_callback(form: Dict[str, Any]) -> bool:
    """PayTR bildirim imzasini dogrular (sahte 'odendi' bildirimini engeller)."""
    if not is_configured():
        return False
    expected = callback_hash(str(form.get("merchant_oid", "")), str(form.get("status", "")), str(form.get("total_amount", "")))
    return hmac.compare_digest(expected, str(form.get("hash", "")))


def client_ip(headers: Dict[str, str], fallback: Optional[str]) -> str:
    """PayTR musterinin gercek IP'sini ister; nginx X-Real-IP (Cloudflare'den) iletir."""
    for key in ("x-real-ip", "cf-connecting-ip"):
        value = headers.get(key)
        if value:
            return value.split(",")[0].strip()
    forwarded = headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return fallback or "127.0.0.1"


def basket_line(name: str, price_tl: float, qty: int = 1) -> Tuple[str, float, int]:
    return (name[:100], float(price_tl), int(qty))


def basket(*lines: Tuple[str, float, int]) -> List[Tuple[str, float, int]]:
    return list(lines)
