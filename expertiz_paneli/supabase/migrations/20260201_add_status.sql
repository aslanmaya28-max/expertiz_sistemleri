-- =====================================================
-- MIGRATION: Reports tablosuna eksik kolon ekleme
-- Tarih: 2026-05-11
-- Aciklama: status, status_updated_at, plaka, firma kolonlari
-- =====================================================

-- status kolonu (workflow durumu)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'reports' AND column_name = 'status'
    ) THEN
        ALTER TABLE reports ADD COLUMN status VARCHAR(30) DEFAULT 'draft'
            CHECK (status IN ('draft', 'pending_ai', 'pending_admin', 'published', 'rejected'));
    END IF;
END $$;

-- status_updated_at kolonu
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'reports' AND column_name = 'status_updated_at'
    ) THEN
        ALTER TABLE reports ADD COLUMN status_updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- plaka kolonu
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'reports' AND column_name = 'plaka'
    ) THEN
        ALTER TABLE reports ADD COLUMN plaka VARCHAR(20);
    END IF;
END $$;

-- firma kolonu
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'reports' AND column_name = 'firma'
    ) THEN
        ALTER TABLE reports ADD COLUMN firma VARCHAR(255);
    END IF;
END $$;

-- Index'ler
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_plaka ON reports(plaka);

-- Mevcut kayitlari guncelle: data->plaka -> plaka kolonuna tasi
UPDATE reports SET plaka = data->>'plaka' WHERE plaka IS NULL AND data->>'plaka' IS NOT NULL;
UPDATE reports SET firma = data->>'firma' WHERE firma IS NULL AND data->>'firma' IS NOT NULL;

-- Mevcut kayitlarin durum senkronizasyonu
UPDATE reports SET status = 'draft' WHERE status IS NULL AND odendi_mi = false;
UPDATE reports SET status = 'draft' WHERE status IS NULL AND odendi_mi = true;
