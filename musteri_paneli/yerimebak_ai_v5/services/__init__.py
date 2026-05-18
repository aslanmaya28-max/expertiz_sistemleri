def get_forensic_service(*args, **kwargs):
    from .forensic_service import get_forensic_service as _factory
    return _factory(*args, **kwargs)


def get_analysis_service(*args, **kwargs):
    from .analysis_service import get_analysis_service as _factory
    return _factory(*args, **kwargs)


def get_market_intelligence_service(*args, **kwargs):
    from .market_service import get_market_intelligence_service as _factory
    return _factory(*args, **kwargs)


def get_trading_service(*args, **kwargs):
    from .trading_service import get_trading_service as _factory
    return _factory(*args, **kwargs)


def get_case_service(*args, **kwargs):
    from .case_service import get_case_service as _factory
    return _factory(*args, **kwargs)


def get_payment_service(*args, **kwargs):
    from .payment_service import get_payment_service as _factory
    return _factory(*args, **kwargs)


def get_auth_service(*args, **kwargs):
    from .auth_service import get_auth_service as _factory
    return _factory(*args, **kwargs)

__all__ = [
    "get_forensic_service",
    "get_analysis_service",
    "get_market_intelligence_service",
    "get_trading_service",
    "get_case_service",
    "get_payment_service",
    "get_auth_service"
]
