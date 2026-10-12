# -*- coding: utf-8 -*-
"""
E-posta gonderimi (SMTP).

Ayarlar (.env):
  SMTP_HOST, SMTP_PORT (587), SMTP_USER, SMTP_PASSWORD,
  SMTP_SECURITY = starttls | ssl | none   (varsayilan starttls)
  SMTP_FROM = "YerimeBak <bildirim@yerimebak.com.tr>"
  PUBLIC_SITE_URL = https://www.yerimebak.com.tr   (e-postadaki baglantilar)

Gonderim arka planda (thread) yapilir; istek yaniti beklemez. SMTP tanimli
degilse e-posta gonderilmez, uyari loglanir (gelistirme ortami).
"""
import html
import logging
import os
import smtplib
import ssl
import threading
from email.message import EmailMessage
from email.utils import formataddr, make_msgid
from typing import List, Optional, Tuple

logger = logging.getLogger(__name__)

# Testler gonderilen e-postalari burada yakalar (SMTP olmadan)
_test_outbox: Optional[List[EmailMessage]] = None


def site_url(path: str = "") -> str:
    base = os.getenv("PUBLIC_SITE_URL", "https://www.yerimebak.com.tr").rstrip("/")
    return f"{base}{path}"


def is_configured() -> bool:
    return bool(os.getenv("SMTP_HOST")) or _test_outbox is not None


def _sender() -> str:
    return os.getenv("SMTP_FROM") or formataddr(("YerimeBak", os.getenv("SMTP_USER") or "bildirim@yerimebak.com.tr"))


def _render(title: str, paragraphs: List[str], button: Optional[Tuple[str, str]]) -> Tuple[str, str]:
    """Duz metin + basit HTML govde."""
    text_lines = [title, ""] + paragraphs
    if button:
        text_lines += ["", f"{button[0]}: {button[1]}"]
    text_lines += ["", "YerimeBak", site_url()]
    body_html = "".join(f"<p style='margin:0 0 12px'>{html.escape(p)}</p>" for p in paragraphs)
    button_html = ""
    if button:
        button_html = (
            f"<p style='margin:20px 0'><a href='{html.escape(button[1], quote=True)}' "
            "style='background:#0E4A78;color:#fff;padding:10px 18px;border-radius:6px;text-decoration:none'>"
            f"{html.escape(button[0])}</a></p>"
        )
    page = (
        "<div style='font-family:Arial,sans-serif;max-width:560px;margin:0 auto;color:#0f172a'>"
        f"<h2 style='color:#0E4A78'>{html.escape(title)}</h2>{body_html}{button_html}"
        f"<p style='color:#64748b;font-size:12px;margin-top:28px'>YerimeBak · "
        f"<a href='{site_url()}'>yerimebak.com.tr</a></p></div>"
    )
    return "\n".join(text_lines), page


def build_message(to: str, subject: str, title: str, paragraphs: List[str],
                  button: Optional[Tuple[str, str]] = None) -> EmailMessage:
    text, page = _render(title, paragraphs, button)
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = _sender()
    msg["To"] = to
    msg["Message-ID"] = make_msgid(domain="yerimebak.com.tr")
    msg.set_content(text)
    msg.add_alternative(page, subtype="html")
    return msg


def _deliver(msg: EmailMessage) -> bool:
    if _test_outbox is not None:
        _test_outbox.append(msg)
        return True
    host = os.getenv("SMTP_HOST")
    if not host:
        logger.warning("SMTP_HOST tanimli degil; e-posta gonderilmedi: %s", msg["Subject"])
        return False
    port = int(os.getenv("SMTP_PORT", "587"))
    security = os.getenv("SMTP_SECURITY", "starttls").lower()
    user, password = os.getenv("SMTP_USER"), os.getenv("SMTP_PASSWORD")
    try:
        if security == "ssl":
            server = smtplib.SMTP_SSL(host, port, timeout=20, context=ssl.create_default_context())
        else:
            server = smtplib.SMTP(host, port, timeout=20)
            if security == "starttls":
                server.starttls(context=ssl.create_default_context())
        with server:
            if user:
                server.login(user, password or "")
            server.send_message(msg)
        return True
    except Exception as exc:
        logger.error("E-posta gonderilemedi (%s): %s", msg["To"], exc)
        return False


def send(to: Optional[str], subject: str, title: str, paragraphs: List[str],
         button: Optional[Tuple[str, str]] = None, background: bool = True) -> bool:
    """E-posta gonderir. background=True: yanit beklemeden arka planda."""
    if not to or "@" not in to:
        return False
    if to.endswith("@yerimebak.ai"):  # telefonla acilmis eski hesaplarin yer tutucu adresi
        return False
    msg = build_message(to, subject, title, paragraphs, button)
    if background and _test_outbox is None:
        threading.Thread(target=_deliver, args=(msg,), daemon=True).start()
        return True
    return _deliver(msg)


def capture_for_tests() -> List[EmailMessage]:
    """Testlerde SMTP yerine bellekte toplar."""
    global _test_outbox
    _test_outbox = []
    return _test_outbox


def stop_capture() -> None:
    global _test_outbox
    _test_outbox = None
