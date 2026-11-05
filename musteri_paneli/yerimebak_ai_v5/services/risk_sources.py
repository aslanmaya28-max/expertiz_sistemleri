"""Kronik arıza kaynaklarının sınıflaması ve bağımsızlık denetimi (029, kullanıcı kararı B).

Ağ bağlantısı gerektirmez. Kural: resmî kayıt tek başına yüksek; aynı risk en az iki **bağımsız** teknik kaynakta
açık araç kapsamıyla geçiyorsa orta. Aynı yayıncının alanları, birbirini kaynak gösteren ya da kopyalanmış metinler
tek kaynak sayılır; forum/şikâyet ve engelli alanlar sayılmaz.
"""
from __future__ import annotations

import ipaddress
import re
from dataclasses import dataclass
from urllib.parse import unquote, urlsplit

# İki seviyeli kamu uzantıları (com.tr, co.uk ...). Liste kasıtlı olarak kısa ve denetlenebilir;
# tanınmayan ülke uzantısında son iki etiket kök sayılır (en kötü ihtimalle iki kaynak birleşir, ayrılmaz).
_SECOND_LEVEL = {"co", "com", "org", "net", "gov", "ac", "edu", "gen", "web", "bel", "k12", "av", "biz", "info",
                 "tv", "ne", "or", "go", "ltd", "plc", "nhs", "police", "mil", "nom", "pol", "tsk", "dr"}
_TWO_LEVEL_EXTRA = {"europa.eu"}  # ec.europa.eu gibi kurumsal alt alanlar europa.eu altında ayrı yayıncıdır


@dataclass(frozen=True)
class SourceRule:
    domain: str
    kind: str          # official | technical | user | blocked
    publisher: str     # aynı yayıncının alanları tek kaynak sayılır
    reason: str
    brand: str = ""    # üretici alanı yalnız kendi markasında resmîdir


def _brand_rules(publisher, brands, domains):
    return [SourceRule(d, "official", publisher, "Üreticinin kendi geri çağırma/servis sayfası", b)
            for b in brands for d in domains]


SOURCE_REGISTRY: tuple[SourceRule, ...] = tuple(
    [SourceRule("nhtsa.gov", "official", "nhtsa", "ABD resmî araç güvenliği kurumu (geri çağırma/TSB arşivi)"),
     SourceRule("kba.de", "official", "kba", "Almanya Federal Motorlu Taşıtlar Kurumu geri çağırma kaydı"),
     SourceRule("ec.europa.eu", "official", "eu-safety-gate", "AB Safety Gate (RAPEX) resmî ürün güvenliği uyarısı"),
     SourceRule("gov.uk", "official", "uk-dvsa", "Birleşik Krallık resmî geri çağırma kaydı"),
     SourceRule("adac.de", "technical", "adac", "ADAC: bağımsız teknik test ve arıza istatistiği"),
     SourceRule("rac.co.uk", "technical", "rac", "RAC: yol yardım ve teknik değerlendirme"),
     SourceRule("theaa.com", "technical", "aa", "The AA: yol yardım ve teknik değerlendirme"),
     SourceRule("whatcar.com", "technical", "haymarket", "What Car? güvenilirlik araştırması (Haymarket)"),
     SourceRule("autocar.co.uk", "technical", "haymarket", "Autocar teknik inceleme (Haymarket)"),
     SourceRule("sikayetvar.com", "user", "sikayetvar", "Kullanıcı şikâyet platformu"),
     SourceRule("donanimhaber.com", "user", "donanimhaber", "Kullanıcı forumu"),
     SourceRule("technopat.net", "user", "technopat", "Kullanıcı forumu"),
     SourceRule("reddit.com", "user", "reddit", "Kullanıcı forumu"),
     SourceRule("araclo.com", "user", "araclo", "Kullanıcı yorumu derlemesi"),
     SourceRule("kronikmotor.com", "blocked", "kronikmotor", "Doğrulanamayan derleme; engelli")]
    + _brand_rules("vw-group", ["seat", "cupra"], ["seat.com", "seat.com.tr", "cupraofficial.com"])
    + _brand_rules("vw-group", ["volkswagen", "vw"], ["volkswagen.com", "volkswagen.com.tr"])
    + _brand_rules("vw-group", ["skoda"], ["skoda-auto.com", "skoda.com.tr"])
    + _brand_rules("vw-group", ["audi"], ["audi.com", "audi.com.tr"])
    + _brand_rules("ford", ["ford"], ["ford.com", "ford.com.tr"])
    + _brand_rules("toyota", ["toyota"], ["toyota.com", "toyota.com.tr", "toyota-europe.com"])
    + _brand_rules("renault-group", ["renault", "dacia"], ["renault.com", "renault.com.tr", "dacia.com.tr"])
    + _brand_rules("bmw-group", ["bmw", "mini"], ["bmw.com", "bmw.com.tr"])
    + _brand_rules("mercedes-benz", ["mercedes-benz", "mercedes"], ["mercedes-benz.com", "mercedes-benz.com.tr"])
    + _brand_rules("stellantis", ["peugeot"], ["peugeot.com", "peugeot.com.tr"])
    + _brand_rules("stellantis", ["citroen"], ["citroen.com", "citroen.com.tr"])
    + _brand_rules("stellantis", ["fiat"], ["fiat.com", "fiat.com.tr"])
    + _brand_rules("stellantis", ["opel"], ["opel.com", "opel.com.tr"])
    + _brand_rules("honda", ["honda"], ["honda.com", "honda.com.tr"])
    + _brand_rules("hyundai-group", ["hyundai"], ["hyundai.com"])
    + _brand_rules("hyundai-group", ["kia"], ["kia.com"])
)

