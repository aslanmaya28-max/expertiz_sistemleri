"""Aynı ham aday/kaynak üzerinde eski-yeni doğrulayıcı tanısı; ağ çağrısı yapmaz."""
from collections import Counter
from yerimebak_ai_v5.services import vehicle_risk as vr
from yerimebak_ai_v5.services import model_aliases, risk_evidence


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
            text = sources.get(url, '')
            topics = risk_evidence.evidence_topics(vr._topics(item['baslik']), item['baslik'])
            _, reason = vr._confidence_details(url, text, vehicle, topics)
            reasons.append({'url': url, 'neden': reason})
        low.append({'baslik': item['baslik'], 'kaynaklar': reasons})
    alias_urls = set()
    for item in current:
        topics = risk_evidence.evidence_topics(vr._topics(item['baslik']), item['baslik'])
        for url in item.get('kaynaklar') or []:
            text = sources.get(url, '')
            if (model_aliases.matches(text, vehicle, aliases_only=True)
                    and vr._scoped(text, vehicle, topics)
                    and not vr._scoped(text, {**vehicle, 'brand': ''}, topics)):
                alias_urls.add(url)
    return {'alias_accepted_source_count': len(alias_urls),
            'raw_risk_count': len(items), 'current_verified_count': len(current),
            'legacy_verified_count': len(previous), 'current_visible_count': sum(r.get('guven') in ('orta', 'yuksek') for r in current),
            'legacy_visible_count': sum(r.get('guven') in ('orta', 'yuksek') for r in previous),
            'confidence_counts': dict(Counter(r.get('guven') for r in current)),
            'dropped': dropped, 'low_confidence': low}
