"""Belgeli pazar adları; ortak platform tek başına eşdeğer araç kanıtı değildir.

Sicil yalnız doğrulanan dizel motorları kapsar. Belgesiz motor, nesil veya
markalar arasında çıkarım yapmaz; yeni satırlar birincil belgeyle genişletilir.
"""
from dataclasses import dataclass
import re

from yerimebak_ai_v5.services.web_market_reference import fold, _displacements, _int


@dataclass(frozen=True)
class ModelAlias:
    brand: str
    names: tuple[str, ...]
    start_year: int
    end_year: int | None
    generation: str
    engines: tuple[tuple[str, str], ...]
    reason: str
    sources: tuple[str, ...]


_TOFAS = 'https://ir.tofas.com.tr/2022/en/m-3-9.html'
_TIPO = 'https://www.media.stellantis.com/pt-pt/fiat/press/fiat-tipo-inicia-comercializacao-em-portugal'
_CROSS = ('https://www.media.stellantis.com/em-en/fiat/press/'
          'new-tipo-and-new-tipo-cross-new-engines-new-design-new-versions-and-new-technology')

MODEL_ALIASES = (
    ModelAlias('Fiat', ('Egea', 'Tipo'), 2015, None, '356 sedan',
               (('1.3', 'multijet'), ('1.6', 'multijet')),
               'Tofaş Egea ihracat adını Tipo olarak belirtir; Fiat 2015 duyurusu '
               'sedan 1.3/1.6 Multijet II motorlarını doğrular.', (_TOFAS, _TIPO)),
    ModelAlias('Fiat', ('Egea Cross', 'Tipo Cross'), 2021, None, 'Tipo/Egea Cross 5 kapı',
               (('1.6', 'multijet'),),
               'Tofaş Cross gövdesini Egea ailesinde gösterir; Fiat Ekim 2020 '
               'duyurusu Cross gövdeyi ve 1.6 Multijet motorunu doğrular. '
               'Türkiye model yılı başlangıcı 2021 alınır.', (_TOFAS, _CROSS)),
)


def _has_name(text, name):
    # Gövde adı motordan sonra da gelebilir: "Tipo 1.3 Multijet hatchback".
    folded_name = fold(name)
    for sentence in re.split(r'(?<!\d)[.!?](?!\d)|[\n;]', fold(text)):
        if not re.search(r'(?<!\w)' + re.escape(folded_name)
                         + r'(?!\w)(?!\s+(?:cross|wagon|hatchback|sw)\b)', sentence):
            continue
        if folded_name in ('egea', 'tipo') and re.search(
                r'\b(?:cross|wagon|hatchback|sw|5[ -](?:door|kapi))\b', sentence):
            continue
        if folded_name in ('egea cross', 'tipo cross') and re.search(r'\b(?:wagon|sw)\b', sentence):
            continue
        return True
    return False


def _rules(vehicle):
    model, brand = fold(vehicle.get('model')).strip(), fold(vehicle.get('brand')).strip()
    return tuple(r for r in MODEL_ALIASES if fold(r.brand) == brand
                 and model in tuple(fold(n) for n in r.names))


def _eligible(rule, vehicle):
    year = _int(vehicle.get('year'))
    engine = fold(' '.join(str(vehicle.get(k) or '') for k in ('engine', 'package')))
    return bool(year and rule.start_year <= year and (rule.end_year is None or year <= rule.end_year)
                and any(d in _displacements(engine) and re.search(r'\b' + f + r'\b', engine)
                        for d, f in rule.engines))


def aliases(vehicle):
    """Yalnız aracın yılı ve motoru belgeli aralıktaysa diğer pazar adları."""
    model = fold(vehicle.get('model')).strip()
    return tuple(n for r in _rules(vehicle) if _eligible(r, vehicle)
                 for n in r.names if fold(n) != model)


def matches(text, vehicle, aliases_only=False):
    names = aliases(vehicle)
    if not aliases_only:
        names = (str(vehicle.get('model') or ''),) + names
    return any(n and _has_name(text, n) for n in names)


def incompatible(text, vehicle):
    """Alias adı geçiyorsa eski kuşak veya başka motor ailesini dışla."""
    model = fold(vehicle.get('model')).strip()
    for rule in _rules(vehicle):
        if not any(_has_name(text, n) for n in rule.names if fold(n) != model):
            continue
        if not _eligible(rule, vehicle):
            return True
        # Aynı hacimdeki benzinli veya farklı dizel ailesi Multijet sayılamaz.
        target = _displacements(' '.join(str(vehicle.get(k) or '') for k in ('engine', 'package')))
        for sentence in re.split(r'(?<!\d)[.!?](?!\d)|[\n;]', text):
            if not any(_has_name(sentence, n) for n in rule.names if fold(n) != model):
                continue
            # Yeni yayın/güncelleme tarihi eski Tipo kuşağını geçerli kılamaz.
            years = [int(y) for y in re.findall(r'\b(?:19|20)\d{2}\b', sentence)]
            if any(y < rule.start_year for y in years):
                return True
            families = set(re.findall(r'\b(?:fire|t-jet|tjet|tsi|tdi|hdi|dci|multijet)\b', fold(sentence)))
            if families - {'multijet'} or _displacements(sentence) - target:
                return True
    return False


def engine_scoped(text, vehicle):
    """Alias cümlesinde belgeli motor hacmi ve ailesi birlikte bulunmalı."""
    target = _displacements(' '.join(str(vehicle.get(k) or '') for k in ('engine', 'package')))
    return any(_eligible(r, vehicle) and any(d in target & _displacements(text)
               and re.search(r'\b' + f + r'\b', fold(text)) for d, f in r.engines)
               for r in _rules(vehicle))
