# -*- coding: utf-8 -*-
"""
Musterinin paylastigi ilan linki: kaynak sitesi ve kisa linklerin cozulmesi.

Emsal (piyasa) verisi yalnizca arabam.com'dan cekilir. Musteri ise cogunlukla
sahibinden.com linki paylasir; sahibinden sayfasi botlara kapali oldugu icin
cekilmez. Yalnizca kisa link (shbd.io) acilip asil ilan adresi okunur; marka /
model / yil o adresteki metinden tahmin edilir, gerisini musteri girer.
"""
import logging
from typing import Optional
from urllib.parse import urljoin, urlsplit

import httpx

logger = logging.getLogger(__name__)

# Kisa link servisi -> ait oldugu site
SHORTENERS = {"shbd.io": "sahibinden"}
SITES = {"arabam.com": "arabam", "sahibinden.com": "sahibinden"}


def _host(url: str) -> str:
    raw = (url or "").strip()
    if raw and "://" not in raw:
        raw = "https://" + raw
    return (urlsplit(raw).hostname or "").lower()


def link_source(url: str) -> Optional[str]:
    """'arabam', 'sahibinden' ya da None."""
    host = _host(url)
    for domain, source in {**SITES, **SHORTENERS}.items():
        if host == domain or host.endswith("." + domain):
            return source
    return None


def is_short_link(url: str) -> bool:
    return _host(url) in SHORTENERS


def is_site_short_link(url: str) -> bool:
    """sahibinden.com/s/<kod>: sitenin kendi kisa adresi; ilan basligi (marka/model/yil) icermez.

    shbd.io bu adrese yonlendirir (canli denendi). Tam ilan adresine (/ilan/...) ancak
    sahibinden.com'a istek atilarak gidilebilir; bunu yapmiyoruz, musteriden tam link isteriz.
    """
    raw = (url or "").strip()
    if raw and "://" not in raw:
        raw = "https://" + raw
    return link_source(url) == "sahibinden" and not is_short_link(url) and urlsplit(raw).path.startswith("/s/")


def resolve_short_link(url: str, timeout_s: float = 6.0, max_hops: int = 3) -> str:
    """Kisa linkin yonlendirdigi adresi dondurur; cozulemezse linkin kendisini.

    Yalnizca kisa link sunucusuna istek atilir; hedef siteye (sahibinden.com) gidilmez.
    """
    current = (url or "").strip()
    if current and "://" not in current:
        current = "https://" + current
    try:
        with httpx.Client(follow_redirects=False, timeout=timeout_s,
                          headers={"User-Agent": "Mozilla/5.0 (YerimeBak link cozucu)"}) as client:
            for _ in range(max_hops):
                if not is_short_link(current):
                    break
                response = client.get(current)
                location = response.headers.get("location")
                if not (300 <= response.status_code < 400 and location):
                    break
                current = urljoin(current, location)
    except httpx.HTTPError as exc:
        logger.warning("[LINK] Kisa link cozulemedi (%s): %s", url, exc)
        return url
    return current if not is_short_link(current) else url
