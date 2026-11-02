"""Tek araştırma -> filtrelenmiş kategorili rapor -> değişmez arşiv -> PDF."""
import io
import json

import pdfplumber
import pytest

from .test_dispatch_flow import client, customer_token, _auth, TEST_DB  # noqa: F401
from .test_tek_rapor import musteri, _payload, _krediler, REFERENCE
from .test_credit_admin_flow import sql
from yerimebak_ai_v5.services import valuation_service, vehicle_risk

pytestmark = pytest.mark.skipif(not TEST_DB, reason='TEST_DATABASE_URL tanımlı değil')


def test_single_research_keeps_verified_metadata_in_archive_and_pdf(client, musteri, monkeypatch):
    uid, headers = musteri
    calls = []
    official = 'https://www.renault.com.tr/servis/clio-triger'
    forum = 'https://forum.donanimhaber.com/clio-sensor'
    complaint = 'https://www.sikayetvar.com/renault/clio-sensor'
    blocked = 'https://kronikmotor.com/clio-adblue'
    sources = {
        official: 'Renault Clio 1.0 TCe triger kayışı için servis bülteni ve geri çağırma.',
        forum: 'Renault Clio 1.0 TCe park sensörü kullanıcı şikâyeti.',
        complaint: 'Renault Clio 1.0 TCe park sensörü kullanıcı şikâyeti.',
        blocked: 'Renault Clio 1.0 TCe AdBlue arızası.',
    }

    def search(query, _client):
        calls.append(query)
        return {'risks': [{'baslik':'Triger kayışı', 'kaynaklar':[official]},
                          {'baslik':'AdBlue arızası', 'kaynaklar':[blocked]}],
                'complaints':[{'baslik':'Park sensörü', 'kaynaklar':[forum, complaint]}],
                'sources':sources, 'cost':.012}

    monkeypatch.setenv('OPENROUTER_API_KEY', 'test-fake')
    monkeypatch.setenv('WEB_RISK_CACHE_DAYS', '0')
    monkeypatch.setattr(vehicle_risk, '_search', search)
    monkeypatch.setattr(valuation_service.web_market_reference, 'get_reference', lambda v: dict(REFERENCE))
    response = client.post('/api/v1/valuation/analyze', headers=headers, json=_payload())
    assert response.status_code == 200, response.text
    body = response.json()
    assert len(calls) == 1
    assert _krediler(uid) == 2 and body['kredi']['dusulen'] == 1
    risks = body['modelRiskleri']['riskler']
    assert len(risks) == 1
    assert risks[0]['kategori'] == 'mekanik_motor' and risks[0]['onem'] == 'yuksek'
    complaints = body['kullaniciSikayetleri']
    assert len(complaints) == 1 and complaints[0]['kaynakSayisi'] == 2
    assert complaints[0]['kategori'] == 'elektronik' and complaints[0]['onem'] == 'orta'
    assert blocked not in response.text and 'AdBlue' not in response.text
    stored = sql('SELECT report_json, valuation_json FROM analysis_history WHERE id=%s',
                 (body['rapor']['id'],), True)[0]
    assert stored['report_json']['modelRiskleri'] == body['modelRiskleri']
    assert stored['report_json']['kullaniciSikayetleri'] == complaints
    costs = json.loads(stored['valuation_json'])
    assert costs['toplam_maliyet_usd'] == .042
    pdf = client.get(f"/api/v1/valuation/reports/{body['rapor']['id']}/pdf", headers=headers)
    assert pdf.status_code == 200
    with pdfplumber.open(io.BytesIO(pdf.content)) as document:
        text = ' '.join(' '.join((p.extract_text() or '').split()) for p in document.pages)
    assert 'Mekanik ve motor' in text and 'Elektronik ve sensör' in text
    assert 'Yüksek masraf' in text and 'Bu araçta en çok dikkat etmeniz gerekenler' in text
    assert text.count('YerimeBak uzmanı bunu yerinde kontrol eder.') == 1
    assert len(calls) == 1 and _krediler(uid) == 2
