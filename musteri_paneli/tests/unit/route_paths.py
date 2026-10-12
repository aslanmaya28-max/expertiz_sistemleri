"""FastAPI surumunden bagimsiz olarak api_router'daki tum yollari toplar.

FastAPI 0.120+ include_router ile eklenen alt yonlendiricileri `_IncludedRouter`
olarak tutar; bu nesnelerin `path` alani yoktur. Yollar OpenAPI semasindan okunur.
"""
from fastapi import FastAPI


def api_paths(router):
    app = FastAPI()
    app.include_router(router)
    return set(app.openapi()["paths"])
