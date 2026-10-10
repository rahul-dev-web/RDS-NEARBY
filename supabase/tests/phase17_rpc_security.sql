-- Phase 17 catalog-level regression checks. Run against a migrated test database.
DO $$
DECLARE
  v_missing text;
BEGIN
  SELECT string_agg(p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')', ', ')
    INTO v_missing
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'cancel_customer_request',
      'create_customer_request',
      'redeem_customer_points',
      'respond_customer_request',
      'respond_to_point_redemption'
    )
    AND NOT coalesce(p.proconfig @> ARRAY['search_path=""'], false);

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'SECURITY DEFINER RPCs missing empty search_path: %', v_missing;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'cancel_customer_request',
        'create_customer_request',
        'redeem_customer_points',
        'respond_customer_request',
        'respond_to_point_redemption'
      )
      AND (has_function_privilege('anon', p.oid, 'EXECUTE')
           OR has_function_privilege('public', p.oid, 'EXECUTE'))
  ) THEN
    RAISE EXCEPTION 'A private request/redemption RPC remains executable by anon/PUBLIC';
  END IF;
END;
$$;
