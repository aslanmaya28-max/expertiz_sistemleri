import os
import random
import logging
from typing import Optional

logger = logging.getLogger(__name__)

_otp_store: dict[str, str] = {}
_redis_client = None

SMS_PROVIDER = os.getenv("SMS_PROVIDER", "dev")
TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "")
TWILIO_PHONE_NUMBER = os.getenv("TWILIO_PHONE_NUMBER", "")
VONAGE_API_KEY = os.getenv("VONAGE_API_KEY", "")
VONAGE_API_SECRET = os.getenv("VONAGE_API_SECRET", "")
VONAGE_PHONE_NUMBER = os.getenv("VONAGE_PHONE_NUMBER", "")


def _get_redis():
    global _redis_client
    if _redis_client is not None:
        return _redis_client
    try:
        import redis
        url = os.getenv("REDIS_URL", "redis://redis:6379/0")
        _redis_client = redis.from_url(url, decode_responses=True)
        _redis_client.ping()
        return _redis_client
    except Exception:
        return None


def generate_otp() -> str:
    return str(random.randint(100000, 999999))


def store_otp(phone: str, code: str, ttl: int = 300) -> None:
    _otp_store[phone] = code
    try:
        r = _get_redis()
        if r:
            r.setex(f"otp:{phone}", ttl, code)
    except Exception:
        pass


def verify_otp(phone: str, code: str) -> bool:
    stored = _otp_store.get(phone)
    if stored and stored == code:
        _otp_store.pop(phone, None)
        try:
            r = _get_redis()
            if r:
                r.delete(f"otp:{phone}")
        except Exception:
            pass
        return True

    try:
        r = _get_redis()
        if r:
            redis_code = r.get(f"otp:{phone}")
            if redis_code and (redis_code if isinstance(redis_code, str) else redis_code.decode()) == code:
                r.delete(f"otp:{phone}")
                return True
    except Exception:
        pass

    return False


def send_sms(phone: str, message: str) -> bool:
    provider = SMS_PROVIDER.lower()

    if provider == "twilio":
        return _send_twilio(phone, message)
    elif provider == "vonage":
        return _send_vonage(phone, message)
    else:
        logger.info(f"[SMS DEV] Phone: {phone}, Message: {message}")
        return True


def _send_twilio(phone: str, message: str) -> bool:
    try:
        from twilio.rest import Client
        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        msg = client.messages.create(body=message, from_=TWILIO_PHONE_NUMBER, to=phone)
        logger.info(f"[SMS TWILIO] SID: {msg.sid}, To: {phone}")
        return msg.status in ("queued", "sent", "delivered")
    except Exception as e:
        logger.error(f"[SMS TWILIO] Failed: {e}")
        return False


def _send_vonage(phone: str, message: str) -> bool:
    try:
        import vonage
        client = vonage.Client(key=VONAGE_API_KEY, secret=VONAGE_API_SECRET)
        sms = vonage.Sms(client)
        response = sms.send_message({"from": VONAGE_PHONE_NUMBER, "to": phone, "text": message})
        if response["messages"][0]["status"] == "0":
            logger.info(f"[SMS VONAGE] Success: {phone}")
            return True
        else:
            logger.error(f"[SMS VONAGE] Failed: {response['messages'][0]['error-text']}")
            return False
    except Exception as e:
        logger.error(f"[SMS VONAGE] Failed: {e}")
        return False


def send_otp_sms(phone: str) -> tuple[bool, str]:
    code = generate_otp()
    message = f"yerimebak.ai dogrulama kodunuz: {code}\nKod 5 dakika gecerlidir."

    store_otp(phone, code)
    sent = send_sms(phone, message)

    if SMS_PROVIDER.lower() == "dev":
        logger.info(f"[SMS DEV] OTP for {phone}: {code}")
        return True, code

    if sent:
        return True, ""
    return False, "SMS gonderilemedi"
