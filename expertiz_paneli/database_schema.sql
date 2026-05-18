-- =====================================================
-- YERIMEBAK EXPERTIZ SISTEMI - SUPABASE POSTGRESQL SCHEMA
-- =====================================================
-- Bu şema, Flutter uygulaması ile Supabase backend arasında
-- kesintisiz veri akışı sağlamak için tasarlanmıştır.

-- =====================================================
-- 1. PROFILES TABLOSU
-- =====================================================
-- Kullanıcı profilleri ve roller (admin/field_staff/customer)
-- + Permission Matrix (JSONB) için RBAC desteği
-- =====================================================

CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ad_soyad VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    telefon VARCHAR(20),
    rol VARCHAR(20) NOT NULL CHECK (rol IN ('admin', 'field_staff', 'customer')),
    bolge VARCHAR(100),
    aktif_mi BOOLEAN DEFAULT true,
    permissions JSONB DEFAULT '[]'::jsonb, -- Permission Matrix: ["report.approve", "user.create", ...]
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 2. VEHICLES TABLOSU
-- =====================================================
-- Araç temel bilgileri
-- =====================================================

CREATE TABLE IF NOT EXISTS vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    marka VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    yil INTEGER NOT NULL,
    plaka VARCHAR(20) UNIQUE NOT NULL,
    sase_no VARCHAR(50) UNIQUE,
    motor_no VARCHAR(50),
    renk VARCHAR(50),
    km INTEGER DEFAULT 0,
    yakit_turu VARCHAR(50),
    vites_tipi VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 3. VEHICLE_PACKAGES TABLOSU
