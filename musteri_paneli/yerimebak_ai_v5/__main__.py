# -*- coding: utf-8 -*-
"""
YERIMEBAK AI v8.1 - Main Entry Point
Allows execution as: python -m yerimebak_ai_v5
"""

import uvicorn


if __name__ == "__main__":
    print("\n  YERIMEBAK AI v8.1 - FastAPI Server Baslatiliyor...")
    print("  Local: http://127.0.0.1:8000")
    print("  API Docs: http://127.0.0.1:8000/docs\n")
    uvicorn.run("yerimebak_ai_v5.main:app", host="127.0.0.1", port=8000, reload=True)
