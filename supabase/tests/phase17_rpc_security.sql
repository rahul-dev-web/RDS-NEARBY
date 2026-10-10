-- Phase 17 catalog-level regression checks. Run against a migrated test database.
-- These checks are read-only and may also be run against the linked project's live catalog.
DO $$
DECLARE
  v_missing text;
  v_definition text;
  v_privilege text;
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
        'finish_customer_request_notification',
        'review_fraud_flag'
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

  -- Fraud review metadata is intentionally not a client-facing API.
  IF NOT (
    SELECT c.relrowsecurity
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'fraud_flags'
  ) THEN
    RAISE EXCEPTION 'fraud_flags must have RLS enabled';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'fraud_flags'
  ) THEN
    RAISE EXCEPTION 'fraud_flags must not have client-facing RLS policies';
  END IF;

  FOREACH v_privilege IN ARRAY ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'] LOOP
    IF has_table_privilege('anon', 'public.fraud_flags', v_privilege)
       OR has_table_privilege('authenticated', 'public.fraud_flags', v_privilege) THEN
      RAISE EXCEPTION 'Client role has unexpected % privilege on fraud_flags', v_privilege;
    END IF;
  END LOOP;

  SELECT pg_get_functiondef(p.oid) INTO v_definition
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'create_customer_request';
  IF v_definition IS NULL
     OR position('An active customer profile is required' IN v_definition) = 0
     OR position('pr.status = ''active''::public.record_status' IN v_definition) = 0
     OR position('v_owner_id = v_customer_id' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'create_customer_request lacks active customer or self-business guard';
  END IF;

  SELECT pg_get_functiondef(p.oid) INTO v_definition
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'cancel_customer_request';
  IF v_definition IS NULL
     OR position('An active customer profile is required' IN v_definition) = 0
     OR position('customer_id = v_customer_id' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'cancel_customer_request lacks active customer or ownership guard';
  END IF;

  SELECT pg_get_functiondef(p.oid) INTO v_definition
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'respond_customer_request';
  IF v_definition IS NULL
     OR position('An active merchant profile is required' IN v_definition) = 0
     OR position('p_decision IS NULL' IN v_definition) = 0
     OR position('p_price::text IN (''NaN'', ''Infinity'', ''-Infinity'')' IN v_definition) = 0
     OR position('owner_id = v_actor_id' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'respond_customer_request lacks role, ownership, or input validation';
  END IF;

  SELECT pg_get_functiondef(p.oid) INTO v_definition
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'respond_to_point_redemption';
  IF v_definition IS NULL
     OR position('An active merchant profile is required' IN v_definition) = 0
     OR position('v_owner_id IS DISTINCT FROM v_actor' IN v_definition) = 0
     OR position('redemption-reversal:' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'respond_to_point_redemption lacks role, ownership, or idempotent refund guard';
  END IF;

  SELECT pg_get_functiondef(p.oid) INTO v_definition
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'redeem_customer_points';
  IF v_definition IS NULL
     OR position('An active customer profile is required' IN v_definition) = 0
     OR position('v_business.owner_id = v_customer_id' IN v_definition) = 0
     OR position('v_existing' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'redeem_customer_points lacks role, self-redemption, or idempotency guard';
  END IF;

  -- Fraud review is a service-only RPC with an in-function admin check and atomic audit.
  SELECT pg_get_functiondef(p.oid) INTO v_definition
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'review_fraud_flag';
  IF v_definition IS NULL
     OR position('p.role = ''admin''::public.user_role' IN v_definition) = 0
     OR position('p.status = ''active''::public.record_status' IN v_definition) = 0
     OR position('FOR UPDATE' IN v_definition) = 0
     OR position('public.audit_logs' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'review_fraud_flag lacks active-admin, row-lock, or audit safeguards';
  END IF;

  IF NOT has_function_privilege('service_role', 'public.review_fraud_flag(uuid,uuid,text,text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.review_fraud_flag(uuid,uuid,text,text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.review_fraud_flag(uuid,uuid,text,text)', 'EXECUTE')
     OR EXISTS (
       SELECT 1
       FROM aclexplode(coalesce(
         (SELECT p.proacl FROM pg_proc p
          WHERE p.oid = 'public.review_fraud_flag(uuid,uuid,text,text)'::regprocedure),
         acldefault('f', (SELECT p.proowner FROM pg_proc p
          WHERE p.oid = 'public.review_fraud_flag(uuid,uuid,text,text)'::regprocedure))
       )) acl
       WHERE acl.grantee = 0 AND acl.privilege_type = 'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'review_fraud_flag must be executable only by service_role';
  END IF;

  -- RLS does not stop a row owner from changing trusted columns unless column
  -- privileges also restrict the writable field set.
  IF has_table_privilege('authenticated', 'public.profiles', 'UPDATE')
     OR has_column_privilege('authenticated', 'public.profiles', 'role', 'UPDATE')
     OR has_column_privilege('authenticated', 'public.profiles', 'status', 'UPDATE')
     OR has_column_privilege('authenticated', 'public.businesses', 'owner_id', 'UPDATE')
     OR has_column_privilege('authenticated', 'public.businesses', 'status', 'UPDATE')
     OR has_column_privilege('authenticated', 'public.businesses', 'verification_status', 'UPDATE')
     OR has_column_privilege('authenticated', 'public.businesses', 'is_open', 'UPDATE')
     OR has_column_privilege('authenticated', 'public.businesses', 'updated_at', 'UPDATE') THEN
    RAISE EXCEPTION 'Authenticated users can update protected profile/business columns';
  END IF;

  IF has_table_privilege('authenticated', 'public.businesses', 'UPDATE')
     OR NOT has_column_privilege('authenticated', 'public.profiles', 'name', 'UPDATE')
     OR NOT has_column_privilege('authenticated', 'public.profiles', 'avatar_url', 'UPDATE')
     OR NOT has_column_privilege('authenticated', 'public.businesses', 'name', 'UPDATE')
     OR NOT has_column_privilege('authenticated', 'public.businesses', 'accepting_requests', 'UPDATE')
     OR NOT has_column_privilege('authenticated', 'public.businesses', 'local_rewards_enabled', 'UPDATE') THEN
    RAISE EXCEPTION 'Column-limited profile/business update grants are missing or too broad';
  END IF;

  -- Idempotency constraints are the last line of defense against concurrent retries.
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'customer_points_ledger_idempotency_key_key'
      AND indexdef ILIKE 'CREATE UNIQUE INDEX%'
  ) THEN
    RAISE EXCEPTION 'Customer points ledger must enforce unique idempotency keys';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'redemptions_customer_idempotency_key_uidx'
      AND indexdef ILIKE 'CREATE UNIQUE INDEX%'
  ) THEN
    RAISE EXCEPTION 'Redemptions must enforce per-customer idempotency keys';
  END IF;
END;
$$;
