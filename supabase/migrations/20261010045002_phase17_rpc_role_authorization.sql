-- Phase 17: enforce active profile roles inside privileged customer-request/redemption RPCs.
-- Keep SECURITY DEFINER because these functions perform coordinated multi-table writes;
-- authorization is enforced explicitly here and EXECUTE remains restricted to authenticated.

CREATE OR REPLACE FUNCTION public.cancel_customer_request(p_request_id uuid)
RETURNS public.request_status
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_customer_id uuid := auth.uid();
  v_role public.user_role;
  v_request public.customer_requests%rowtype;
BEGIN
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING errcode = '28000';
  END IF;

  SELECT pr.role INTO v_role
  FROM public.profiles pr
  WHERE pr.id = v_customer_id
    AND pr.status = 'active'::public.record_status
  FOR SHARE;

  IF NOT FOUND OR v_role <> 'customer'::public.user_role THEN
    RAISE EXCEPTION 'An active customer profile is required' USING errcode = '42501';
  END IF;

  SELECT * INTO v_request
  FROM public.customer_requests
  WHERE id = p_request_id AND customer_id = v_customer_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found' USING errcode = 'P0002';
  END IF;
  IF v_request.status <> 'pending'::public.request_status THEN
    RAISE EXCEPTION 'Only pending requests can be cancelled' USING errcode = '55000';
  END IF;

  UPDATE public.customer_requests
  SET status = 'cancelled'::public.request_status
  WHERE id = v_request.id;

  DELETE FROM public.notifications
  WHERE related_entity_type = 'customer_request_reminder'
    AND related_entity_id = v_request.id
    AND status = 'queued'::public.notification_status;

  RETURN 'cancelled'::public.request_status;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_customer_request(
  p_business_id uuid,
  p_request_type public.request_type,
  p_title text,
  p_description text DEFAULT NULL::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_customer_id uuid := auth.uid();
  v_role public.user_role;
  v_owner_id uuid;
  v_business_name text;
  v_request_id uuid;
  v_title text := btrim(coalesce(p_title, ''));
  v_description text := nullif(btrim(coalesce(p_description, '')), '');
BEGIN
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING errcode = '28000';
  END IF;

  SELECT pr.role INTO v_role
  FROM public.profiles pr
  WHERE pr.id = v_customer_id
    AND pr.status = 'active'::public.record_status
  FOR SHARE;

  IF NOT FOUND OR v_role <> 'customer'::public.user_role THEN
    RAISE EXCEPTION 'An active customer profile is required' USING errcode = '42501';
  END IF;

  IF p_business_id IS NULL OR p_request_type IS NULL THEN
    RAISE EXCEPTION 'Business and request type are required' USING errcode = '22023';
  END IF;
  IF v_title = '' OR char_length(v_title) > 120 THEN
    RAISE EXCEPTION 'Title must contain 1–120 characters' USING errcode = '22023';
  END IF;
  IF v_description IS NOT NULL AND char_length(v_description) > 1000 THEN
    RAISE EXCEPTION 'Description must be at most 1000 characters' USING errcode = '22023';
  END IF;

  SELECT b.owner_id, b.name
  INTO v_owner_id, v_business_name
  FROM public.businesses b
  WHERE b.id = p_business_id
    AND b.status = 'active'::public.record_status
    AND b.verification_status = 'verified'::public.verification_status
    AND b.accepting_requests = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'This business is not currently accepting requests' USING errcode = 'P0002';
  END IF;
  IF v_owner_id = v_customer_id THEN
    RAISE EXCEPTION 'You cannot send a customer request to your own business' USING errcode = '42501';
  END IF;

  INSERT INTO public.customer_requests(
    customer_id, business_id, request_type, title, description, status, expires_at
  )
  VALUES (
    v_customer_id, p_business_id, p_request_type, v_title, v_description,
    'pending'::public.request_status, now() + interval '10 minutes'
  )
  RETURNING id INTO v_request_id;

  INSERT INTO public.notifications(
    user_id, title, message, priority, type, related_entity_type, related_entity_id, status, scheduled_at
  )
  VALUES
    (v_owner_id, 'New customer request',
     left(v_title || ' · ' || coalesce(v_description, 'Please respond within 10 minutes.'), 500),
     'high'::public.notification_priority, 'customer_request_created', 'customer_request',
     v_request_id, 'queued'::public.notification_status, now()),
    (v_owner_id, 'Customer request reminder',
     left('A customer request for ' || v_business_name || ' is still awaiting a response.', 500),
     'high'::public.notification_priority, 'customer_request_reminder_3m', 'customer_request_reminder',
     v_request_id, 'queued'::public.notification_status, now() + interval '3 minutes'),
    (v_owner_id, 'Final customer request reminder',
     left('Final reminder: respond to the customer request for ' || v_business_name || '.', 500),
     'high'::public.notification_priority, 'customer_request_reminder_8m', 'customer_request_reminder',
     v_request_id, 'queued'::public.notification_status, now() + interval '8 minutes');

  RETURN v_request_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.respond_customer_request(
  p_request_id uuid,
  p_decision text,
  p_message text DEFAULT NULL::text,
  p_price numeric DEFAULT NULL::numeric
)
RETURNS public.request_status
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor_id uuid := auth.uid();
  v_role public.user_role;
  v_request public.customer_requests%rowtype;
  v_business public.businesses%rowtype;
  v_response_status public.request_status;
  v_message text := nullif(btrim(coalesce(p_message, '')), '');
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING errcode = '28000';
  END IF;

  SELECT pr.role INTO v_role
  FROM public.profiles pr
  WHERE pr.id = v_actor_id
    AND pr.status = 'active'::public.record_status
  FOR SHARE;

  IF NOT FOUND OR v_role <> 'merchant'::public.user_role THEN
    RAISE EXCEPTION 'An active merchant profile is required' USING errcode = '42501';
  END IF;

  IF p_decision IS NULL OR p_decision NOT IN ('accept', 'decline') THEN
    RAISE EXCEPTION 'Decision must be accept or decline' USING errcode = '22023';
  END IF;
  IF p_request_id IS NULL THEN
    RAISE EXCEPTION 'Request is required' USING errcode = '22023';
  END IF;
  IF v_message IS NOT NULL AND char_length(v_message) > 1000 THEN
    RAISE EXCEPTION 'Message must be at most 1000 characters' USING errcode = '22023';
  END IF;
  IF p_price IS NOT NULL AND (
    p_price::text IN ('NaN', 'Infinity', '-Infinity')
    OR p_price < 0
    OR p_price > 100000000
  ) THEN
    RAISE EXCEPTION 'Price must be finite and between 0 and 100000000' USING errcode = '22023';
  END IF;

  SELECT * INTO v_request
  FROM public.customer_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found' USING errcode = 'P0002';
  END IF;

  SELECT * INTO v_business
  FROM public.businesses
  WHERE id = v_request.business_id AND owner_id = v_actor_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'You do not own this request''s business' USING errcode = '42501';
  END IF;
  IF v_request.status <> 'pending'::public.request_status THEN
    RAISE EXCEPTION 'Request is no longer pending' USING errcode = '55000';
  END IF;
  IF v_request.expires_at <= now() THEN
    UPDATE public.customer_requests
    SET status = 'expired'::public.request_status
    WHERE id = v_request.id;

    DELETE FROM public.notifications
    WHERE related_entity_type = 'customer_request_reminder'
      AND related_entity_id = v_request.id
      AND status = 'queued'::public.notification_status;

    RETURN 'expired'::public.request_status;
  END IF;

  v_response_status := CASE
    WHEN p_decision = 'accept' THEN 'accepted'::public.request_status
    ELSE 'declined'::public.request_status
  END;

  INSERT INTO public.request_responses(
    request_id, business_id, response_type, price, message, status
  )
  VALUES (v_request.id, v_request.business_id, p_decision, p_price, v_message, v_response_status);

  UPDATE public.customer_requests
  SET status = v_response_status
  WHERE id = v_request.id;

  INSERT INTO public.notifications(
    user_id, title, message, priority, type, related_entity_type, related_entity_id, status, scheduled_at
  )
  VALUES (
    v_request.customer_id,
    CASE WHEN p_decision = 'accept' THEN 'Your request was accepted' ELSE 'Your request was declined' END,
    left(coalesce(v_message, v_business.name ||
      CASE WHEN p_decision = 'accept' THEN ' accepted your request.' ELSE ' declined your request.' END), 500),
    'high'::public.notification_priority, 'customer_request_response', 'customer_request',
    v_request.id, 'queued'::public.notification_status, now()
  );

  DELETE FROM public.notifications
  WHERE related_entity_type = 'customer_request_reminder'
    AND related_entity_id = v_request.id
    AND status = 'queued'::public.notification_status;

  RETURN v_response_status;
END;
$function$;

CREATE OR REPLACE FUNCTION public.respond_to_point_redemption(
  p_redemption_id uuid,
  p_action text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_role public.user_role;
  v_redemption public.redemptions%rowtype;
  v_owner_id uuid;
  v_balance integer;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING errcode = '28000';
  END IF;

  SELECT pr.role INTO v_role
  FROM public.profiles pr
  WHERE pr.id = v_actor
    AND pr.status = 'active'::public.record_status
  FOR SHARE;

  IF NOT FOUND OR v_role <> 'merchant'::public.user_role THEN
    RAISE EXCEPTION 'An active merchant profile is required' USING errcode = '42501';
  END IF;

  IF p_redemption_id IS NULL OR p_action IS NULL OR p_action NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Invalid redemption response' USING errcode = '22023';
  END IF;

  SELECT r.* INTO v_redemption
  FROM public.redemptions r
  WHERE r.id = p_redemption_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Redemption not found' USING errcode = 'P0002';
  END IF;

  SELECT b.owner_id INTO v_owner_id
  FROM public.businesses b
  WHERE b.id = v_redemption.business_id;

  IF v_owner_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'Only the business owner can respond to this redemption' USING errcode = '42501';
  END IF;

  IF v_redemption.status <> 'pending'::public.record_status THEN
    RETURN jsonb_build_object(
      'redemption_id', v_redemption.id, 'status', v_redemption.status, 'replayed', true
    );
  END IF;

  IF p_action = 'approve' THEN
    UPDATE public.redemptions
    SET status = 'active'::public.record_status
    WHERE id = v_redemption.id;

    INSERT INTO public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
    VALUES (
      v_actor, 'point_redemption_approved', 'redemption', v_redemption.id,
      jsonb_build_object('business_id', v_redemption.business_id, 'points_used', v_redemption.points_used)
    );

    RETURN jsonb_build_object('redemption_id', v_redemption.id, 'status', 'active', 'replayed', false);
  END IF;

  INSERT INTO public.customer_wallets(customer_id, balance)
  VALUES (v_redemption.customer_id, 0)
  ON CONFLICT (customer_id) DO NOTHING;

  SELECT w.balance INTO v_balance
  FROM public.customer_wallets w
  WHERE w.customer_id = v_redemption.customer_id
  FOR UPDATE;

  UPDATE public.customer_wallets
  SET balance = balance + v_redemption.points_used, updated_at = now()
  WHERE customer_id = v_redemption.customer_id
  RETURNING balance INTO v_balance;

  INSERT INTO public.customer_points_ledger(
    customer_id, amount, transaction_type, reference_id, balance_after, idempotency_key
  )
  VALUES (
    v_redemption.customer_id, v_redemption.points_used,
    'reversal'::public.point_transaction_type, v_redemption.id, v_balance,
    'redemption-reversal:' || v_redemption.id::text
  );

  UPDATE public.redemptions
  SET status = 'inactive'::public.record_status
  WHERE id = v_redemption.id;

  INSERT INTO public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  VALUES (
    v_actor, 'point_redemption_rejected_refunded', 'redemption', v_redemption.id,
    jsonb_build_object(
      'business_id', v_redemption.business_id,
      'customer_id', v_redemption.customer_id,
      'points_refunded', v_redemption.points_used
    )
  );

  RETURN jsonb_build_object(
    'redemption_id', v_redemption.id, 'status', 'inactive',
    'points_refunded', v_redemption.points_used, 'customer_balance_after', v_balance, 'replayed', false
  );
END;
$function$;
