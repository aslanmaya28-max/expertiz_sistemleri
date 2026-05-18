# -*- coding: utf-8 -*-
"""
Supabase JWT Validation Middleware
Validates Supabase-issued JWT tokens for Flutter-to-Python authentication
"""
import os
import logging
import base64
import hashlib
import hmac
import json
import time
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)

try:
    from jose import jwt, JWTError, ExpiredSignatureError
    JOSE_AVAILABLE = True
except ImportError:
    JOSE_AVAILABLE = False
    logger.warning("python-jose not installed. Supabase JWT validation disabled.")


SUPABASE_JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET", "")
SUPABASE_URL = os.getenv("SUPABASE_URL", "")


def validate_supabase_jwt(token: str) -> Optional[Dict[str, Any]]:
    """
    Validate a Supabase-issued JWT token.
    
    Returns user claims dict if valid, None otherwise.
    Claims include: sub (user_id), email, role, app_metadata, etc.
    """
    if not JOSE_AVAILABLE:
        return _validate_hs256_jwt(token)

    if not SUPABASE_JWT_SECRET:
        logger.warning("SUPABASE_JWT_SECRET not configured")
        return None

    try:
        payload = jwt.decode(
            token,
            SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            options={
                "verify_aud": False,
                "verify_exp": True,
            },
        )

        user_id = payload.get("sub")
        if not user_id:
            logger.warning("Supabase JWT missing 'sub' claim")
            return None

        return {
            "id": user_id,
            "email": payload.get("email", ""),
            "role": payload.get("role", "authenticated"),
            "app_metadata": payload.get("app_metadata", {}),
            "user_metadata": payload.get("user_metadata", {}),
            "is_supabase": True,
        }

    except ExpiredSignatureError:
        logger.warning("Supabase JWT expired")
        return None
    except JWTError as e:
        logger.warning(f"Supabase JWT validation failed: {e}")
        return None
    except Exception as e:
        logger.warning(f"Unexpected JWT error: {e}")
        return None


def _b64url_decode(value: str) -> bytes:
    padded = value + "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(padded.encode("ascii"))


def _validate_hs256_jwt(token: str) -> Optional[Dict[str, Any]]:
    if not SUPABASE_JWT_SECRET:
        logger.warning("SUPABASE_JWT_SECRET not configured")
        return None

    try:
        header_b64, payload_b64, signature_b64 = token.split(".")
        header = json.loads(_b64url_decode(header_b64))
        if header.get("alg") != "HS256":
            logger.warning("Unsupported Supabase JWT algorithm")
            return None

        signing_input = f"{header_b64}.{payload_b64}".encode("ascii")
        expected = hmac.new(
            SUPABASE_JWT_SECRET.encode("utf-8"),
            signing_input,
            hashlib.sha256,
        ).digest()
        actual = _b64url_decode(signature_b64)
        if not hmac.compare_digest(expected, actual):
            logger.warning("Supabase JWT signature validation failed")
            return None

        payload = json.loads(_b64url_decode(payload_b64))
        exp = payload.get("exp")
        if exp is not None and int(exp) < int(time.time()):
            logger.warning("Supabase JWT expired")
            return None

        user_id = payload.get("sub")
        if not user_id:
            logger.warning("Supabase JWT missing 'sub' claim")
            return None

        return {
            "id": user_id,
            "email": payload.get("email", ""),
            "role": payload.get("role", "authenticated"),
            "app_metadata": payload.get("app_metadata", {}),
            "user_metadata": payload.get("user_metadata", {}),
            "is_supabase": True,
        }
    except Exception as e:
        logger.warning(f"Supabase JWT fallback validation failed: {e}")
        return None


def get_supabase_user_id(token: str) -> Optional[str]:
    """Extract user ID from Supabase JWT without full validation (for quick checks)."""
    try:
        if JOSE_AVAILABLE and SUPABASE_JWT_SECRET:
            payload = jwt.decode(
                token,
                SUPABASE_JWT_SECRET,
                algorithms=["HS256"],
                options={"verify_aud": False, "verify_exp": False},
            )
            return payload.get("sub")
    except Exception:
        pass
    return None
