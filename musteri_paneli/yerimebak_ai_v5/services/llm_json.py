"""Model yanıtından yalnız tamamlanmış JSON alanlarını ve liste maddelerini okur.

Eksik değer uydurmaz, bozuk maddenin içini onarmaz. Kurtarılan veri tüketicinin
kaynak, kapsam ve fiyat kontrollerinden ayrıca geçmelidir. Günlüğe içerik yazılmaz.
"""
import json
import logging
import math

logger = logging.getLogger(__name__)


def _gecersiz_sabit(_):
    raise ValueError('JSON sayısı sonlu olmalıdır')


def _sonlu_sayi(text):
    value = float(text)
    if not math.isfinite(value):
        raise ValueError('JSON sayısı sonlu olmalıdır')
    return value


_DECODER = json.JSONDecoder(parse_constant=_gecersiz_sabit, parse_float=_sonlu_sayi)
_SPACE = ' \t\r\n'


def _skip(text, pos, chars=_SPACE):
    while pos < len(text) and text[pos] in chars:
        pos += 1
    return pos


def _items(text, start):
    """Bozuk dizide yalnız kapanmış nesneler; bozuk ilk maddede durulur."""
    items, pos = [], start + 1
    while True:
        pos = _skip(text, pos, _SPACE + ',')
        if pos >= len(text) or text[pos] != '{':
            return items
        try:
            value, end = _DECODER.raw_decode(text, pos)
        except ValueError:
            return items
        items.append(value)
        pos = end


def _root_lists(text, start, names):
    """Kök nesnedeki dizi başlarını bulur; alıntı içini ve iç nesneleri atlar."""
    stack, pos, state = ['{'], start + 1, 'key'
    while pos < len(text) and stack:
        char = text[pos]
        if char == '"':
            try:
                value, end = _DECODER.raw_decode(text, pos)
            except ValueError:
                return
            after = _skip(text, end)
            if stack == ['{']:
                if state in ('key', 'after') and after < len(text) and text[after] == ':':
                    array = _skip(text, after + 1)
                    if value in names and array < len(text) and text[array] == '[':
                        yield value, array
                    state, pos = 'value', after + 1
                    continue
                state = 'after' if state == 'value' else 'invalid'
            pos = end
            continue
        if char in '[{':
            if stack == ['{'] and state == 'value':
                state = 'container'
            stack.append(char)
        elif char in ']}' and stack[-1] == {']':'[', '}':'{'}[char]:
            stack.pop()
            if stack == ['{'] and state == 'container':
                state = 'after'
        elif stack == ['{']:
            if char == ',':
                state = 'key'
            elif char == ':':
                state = 'invalid'
            elif state == 'value' and char not in _SPACE:
                try:
                    _, pos = _DECODER.raw_decode(text, pos)
                    state = 'after'
                    continue
                except ValueError:
                    state = 'invalid'
        # Fazladan kapanış, sonraki kök listeyi keşfetmeyi engellemesin.
        pos += 1


def _prefix(text, start):
    """Virgül eksik olsa da tamamlanmış alanları okur; yarım değerde durur."""
    output, pos = {}, start + 1
    while True:
        pos = _skip(text, pos, _SPACE + ',')
        if pos >= len(text) or text[pos] != '"':
            return output
        try:
            key, end = _DECODER.raw_decode(text, pos)
            end = _skip(text, end)
            if end >= len(text) or text[end] != ':':
                return output
            value_pos = _skip(text, end + 1)
            value, end = _DECODER.raw_decode(text, value_pos)
        except ValueError:
            return output
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            # EOF'taki sayının devamı kesilmiş olabilir (12000 -> 1200000).
            if end == len(text) or text[end] not in _SPACE + ',}"':
                return output
        output[key] = value
        pos = end


def oku(content, listeler=()):
    """JSON nesnesi döndürür; JSON/sağlam alan yoksa ValueError verir.

    Tam nesneler kod bloğu veya kısa açıklama içinde olabilir. Bozuk nesnede
    kapanmış alanlar korunur; yalnız adı belirtilen kesik diziler kurtarılır.
    """
    if not isinstance(content, str) or not content.strip():
        raise ValueError('Arama yanıtında JSON yok')
    start = content.find('{')
    array = content.find('[')
    if start < 0 or (array >= 0 and array < start):
        raise ValueError('Arama yanıtında JSON yok')
    try:
        value, _ = _DECODER.raw_decode(content, start)
        if isinstance(value, dict):
            return value
    except ValueError:
        pass

    result = _prefix(content, start)
    for name, array in _root_lists(content, start, set(listeler)):
        try:
            result[name], _ = _DECODER.raw_decode(content, array)
        except ValueError:
            result[name] = _items(content, array)
    if not result:
        raise ValueError('Arama yanıtında JSON yok')
    logger.warning('[LLM JSON] Bozuk yanıttan kurtarılan alan sayısı=%d, liste maddesi=%d',
                   len(result), sum(len(value) for value in result.values() if isinstance(value, list)))
    return result
