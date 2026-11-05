"""Aynı ham aday/kaynak üzerinde eski-yeni doğrulayıcı tanısı; ağ çağrısı yapmaz."""
from collections import Counter
from urllib.parse import urlsplit
from yerimebak_ai_v5.services import vehicle_risk as vr


def _drop_reason(item, sources, vehicle):
    if not isinstance(item, dict) or not isinstance(item.get('baslik'), str):
        return 'Geçersiz aday'
    if not vr._topics(item['baslik']):
        return 'Başlıkta tanınan teknik konu yok'
    details = ' '.join(str(item.get(k) or '') for k in ('baslik', 'aciklama', 'etkiledigi', 'belirtiler', 'kontrol'))
    if vr._fuel_incompatible(details, vehicle):
        return 'Yakıt türüyle uyumsuz konu'
    if vr._incompatible(str(item.get('etkiledigi') or ''), vehicle):
        return 'Adayın motor/şanzıman/yıl kapsamı uyumsuz'
    if not any(isinstance(url, str) and url.rstrip('/') in sources for url in item.get('kaynaklar') or []):
        return 'Atıfta dönen kaynak metni yok'
    return 'Kaynakta konu veya motor/şanzıman/yıl cümlesi doğrulanamadı'


def compare_candidates(items, sources, vehicle, current, legacy):
    previous = legacy._verified_items(items, sources, vehicle)
    accepted = {vr.fold(r['baslik']) for r in current}
    dropped, low, seen = [], [], set()
    for item in items:
        title = item.get('baslik') if isinstance(item, dict) else None
        key = vr.fold(title or '')
        if key in seen and key in accepted:
            dropped.append({'baslik': title, 'neden': 'Tekrarlanan başlık'})
        elif key not in accepted:
            dropped.append({'baslik': title, 'neden': _drop_reason(item, sources, vehicle)})
        seen.add(key)
    for item in current:
        if item.get('guven') != 'dusuk':
            continue
        reasons = []
        for url in item.get('kaynaklar') or []:
            host = urlsplit(url).hostname or ''
            text = sources.get(url, '')
            target = vr._displacements(str(vehicle.get('engine') or '') + ' ' + str(vehicle.get('package') or ''))
            if (vr._domain(host, vr._USER_SOURCES + vr._COMPILATIONS)
                    or any(word in host for word in ('forum', 'club', 'reddit', 'community'))):
                reason = 'Kullanıcı/derleme kaynağı'
            elif vr.fold(vehicle.get('model')) not in vr.fold(text) or (target and not target & vr._displacements(text)):
                reason = 'Kaynakta model/motor kapsamı yetersiz'
            else:
                reason = 'Kaynak mevcut üretici/teknik güven listesinde değil'
            reasons.append({'url': url, 'neden': reason})
        low.append({'baslik': item['baslik'], 'kaynaklar': reasons})
    return {'raw_risk_count': len(items), 'current_verified_count': len(current),
            'legacy_verified_count': len(previous), 'current_visible_count': sum(r.get('guven') in ('orta', 'yuksek') for r in current),
            'legacy_visible_count': sum(r.get('guven') in ('orta', 'yuksek') for r in previous),
            'confidence_counts': dict(Counter(r.get('guven') for r in current)),
            'dropped': dropped, 'low_confidence': low}
