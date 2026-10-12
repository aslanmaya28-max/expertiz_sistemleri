import asyncio
import sys
import os
import re
import time
import logging
from pathlib import Path
from typing import Callable

BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR.parent) not in sys.path:
    sys.path.append(str(BASE_DIR.parent))

from fastapi import FastAPI, WebSocket, Request, Response
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from contextlib import asynccontextmanager
import uvicorn

from yerimebak_ai_v5.api.v1.router import api_router

logger = logging.getLogger(__name__)

# Hata takibi (istege bagli): .env'de SENTRY_DSN tanimliysa hatalar Sentry'ye gider.
if os.getenv("SENTRY_DSN"):
    try:
        import sentry_sdk

        sentry_sdk.init(
            dsn=os.getenv("SENTRY_DSN"),
            environment=os.getenv("SENTRY_ENVIRONMENT", "production"),
            traces_sample_rate=float(os.getenv("SENTRY_TRACES_SAMPLE_RATE", "0")),
            send_default_pii=False,
        )
    except Exception as exc:  # pragma: no cover
        logger.error(f"Sentry baslatilamadi: {exc}")


# 🔒 GÜVENLİK: Rate limiting state
_rate_limit_store: dict = {}

_RATE_LIMIT_MAX_KEYS = 50_000


def _rate_limit_key(request: Request) -> str:
    """Client IP bazli rate limit anahtari.

    X-Real-IP nginx tarafindan yazilir (istemci degistiremez). X-Forwarded-For'un
    ilk degeri istemcinin gonderdigi sahte bir deger olabilecegi icin kullanilmaz.
    """
    client_ip = request.headers.get("X-Real-IP") or (request.client.host if request.client else "unknown")
    return f"rl:{client_ip}:{request.url.path}"

def _check_rate_limit(request: Request, max_requests: int = 60, window_seconds: int = 60) -> bool:
    """🔒 Rate limit kontrolu. True = izin ver, False = limit asildi."""
    key = _rate_limit_key(request)
    now = time.time()
    window_start = now - window_seconds
    
    # Eski kayitlari temizle; bos anahtarlar silinir (bellek sismesin)
    if len(_rate_limit_store) > _RATE_LIMIT_MAX_KEYS:
        for stale in [k for k, v in _rate_limit_store.items() if not v or v[-1] <= window_start]:
            _rate_limit_store.pop(stale, None)
    _rate_limit_store[key] = [t for t in _rate_limit_store.get(key, []) if t > window_start]
    
    if len(_rate_limit_store[key]) >= max_requests:
        return False
    
    _rate_limit_store[key].append(now)
    return True


@asynccontextmanager
async def lifespan(app: FastAPI):
    from yerimebak_ai_v5.core.database_config import DatabaseConfig
    logger.info("[STARTUP] Database bootstrap + alignment...")
    try:
        DatabaseConfig.bootstrap()
        DatabaseConfig.alignment()
        # Personel / talep / atama tablolarini commit ederek hazirla
        from yerimebak_ai_v5.services.dispatch_service import ensure_workflow_schema_once
        ensure_workflow_schema_once()
        # Fiyatlandirma katalogu + PayTR odeme kolonlari
        from yerimebak_ai_v5.services import checkout_service, pricing_service
        pricing_service.ensure_schema()
        checkout_service.ensure_schema()
        # E-posta dogrulama / sifre sifirlama
        from yerimebak_ai_v5.services import account_service
        account_service.ensure_schema()
        # Ilk admin (.env: INITIAL_ADMIN_EMAIL / INITIAL_ADMIN_PASSWORD); varsa dokunulmaz
        from yerimebak_ai_v5.services.auth_service import get_auth_service
        get_auth_service().ensure_initial_admin()
        logger.info("[STARTUP] Database ready.")
    except Exception as e:
        logger.error(f"[STARTUP] Database init failed: {e}", exc_info=True)

    # Merkezi AI analiz robotu: gonderimde arka planda hemen calisir; bu dongu
    # basarisiz olan / sunucu yeniden baslarken yarim kalan pending_ai raporlarini toplar.
    ai_worker = None
    ai_task = None
    if os.getenv("AI_WORKER_ENABLED", "true").lower() in ("1", "true", "yes"):
        try:
            from yerimebak_ai_v5.workers.ai_analysis_worker import get_ai_analysis_worker
            ai_worker = get_ai_analysis_worker()
            ai_task = asyncio.create_task(
                ai_worker.run_loop(int(os.getenv("AI_WORKER_INTERVAL", "30")))
            )
            logger.info("[STARTUP] AI analysis worker loop started.")
        except Exception as e:
            logger.error(f"[STARTUP] AI worker could not start: {e}")
    yield
    logger.info("[SHUTDOWN] Cleaning up...")
    if ai_worker is not None:
        ai_worker.stop()
    if ai_task is not None:
        ai_task.cancel()


