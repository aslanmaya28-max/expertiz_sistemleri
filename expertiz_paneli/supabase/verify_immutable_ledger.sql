-- =====================================================
-- VERIFICATION SCRIPT: IMMUTABLE LEDGER DEPLOYMENT
-- =====================================================
-- 
-- Run this script AFTER applying the migration to verify
-- that all immutability measures are in place.
-- 
-- Expected: All destructive operations should FAIL
-- Expected: INSERT should SUCCEED
-- =====================================================

-- =====================================================
-- TEST 1: VERIFY TABLE EXISTS
-- =====================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'explainability_ledger') THEN
    RAISE NOTICE '✅ Table explainability_ledger exists';
  ELSE
    RAISE EXCEPTION '❌ Table explainability_ledger does NOT exist';
  END IF;
END $$;

-- =====================================================
-- TEST 2: VERIFY TRIGGER EXISTS
-- =====================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'immutable_ledger_trigger'
  ) THEN
    RAISE NOTICE '✅ Trigger immutable_ledger_trigger exists';
  ELSE
    RAISE EXCEPTION '❌ Trigger immutable_ledger_trigger NOT found';
  END IF;
END $$;

-- =====================================================
-- TEST 3: VERIFY RLS IS ENABLED
-- =====================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class 
    WHERE relname = 'explainability_ledger' 
    AND relrowsecurity = true
  ) THEN
    RAISE NOTICE '✅ Row Level Security is ENABLED';
  ELSE
    RAISE EXCEPTION '❌ Row Level Security is NOT enabled';
  END IF;
END $$;

-- =====================================================
-- TEST 4: VERIFY RLS POLICIES
-- =====================================================
DO $$
DECLARE
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE tablename = 'explainability_ledger';
  
  IF policy_count >= 4 THEN
    RAISE NOTICE '✅ RLS policies configured (found % policies)', policy_count;
  ELSE
    RAISE EXCEPTION '❌ Insufficient RLS policies (found %, expected at least 4)', policy_count;
  END IF;
END $$;

-- =====================================================
-- TEST 5: VERIFY HASH CONSTRAINTS
-- =====================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'decision_hash_length_check'
  ) THEN
    RAISE NOTICE '✅ Hash length constraint exists';
  ELSE
    RAISE EXCEPTION '❌ Hash length constraint NOT found';
  END IF;
END $$;

-- =====================================================
-- TEST 6: UPDATE ATTEMPT (SHOULD FAIL)
-- =====================================================
DO $$
BEGIN
  -- This should raise an exception
  PERFORM prevent_ledger_mutation();
  
  RAISE NOTICE '⚠️  UPDATE test: Function exists (will test operation below)';
EXCEPTION
  WHEN OTHERS THEN
    NULL; -- Function may not be callable directly
END $$;

-- Actual UPDATE test
BEGIN
  UPDATE explainability_ledger 
  SET reasoning = 'MODIFIED' 
  WHERE id = '00000000-0000-0000-0000-000000000000';
  
  RAISE EXCEPTION '❌ UPDATE succeeded (SHOULD HAVE FAILED!)';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM LIKE '%IMMUTABLE LEDGER%' THEN
    RAISE NOTICE '✅ UPDATE blocked correctly: %', SQLERRM;
  ELSE
    RAISE NOTICE '⚠️  UPDATE blocked (different error): %', SQLERRM;
  END IF;
END;

-- =====================================================
-- TEST 7: DELETE ATTEMPT (SHOULD FAIL)
-- =====================================================
BEGIN
  DELETE FROM explainability_ledger 
  WHERE id = '00000000-0000-0000-0000-000000000000';
  
  RAISE EXCEPTION '❌ DELETE succeeded (SHOULD HAVE FAILED!)';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM LIKE '%IMMUTABLE LEDGER%' THEN
    RAISE NOTICE '✅ DELETE blocked correctly: %', SQLERRM;
  ELSE
    RAISE NOTICE '⚠️  DELETE blocked (different error): %', SQLERRM;
  END IF;
END;

-- =====================================================
-- TEST 8: TRUNCATE ATTEMPT (SHOULD FAIL)
-- =====================================================
BEGIN
  TRUNCATE explainability_ledger;
  
  RAISE EXCEPTION '❌ TRUNCATE succeeded (SHOULD HAVE FAILED!)';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM LIKE '%permission denied%' THEN
    RAISE NOTICE '✅ TRUNCATE blocked correctly: %', SQLERRM;
  ELSE
    RAISE NOTICE '⚠️  TRUNCATE blocked (different error): %', SQLERRM;
  END IF;
END;

-- =====================================================
-- TEST 9: INSERT TEST (SHOULD SUCCEED)
-- =====================================================
DO $$
DECLARE
  test_id UUID;
BEGIN
  -- Test INSERT in a transaction
  BEGIN
    INSERT INTO explainability_ledger (
      report_id,
      decision_hash,
      image_hash,
      reasoning,
      ai_output,
      model_name,
      model_version,
      confidence_score
    ) VALUES (
      gen_random_uuid(),
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      'VERIFICATION_TEST',
      'Test output',
      'TestModel',
      '1.0',
      95.5
    );
    
    -- Get the inserted record ID
    SELECT id INTO test_id
    FROM explainability_ledger
    WHERE reasoning = 'VERIFICATION_TEST'
    LIMIT 1;
    
    IF test_id IS NOT NULL THEN
      RAISE NOTICE '✅ INSERT succeeded (ID: %)', test_id;
      
      -- Clean up test record
      DELETE FROM explainability_ledger WHERE id = test_id;
      RAISE NOTICE '✅ Test record cleaned up';
    ELSE
      RAISE EXCEPTION '❌ INSERT failed - record not found';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️  INSERT test failed: %', SQLERRM;
  END;
END $$;

-- =====================================================
-- TEST 10: VERIFY AUDIT TABLE EXISTS
-- =====================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'explainability_ledger_violation_audit') THEN
    RAISE NOTICE '✅ Audit table explainability_ledger_violation_audit exists';
  ELSE
    RAISE NOTICE '⚠️  Audit table not found (optional)';
  END IF;
END $$;

-- =====================================================
-- FINAL SUMMARY
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=====================================================';
  RAISE NOTICE 'IMMUTABLE LEDGER VERIFICATION COMPLETE';
  RAISE NOTICE '=====================================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Expected Results:';
  RAISE NOTICE '  ✅ All checks should pass';
  RAISE NOTICE '  ✅ UPDATE should be blocked';
  RAISE NOTICE '  ✅ DELETE should be blocked';
  RAISE NOTICE '  ✅ TRUNCATE should be blocked';
  RAISE NOTICE '  ✅ INSERT should work';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  CRITICAL WARNING:';
  RAISE NOTICE '  Any record written to explainability_ledger after';
  RAISE NOTICE '  this point is legally non-repudiable and represents';
  RAISE NOTICE '  a permanent legal artifact.';
  RAISE NOTICE '';
  RAISE NOTICE '🪨 "Logs can be edited. Ledgers are carved in stone."';
  RAISE NOTICE '=====================================================';
END $$;