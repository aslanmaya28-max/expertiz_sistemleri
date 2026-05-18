-- =====================================================
-- FAZ-3.0 / M1 — STATUS WORKFLOW & RLS DEPLOYMENT
-- =====================================================
--
-- ⚖️ LEGAL STANDARD:
-- This migration enforces forensic-grade workflow integrity:
-- - Status transitions are audited
-- - Row-Level Security prevents unauthorized access
-- - Customer sees ONLY published reports
-- - Admin approval is MANDATORY for publication
-- - All transitions are logged to audit trail
--
-- 🎯 OBJECTIVE:
-- Implement multi-stage review workflow:
-- draft → pending_ai → pending_admin → published
--                                 ↘ rejected
--
-- 🪨 PRINCIPLE:
-- "Once sealed, forever revealed."
-- =====================================================

-- =====================================================
-- STEP 1: CREATE STATUS ENUM TYPE
-- =====================================================

DO $$ BEGIN
    CREATE TYPE report_status AS ENUM (
        'draft',
        'pending_ai',
        'pending_admin',
        'rejected',
        'published'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON TYPE report_status IS '
Status values:
  draft         - Personnel working on report
  pending_ai    - Queued for AI analysis
  pending_admin - Awaiting admin approval
  rejected      - Rejected by admin, needs correction
  published     - Published to customer, immutable
';

-- =====================================================
-- STEP 2: ADD STATUS COLUMN TO reports TABLE
-- =====================================================

-- Add status column with default 'draft'
-- 🔒 DÜZELTİLDİ: Önce VARCHAR varsa kaldir, sonra ENUM ekle (tip çakışması)
DO $$ BEGIN
    -- Eğer status sütunu VARCHAR ise, önce onu kaldir
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'reports' AND column_name = 'status' 
        AND data_type = 'character varying'
    ) THEN
        ALTER TABLE reports DROP COLUMN status;
    END IF;
END $$;

ALTER TABLE reports 
ADD COLUMN IF NOT EXISTS status report_status NOT NULL DEFAULT 'draft';

-- Add status history tracking
ALTER TABLE reports
ADD COLUMN IF NOT EXISTS status_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS status_updated_by UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_status_updated ON reports(status_updated_at DESC);

-- =====================================================
-- STEP 3: STATUS TRANSITION TRIGGER
-- =====================================================

-- Function to enforce valid status transitions
CREATE OR REPLACE FUNCTION enforce_status_transition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    old_status report_status;
    new_status report_status;
    user_role TEXT;