# 🔒 GÜVENLİK: CORS - Sadece izin verilen originler
ALLOWED_ORIGINS = os.getenv("CORS_ORIGINS", "http://localhost:8505,http://localhost:3000,http://localhost:8000").split(",")

app = FastAPI(
    title="Yerimebak SaaS API",
    description="Antigravity v8.1 Forensic Evidence Orchestrator",
    version="8.1.0",
    lifespan=lifespan,
)


def _build_allowed_origins():
    origins = [o.strip() for o in ALLOWED_ORIGINS if o.strip()]
    if os.getenv("DEBUG_MODE", "False").lower() == "true":
        return origins
    return origins


# 🔒 GÜVENLİK: CORS middleware - sadece izin verilen metodlar ve headerlar
app.add_middleware(
    CORSMiddleware,
    allow_origins=_build_allowed_origins(),
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-API-Key", "X-CSRF-Token"],
)

# 🔒 DÜZELTİLDİ (Domain): *.yerimebak.com → *.yerimebak.com.tr
# Gerçek production domain .com.tr, .com değil.
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=[
        "localhost",
        "127.0.0.1",
        # Docker ic agi (healthcheck / servisler arasi cagrilar)
        "app",
        "*.yerimebak.com.tr",
        "yerimebak.com.tr",
        "app.yerimebak.com.tr",
        "api.yerimebak.com.tr",
    ],
)


# 🔒 GÜVENLİK: Security headers + rate limiting middleware
@app.middleware("http")
async def security_middleware(request: Request, call_next: Callable) -> Response:
    # Rate limiting
    if not _check_rate_limit(request):
        return Response(
            content='{"error": "Cok fazla istek. Lutfen bekleyin."}',
            status_code=429,
            media_type="application/json",
            headers={"Retry-After": "60", "X-RateLimit-Reset": str(int(time.time() + 60))},
        )
    
    response = await call_next(request)
    
    # 🔒 GÜVENLİK: Security headers
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    response.headers["Cache-Control"] = "no-store, max-age=0"
    
    return response

static_dir = BASE_DIR / "dashboard" / "static"
if not static_dir.exists():
    static_dir = Path("yerimebak_ai_v5/dashboard/static")

if static_dir.exists():
    app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")

app.include_router(api_router, prefix="/api/v1")

from yerimebak_ai_v5.core.broadcaster import broadcaster


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str = None):
    if not token:
        query_params = dict(websocket.query_params)
        token = query_params.get("token") or query_params.get("api_key")
    if not token:
        await websocket.close(code=4001, reason="Authentication required")
        return
    try:
        from yerimebak_ai_v5.services.auth_service import get_auth_service
        auth = get_auth_service()
        user = auth.verify_api_key(token) if len(token) > 30 else auth.verify_token(token)
        if not user:
            await websocket.close(code=4001, reason="Invalid credentials")
            return
    except Exception:
        await websocket.close(code=4001, reason="Auth verification failed")
        return

    await broadcaster.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except Exception:
        broadcaster.disconnect(websocket)


@app.get("/health")
async def health_check():
    return {"status": "ok", "version": "8.1.0"}


if __name__ == "__main__":
    print("\n  YERIMEBAK AI v8.1 - FastAPI Server Baslatiliyor...")
    print("  Local: http://127.0.0.1:8000")
    print("  API Docs: http://127.0.0.1:8000/docs\n")
    uvicorn.run("yerimebak_ai_v5.main:app", host="127.0.0.1", port=8000, reload=True)
