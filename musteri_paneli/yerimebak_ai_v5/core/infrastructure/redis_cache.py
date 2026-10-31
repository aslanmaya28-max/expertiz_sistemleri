import os
import json
import logging
import time
from typing import Any, Optional

logger = logging.getLogger(__name__)

_redis_client = None
_retry_after = 0.0  # baglanti hatasindan sonra her istekte yeniden denenmesin


def _get_redis():
    global _redis_client, _retry_after
    if _redis_client is not None:
        return _redis_client
    if time.monotonic() < _retry_after:
        return None
    try:
        import redis
        url = os.getenv("REDIS_URL", "redis://redis:6379/0")
        # Kisa zaman asimi: Redis yavaslar/duserse istekler beklemez, onbelleksiz devam eder
        _redis_client = redis.from_url(url, decode_responses=True, socket_connect_timeout=1, socket_timeout=1)
        _redis_client.ping()
        logger.info("[REDIS] Connected.")
        return _redis_client
    except Exception as e:
        logger.warning(f"[REDIS] Connection failed: {e}")
        _redis_client = None
        _retry_after = time.monotonic() + 30
        return None


def cache_get(key: str) -> Optional[Any]:
    r = _get_redis()
    if not r:
        return None
    try:
        val = r.get(key)
        if val:
            return json.loads(val)
    except Exception:
        pass
    return None


def cache_set(key: str, value: Any, ttl: int = 300) -> None:
    r = _get_redis()
    if not r:
        return
    try:
        r.setex(key, ttl, json.dumps(value, default=str, ensure_ascii=False))
    except Exception:
        pass


def cache_delete(pattern: str) -> None:
    r = _get_redis()
    if not r:
        return
    try:
        for key in r.scan_iter(pattern):
            r.delete(key)
    except Exception:
        pass


def cache_invalidate_vitrin() -> None:
    cache_delete("vitrin:*")
