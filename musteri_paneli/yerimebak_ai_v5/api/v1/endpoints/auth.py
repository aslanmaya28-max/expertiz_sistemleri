import re
from fastapi import APIRouter, HTTPException, Header, Depends, Request
from typing import Dict, Any, Optional
from pydantic import BaseModel, field_validator

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.services.auth_service import get_auth_service, _create_jwt
from yerimebak_ai_v5.core.supabase_auth import validate_supabase_jwt
from yerimebak_ai_v5.core.client_ip import client_ip as _client_ip

router = APIRouter()


class RegisterRequest(BaseModel):
    email: str
    password: str
    full_name: Optional[str] = None
    phone: Optional[str] = None
    # Kullanim Kosullari + KVKK Aydinlatma Metni onayi (zorunlu)
    terms_accepted: bool = False

    # 🔒 GÜVENLİK: Email ve şifre validasyonu
    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        if not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', v):
            raise ValueError("Gecersiz email formatı")
        return v.lower().strip()

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("Sifre en az 6 karakter olmalidir")
        if len(v) > 128:
            raise ValueError("Sifre en fazla 128 karakter olabilir")
        return v


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


class LoginRequest(BaseModel):
    email: str
    password: str

    # 🔒 GÜVENLİK: Email validasyonu
    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        if not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', v):
            raise ValueError("Gecersiz email formatı")
        return v.lower().strip()


class ForgotPasswordRequest(BaseModel):
    email: str


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str


class VerifyEmailRequest(BaseModel):
    token: str


class AdminCreateRequest(BaseModel):
    email: str
    password: str
    admin_key: str

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        if not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', v):
            raise ValueError("Gecersiz email formatı")
        return v.lower().strip()

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("Sifre en az 6 karakter olmalidir")
        return v