_BY_DOMAIN: dict[str, list[SourceRule]] = {}
for _r in SOURCE_REGISTRY:
    _BY_DOMAIN.setdefault(_r.domain, []).append(_r)

_USER_WORDS = ("forum", "club", "reddit", "community", "topluluk")


def _host(url: str) -> str:
    try:
        parts = urlsplit(url.strip())
        if parts.scheme not in ("http", "https"):
            return ""
        parts.port  # geçersiz port ValueError verir
        host = (parts.hostname or "").lower().rstrip(".")
    except (ValueError, AttributeError):
        return ""
    if not host or ".." in host or host == "localhost" or "." not in host:
        return ""
    try:
        ipaddress.ip_address(host)
        return ""
    except ValueError:
        pass
    if not all(re.fullmatch(r"[a-z0-9-]+", label) and not label.startswith("-") for label in host.split(".")):
        return ""
    return host


def root_domain(url: str) -> str:
    """Kayıt edilebilir kök alan (eTLD+1); geçersiz/IP/yerel adreslerde boş metin."""
    host = _host(url) if "://" in str(url) else ""
    if not host:
        return ""
    labels = host.split(".")
    for extra in _TWO_LEVEL_EXTRA:
        if host == extra or host.endswith("." + extra):
            return ".".join(labels[-3:]) if len(labels) >= 3 else ""
    two_level = len(labels[-1]) == 2 and len(labels) >= 2 and labels[-2] in _SECOND_LEVEL
    size = 3 if two_level else 2
    return ".".join(labels[-size:]) if len(labels) >= size else ""


def _rules(url: str) -> list[SourceRule]:
    host = _host(url)
    if not host:
        return []
    for domain, rules in _BY_DOMAIN.items():
        if host == domain or host.endswith("." + domain):
            return rules
    return []


def source_kind(url: str, brand: str = "") -> str:
    """official | technical | user | blocked | unknown."""
    host = _host(url)
    if not host:
        return "unknown"
    rules = _rules(url)
    if any(r.kind == "blocked" for r in rules):
        return "blocked"
    path = unquote(urlsplit(url).path or "").lower()
    if any(r.kind == "user" for r in rules) or any(w in host or w in path for w in _USER_WORDS):
        return "user"
    b = (brand or "").strip().lower()
    for r in rules:
        if r.kind == "official" and (not r.brand or r.brand == b):
            return "official"
        if r.kind == "technical":
            return "technical"
    return "unknown"


def publisher(url: str) -> str:
    rules = _rules(url)
    return rules[0].publisher if rules else root_domain(url)


def is_same_publisher(left: str, right: str) -> bool:
    a, b = publisher(left), publisher(right)
    return bool(a) and a == b


# --- bağımsızlık ------------------------------------------------------------

_HOST_TOKEN = re.compile(r"(?<![\w@.-])(?:https?://)?((?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,})(?![\w-]|\.[a-z0-9])",
                         re.IGNORECASE)


def _cited_roots(text: str) -> set[str]:
    return {r for r in (root_domain("https://" + m.group(1)) for m in _HOST_TOKEN.finditer(text or "")) if r}


def _words(text: str) -> list[str]:
    return re.findall(r"\w+", (text or "").lower())


def _sentences(text: str) -> set[str]:
    return {" ".join(_words(s)) for s in re.split(r"(?<!\d)[.!?](?!\d)|[\n;]", text or "") if len(_words(s)) >= 10}


def _shingles(text: str, n: int = 4) -> set[tuple[str, ...]]:
    w = _words(text)
    return {tuple(w[i:i + n]) for i in range(len(w) - n + 1)}


def _copied(a: str, b: str) -> bool:
    if _sentences(a) & _sentences(b):
        return True
    sa, sb = _shingles(a), _shingles(b)
    return bool(sa and sb) and len(sa & sb) / min(len(sa), len(sb)) >= 0.5


def independent_count(sources: dict[str, str], brand: str = "") -> int:
    """Bağımsız kaynak sayısı: aynı yayıncı, karşılıklı atıf ve kopya metin birleşik bileşen olarak tek sayılır."""
    nodes = [(u, t) for u, t in (sources or {}).items()
             if isinstance(t, str) and t.strip() and root_domain(u)
             and source_kind(u, brand) not in ("user", "blocked")]
    parent = list(range(len(nodes)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    roots = [root_domain(u) for u, _ in nodes]
    cites = [_cited_roots(t) for _, t in nodes]
    for i in range(len(nodes)):
        for j in range(i + 1, len(nodes)):
            joined = (is_same_publisher(nodes[i][0], nodes[j][0]) or roots[i] in cites[j] or roots[j] in cites[i]
                      or _copied(nodes[i][1], nodes[j][1]))
            if joined:
                parent[find(i)] = find(j)
    return len({find(i) for i in range(len(nodes))})
