-- Phase 17 catalog-level regression checks. Run against a migrated test database.
DO $$
DECLARE
  v_missing text;
  v_definition text;
BEGIN
  SELECT string_agg(p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')', ', ')
    INTO v_missing
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.prosecdef
    AND NOT coalesce(p.proconfig @> ARRAY['search_path=""'], false);

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'SECURITY DEFINER functions missing empty search_path: %', v_missing;
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
      AND (
        has_function_privilege('anon', p.oid, 'EXECUTE')
        OR EXISTS (
          SELECT 1
          FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
          WHERE acl.grantee = 0
            AND acl.privilege_type = 'EXECUTE'
        )
      )
  ) THEN
    RAISE EXCEPTION 'A private request/redemption RPC remains executable by anon/PUBLIC';
  END IF;

  -- Service-only RPCs and trigger/scheduler helpers must not be executable by clients.
  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'cancel_customer_request_reminders',
        'claim_due_customer_request_notifications',
        'consume_merchant_credits',
        'create_boost_shop_campaign',
        'create_promote_offer_campaign',
        'expire_stale_customer_requests',
        'finish_customer_request_notification'
      )
      AND (
        has_function_privilege('anon', p.oid, 'EXECUTE')
        OR has_function_privilege('authenticated', p.oid, 'EXECUTE')
        OR EXISTS (
          SELECT 1 FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
          WHERE acl.grantee = 0 AND acl.privilege_type = 'EXECUTE'
        )
      )
  ) THEN
    RAISE EXCEPTION 'A service-only SECURITY DEFINER helper is executable by client roles';
  END IF;

  SELECT pg_get_functiondef(p.oid) INTO v_definition
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'create_customer_request';
  IF v_definition IS NULL
     OR position('An active customer profile is required' IN v_definition) = 0
     OR position('pr.status = ''active''::public.record_status' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'create_customer_request lacks active customer role/status guard';
  END IF;

  SELECT pg_get_functiondef(p.oid) INTO v_definition
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'cancel_customer_request';
  IF v_definition IS NULL
     OR position('An active customer profile is required' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'cancel_customer_request lacks active customer role/status guard';
  END IF;

  SELECT pg_get_functiondef(p.oid) INTO v_definition
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'respond_customer_request';
  IF v_definition IS NULL
     OR position('An active merchant profile is required' IN v_definition) = 0
     OR position('p_decision IS NULL' IN v_definition) = 0
     OR position('p_price::text IN (''NaN'', ''Infinity'', ''-Infinity'')' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'respond_customer_request lacks role or input validation';
  END IF;

  SELECT pg_get_functiondef(p.oid) INTO v_definition
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'respond_to_point_redemption';
  IF v_definition IS NULL
     OR position('An active merchant profile is required' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'respond_to_point_redemption lacks active merchant role/status guard';
  END IF;

  SELECT pg_get_functiondef(p.oid) INTO v_definition
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'redeem_customer_points';
  IF v_definition IS NULL
     OR position('An active customer profile is required' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'redeem_customer_points lacks active customer role/status guard';
  END IF;
END;
$$;