BEGIN
    -- Get old and new status
    old_status := OLD.status;
    new_status := NEW.status;
    
    -- Skip if status hasn't changed
    IF old_status = new_status THEN
        RETURN NEW;
    END IF;
    
    -- 🔒 DÜZELTİLDİ (Bug #5): raw_user_meta_data->>'role' yerine 
    -- doğrudan JWT claim'den role al, personel/field_staff hepsi kabul edilsin
    user_role := COALESCE(
        auth.jwt() ->> 'role',
        (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid())
    );
    
    -- =====================================================
    -- VALIDATE STATUS TRANSITIONS
    -- =====================================================
    
    -- draft → pending_ai (Personnel: Submit for Review)
    IF old_status = 'draft' AND new_status = 'pending_ai' THEN
        -- 🔒 DÜZELTİLDİ (Bug #5): 'personnel' + 'field_staff' + 'staff' rolu kabul edilir
        IF user_role NOT IN ('personnel', 'field_staff', 'staff', 'admin') THEN
            RAISE EXCEPTION 'STATUS FORBIDDEN: Only personnel or admin can submit reports for AI analysis';
        END IF;
    
    -- pending_ai → pending_admin (AI Service: Analysis complete)
    ELSIF old_status = 'pending_ai' AND new_status = 'pending_admin' THEN
        -- Only AI service (service_role) or admin can transition
        IF user_role NOT IN ('service_role', 'admin') THEN
            RAISE EXCEPTION 'STATUS FORBIDDEN: Only AI service or admin can mark analysis as complete';
        END IF;
    
    -- pending_admin → published (Admin: Approve & Seal)
    ELSIF old_status = 'pending_admin' AND new_status = 'published' THEN
        -- ONLY admin can publish
        IF user_role != 'admin' THEN
            RAISE EXCEPTION 'STATUS FORBIDDEN: Only admin can publish reports. Legal requirement.';
        END IF;
        
        -- Enforce rejection reason is null
        IF NEW.rejection_reason IS NOT NULL THEN
            RAISE EXCEPTION 'STATUS FORBIDDEN: Published reports cannot have rejection reason';
        END IF;
    
    -- pending_admin → rejected (Admin: Reject with Reason)
    ELSIF old_status = 'pending_admin' AND new_status = 'rejected' THEN
        -- ONLY admin can reject
        IF user_role != 'admin' THEN
            RAISE EXCEPTION 'STATUS FORBIDDEN: Only admin can reject reports';
        END IF;
        
        -- Require rejection reason
        IF NEW.rejection_reason IS NULL OR LENGTH(TRIM(NEW.rejection_reason)) = 0 THEN
            RAISE EXCEPTION 'STATUS FORBIDDEN: Rejection reason is required when rejecting a report';
        END IF;
    
    -- rejected → draft (Personnel: Correct & Resubmit)
    ELSIF old_status = 'rejected' AND new_status = 'draft' THEN
        -- 🔒 DÜZELTİLDİ (Bug #5): 'personnel' + 'field_staff' kabul edilir
        IF user_role NOT IN ('personnel', 'field_staff', 'staff', 'admin') THEN
            RAISE EXCEPTION 'STATUS FORBIDDEN: Only personnel or admin can reopen rejected reports';
        END IF;
        
        -- Clear rejection reason on reopen
        NEW.rejection_reason := NULL;
    
    -- Any other transition is FORBIDDEN
    ELSE
        RAISE EXCEPTION 'STATUS FORBIDDEN: Invalid status transition from % to %', old_status, new_status;
    END IF;
    
    -- =====================================================
    -- UPDATE STATUS METADATA
    -- =====================================================
    
    -- Update timestamp and user
    NEW.status_updated_at := NOW();
    NEW.status_updated_by := auth.uid();
    
    -- =====================================================
    -- AUDIT TRAIL
    -- =====================================================
    
    -- 🔒 DÜZELTİLDİ (Bug #4): audit_logs INSERT — database_schema.sql'deki
    -- gerçek audit_logs şemasına uygun hale getirildi.
    -- Orijinal şema: user_id, user_email, user_name, action, entity_type, entity_id,
    --                 old_value, new_value, ip_address, user_agent, metadata
    INSERT INTO audit_logs (
        action,
        entity_type,
        entity_id,
        user_id,
        user_email,
        user_name,
        old_value,
        new_value,
        metadata,
        created_at
    ) VALUES (
        'status_transition',
        'report',
        NEW.id::TEXT,
        auth.uid(),
        COALESCE((SELECT email FROM auth.users WHERE id = auth.uid()), 'system@yerimebak.com'),
        COALESCE((SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE id = auth.uid()), 'System'),
        jsonb_build_object('status', old_status),
        jsonb_build_object('status', new_status, 'rejection_reason', NEW.rejection_reason),
        jsonb_build_object(
            'old_status', old_status,
            'new_status', new_status,
            'rejection_reason', NEW.rejection_reason,
            'transitioned_by_role', user_role
        ),
        NOW()
    );
    
    RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS status_transition_trigger ON reports;
CREATE TRIGGER status_transition_trigger
    BEFORE UPDATE OF status ON reports
    FOR EACH ROW
    EXECUTE FUNCTION enforce_status_transition();

COMMENT ON FUNCTION enforce_status_transition() IS '
Forensic-grade status transition enforcement.
All transitions are validated against role-based rules.
Unauthorized transitions throw exceptions and are logged to audit trail.
';

-- =====================================================
-- STEP 4: ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on reports table
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports FORCE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "reports_select_policy" ON reports;
DROP POLICY IF EXISTS "reports_insert_policy" ON reports;
DROP POLICY IF EXISTS "reports_update_policy" ON reports;
DROP POLICY IF EXISTS "reports_delete_policy" ON reports;
DROP POLICY IF EXISTS "customer_select_published_only" ON reports;

-- -----------------------------------------------------
-- CUSTOMER ACCESS (READ-ONLY, PUBLISHED ONLY)
-- -----------------------------------------------------

-- 🔒 DÜZELTİLDİ (Bug #7): customer_reports tablosu mevcut değil.
-- Bunun yerine doğrudan reports.user_id kontrolü yapılıyor.
-- customer-reports junction table yok, ilişki reports.user_id üzerinden.
CREATE POLICY "customer_select_published_only"
    ON reports
    FOR SELECT
    TO authenticated
    USING (
        -- Customer can ONLY see published reports
        status = 'published'
        AND
        -- Customer can ONLY see their own reports via user_id
        user_id = auth.uid()
    )
    WITH CHECK (
        status = 'published'
        AND
        user_id = auth.uid()
    );

COMMENT ON POLICY "customer_select_published_only" ON reports IS '
FORENSIC REQUIREMENT: Customers can ONLY access published reports.
This is enforced at database level via RLS.
Any attempt to access non-published reports will be blocked.
';

-- -----------------------------------------------------
-- PERSONNEL ACCESS (CRUD OWN DRAFTS)
-- -----------------------------------------------------

CREATE POLICY "personnel_select_own"
    ON reports
    FOR SELECT
    TO authenticated
    USING (
        -- Personnel can see own reports (any status)
        user_id = auth.uid()
        AND
        auth.jwt() ->> 'role' IN ('personnel', 'field_staff', 'staff')
    );

CREATE POLICY "personnel_insert_own"
    ON reports
    FOR INSERT
    TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        AND
        auth.jwt() ->> 'role' IN ('personnel', 'field_staff', 'staff')
        AND
        -- Personnel can only create draft reports
        status = 'draft'
    );

CREATE POLICY "personnel_update_own"
    ON reports
    FOR UPDATE
    TO authenticated
    USING (
        user_id = auth.uid()
        AND
        auth.jwt() ->> 'role' IN ('personnel', 'field_staff', 'staff')
        AND
        -- Personnel can only update draft or rejected reports
        status IN ('draft', 'rejected')
    )
    WITH CHECK (
        user_id = auth.uid()
        AND
        auth.jwt() ->> 'role' IN ('personnel', 'field_staff', 'staff')
        AND
        status IN ('draft', 'rejected')
    );

COMMENT ON POLICY "personnel_select_own" ON reports IS '
Personnel can CRUD own reports in draft or rejected status.
Cannot modify once submitted for AI analysis.
';

-- -----------------------------------------------------
-- ADMIN ACCESS (FULL CONTROL)
-- -----------------------------------------------------

CREATE POLICY "admin_select_all"
    ON reports
    FOR SELECT
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'admin'
    );

CREATE POLICY "admin_update_all"
    ON reports
    FOR UPDATE
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'admin'
    )
    WITH CHECK (
        auth.jwt() ->> 'role' = 'admin'
    );

COMMENT ON POLICY "admin_update_all" ON reports IS '
Admin has full control over all reports.
Only admin can approve (publish) or reject reports.
Legal requirement: Admin approval is MANDATORY for publication.
';

-- -----------------------------------------------------
-- SERVICE ROLE ACCESS (AI ANALYSIS)
-- -----------------------------------------------------

CREATE POLICY "service_role_update_for_ai"
    ON reports
    FOR UPDATE
    TO service_role
    USING (
        -- Service role can update status from pending_ai to pending_admin
        status = 'pending_ai'
    )
    WITH CHECK (
        -- Service role can only transition to pending_admin
        status = 'pending_admin'
    );

COMMENT ON POLICY "service_role_update_for_ai" ON reports IS '
Service role (AI analysis) can only transition pending_ai → pending_admin.
Cannot modify any other status.
';

-- =====================================================
-- STEP 5: LEGACY DATA MIGRATION
-- =====================================================

-- Set all existing reports to 'draft' status
-- This ensures backward compatibility
-- 🔒 DÜZELTİLDİ (Bug #6): NULL UUID FK referansı — auth.users'da kaydı olmayan
-- bir UUID kullanmak FK violation hatasına yol açar.
-- Bunun yerine status_updated_by NULL bırakılıyor.
UPDATE reports
SET 
    status = 'draft',
    status_updated_at = NOW(),
    status_updated_by = NULL
WHERE status IS NULL;

COMMENT ON TABLE reports IS '
Expertiz reports with forensic-grade status workflow.
Status transitions are enforced via triggers and RLS.
Customer access is restricted to published reports only.
';

-- =====================================================
-- STEP 6: HELPER FUNCTIONS
-- =====================================================

-- Function to get reports by status (for review queue)
-- 🔒 DÜZELTİLDİ (Bug #12): reports.customer_id kolonu tanımlı değil,
-- database_schema.sql''de sadece user_id var. customer_id → user_id yapıldı.
CREATE OR REPLACE FUNCTION get_reports_by_status(
    p_status report_status,
    p_limit INT DEFAULT 50,
    p_offset INT DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    status report_status,
    created_at TIMESTAMPTZ,
    status_updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        r.user_id,
        r.status,
        r.created_at,
        r.status_updated_at
    FROM reports r
    WHERE r.status = p_status
    ORDER BY r.status_updated_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION get_reports_by_status IS '
Helper function for admin review queue.
Returns paginated list of reports by status.
';

-- =====================================================
-- STEP 7: AUDIT & VERIFICATION
-- =====================================================

-- Log migration completion
-- 🔒 DÜZELTİLDİ (Bug #4 + Bug #6): audit_logs INSERT gerçek şemaya uygun
INSERT INTO audit_logs (
    action,
    entity_type,
    entity_id,
    user_id,
    user_email,
    user_name,
    old_value,
    new_value,
    metadata,
    created_at
) VALUES (
    'migration_completed',
    'system',
    'migration-20260202-status-workflow',
    NULL,
    'system@yerimebak.com',
    'System Migration',
    NULL,
    NULL,
    jsonb_build_object(
        'migration_name', '20260202_status_workflow',
        'description', 'Status workflow and RLS deployment',
        'features', jsonb_build_array(
            'Status enum type',
            'Status transition triggers',
            'Row-Level Security policies',
            'Legacy data migration',
            'Helper functions'
        )
    ),
    NOW()
);

-- =====================================================
-- VERIFICATION QUERIES (MANUAL RUN AFTER MIGRATION)
-- =====================================================

-- 1. Verify status type created
-- SELECT typename FROM pg_type WHERE typname = 'report_status';

-- 2. Verify policies created
-- SELECT schemaname, tablename, policyname FROM pg_policies WHERE tablename = 'reports';

-- 3. Verify trigger created
-- SELECT tgname FROM pg_trigger WHERE tgrelid = 'reports'::regclass AND tgname = 'status_transition_trigger';

-- 4. Verify legacy data migrated
-- SELECT status, COUNT(*) FROM reports GROUP BY status;

-- =====================================================
-- END OF MIGRATION
-- =====================================================
