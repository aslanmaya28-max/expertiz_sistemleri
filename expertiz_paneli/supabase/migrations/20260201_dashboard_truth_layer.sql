-- =====================================================
-- FAZ-0.6: DASHBOARD TRUTH & EVIDENCE LAYER
-- =====================================================
-- Dashboard numbers must NEVER be calculated in Flutter.
-- Supabase RPC is the single source of truth.
-- =====================================================

-- =====================================================
-- 1. SERVICE HEARTBEAT TABLE
-- =====================================================

-- Service heartbeat table
-- Each AuthAwareService writes heartbeat every 60s when alive
CREATE TABLE IF NOT EXISTS service_heartbeat (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_name TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  last_beat_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_alive BOOLEAN NOT NULL DEFAULT true,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast heartbeat queries
CREATE INDEX IF NOT EXISTS idx_service_heartbeat_service_name 
  ON service_heartbeat(service_name);

CREATE INDEX IF NOT EXISTS idx_service_heartbeat_user_id 
  ON service_heartbeat(user_id);

CREATE INDEX IF NOT EXISTS idx_service_heartbeat_last_beat_at 
  ON service_heartbeat(last_beat_at DESC);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_service_heartbeat_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER service_heartbeat_updated_at
  BEFORE UPDATE ON service_heartbeat
  FOR EACH ROW
  EXECUTE FUNCTION update_service_heartbeat_updated_at();

-- Heartbeat upsert function
-- Services call this every 60s when alive
CREATE OR REPLACE FUNCTION upsert_service_heartbeat(
  p_service_name TEXT,
  p_user_id UUID,
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO service_heartbeat (service_name, user_id, last_beat_at, is_alive, metadata)
  VALUES (p_service_name, p_user_id, NOW(), true, p_metadata)
  ON CONFLICT (service_name, user_id)
  DO UPDATE SET
    last_beat_at = NOW(),
    is_alive = true,
    metadata = p_metadata,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 2. ADMIN DASHBOARD STATS RPC
-- =====================================================

-- Get admin dashboard statistics
-- SECURITY DEFINER: Reject non-admin users
-- Returns: JSON with all dashboard metrics
CREATE OR REPLACE FUNCTION get_admin_dashboard_stats(
  p_user_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_stats JSONB;
  v_total_stamps BIGINT;
  v_stamps_last_24h BIGINT;
  v_ai_accuracy NUMERIC;
  v_low_confidence_count BIGINT;
  v_last_stamp_at TIMESTAMPTZ;
  v_system_health TEXT;
  v_active_services INTEGER;
  v_expected_services INTEGER := 3; -- Vision, Ledger, AI
BEGIN
  -- Get current user if not provided
  v_user_id := COALESCE(p_user_id, auth.uid());
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  -- Check user role (admin only)
  SELECT role INTO v_user_role
  FROM profiles
  WHERE id = v_user_id;

  IF v_user_role != 'admin' THEN
    RAISE EXCEPTION 'User is not admin';
  END IF;

  -- 1. Total stamps count
  SELECT COUNT(*) INTO v_total_stamps
  FROM ekspertiz_raporlari
  WHERE deleted_at IS NULL;

  -- 2. Stamps in last 24h
  SELECT COUNT(*) INTO v_stamps_last_24h
  FROM ekspertiz_raporlari
  WHERE created_at >= NOW() - INTERVAL '24 hours'
  AND deleted_at IS NULL;

  -- 3. AI accuracy (average confidence score)
  SELECT COALESCE(AVG((metadata->>'ai_confidence')::NUMERIC), 0) INTO v_ai_accuracy
  FROM ekspertiz_raporlari
  WHERE created_at >= NOW() - INTERVAL '7 days'
  AND deleted_at IS NULL
  AND metadata ? 'ai_confidence';

  -- 4. Low confidence count (< 70%)
  SELECT COUNT(*) INTO v_low_confidence_count
  FROM ekspertiz_raporlari
  WHERE created_at >= NOW() - INTERVAL '24 hours'
  AND deleted_at IS NULL
  AND (metadata->>'ai_confidence')::NUMERIC < 70;

  -- 5. Last stamp time
  SELECT MAX(created_at) INTO v_last_stamp_at
  FROM ekspertiz_raporlari
  WHERE deleted_at IS NULL;

  -- 6. Active services (heartbeat within last 2 minutes)
  SELECT COUNT(DISTINCT service_name) INTO v_active_services
  FROM service_heartbeat
  WHERE last_beat_at >= NOW() - INTERVAL '2 minutes'
  AND is_alive = true;

  -- 7. System health calculation (multi-condition)
  IF v_active_services >= v_expected_services THEN
    v_system_health := 'healthy';
  ELSEIF v_active_services >= v_expected_services / 2 THEN
    v_system_health := 'degraded';
  ELSE
    v_system_health := 'critical';
  END IF;

  -- Build stats JSON
  SELECT jsonb_build_object(
    'total_stamps', v_total_stamps,
    'stamps_last_24h', v_stamps_last_24h,
    'ai_accuracy', ROUND(v_ai_accuracy::NUMERIC, 2),
    'low_confidence_count', v_low_confidence_count,
    'last_stamp_at', v_last_stamp_at,
    'system_health', v_system_health,
    'active_services', v_active_services,
    'expected_services', v_expected_services,
    'timestamp', NOW()
  ) INTO v_stats;

  RETURN v_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_admin_dashboard_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_service_heartbeat(TEXT, UUID, JSONB) TO authenticated;

-- Grant select/insert on service_heartbeat
GRANT SELECT, INSERT, UPDATE ON service_heartbeat TO authenticated;

-- =====================================================
-- 3. REALTIME TRIGGER FOR DASHBOARD UPDATES
-- =====================================================

-- Function to broadcast dashboard update
CREATE OR REPLACE FUNCTION broadcast_dashboard_update()
RETURNS TRIGGER AS $$
BEGIN
  -- Broadcast to dashboard channel
  PERFORM pg_notify('dashboard_updates', JSON_BUILD_OBJECT(
    'table', TG_TABLE_NAME,
    'action', TG_OP,
    'data', row_to_json(NEW)
  )::TEXT);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for ekspertiz_raporlari
CREATE TRIGGER ekspertiz_raporlari_dashboard_trigger
  AFTER INSERT OR UPDATE ON ekspertiz_raporlari
  FOR EACH ROW
  EXECUTE FUNCTION broadcast_dashboard_update();

-- =====================================================
-- 4. CLEANUP OLD HEARTBEATS
-- =====================================================

-- Delete heartbeats older than 24 hours
CREATE OR REPLACE FUNCTION cleanup_old_heartbeats()
RETURNS VOID AS $$
BEGIN
  DELETE FROM service_heartbeat
  WHERE last_beat_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;

-- Schedule cleanup (run every hour)
-- Note: Requires pg_cron extension
-- SELECT cron.schedule('cleanup_heartbeats', '0 * * * *', 'SELECT cleanup_old_heartbeats()');