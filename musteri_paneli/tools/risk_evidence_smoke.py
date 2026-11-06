"""Beş araç için 029/030 kaynak ve takma ad kapsamı ölçümü.

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


def selected_vehicles(technical_pair=False):
    if technical_pair:
        return TECHNICAL_VEHICLES
    return VEHICLES + TECHNICAL_VEHICLES + [
        {'brand': 'Fiat', 'model': 'Egea Cross', 'package': '1.6 Multijet', 'engine': '1.6 Multijet',
         'transmission': 'Manuel', 'fuel': 'Dizel', 'year': 2021, 'km': 100000},
    ]


if __name__ == '__main__':
    os.environ['DATABASE_URL'] = 'postgresql://postgres:test@localhost:55432/ybtest_030_smoke'
    os.environ['WEB_RISK_CACHE_DAYS'] = '0'
    os.environ['RISK_COST_SEARCH_LIMIT'] = '20'
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--technical-pair', action='store_true', help='Ford Focus / Volkswagen Golf çiftini ölç')
    args = parser.parse_args()
    if not os.getenv('OPENROUTER_API_KEY'):
        raise SystemExit('Yetkili süreçte OPENROUTER_API_KEY tanımlı olmalı; gizli dosya okunmadı.')
    outputs = []
    legacy = types.ModuleType('risk_baseline_029')
    source = subprocess.check_output(['git', 'show', '1701e1c:musteri_paneli/yerimebak_ai_v5/services/vehicle_risk.py'],
        cwd=Path(__file__).resolve().parents[2], encoding='utf-8')
    exec(compile(source, '1701e1c/vehicle_risk.py', 'exec'), legacy.__dict__)
    original = vr._verified_items
    for vehicle in selected_vehicles(args.technical_pair):
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
                        'alias_accepted_source_count': sum(t['alias_accepted_source_count'] for t in traces),
                        'diagnostics': traces,
                        'items': [{key: r.get(key) for key in ('baslik', 'guven', 'kategori',
                                   'tahminiMaliyet', 'tipikKm', 'maliyetKaynagi', 'kmKaynagi')} for r in visible]})
    print(json.dumps(outputs, ensure_ascii=False, indent=2))
    if any(row['error'] for row in outputs):
        raise SystemExit(1)
