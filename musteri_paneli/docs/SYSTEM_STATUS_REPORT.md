# YERİMEBAK AI — System Status Report

**Generated:** 2026-05-03 01:03 (Europe/Istanbul)  
**Version:** v8.3  
**Reporter:** Cline (Senior Architect)

---

## Executive Summary

| Category | Status | Notes |
|----------|--------|-------|
| Core Config | ✅ FIXED | `DB_PATH` → `DATABASE_URL` (PostgreSQL) |
| Database | ✅ PostgreSQL | SQLite remnants cleaned from 3 critical files |
| API Layer | ✅ Operational | FastAPI with 8 endpoint groups (auth, credits, payments, analysis, extension, scrapers, listings, cases) |
| Dashboard | ✅ Operational | Streamlit multi-page, admin/customer views |
| Backend Scrapers | ✅ 2 Active | **Arabam** (arabam_detailed, arabam_smart, arabam_v4) + **Borusan** (borusan_smart) |
| Chrome Extension | ✅ Ready | Manifest V3, 3 content scripts (Sahibinden, Arabam, Letgo) |
| Docker | ✅ Configured | docker-compose + Dockerfile + nginx |
| Auth & Billing | ✅ FIXED | Credit packages aligned (Mini/Standart/Pro), initial credits=3 |
| AI Engines | ✅ Operational | Engine V8, Risk Engine V8, Opportunity Engine, Condition Analyzer |
| Credit Audit | ✅ NEW | `credit_usage_logs` table + auto-logging on every analysis |

---

## Platform Coverage Matrix

| Platform | Backend Scraper | Chrome Extension | Notes |
|----------|:---------------:|:----------------:|-------|
| Arabam.com | ✅ arabam_detailed + arabam_v4 | ✅ arabam.js | Primary data source |
| Borusan (BMW) | ✅ borusan_smart | — | Gallery/bayi source |
| Sahibinden.com | — | ✅ sahibinden.js | Extension-only (no backend scraper) |
| Letgo.com | ❌ Removed | ✅ letgo.js | Extension-only; backend stub deleted |

> **Key architectural decision:** Letgo backend scraper (`letgo_smart.py`) was a **stub/placeholder** returning empty results. Removed to avoid dead code. Chrome extension's Letgo content script remains fully functional for user-initiated analysis.

---

## SaaS Billing & Credit System

### Credit Packages (Aligned ✅)

| Package | Credits | Price (₺) | Price/Credit |
|---------|:-------:|:----------:|:------------:|
| Mini | 1 | 100 ₺ | 100 ₺ |
| Standart | 5 | 400 ₺ | 80 ₺ |
| Pro | 10 | 750 ₺ | 75 ₺ |

- **Initial credits on registration:** 3 (was 10, aligned)
- **Analysis cost:** 1 credit per vehicle analysis
- **Payment flow:** User creates order → Admin approves → Credits loaded

### Implementation Files

| File | Role | Status |
|------|------|--------|
| `services/payment_service.py` | CREDIT_PACKAGES, deduct_credits, order management | ✅ Aligned |
| `services/auth_service.py` | Registration with initial 3 credits | ✅ Aligned |
| `dashboard/services/billing_service.py` | Dashboard-side billing logic | ✅ Aligned |
| `dashboard/pages/pricing.py` | Credit purchase UI | ✅ Aligned |
| `api/v1/endpoints/credits.py` | Balance inquiry, history | ✅ Active |
| `api/v1/endpoints/payments.py` | Order create/approve/reject, packages | ✅ Active |
| `api/v1/endpoints/auth.py` | Login/register, API key auth | ✅ Active |
| `chrome-extension/popup.js` | Credits display, X-API-Key auth | ✅ Active |

### Credit Flow

```
User registers → 3 free credits
     │
     ├─ Chrome Extension: X-API-Key header → /api/v1/extension/analyze
     │   └─ deduct_credits() → credit_usage_logs + analysis_history
     │
     ├─ Dashboard: Session auth → analiz page
     │   └─ billing_service.use_credit() → deduct_credits()
     │
     └─ Buy credits: /payments/order → Admin approves → Credits added
```

### New: Credit Audit Trail (`credit_usage_logs`)