-- =====================================================
-- Araç paketleri ve ağırlıkları (vehicle_packages.dart'tan)
-- =====================================================

CREATE TABLE IF NOT EXISTS vehicle_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_id VARCHAR(100) UNIQUE NOT NULL, -- fia_egea_lounge, vw_golf_gti, vb.
    package_name VARCHAR(255) NOT NULL, -- Lounge, GTI, vb.
    brand_name VARCHAR(100) NOT NULL, -- Fiat, Volkswagen, vb.
    model_name VARCHAR(100) NOT NULL, -- Egea, Golf, vb.
    weight DECIMAL(3,2) NOT NULL CHECK (weight >= 1.0 AND weight <= 2.0), -- Paket ağırlık çarpanı
    description TEXT,
    start_year INTEGER,
    end_year INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Örnek veri ekleme (vehicle_packages.dart'tan)
INSERT INTO vehicle_packages (package_id, package_name, brand_name, model_name, weight, description, start_year, end_year) VALUES
-- Fiat Egea
('fia_egea_easy', 'Easy', 'Fiat', 'Egea', 1.0, 'Standart paket', 2016, 2024),
('fia_egea_street', 'Street', 'Fiat', 'Egea', 1.1, 'Orta seviye paket', 2016, 2024),
('fia_egea_lounge', 'Lounge', 'Fiat', 'Egea', 1.25, 'Premium paket', 2016, 2024),
('fia_egea_cross', 'Cross', 'Fiat', 'Egea', 1.3, 'Cross paket', 2016, 2024),
('fia_egea_dolce', 'Dolcevita', 'Fiat', 'Egea', 1.35, 'Premium+', 2016, 2024),
('fia_egea_sport', 'Sport', 'Fiat', 'Egea', 1.4, 'Spor paket', 2016, 2024),

-- Volkswagen Golf
('vw_golf_trend', 'Trendline', 'Volkswagen', 'Golf', 1.0, 'Standart paket', 2015, 2024),
('vw_golf_comfort', 'Comfortline', 'Volkswagen', 'Golf', 1.15, 'Orta seviye', 2015, 2024),
('vw_golf_high', 'Highline', 'Volkswagen', 'Golf', 1.3, 'Premium', 2015, 2024),
('vw_golf_rline', 'R-Line', 'Volkswagen', 'Golf', 1.4, 'Spor paket', 2015, 2024),
('vw_golf_gti', 'GTI', 'Volkswagen', 'Golf', 1.6, 'Sport', 2015, 2024),
('vw_golf_r', 'R', 'Volkswagen', 'Golf', 1.8, 'Ultimate sport', 2015, 2024)

ON CONFLICT (package_id) DO NOTHING;

-- =====================================================
-- 4. REPORTS TABLOSU
-- =====================================================
-- Expertiz raporları ve AI analiz sonuçları
-- =====================================================

CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    
    -- Temel bilgiler
    ilan_linki TEXT,
    sehir VARCHAR(100),
    ilce VARCHAR(100),
    ekspertiz_firmasi VARCHAR(255),
    secilen_paket VARCHAR(100) REFERENCES vehicle_packages(package_id),
    
    -- Fiyatlandırma
    hizmet_bedeli DECIMAL(10,2) DEFAULT 6500.0,
    paket_fiyati DECIMAL(10,2) DEFAULT 0.0,
    toplam_tutar DECIMAL(10,2) DEFAULT 0.0,
    hasar_tutar DECIMAL(10,2) DEFAULT 0.0,
    odendi_mi BOOLEAN DEFAULT false,
    
    -- Durum bilgileri
    -- NOTE: 'durum' eski (legacy) is akis durumudur, 'status' yeni forensic workflow durumudur.
    -- Yeni kod sadece 'status' kullanmalidir. 'durum' geriye uyumluluk icin korunur.
    durum VARCHAR(50) DEFAULT 'OdemeBekliyor' CHECK (durum IN ('OdemeBekliyor', 'Islemde', 'Tamamlandi', 'Iptal')),
    status VARCHAR(30) DEFAULT 'draft' CHECK (status IN ('draft', 'pending_ai', 'pending_admin', 'published', 'rejected')),
    status_updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    version_id INTEGER DEFAULT 0,
    plaka VARCHAR(20),
    firma VARCHAR(255),
    olusturan_kullanici VARCHAR(255),
    
    -- AI Analiz Sonuçları
    ai_analizi_yapildi_mi BOOLEAN DEFAULT false,
    ai_piyasa_degeri DECIMAL(12,2),
    ai_onerilen_alim_fiyati DECIMAL(12,2),
    ai_alti_aylik_getiri DECIMAL(12,2),
    ai_bir_yillik_getiri DECIMAL(12,2),
    ai_yorumu TEXT,
    ai_deger_kaybi DECIMAL(5,2),
    ai_enflasyon_tahmini_12ay DECIMAL(5,2),
    ai_net_kar_potansiyeli DECIMAL(12,2),
    
    -- Piyasa Değeri Hesaplama (Sistem)
    piyasa_degeri_sistem DECIMAL(12,2), -- MarketRadarService sonucu
    piyasa_degeri_ayarlamlar JSONB, -- Ayarlamalar listesi
    
    -- JSONB: Tüm expertiz detayları (dis_ekspertiz, ic_ekspertiz, boya_kaporta, vb.)
    data JSONB DEFAULT '{}'::jsonb,
    
    -- AI Analiz Detayları (JSONB)
    ai_analiz_detay JSONB,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 5. AUDIT_LOGS TABLOSU
-- =====================================================
-- Tüm kritik işlemlerin kaydı (Audit Logging)
-- =====================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    user_email VARCHAR(255) NOT NULL,
    user_name VARCHAR(255) NOT NULL,
    action VARCHAR(50) NOT NULL, -- REPORT_CREATED, AI_ANALYSIS_TRIGGERED, etc.
    entity_type VARCHAR(50) NOT NULL, -- report, user, payment, etc.
    entity_id VARCHAR(100), -- Entity ID (optional)
    old_value JSONB, -- Değişiklikten önceki değer (optional)
    new_value JSONB, -- Değişiklikten sonraki değer (optional)
    ip_address VARCHAR(50), -- IP adresi (optional)
    user_agent TEXT, -- Browser/device info (optional)
    metadata JSONB, -- Ek metadata (optional)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Audit Logs Index'leri
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity_type ON audit_logs(entity_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity_id ON audit_logs(entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_email ON audit_logs(user_email);

-- JSONB Index'leri (old_value, new_value, metadata alanları için)
CREATE INDEX IF NOT EXISTS idx_audit_logs_old_value_gin ON audit_logs USING GIN (old_value);
CREATE INDEX IF NOT EXISTS idx_audit_logs_new_value_gin ON audit_logs USING GIN (new_value);
CREATE INDEX IF NOT EXISTS idx_audit_logs_metadata_gin ON audit_logs USING GIN (metadata);

-- Audit Logs için RLS (Row Level Security)
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Adminler tüm audit loglarını görebilir
CREATE POLICY "Adminler tüm audit loglarını görebilir" ON audit_logs
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND rol = 'admin')
    );

-- Kullanıcılar kendi audit loglarını görebilir
CREATE POLICY "Kullanıcılar kendi audit loglarını görebilir" ON audit_logs
    FOR SELECT USING (user_id = auth.uid());

-- Audit Logs updated_at trigger (opsiyonel, çünkü created_at zaten var)
-- CREATE TRIGGER update_audit_logs_updated_at BEFORE UPDATE ON audit_logs
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- INDEXLER - Performans Optimizasyonu
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_reports_user_id ON reports(user_id);
CREATE INDEX IF NOT EXISTS idx_reports_vehicle_id ON reports(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_reports_durum ON reports(durum);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_plaka ON reports(plaka);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_ai_analizi_yapildi_mi ON reports(ai_analizi_yapildi_mi);
CREATE INDEX IF NOT EXISTS idx_reports_secilen_paket ON reports(secilen_paket);
CREATE INDEX IF NOT EXISTS idx_vehicles_plaka ON vehicles(plaka);
CREATE INDEX IF NOT EXISTS idx_vehicles_marka_model ON vehicles(marka, model);
CREATE INDEX IF NOT EXISTS idx_profiles_rol ON profiles(rol);
CREATE INDEX IF NOT EXISTS idx_profiles_bolge ON profiles(bolge);
CREATE INDEX IF NOT EXISTS idx_vehicle_packages_package_id ON vehicle_packages(package_id);

-- JSONB Index'leri (data alanı içindeki sorgular için)
CREATE INDEX IF NOT EXISTS idx_reports_data_gin ON reports USING GIN (data);
CREATE INDEX IF NOT EXISTS idx_reports_ai_analiz_detay_gin ON reports USING GIN (ai_analiz_detay);

-- =====================================================
-- TRIGGERLAR - Otomatik updated_at güncelleme
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicle_packages_updated_at BEFORE UPDATE ON vehicle_packages
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_reports_updated_at BEFORE UPDATE ON reports
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- ROW LEVEL SECURITY (RLS) - Supabase Güvenliği
-- =====================================================

-- Profil tablosu için RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Kullanıcılar sadece kendi profilini görebilir
CREATE POLICY "Kullanıcılar kendi profilini görebilir" ON profiles
    FOR SELECT USING (auth.uid() = id);

-- Adminler tüm profilleri görebilir
CREATE POLICY "Adminler tüm profilleri görebilir" ON profiles
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND rol = 'admin')
    );

-- Reports tablosu için RLS
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Kullanıcılar kendi raporlarını görebilir
CREATE POLICY "Kullanıcılar kendi raporlarını görebilir" ON reports
    FOR SELECT USING (user_id = auth.uid());

-- Personeller tüm raporları görebilir (işlem gereği)
CREATE POLICY "Personeller tüm raporları görebilir" ON reports
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND rol = 'field_staff')
    );

