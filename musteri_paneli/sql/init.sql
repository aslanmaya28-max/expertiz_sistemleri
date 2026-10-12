-- YERIMEBAK AI v8.1 — PostgreSQL Init Script
-- Compatible with DatabaseConfig.bootstrap()
-- docker-compose.yml mounts this to /docker-entrypoint-initdb.d/init.sql

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════════════════════
-- CORE TABLES
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS listings (
    id SERIAL PRIMARY KEY,
    brand TEXT NOT NULL,
    model TEXT NOT NULL,
    year INTEGER,
    price INTEGER,
    km INTEGER,
    fuel TEXT,
    fuel_type TEXT,
    transmission TEXT,
    source TEXT,
    url TEXT UNIQUE,
    color TEXT,
    paint_info TEXT,
    accident_record TEXT,
    damage_info TEXT,
    guarantee TEXT,
    package_info TEXT,
    description TEXT,
    location TEXT,
    listing_date TEXT,
    engine_size TEXT,
    horsepower TEXT,
    series TEXT,
    body_type TEXT,
    title TEXT,
    image_url TEXT,
    risk_score FLOAT,
    opportunity_score FLOAT,
    predicted_future_price INTEGER,
    vision_condition_score FLOAT,
    vision_analysis_report TEXT,
    action_recommendation TEXT,
    buy_price_min INTEGER,
    buy_price_max INTEGER,
    predicted_profit_tl INTEGER,
    predicted_profit_pct FLOAT,
    heavy_damage TEXT,
    seller_type TEXT,
    traction TEXT,
    last_push_alert TIMESTAMP,
    analyzed_at TIMESTAMP,
    market_avg_price INTEGER,
    price_deviation_pct FLOAT,
    risk_level TEXT,
    decision TEXT,
    exit_price INTEGER,
    days_to_sell INTEGER,
    status TEXT DEFAULT 'active',
    scraped_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    proxy TEXT,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_requests (
    id SERIAL PRIMARY KEY,
    brand TEXT,
    model TEXT,
    year INTEGER,
    ip_address TEXT,
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS price_history (
    id SERIAL PRIMARY KEY,
    listing_id INTEGER,
    price INTEGER,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(listing_id) REFERENCES listings(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS valuation_history (
    id SERIAL PRIMARY KEY,
    vehicle_brand TEXT,
    vehicle_model TEXT,
    vehicle_year INTEGER,
    actual_price INTEGER,
    ai_price INTEGER,
    confidence FLOAT,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ═══════════════════════════════════════════════════════════════
-- SAAS TABLES
-- ═══════════════════════════════════════════════════════════════

-- 🔒 GÜVENLİK: api_key_hash alani eklendi. API anahtarlari hash'lenerek saklanir.
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,  -- 🔒 DÜZELTİLDİ: NOT NULL constraint eklendi
    credits INTEGER DEFAULT 3,
    api_key TEXT UNIQUE,
    api_key_hash TEXT,  -- 🔒 API anahtarinin hash'lenmis hali (opsiyonel, ileride kullanilacak)
    tier TEXT DEFAULT 'free',
    role TEXT DEFAULT 'user',
    full_name TEXT,
    phone TEXT,
    phone_verified INTEGER DEFAULT 0,
    username TEXT,
    is_active INTEGER DEFAULT 1,
    last_login TIMESTAMP,
    profile_image TEXT,
    google_id TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- update_users_updated_at tetikleyicisi bu kolonu doldurur
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS analysis_history (
    id TEXT PRIMARY KEY,
    user_id INTEGER,
    vehicle_json TEXT,
    valuation_json TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS payment_orders (
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    user_email TEXT,
    user_phone TEXT,
    package_key TEXT NOT NULL,
    package_name TEXT,
    credits INTEGER NOT NULL,
    amount_tl REAL NOT NULL,
    status TEXT DEFAULT 'pending',
    payment_method TEXT DEFAULT 'havale',
    payment_ref TEXT,
    admin_note TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP,
    approved_by TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS credit_usage_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    api_key TEXT,
    action VARCHAR(100) NOT NULL,
    credits_used INTEGER DEFAULT 1,
    description TEXT,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS system_logs (
    id SERIAL PRIMARY KEY,
    level VARCHAR(20),
    message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ═══════════════════════════════════════════════════════════════
-- INDEXES
-- ═══════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_listings_lookup ON listings(brand, model, year);
CREATE INDEX IF NOT EXISTS idx_listings_source ON listings(source);
CREATE INDEX IF NOT EXISTS idx_listings_price ON listings(price);
CREATE INDEX IF NOT EXISTS idx_users_api_key ON users(api_key);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);
CREATE INDEX IF NOT EXISTS idx_payment_orders_user ON payment_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_orders_status ON payment_orders(status);
CREATE INDEX IF NOT EXISTS idx_analysis_history_user ON analysis_history(user_id);
CREATE INDEX IF NOT EXISTS idx_listings_opportunity ON listings(opportunity_score DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status);
CREATE INDEX IF NOT EXISTS idx_listings_analyzed ON listings(analyzed_at);
CREATE INDEX IF NOT EXISTS idx_listings_decision ON listings(decision);
CREATE INDEX IF NOT EXISTS idx_listings_updated ON listings(updated_at DESC);

-- ═══════════════════════════════════════════════════════════════
-- SUPABASE COMPATIBILITY TABLES
-- ═══════════════════════════════════════════════════════════════

-- ekspertiz_raporlari: Supabase migration'larinda referans ediliyor
CREATE TABLE IF NOT EXISTS ekspertiz_raporlari (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    customer_id UUID,
    report_id UUID,
    brand TEXT,
    model TEXT,
    year INTEGER,
    plate TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    ai_confidence FLOAT,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- raporlar: evidence_rpc_functions.sql'de referans ediliyor
CREATE TABLE IF NOT EXISTS raporlar (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    customer_id UUID,
    report_id UUID,
    brand TEXT,
    model TEXT,
    year INTEGER,
    plate TEXT,
    sehir TEXT,
    status TEXT DEFAULT 'draft',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- customer_reports: status_workflow.sql'de referans ediliyor
CREATE TABLE IF NOT EXISTS customer_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    report_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(customer_id, report_id)
);

-- =====================================================
-- FUNCTIONLAR - Yardımcı Veritabanı Fonksiyonları
-- =====================================================

-- Paket ağırlığını getiren fonksiyon (expertiz_paneli/database_schema.sql'den)
CREATE OR REPLACE FUNCTION get_package_weight(package_id VARCHAR)
RETURNS DECIMAL AS $$
BEGIN
    RETURN (
        SELECT weight 
        FROM vehicle_packages 
        WHERE vehicle_packages.package_id = get_package_weight.package_id
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════
-- TRIGGERS: updated_at auto-update

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- listings tablosu için trigger
CREATE TRIGGER update_listings_updated_at BEFORE UPDATE ON listings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- users tablosu için trigger
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- payment_orders tablosu için trigger
CREATE TRIGGER update_payment_orders_updated_at BEFORE UPDATE ON payment_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