class ProfileUpdateRequest(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None
    company_name: Optional[str] = None
    city: Optional[str] = None
    tax_number: Optional[str] = None
    tax_office: Optional[str] = None
    invoice_address: Optional[str] = None

    # 🔒 GÜVENLİK: Input sanitization
    @field_validator("full_name", "company_name", "city", "tax_office", "invoice_address")
    @classmethod
    def sanitize_text(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        # HTML tag'lerini temizle
        v = re.sub(r'<[^>]*>', '', v)
        # Zararlı karakterleri temizle
        v = re.sub(r'[<>\'"]', '', v)
        return v.strip()[:200]


def _ensure_profile_columns(cursor: Any) -> None:
    profile_columns = {
        "company_name": "TEXT",
        "city": "TEXT",
        "tax_number": "TEXT",
        "tax_office": "TEXT",
        "invoice_address": "TEXT",
    }
    for column, column_type in profile_columns.items():
        cursor.execute(f"ALTER TABLE users ADD COLUMN IF NOT EXISTS {column} {column_type}")


def _public_profile(user: Dict[str, Any]) -> Dict[str, Any]:
    role = _public_role(user.get("role", "user"))
    return {
        "id": user.get("id"),
        "email": user.get("email"),
        "full_name": user.get("full_name"),
        "phone": user.get("phone"),
        "credits": user.get("credits", 0),
        "tier": user.get("tier", "free"),
        "role": role,
        "company_name": user.get("company_name"),
        "city": user.get("city"),
        "tax_number": user.get("tax_number"),
        "tax_office": user.get("tax_office"),
        "invoice_address": user.get("invoice_address"),
        "email_verified": user.get("email_verified") is not False,
        "must_change_password": bool(user.get("must_change_password")),
    }


def _public_role(value: Any) -> str:
    role = str(value or "user").lower().strip()
    if role in ("user", "musteri"):
        return "customer"
    if role in ("personel", "personnel", "staff", "field_staff"):
        return "field_staff"
    return role


def get_current_user(
    api_key: str = Header(None, alias="X-API-Key"),
    authorization: str = Header(None, alias="Authorization"),
) -> Dict[str, Any]:
    auth = get_auth_service()

    if api_key:
        user = auth.verify_api_key(api_key)
        if user:
            return user

    if authorization and authorization.startswith("Bearer "):
        token = authorization[7:]
        user = auth.verify_token(token)
        if user:
            return user

        supabase_user = validate_supabase_jwt(token)
        if supabase_user:
            return supabase_user

    raise HTTPException(status_code=401, detail="API Key veya token gerekli")


def get_current_user_optional(authorization: str = Header(None, alias="Authorization")) -> Optional[Dict[str, Any]]:
    auth = get_auth_service()

    if authorization and authorization.startswith("Bearer "):
        token = authorization[7:]
        user = auth.verify_token(token)
        if user:
            return user

    return None


def get_authenticated_user(
    api_key: str = Header(None, alias="X-API-Key"),
    authorization: str = Header(None, alias="Authorization"),
) -> Dict[str, Any]:
    auth = get_auth_service()

    if api_key:
        user = auth.verify_api_key(api_key)
        if user:
            return user

    if authorization and authorization.startswith("Bearer "):
        token = authorization[7:]

        user = auth.verify_token(token)
        if user:
            return user

        supabase_user = validate_supabase_jwt(token)
        if supabase_user:
            return supabase_user

    raise HTTPException(status_code=401, detail="Gecerli bir API Key veya token gerekli")


def _is_admin_role(value: Any) -> bool:
    return str(value or "").lower().strip() == "admin"


def _metadata_has_admin_role(user: Dict[str, Any]) -> bool:
    metadata = user.get("app_metadata")
    if isinstance(metadata, dict) and (
        _is_admin_role(metadata.get("role")) or _is_admin_role(metadata.get("user_role"))
    ):
        return True
    return False


def _database_admin_role(user: Dict[str, Any]) -> Optional[str]:
    user_id = str(user.get("id") or "")
    email = str(user.get("email") or "")
    if not user_id and not email:
        return None

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT role
            FROM users
            WHERE id::text = %s OR lower(email) = lower(%s)
            LIMIT 1
            """,
            (user_id, email),
        )
        row = cursor.fetchone()
        if row:
            role = row.get("role") if isinstance(row, dict) else row[0]
            if role:
                return str(role)

        cursor.execute(
            """
            SELECT rol
            FROM profiles
            WHERE id::text = %s OR lower(email) = lower(%s)
            LIMIT 1
            """,
            (user_id, email),
        )
        row = cursor.fetchone()
        if row:
            role = row.get("rol") if isinstance(row, dict) else row[0]
            if role:
                return str(role)
    except Exception:
        return None
    finally:
        DatabaseConfig.return_connection(conn)

    return None


def get_admin_user(user: Dict[str, Any] = Depends(get_authenticated_user)) -> Dict[str, Any]:
    if _is_admin_role(user.get("role")) or _metadata_has_admin_role(user):
        return user

    db_role = _database_admin_role(user)
    if not _is_admin_role(db_role):
        raise HTTPException(status_code=403, detail="Admin yetkisi gerekli")

    enriched = dict(user)
    enriched["role"] = "admin"
    enriched["admin_role_source"] = "database"
    return enriched


def _create_token_payload(user: Dict[str, Any]) -> str:
    return _create_jwt({
        "sub": user["id"],
        "email": user["email"],
        "full_name": user.get("full_name"),
        "phone": user.get("phone"),
        "credits": user.get("credits", 0),
        "tier": user.get("tier", "free"),
        "role": _public_role(user.get("role", "user")),
    })


@router.get("/profile")
async def get_profile(user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    auth = get_auth_service()
    conn = auth_service_conn = None
    try:
        from yerimebak_ai_v5.core.database_config import DatabaseConfig

        auth_service_conn = DatabaseConfig.get_connection()
        conn = auth_service_conn
        cursor = conn.cursor()
        _ensure_profile_columns(cursor)
        conn.commit()
        cursor.execute("SELECT * FROM users WHERE id = %s", (user["id"],))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Kullanici bulunamadi")
        return {"success": True, "profile": _public_profile(dict(row))}
    finally:
        if conn is not None:
            from yerimebak_ai_v5.core.database_config import DatabaseConfig

            DatabaseConfig.return_connection(conn)


@router.put("/profile")
async def update_profile(
    payload: ProfileUpdateRequest,
    user: Dict[str, Any] = Depends(get_current_user),
) -> Dict[str, Any]:
    from yerimebak_ai_v5.core.database_config import DatabaseConfig

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_profile_columns(cursor)
        updates = payload.model_dump(exclude_unset=True)
        allowed = {
            "full_name",
            "phone",
            "company_name",
            "city",
            "tax_number",
            "tax_office",
            "invoice_address",
        }
        updates = {key: value for key, value in updates.items() if key in allowed}
        if updates:
            assignments = ", ".join([f"{key} = %s" for key in updates.keys()])
            cursor.execute(
                f"UPDATE users SET {assignments} WHERE id = %s",
                tuple(updates.values()) + (user["id"],),
            )

        conn.commit()

        cursor.execute("SELECT * FROM users WHERE id = %s", (user["id"],))
        row = cursor.fetchone()
        return {"success": True, "profile": _public_profile(dict(row))}
    finally:
        DatabaseConfig.return_connection(conn)


@router.post("/register")
async def register(request: RegisterRequest, http_request: Request) -> Dict[str, Any]:
    if not request.terms_accepted:
        raise HTTPException(status_code=400, detail="Kullanim Kosullari ve KVKK Aydinlatma Metni onaylanmalidir")
    auth = get_auth_service()
    result = auth.register(email=request.email, password=request.password, full_name=request.full_name, phone=request.phone)
    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])
    from yerimebak_ai_v5.services import account_service

    account_service.record_consents(
        result["user"]["id"], ["terms_of_use", "kvkk_notice"],
        ip=_client_ip(http_request.headers, http_request.client.host if http_request.client else None),
    )
    return result


@router.post("/login")
async def login(request: LoginRequest) -> Dict[str, Any]:
    auth = get_auth_service()
    result = auth.login(email=request.email, password=request.password)
    if "error" in result:
        raise HTTPException(status_code=401, detail=result["error"])

    token = _create_token_payload(result["user"])
    result["token"] = token
    return result


@router.post("/change-password")
async def change_password(
    payload: ChangePasswordRequest,
    user: Dict[str, Any] = Depends(get_current_user),
) -> Dict[str, Any]:
    result = get_auth_service().change_password(user.get("id"), payload.current_password, payload.new_password)
    if "error" in result:
        raise HTTPException(status_code=int(result.get("http_status") or 400), detail=result["error"])
    return result


# Telefon / SMS ile kayit ve giris kaldirildi: hicbir arayuz kullanmiyordu ve
# dogrulamasiz hesap acilmasina (bedava kredi istismari) izin veriyordu.


@router.post("/forgot-password")
async def forgot_password(request: ForgotPasswordRequest) -> Dict[str, Any]:
    """Sifremi unuttum: kayitli e-postaya tek kullanimlik baglanti gonderir."""
    from yerimebak_ai_v5.services import account_service

    return account_service.request_password_reset(request.email)


@router.post("/reset-password")
async def reset_password(request: ResetPasswordRequest) -> Dict[str, Any]:
    from yerimebak_ai_v5.services import account_service

    result = account_service.reset_password(request.token, request.new_password)
    if "error" in result:
        raise HTTPException(status_code=int(result.get("http_status") or 400), detail=result["error"])
    return result


@router.post("/verify-email")
async def verify_email(request: VerifyEmailRequest) -> Dict[str, Any]:
    """E-posta dogrulama; hos geldin kredisi ilk dogrulamada yuklenir."""
    from yerimebak_ai_v5.services import account_service

    result = account_service.verify_email(request.token)
    if "error" in result:
        raise HTTPException(status_code=int(result.get("http_status") or 400), detail=result["error"])
    return result


@router.post("/resend-verification")
async def resend_verification(user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    from yerimebak_ai_v5.services import account_service

    result = account_service.resend_verification(user)
    if "error" in result:
        raise HTTPException(status_code=int(result.get("http_status") or 400), detail=result["error"])
    return result


@router.get("/me")
async def get_me(user: Dict[str, Any] = Depends(get_authenticated_user)) -> Dict[str, Any]:
    return {"success": True, "user": user}


@router.post("/refresh-token")
async def refresh_token(user: Dict[str, Any] = Depends(get_authenticated_user)) -> Dict[str, Any]:
    auth = get_auth_service()
    new_token = auth.refresh_token(user["id"])
    if not new_token:
        raise HTTPException(status_code=401, detail="Token yenileme basarisiz")
    return {"success": True, "token": new_token}


@router.post("/admin/create")
async def create_admin(request: AdminCreateRequest) -> Dict[str, Any]:
    auth = get_auth_service()
    result = auth.create_admin(email=request.email, password=request.password, admin_key=request.admin_key)
    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])
    return result
