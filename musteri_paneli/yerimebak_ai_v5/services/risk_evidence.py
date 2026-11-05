"""Konuya bağlı kaynak kanıtı; kilometre/masraf tahmin etmez."""
from copy import deepcopy
from datetime import datetime
import re
from zoneinfo import ZoneInfo
from yerimebak_ai_v5.services.web_market_reference import fold


def today():
    return datetime.now(ZoneInfo('Europe/Istanbul')).date().isoformat()


def category(topics):
    keys = set(topics)
    if keys & {'sanziman', 'mekatronik', 'debriyaj', 'volan'}:
        return 'sanziman'
    if keys & {'sensor', 'adas', 'elektronik_unite', 'multimedya', 'anahtarsiz', 'gosterge', 'aku', 'far_bugusu'}:
        return 'elektronik'
    if keys & {'suspansiyon', 'fren', 'lastik', 'rot', 'aks', 'direksiyon'}:
        return 'alt_takim'
    if keys & {'trim', 'kaplama', 'kasa', 'kaporta'}:
        return 'kaporta'
    if keys & {'triger', 'zincir', 'dpf', 'egr', 'enjektor', 'turbo', 'yag', 'sogutma',
               'adblue', 'yakit_pompasi', 'yag_pompasi', 'motor', 'egzoz', 'buji', 'atesleme',
               'ariza_lambasi', 'guc_kaybi'}:
        return 'motor'
    return 'diger'


def sentences(text):
    return re.split(r'(?<!\d)[.!?](?!\d)|[\n;]', text)


def evidence_topics(topics, title=None):
    """DSG gibi araç bağlamını, adı verilen arızalı parçanın kanıtı sayma."""
    keys = list(dict.fromkeys(topics))
    if ('sanziman' in keys and title is not None
            and not re.search(r'\b(?:sanziman|transmission|gearbox)\w*', fold(title))
            and any(key not in ('sanziman', 'geri_cagirma') for key in keys)):
        keys.remove('sanziman')
    concrete = [key for key in keys if key != 'geri_cagirma']
    return concrete or keys


_N = r'(?:\d{1,3}(?:[. ]\d{3})+|\d+)'


def km_range(sources, topics, topic_terms):
    required = set(topics) - {'geri_cagirma'} or set(topics)
    for url, text in sources.items():
        for sentence in sentences(text):
            # Ayrı parçaları anlatan yan cümleler birbirinin km'sini devralmaz.
            for clause in re.split(r',|\b(?:ve|ancak|fakat|ama)\b', fold(sentence)):
                ranges = list(re.finditer(r'(?<![-–—\d.,])(' + _N + r')\s*[-–—]\s*(' + _N + r')\s*(?:km|kilometre)\b', clause))
                points = list(re.finditer(r'(?<![-–—\d.,])(' + _N + r')\s*(?:km|kilometre)\s+civari(?:nda)?\b', clause))
                for match in ranges + points:
                    distances = {}
                    for topic, terms in topic_terms.items():
                        for term in terms:
                            # DSG/DCT araç bağlamıdır; asıl parça seçilmişse
                            # onun km'sine rakip başka bir parça sayılmaz.
                            if (topic == 'sanziman' and topic not in required
                                    and fold(term) in {'dsg', 'dct', 'edc', 'cvt'}):
                                continue
                            pattern = r'\b' + re.escape(fold(term)) + (r'\b' if term in ('pas', 'aks') else '')
                            for anchor in re.finditer(pattern, clause):
                                distance = max(match.start() - anchor.end(), anchor.start() - match.end(), 0)
                                distances[topic] = min(distances.get(topic, float('inf')), distance)
                    own = min((d for key, d in distances.items() if key in required), default=float('inf'))
                    other = min((d for key, d in distances.items() if key not in required
                                 and key not in {'geri_cagirma', 'titreme', 'ariza_lambasi', 'guc_kaybi'}), default=float('inf'))
                    if own == float('inf') or other <= own:
                        continue
                    values = [int(re.sub(r'\D', '', x)) for x in match.groups()]
                    low, high = values if len(values) == 2 else (values[0], values[0])
                    if 0 < low <= high <= 2_000_000:
                        return {'min': low, 'max': high}, {'url': url, 'tarih': today()}
    return None


def at_km(item, km):
    out = deepcopy(item)
    span = out.get('tipikKm')
    if (isinstance(span, dict) and not isinstance(km, bool) and isinstance(km, (int, float))
            and isinstance(span.get('min'), (int, float)) and isinstance(span.get('max'), (int, float))
            and 0 <= span['min'] <= span['max'] and span['min'] - 10000 <= km <= span['max'] + 10000):
        out['onem'] = {'dusuk': 'orta', 'orta': 'yuksek', 'yuksek': 'yuksek'}.get(out.get('onem'), 'orta')
        out['kilometreUyarisi'] = 'Bu kilometrede dikkat'
    else:
        out.pop('kilometreUyarisi', None)
    return out


def cost_proof(value, text, repair, topics, topic_reader, cost_reader):
    if not isinstance(repair, str) or not 2 <= len(repair) <= 160:
        return None
    phrase = fold(repair).strip()
    actions = re.findall(r'\b(?:onar|tamir|degis|revizyon|yenile|bakim|kontrol)\w*', phrase)
    if (len(actions) != 1 or not re.search(r'\b(?:onar|tamir|degis|revizyon|yenile)\w*', phrase)
            or re.search(r'\b(?:ve|ile)\b|[+/&]', phrase)):
        return None
    required = set(topics) - {'geri_cagirma', 'motor', 'sanziman'} or set(topics)
    if 'zincir' in required:
        required.discard('triger')
    if not required <= set(topic_reader(phrase)):
        return None
    for sentence in sentences(text):
        sentence = fold(sentence)
        start = sentence.find(phrase)
        if start < 0:
            continue
        tail = sentence[start:]
        currency = re.search(r'\btl\b|₺', tail)
        if not currency:
            continue
        proof = tail[:currency.end()]
        # Başka bir işlemin tutarı aynı cümleden ödünç alınamaz.
        if re.search(r'\b(?:onar|tamir|degis|revizyon|yenile|bakim|kontrol)\w*', proof[len(phrase):]):
            continue
        if set(topic_reader(proof)) - required - {'motor', 'sanziman'}:
            continue
        result = cost_reader(value, [proof], list(required))
        if result:
            return result
    return None
