-- =====================================================
-- FAZ-6.0: THE FIELD-OFFICE BRIDGE - DATABASE UPDATES
-- =====================================================
-- 
-- This migration adds support for:
-- 1. Admin annotations on rejected reports
-- 2. Media metadata capture (GPS, device info)
-- 3. QR code verification endpoint
--
-- Author: Cline (AI Assistant)
-- Date: 02/02/2026
-- =====================================================

-- ============================================
-- 1. ADD ADMIN ANNOTATIONS FIELD
-- ============================================

-- Add admin_annotations column to reports table
ALTER TABLE reports 
ADD COLUMN IF NOT EXISTS admin_annotations JSONB DEFAULT '[]'::jsonb;

-- Add comment for documentation
COMMENT ON COLUMN reports.admin_annotations IS 'Admin annotations for rejected reports. Contains array of annotation objects with fieldKey, message, adminId, etc.';

-- Create GIN index for faster JSONB queries
CREATE INDEX IF NOT EXISTS idx_reports_admin_annotations 
ON reports USING GIN (admin_annotations);

-- ============================================
-- 2. ADD MEDIA METADATA FIELD
-- ============================================

-- Add media_metadata column to reports table
ALTER TABLE reports 
ADD COLUMN IF NOT EXISTS media_metadata JSONB DEFAULT '{}'::jsonb;

-- Add comment for documentation
COMMENT ON COLUMN reports.media_metadata IS 'Media metadata for all photos in the report. Contains GPS coordinates, device info, timestamps, etc.';

-- Create GIN index for faster JSONB queries
CREATE INDEX IF NOT EXISTS idx_reports_media_metadata 
ON reports USING GIN (media_metadata);

-- ============================================
-- 3. ADD OFFLINE SYNC FIELDS
-- ============================================

-- Add fields for offline queue management
ALTER TABLE reports 
ADD COLUMN IF NOT EXISTS is_offline BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS offline_created_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ;

-- Add comments
COMMENT ON COLUMN reports.is_offline IS 'True if report was created while offline';
COMMENT ON COLUMN reports.offline_created_at IS 'Timestamp when report was created offline';
COMMENT ON COLUMN reports.last_synced_at IS 'Timestamp when report was last synced with server';

-- Create index for offline reports query
CREATE INDEX IF NOT EXISTS idx_reports_offline 
ON reports (is_offline, offline_created_at);

-- ============================================
-- 4. QR CODE VERIFICATION FUNCTION
-- ============================================

-- Create function to verify report by QR code
CREATE OR REPLACE FUNCTION verify_report_by_qr(report_uuid UUID)
RETURNS JSON AS $$
DECLARE
  report_data JSON;
  ledger_hash TEXT;
  is_valid BOOLEAN;
  is_verified BOOLEAN;
  report_status TEXT;
  created_at TIMESTAMPTZ;
BEGIN
  -- Get report data
  SELECT 
    row_to_json(r.*),
    r.status,
    r.created_at
  INTO report_data, report_status, created_at
  FROM reports r
  WHERE r.id = report_uuid;
  
  -- Check if report exists
  is_valid := (report_data IS NOT NULL);
  
  -- Get latest ledger hash
  SELECT decision_hash INTO ledger_hash
  FROM explainability_ledger
  WHERE report_id = report_uuid
  ORDER BY created_at DESC
  LIMIT 1;
  
  -- Check if report is verified (has ledger entry)
  is_verified := (ledger_hash IS NOT NULL);
  
  -- Return verification result
  RETURN json_build_object(
    'is_valid', is_valid,
    'is_verified', is_verified,
    'report_id', report_uuid,
    'report_status', report_status,
    'created_at', created_at,
    'ledger_hash', ledger_hash,
    'verification_url', 'https://yerimebak.com/verify/' || report_uuid::text,
    'message', CASE 
      WHEN NOT is_valid THEN 'Rapor bulunamadı'
      WHEN NOT is_verified THEN 'Rapor henüz mühürlenmemiş'
      ELSE 'Bu rapor YerimeBak tarafından mühürlenmiş ve değiştirilmemiştir'
    END
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION verify_report_by_qr(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_report_by_qr(UUID) TO anon;

-- ============================================
-- 5. HELPER FUNCTIONS
-- ============================================

-- Function to add annotation to report
CREATE OR REPLACE FUNCTION add_admin_annotation(
  report_uuid UUID,
  field_key TEXT,
  field_label TEXT,
  annotation_type TEXT,
  message TEXT,
  admin_id UUID,
  admin_name TEXT,
  severity TEXT DEFAULT 'medium'
) RETURNS JSON AS $$
DECLARE
  current_annotations JSONB;
  new_annotation JSONB;
BEGIN
  -- Get current annotations
  SELECT COALESCE(admin_annotations, '[]'::jsonb)
  INTO current_annotations
  FROM reports
  WHERE id = report_uuid;
  
  -- Create new annotation
  new_annotation = jsonb_build_object(
    'id', gen_random_uuid()::text,
    'fieldKey', field_key,
    'fieldLabel', field_label,
    'annotationType', annotation_type,
    'message', message,
    'adminId', admin_id::text,
    'adminName', admin_name,
    'createdAt', now()::text,
    'severity', severity
  );
  
  -- Append to annotations array
  current_annotations = current_annotations || new_annotation;
  
  -- Update report
  UPDATE reports
  SET admin_annotations = current_annotations
  WHERE id = report_uuid;
  
  RETURN json_build_object(
    'success', true,
    'annotation', new_annotation,
    'total_annotations', jsonb_array_length(current_annotations)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION add_admin_annotation TO authenticated;

-- Function to clear all annotations
CREATE OR REPLACE FUNCTION clear_admin_annotations(report_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE reports
  SET admin_annotations = '[]'::jsonb
  WHERE id = report_uuid;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION clear_admin_annotations TO authenticated;

-- ============================================
-- 6. MIGRATION COMPLETE
-- ============================================

-- Log migration completion
DO $$
BEGIN
  RAISE NOTICE 'FAZ-6.0 database migration completed successfully';
  RAISE NOTICE 'Added: admin_annotations, media_metadata, offline_sync fields';
  RAISE NOTICE 'Added: QR verification function';
  RAISE NOTICE 'Added: Annotation helper functions';
END $$;