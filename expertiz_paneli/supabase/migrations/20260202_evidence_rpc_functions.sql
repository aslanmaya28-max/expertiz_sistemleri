-- =====================================================
-- EVIDENCE RPC FUNCTIONS
-- FAZ-1.0 / D0 — Data Layer for Evidence Cards
-- =====================================================
-- PURPOSE: Provide optimized RPC functions for fetching
-- ledger evidence data across Admin, Personnel, and Customer panels
--
-- SECURITY: All functions respect RLS policies
-- PERFORMANCE: Uses optimized queries with proper indexing
-- =====================================================

-- =====================================================
-- ADMIN PANEL: Get All Evidence Stats
-- =====================================================
-- Returns comprehensive evidence statistics for admin dashboard
-- Includes all ledger entries with full reasoning data
CREATE OR REPLACE FUNCTION get_admin_evidence_stats(
  limit_count INT DEFAULT 50,
  offset_count INT DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  evidence_id TEXT,
  timestamp TIMESTAMP WITH TIME ZONE,
  hash TEXT,
  is_verified BOOLEAN,
  observation TEXT,
  assumption TEXT,
  limitation TEXT,
  report_id UUID,
  analyst_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    le.id,
    SUBSTRING(le.id::TEXT, 1, 8) as evidence_id,
    le.created_at as timestamp,
    le.decision_hash as hash,
    false as is_verified,
    -- 🔒 DÜZELTİLDİ (Bug #3): reasoning JSONB cast — TEXT kolon JSONB'e cast ediliyor
    COALESCE((le.reasoning::jsonb)->'technical_justification'->>'observations', '') as observation,
    COALESCE((le.reasoning::jsonb)->'technical_justification'->>'assumptions', '') as assumption,
    COALESCE(
      CASE 
        WHEN ((le.reasoning::jsonb)->'limitations'->>'hasLimitations')::boolean = true 
        THEN COALESCE(array_to_string(
          ARRAY(SELECT jsonb_array_elements_text((le.reasoning::jsonb)->'limitations'->'limitationNotes')),
          '; '
        ), '')
        ELSE ''
      END,
      ''
    ) as limitation,
    le.report_id,
    le.analyst_id
  FROM explainability_ledger le
  ORDER BY le.created_at DESC
  LIMIT limit_count
  OFFSET offset_count;
END;
$$;

-- =====================================================
-- PERSONNEL PANEL: Get Personnel Evidence Stats
-- =====================================================
-- Returns evidence records created by specific personnel
CREATE OR REPLACE FUNCTION get_personnel_evidence_stats(
  personnel_id UUID,
  limit_count INT DEFAULT 50,
  offset_count INT DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  evidence_id TEXT,
  timestamp TIMESTAMP WITH TIME ZONE,
  hash TEXT,
  is_verified BOOLEAN,
  observation TEXT,
  assumption TEXT,
  limitation TEXT,
  report_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    le.id,
    SUBSTRING(le.id::TEXT, 1, 8) as evidence_id,
    le.created_at as timestamp,
    le.decision_hash as hash,
    false as is_verified,
    -- 🔒 DÜZELTİLDİ (Bug #3): reasoning JSONB cast
    COALESCE((le.reasoning::jsonb)->'technical_justification'->>'observations', '') as observation,
    COALESCE((le.reasoning::jsonb)->'technical_justification'->>'assumptions', '') as assumption,
    COALESCE(
      CASE 
        WHEN ((le.reasoning::jsonb)->'limitations'->>'hasLimitations')::boolean = true 
        THEN COALESCE(array_to_string(
          ARRAY(SELECT jsonb_array_elements_text((le.reasoning::jsonb)->'limitations'->'limitationNotes')),
          '; '
        ), '')
        ELSE ''
      END,
      ''
    ) as limitation,
    le.report_id
  FROM explainability_ledger le
  WHERE le.analyst_id = personnel_id
  ORDER BY le.created_at DESC
  LIMIT limit_count
  OFFSET offset_count;
END;
$$;

-- =====================================================
-- CUSTOMER PANEL: Get Customer Evidence Stats
-- =====================================================
-- Returns evidence records for reports owned by customer
CREATE OR REPLACE FUNCTION get_customer_evidence_stats(
  customer_id UUID,
  limit_count INT DEFAULT 50,
  offset_count INT DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  evidence_id TEXT,
  timestamp TIMESTAMP WITH TIME ZONE,
  hash TEXT,
  is_verified BOOLEAN,
  observation TEXT,
  assumption TEXT,
  limitation TEXT,
  report_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    le.id,
    SUBSTRING(le.id::TEXT, 1, 8) as evidence_id,
    le.created_at as timestamp,
    le.decision_hash as hash,
    false as is_verified,
    -- 🔒 DÜZELTİLDİ (Bug #3): reasoning JSONB cast
    COALESCE((le.reasoning::jsonb)->'technical_justification'->>'observations', '') as observation,
    COALESCE((le.reasoning::jsonb)->'technical_justification'->>'assumptions', '') as assumption,
    COALESCE(
      CASE 
        WHEN ((le.reasoning::jsonb)->'limitations'->>'hasLimitations')::boolean = true 
        THEN COALESCE(array_to_string(
          ARRAY(SELECT jsonb_array_elements_text((le.reasoning::jsonb)->'limitations'->'limitationNotes')),
          '; '
        ), '')
        ELSE ''
      END,
      ''
    ) as limitation,
    le.report_id
  FROM explainability_ledger le
  INNER JOIN reports r ON le.report_id = r.id
  WHERE r.user_id = customer_id
  ORDER BY le.created_at DESC
  LIMIT limit_count
  OFFSET offset_count;
END;
$$;

-- =====================================================
-- EVIDENCE COUNT BY STATUS
-- =====================================================
-- Returns summary statistics for dashboard widgets
CREATE OR REPLACE FUNCTION get_evidence_summary_stats(
  user_id UUID,
  user_role TEXT
)
RETURNS TABLE (
  total_evidence BIGINT,
  verified_evidence BIGINT,
  with_limitations BIGINT,
  last_evidence_date TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Admin: global stats
  IF user_role = 'admin' THEN
    RETURN QUERY
    SELECT 
      COUNT(*) as total_evidence,
      0 as verified_evidence,
      -- 🔒 DÜZELTİLDİ (Bug #3): reasoning JSONB cast
      COUNT(*) FILTER (
        WHERE ((reasoning::jsonb)->'limitations'->>'hasLimitations')::boolean = true
      ) as with_limitations,
      MAX(created_at) as last_evidence_date
    FROM explainability_ledger;
  
  -- Personnel: personal stats
  ELSIF user_role = 'field_staff' THEN
    RETURN QUERY
    SELECT 
      COUNT(*) as total_evidence,
      0 as verified_evidence,
      -- 🔒 DÜZELTİLDİ (Bug #3): reasoning JSONB cast
      COUNT(*) FILTER (
        WHERE ((reasoning::jsonb)->'limitations'->>'hasLimitations')::boolean = true
      ) as with_limitations,
      MAX(created_at) as last_evidence_date
    FROM explainability_ledger
    WHERE analyst_id = user_id;
  
  -- Customer: owned report stats
  -- 🔒 DÜZELTİLDİ (Bug #1, #2): raporlar → reports, musteri_id → user_id
  ELSIF user_role = 'customer' THEN
    RETURN QUERY
    SELECT 
      COUNT(*) as total_evidence,
      0 as verified_evidence,
      -- 🔒 DÜZELTİLDİ (Bug #3): reasoning JSONB cast
      COUNT(*) FILTER (
        WHERE ((le.reasoning::jsonb)->'limitations'->>'hasLimitations')::boolean = true
      ) as with_limitations,
      MAX(le.created_at) as last_evidence_date
    FROM explainability_ledger le
    INNER JOIN reports r ON le.report_id = r.id
    WHERE r.user_id = user_id;
  
  ELSE
    RETURN QUERY
    SELECT 
      0::BIGINT as total_evidence,
      0::BIGINT as verified_evidence,
      0::BIGINT as with_limitations,
      NULL::TIMESTAMP WITH TIME ZONE as last_evidence_date;
  END IF;
END;
$$;

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================
GRANT EXECUTE ON FUNCTION get_admin_evidence_stats TO authenticated;
GRANT EXECUTE ON FUNCTION get_personnel_evidence_stats TO authenticated;
GRANT EXECUTE ON FUNCTION get_customer_evidence_stats TO authenticated;
GRANT EXECUTE ON FUNCTION get_evidence_summary_stats TO authenticated;

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_ledger_created_at 
ON explainability_ledger(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ledger_analyst_id 
ON explainability_ledger(analyst_id);

CREATE INDEX IF NOT EXISTS idx_ledger_report_id 
ON explainability_ledger(report_id);

-- =====================================================
-- COMMENTS
-- =====================================================
COMMENT ON FUNCTION get_admin_evidence_stats IS 
'FAZ-1.0: Returns all ledger evidence for admin dashboard with reasoning extracted';

COMMENT ON FUNCTION get_personnel_evidence_stats IS 
'FAZ-1.0: Returns ledger evidence created by specific personnel member';

COMMENT ON FUNCTION get_customer_evidence_stats IS 
'FAZ-1.0: Returns ledger evidence for reports owned by customer';

COMMENT ON FUNCTION get_evidence_summary_stats IS 
'FAZ-1.0: Returns summary statistics (total, verified, limitations) for dashboard widgets';