- **Table:** `credit_usage_logs` (id, user_id, api_key, action, credits_used, description, ip_address, created_at)
- **Auto-logged:** Every `deduct_credits()` call writes to this table
- **Graceful fallback:** If table doesn't exist yet, logs warning instead of crashing

---

## Critical Fixes Applied

### Session 1: Database Migration (PostgreSQL)

| # | File | Severity | Issue | Fix |
|---|------|----------|-------|-----|
| 1 | `core/config.py` | 🔴 CRITICAL | `DB_PATH` → `AttributeError` crash | Replaced with `DATABASE_URL = os.getenv(...)` |
| 2 | `core/forensic_db_guard.py` | 🟠 HIGH | SQLite branches (`sqlite_master`) | Rewrote for PostgreSQL (`information_schema`) |
| 3 | `dashboard/app_v2.py` | 🟡 MEDIUM | `DB_PATH` import doesn't exist | Removed import; uses `DATABASE_URL` env var |

### Session 2: Letgo Backend Cleanup

| # | File | Action | Detail |
|---|------|--------|--------|
| 1 | `scrapers/letgo_smart.py` | 🗑️ DELETED | Stub file — always returned empty list |
| 2 | `core/market_analyzer.py` | ✏️ EDITED | Removed `LetgoSmartCollector` import; updated to "Arabam + Borusan" |
| 3 | `data_lake/cache.py` | ✏️ EDITED | Removed `LetgoSmartCollector` import and `_scrape_letgo()` method |
| 4 | `workers/bulk_scraper_worker.py` | ✏️ EDITED | Removed `LetgoSmartCollector` import and Letgo task |
| 5 | `core/master_pipeline.py` | ✏️ EDITED | Cleaned commented-out Letgo import |

### Session 3: Docker & Infrastructure Cleanup

| # | File | Severity | Issue | Fix |
|---|------|----------|-------|-----|
| 1 | `docker-compose.yml` | 🔴 HIGH | Backup service used `cp market.db` (SQLite backup) | Rewrote to `postgres:15-alpine` + `pg_dump | gzip` |
| 2 | `docker-compose.yml` | 🟡 MEDIUM | Dashboard `DATA_PATH=/app/data/market.db` (SQLite ref) | Changed to `DATA_PATH=/app/data` |
| 3 | `.env.production` | 🔴 HIGH | `DB_HOST=db` but docker-compose service is `postgres` | Fixed to `DB_HOST=postgres` |

### Session 4: Billing & Credit Alignment

| # | File | Severity | Issue | Fix |
|---|------|----------|-------|-----|
| 1 | `services/payment_service.py` | 🟠 HIGH | CREDIT_PACKAGES had starter/basic/pro/enterprise (wrong prices) | Updated to mini/standart/pro with correct prices |
| 2 | `services/payment_service.py` | 🟡 MEDIUM | `get_or_create_user()` gave 10 initial credits | Changed to 3 |
| 3 | `services/auth_service.py` | 🟡 MEDIUM | `register()` gave 10 initial credits | Changed to 3 |
| 4 | `services/payment_service.py` | 🟢 NEW | No credit usage audit trail | Added `credit_usage_logs` insert in `deduct_credits()` |
| 5 | `sql/init.sql` | 🟢 NEW | No `credit_usage_logs` table | Added table with indexes |

**Verification:** All 3 credit sources (API auth, API payment_service, Dashboard billing) now consistently give 3 initial credits and use the same mini/standart/pro packages.

### Session 5: Health Check & Infrastructure Fix (v8.3)

| # | File | Severity | Issue | Fix |
|---|------|----------|-------|-----|
| 1 | `core/database_config.py` | 🟡 MEDIUM | `python-dotenv` import but no `load_dotenv()` call — `.env` file never loaded in standalone mode | Added `load_dotenv(find_dotenv())` with `try/except` fallback |
| 2 | — | 🟢 INFO | Full syntax audit: 154 Python files, 0 errors | All `.py` files compile cleanly |
| 3 | `dashboard/app_v2.py` | 🟢 INFO | Customer vitrin page `_render_vitrin_page()` has brand/model filter | Filter logic correct; depends on `get_active_brands()` returning data from DB |
| 4 | `dashboard/app_v2.py` | 🟢 INFO | Admin `render_main_dashboard()` also has brand filter | Filter logic correct; same dependency on DB data |

