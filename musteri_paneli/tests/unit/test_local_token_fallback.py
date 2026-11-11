"""İptal edilen yerel JWT ikinci doğrulayıcıdan oturum kazanamaz."""
from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from yerimebak_ai_v5.api.v1.endpoints import auth
from yerimebak_ai_v5.services.auth_service import _create_jwt


@pytest.mark.parametrize('dependency', [auth.get_current_user, auth.get_authenticated_user])
def test_iptal_edilmis_yerel_token_supabase_olarak_kabul_edilmez(monkeypatch, dependency):
    monkeypatch.setattr(auth, 'get_auth_service', lambda: SimpleNamespace(verify_token=lambda token: None))
    monkeypatch.setattr(auth, 'validate_supabase_jwt', lambda token: {'id': '1', 'is_supabase': True})
    token = _create_jwt({'sub': '1', 'email': 'test@yerimebak.test', 'tv': 0})
    with pytest.raises(HTTPException) as denied:
        dependency(f'Bearer {token}')
    assert denied.value.status_code == 401


def test_yerel_olmayan_token_supabase_dogrulayicisina_gider(monkeypatch):
    monkeypatch.setattr(auth, 'get_auth_service', lambda: SimpleNamespace(verify_token=lambda token: None))
    user = {'id': 'supabase-user', 'is_supabase': True}
    monkeypatch.setattr(auth, 'validate_supabase_jwt', lambda token: user)
    assert auth.get_authenticated_user('Bearer foreign-token') == user
