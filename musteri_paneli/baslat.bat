@echo off
setlocal enabledelayedexpansion
title YERIMEBAK AI v8.1 - Baslatiliyor...
echo ==================================================
echo         YERIMEBAK AI v8.1 STARTUP
echo ==================================================
echo.

cd /d "%~dp0"

echo [1/6] Sanal Ortam (venv) aktiflestiriliyor...
if exist venv\Scripts\activate (
    call venv\Scripts\activate
) else (
    echo WARNING: venv klasoru bulunamadi, global Python kullanilacak.
)

echo [2/6] .env dosyasi yukleniyor...
if exist .env (
    for /f "usebackq tokens=1,* delims==" %%a in (".env") do (
        set "line=%%a"
        if not "!line:~0,1!"=="#" (
            if not "%%b"=="" set "%%a=%%b"
        )
    )
    echo OK .env yuklendi.
) else (
    echo WARNING: .env bulunamadi, varsayilan ayarlar.
)

echo [3/6] Veritabani bootstrap + alignment...
python -c "from yerimebak_ai_v5.core.database_config import DatabaseConfig; DatabaseConfig.bootstrap(); DatabaseConfig.alignment(); print('OK')"

echo [4/6] API Sunucusu (Port 8000) baslatiliyor...
start "API Server" /b python -m yerimebak_ai_v5.main

echo [5/6] Frontend (Port 3000) baslatiliyor...
cd frontend
if exist node_modules (
    start "Frontend" /b npm run dev
) else (
    echo npm install yapiliyor...
    call npm install
    start "Frontend" /b npm run dev
)
cd ..

echo [6/6] Dashboard (Port 8505) baslatiliyor...
echo Lutfen bekleyin...
start "Dashboard" /b streamlit run yerimebak_ai_v5\dashboard\app_v2.py --server.port 8505

echo.
echo ==================================================
echo   API:       http://localhost:8000
echo   Frontend:  http://localhost:3000
echo   Dashboard: http://localhost:8505
echo   API Docs:  http://localhost:8000/docs
echo ==================================================
echo.
echo Kapatmak icin Ctrl+C basiniz.
pause