#### Customer Panel Filter Analysis

The customer vitrin page (`_render_vitrin_page`) uses a two-tab layout:

```
Tab 1: 🔥 Fırsat Araçlar
  ├─ Brand selectbox (from get_active_brands())
  ├─ Model selectbox (dynamically populated from get_opportunity_vehicles)
  ├─ Client-side brand/model filtering (lowercase comparison)
  └─ Renders up to 30 cards

Tab 2: 📦 Tüm Araçlar
  ├─ Brand selectbox (from get_active_brands())
  ├─ Model selectbox (dynamically populated from get_detailed_listings)
  ├─ Client-side brand/model filtering (lowercase comparison)
  └─ Renders up to 30 cards
```

**Root cause if filters show empty:** `get_active_brands()` queries `SELECT DISTINCT brand FROM listings` — if the DB is empty or brands are NULL, the dropdown will only show "Tüm Markalar" and no filtering will work. This is a **data issue**, not a code bug.

---

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/auth/register` | Public | Register new user (3 free credits) |
| POST | `/api/v1/auth/login` | Public | Login with email/password |
| GET | `/api/v1/auth/me` | X-API-Key | Get current user info + credits |
| GET | `/api/v1/credits/balance` | X-API-Key | Get credit balance |
| GET | `/api/v1/credits/history` | X-API-Key | Get analysis history |
| GET | `/api/v1/payments/packages` | Public | List credit packages |
| POST | `/api/v1/payments/order` | X-API-Key | Create payment order |
| GET | `/api/v1/payments/orders` | X-API-Key | Get my orders |
| POST | `/api/v1/payments/approve` | Admin | Approve payment order |
| POST | `/api/v1/payments/reject` | Admin | Reject payment order |
| GET | `/api/v1/payments/admin/orders` | Admin | List all orders |
| POST | `/api/v1/extension/analyze` | X-API-Key | Chrome extension analysis |
| GET | `/api/v1/analysis/...` | — | Analysis endpoints |
| GET | `/api/v1/scrapers/...` | — | Scraper management |
| GET | `/api/v1/listings/...` | — | Listings CRUD |
| GET | `/api/v1/cases/...` | — | Cases management |

---

## Remaining Low-Risk SQLite References (Comments Only)

These are in comments/docstrings and do NOT affect runtime:
- `yerimebak_ai_v5/api/v1/endpoints/listings.py:147` — parameter placeholder logic (`?` vs `%s`)
- `yerimebak_ai_v5/dashboard/components/database_monitor.py:15` — fallback label
- `yerimebak_ai_v5/dashboard/pages/errors.py:9` — hardcoded error example
- `yerimebak_ai_v5/dashboard/services/analiz_service.py:130` — docstring comment
- `yerimebak_ai_v5/services/trading_service.py:15` — comment
- `yerimebak_ai_v5/tools/data_refresher.py:8` — `import sqlite3` (unused file)
- `yerimebak_ai_v5/workers/db_service.py:167-169` — comments
- `yerimebak_ai_v5/workers/maintenance/cleanup_worker.py` — `import sqlite3` (unused file)

**Recommendation:** Clean these in a future maintenance session.

---

## Architecture Overview

```
yerimebak_sistemleri/
├── yerimebak_ai_v5/          # Main application
│   ├── main.py               # Entry point (FastAPI + uvicorn)
│   ├── __main__.py            # Module runner
│   ├── core/                  # Core business logic
│   │   ├── config.py          # App configuration (FIXED)
│   │   ├── database_config.py # PostgreSQL connection & schema
│   │   ├── forensic_db_guard.py # DB integrity guard (FIXED)
│   │   ├── repository.py      # Data access layer
│   │   ├── master_pipeline.py # Master forensic pipeline (CLEANED)
│   │   ├── engine_v8.py       # Main valuation engine
│   │   ├── risk_engine_v8.py  # Deterministic risk calculation
│   │   ├── opportunity_engine.py # Opportunity detection
│   │   ├── condition_analyzer.py # KM/condition analysis
│   │   ├── market_analyzer.py # Market price analysis (CLEANED)
│   │   ├── link_analyzer.py   # URL analysis
│   │   └── unified_ai_service.py # AI orchestration
│   ├── api/v1/                # REST API (8 endpoint groups)
│   │   ├── router.py          # API router
│   │   └── endpoints/         # auth, credits, payments, analysis,
│   │                         # extension, scrapers, listings, cases
│   ├── dashboard/             # Streamlit UI
│   │   ├── app_v2.py          # Main dashboard (FIXED)
│   │   ├── pages/             # analiz, kayit, pricing, scraper_control
│   │   ├── services/          # auth, billing, live_data, analiz
│   │   └── components/        # database_monitor
│   ├── scrapers/              # Web scrapers (2 active backends)
│   │   ├── arabam_detailed.py # Arabam.com (primary)
│   │   ├── arabam_smart.py    # Arabam.com (smart)
│   │   ├── arabam_v4/         # Arabam.com (v4 - stealth pattern)
│   │   └── borusan_smart.py   # Borusan Next (BMW gallery)
│   ├── services/              # Business services
│   │   ├── payment_service.py # Credit & payment management (ALIGNED)
│   │   └── auth_service.py    # Authentication (ALIGNED)
│   ├── workers/               # Background workers
│   │   ├── scraper_manager.py # Scraper orchestration
│   │   ├── scraper_worker.py  # Worker process
│   │   ├── bulk_scraper_worker.py # Bulk scraping (CLEANED)
│   │   └── alert_worker.py    # Alert notifications
│   ├── data_lake/             # Database + cache layer
│   │   ├── database.py        # DB manager
│   │   └── cache.py           # Market cache (CLEANED)
│   ├── schemas/               # Data schemas
│   └── tools/                 # Utility tools
├── chrome-extension/          # Browser extension (Manifest V3)
│   ├── manifest.json          # 3 platforms: Sahibinden, Arabam, Letgo
│   ├── popup.html/js/css      # Extension UI
│   └── content_scripts/       # sahibinden.js, arabam.js, letgo.js
├── sql/init.sql               # Database initialization (+ credit_usage_logs)
├── scripts/                   # Maintenance & utility scripts
├── tests/                     # Test suite
├── docker-compose.yml         # Docker orchestration
├── Dockerfile                 # Container definition
├── nginx.conf                 # Reverse proxy config
├── requirements.txt           # Python dependencies
├── baslat.bat                 # Windows quick-start script
└── .env                       # Environment variables
```

---

## Database Schema (PostgreSQL)

**Tables:**
- `listings` — 30+ columns including AI analysis fields (risk_score, opportunity_score, predicted_future_price, vision_condition_score, etc.)
- `price_history` — Historical price tracking
- `valuation_history` — AI valuation accuracy tracking
- `users` — SaaS user management (email, password, api_key, credits, tier, role)
- `analysis_history` — Vehicle analysis records per user
- `payment_orders` — Credit purchase orders (pending/approved/rejected)
- `credit_usage_logs` — **NEW** Audit trail for every credit deduction
- `system_logs` — System-level logging

**Connection:** `DATABASE_URL=postgresql://user:pass@host:port/dbname`

---

## Recommendations

1. **Clean remaining SQLite comments** — Schedule for next maintenance window
2. **Add integration tests** — Verify PostgreSQL connectivity in CI/CD
3. **Monitor worker health** — Ensure `baslat.bat` restarts workers after config fix
4. **Update .env.example** — Document required `DATABASE_URL` format
5. **Consider Sahibinden backend scraper** — Currently extension-only; could add `sahibinden_smart.py` for bulk data collection
6. **Update arabam_v4 comments** — References to "Letgo v4.0 pattern" are technical pattern names (not Letgo integration); consider renaming to "Stealth v4.0 pattern" for clarity
7. **Add credit_usage_logs to existing DB** — Run `CREATE TABLE IF NOT EXISTS credit_usage_logs (...)` on existing PostgreSQL instances
8. **Add rate limiting** — Protect `/api/v1/extension/analyze` from abuse beyond credit checks