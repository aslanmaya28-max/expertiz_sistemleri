import pytest
from yerimebak_ai_v5.services.payment_service import credit_movement

@pytest.mark.parametrize('action,stored,description,kind,amount,source', [
    ('credit_purchase', 5, 'PayTR INTERNAL-ORDER: 5 kredi', 'yukleme', 5, 'paytr'),
    ('credit_purchase', 10, 'Google Play GPA.1234-5678: token-secret', 'yukleme', 10, 'google_play'),
    ('analysis', 1, 'token-secret', 'kullanim', -1, 'analiz'),
    ('google_play_voided', -3, 'Google Play GPA.secret: token-secret', 'iade', -3, 'google_play'),
    ('credit_refund', -5, 'Iade INTERNAL-ORDER: token-secret', 'iade', -5, 'paytr'),
    ('admin_adjustment', -4, 'token-secret', 'yukleme', 4, 'admin'),
    ('admin_adjustment', 2, 'token-secret', 'duzeltme', -2, 'admin'),
    ('account_deleted', -8, 'token-secret', 'sifirlama', -8, 'hesap_silme'),
    ('welcome_bonus', 2, 'token-secret', 'yukleme', 2, 'admin'),
    ('future_action', -7, 'token-secret', 'duzeltme', -7, 'admin'),
])
def test_credit_movement_mapping_and_privacy(action, stored, description, kind, amount, source):
    result = credit_movement({'id': 12, 'created_at': None, 'action': action,
                              'credits_used': stored, 'description': description})
    assert (result['tur'], result['miktar'], result['kaynak']) == (kind, amount, source)
    assert set(result) == {'id', 'tarih', 'tur', 'miktar', 'aciklama', 'kaynak'}
    assert not any(secret in result['aciklama'] for secret in ('token-secret', 'INTERNAL-ORDER', 'GPA.'))


def test_legacy_movement_with_missing_amount_and_date_is_preserved():
    result = credit_movement({'id': 13, 'created_at': None, 'action': 'legacy_unknown',
                              'credits_used': None, 'description': None})
    assert result['id'] == 13 and result['miktar'] == 0 and result['tarih'] is None
    assert result['tur'] == 'duzeltme'