-- Adminler tüm raporları görebilir ve düzenleyebilir
CREATE POLICY "Adminler tüm raporları yönetebilir" ON reports
    FOR ALL USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND rol = 'admin')
    );

-- Vehicles tablosu için RLS
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;

-- Tüm authenticated kullanıcılar araçları görebilir
CREATE POLICY "Authenticated kullanıcılar araçları görebilir" ON vehicles
    FOR SELECT TO authenticated USING (true);

-- =====================================================
-- VIEWS - Kullanışlı Sorgular
-- =====================================================

-- Rapor Detay View (Araç bilgileri ile birleştirilmiş)
CREATE OR REPLACE VIEW rapor_detay_view AS
SELECT 
    r.id,
    r.user_id,
    p.ad_soyad AS musteri_ad_soyad,
    p.email AS musteri_email,
    v.marka,
    v.model,
    v.yil,
    v.plaka,
    r.durum,
    r.ai_analizi_yapildi_mi,
    r.ai_piyasa_degeri,
    r.piyasa_degeri_sistem,
    r.toplam_tutar,
    r.created_at
FROM reports r
LEFT JOIN profiles p ON r.user_id = p.id
LEFT JOIN vehicles v ON r.vehicle_id = v.id
ORDER BY r.created_at DESC;

-- =====================================================
-- FUNCTIONLAR - Yardımcı Veritabanı Fonksiyonları
-- =====================================================

-- Paket ağırlığını getiren fonksiyon (Flutter'daki getPackageWeight karşılığı)
-- 🔒 DÜZELTİLDİ: package_id parametresi doğru kullanılıyor
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

-- =====================================================
-- TEST VERILERI (Opsiyonel - Geliştirme için)
-- =====================================================

-- Test kullanıcıları
INSERT INTO profiles (ad_soyad, email, rol, bolge) VALUES
('Admin User', 'admin@yerimebak.com', 'admin', 'İstanbul'),
('Personel User', 'personel@yerimebak.com', 'field_staff', 'Ankara'),
('Musteri User', 'musteri@yerimebak.com', 'customer', 'İzmir')
ON CONFLICT (email) DO NOTHING;

-- Test araçları
INSERT INTO vehicles (marka, model, yil, plaka, sase_no, renk, km) VALUES
('Fiat', 'Egea', 2020, '34 ABC 123', '1234567890', 'Beyaz', 45000),
('Volkswagen', 'Golf', 2019, '06 XYZ 456', '0987654321', 'Gri', 60000),
('Renault', 'Megane', 2021, '35 DEF 789', '1122334455', 'Siyah', 30000)
ON CONFLICT (plaka) DO NOTHING;

-- =====================================================
-- END OF SCHEMA
-- =====================================================