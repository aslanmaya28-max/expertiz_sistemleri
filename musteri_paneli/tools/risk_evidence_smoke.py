"""İki gerçek araç modeli için kontrollü önce/sonra kaynak kapsamı ölçümü.

Anahtar yetkili süreç ortamından gelir; gizli dosya okunmaz. Tek özel yerel test
veritabanı yalnız bütçe sayacı içindir; uygulama ve demo verilerine dokunmaz.
"""
import json
import os
import argparse
from pathlib import Path
import subprocess
import types
os.environ['PYTHON_DOTENV_DISABLED'] = '1'
os.environ['DATABASE_URL'] = 'postgresql://postgres:test@localhost:55432/ybtest_026_smoke'
os.environ['WEB_RISK_CACHE_DAYS'] = '0'
os.environ['RISK_COST_SEARCH_LIMIT'] = '20'

from yerimebak_ai_v5.services import vehicle_risk as vr
from tools.risk_smoke_diagnostics import compare_candidates

VEHICLES = [
    {'brand': 'Cupra', 'model': 'Formentor', 'package': '1.5 TSI DSG', 'engine': '1.5 TSI',
     'transmission': 'Otomatik', 'fuel': 'Benzin', 'year': 2023, 'km': 80000},
    {'brand': 'Fiat', 'model': 'Egea', 'package': '1.3 Multijet', 'engine': '1.3 Multijet',
     'transmission': 'Manuel', 'fuel': 'Dizel', 'year': 2020, 'km': 130000},
]

TECHNICAL_VEHICLES = [
    {'brand': 'Ford', 'model': 'Focus', 'package': '1.0 EcoBoost', 'engine': '1.0 EcoBoost',
     'transmission': 'Manuel', 'fuel': 'Benzin', 'year': 2017, 'km': 110000},
    {'brand': 'Volkswagen', 'model': 'Golf', 'package': '1.4 TSI DSG', 'engine': '1.4 TSI',
     'transmission': 'Otomatik', 'fuel': 'Benzin', 'year': 2016, 'km': 130000},
]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--technical-pair', action='store_true', help='Ford Focus / Volkswagen Golf çiftini ölç')
    args = parser.parse_args()
    if not os.getenv('OPENROUTER_API_KEY'):
        raise SystemExit('Yetkili süreçte OPENROUTER_API_KEY tanımlı olmalı; gizli dosya okunmadı.')
    outputs = []
    legacy = types.ModuleType('risk_baseline_026')
    source = subprocess.check_output(['git', 'show', 'e09f9cb:musteri_paneli/yerimebak_ai_v5/services/vehicle_risk.py'],
        cwd=Path(__file__).resolve().parents[2], encoding='utf-8')
    exec(compile(source, 'e09f9cb/vehicle_risk.py', 'exec'), legacy.__dict__)
    original = vr._verified_items
    for vehicle in (TECHNICAL_VEHICLES if args.technical_pair else VEHICLES):
        traces = []
        def traced(items, sources, current_vehicle):
            result = original(items, sources, current_vehicle)
            traces.append(compare_candidates(items, sources, current_vehicle, result, legacy))
            return result
        vr._verified_items = traced
        try:
            report = vr.get_model_risks(vehicle)
        finally:
            vr._verified_items = original
        scope = report.get('scope') or {}
        visible = [r for r in report['riskler'] if r.get('guven') in ('orta', 'yuksek')]
        outputs.append({'vehicle': f"{vehicle['brand']} {vehicle['model']} {vehicle['package']}",
                        'risk_count': len(visible), 'coverage': scope.get('coverage'),
                        'extra_searches': scope.get('cost_searches', 0),
                        'extra_cost_usd': scope.get('cost_search_usd', 0),
                        'total_cost_usd': scope.get('cost_usd'), 'error': report.get('hata', False),
                        'diagnostics': traces,
                        'items': [{key: r.get(key) for key in ('baslik', 'guven', 'kategori',
                                   'tahminiMaliyet', 'tipikKm', 'maliyetKaynagi', 'kmKaynagi')} for r in visible]})
    print(json.dumps(outputs, ensure_ascii=False, indent=2))
    if any(row['error'] for row in outputs):
        raise SystemExit(1)
