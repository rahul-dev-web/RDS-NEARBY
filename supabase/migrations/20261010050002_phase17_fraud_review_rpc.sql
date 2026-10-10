-- Phase 17: trusted, atomic fraud-review decisions.
-- Client roles cannot access fraud_flags or execute this RPC directly. The Edge
-- Function authenticates the caller, verifies an active admin profile, then calls
-- this service-role-only function. This function repeats the profile check and
-- writes the review decision + audit event in one transaction.

CREATE OR REPLACE FUNCTION public.review_fraud_flag(
  p_flag_id uuid,
  p_admin_id uuid,
  p_decision text,
  p_review_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_flag public.fraud_flags%rowtype;
  v_reason text := btrim(coalesce(p_review_reason, ''));
  v_next_status public.fraud_status;
BEGIN
  IF p_flag_id IS NULL OR p_admin_id IS NULL THEN
    RAISE EXCEPTION 'Fraud flag and reviewer are required' USING errcode = '22023';
  END IF;

  IF p_decision IS NULL OR p_decision NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Decision must be approve or reject' USING errcode = '22023';
  END IF;

  IF char_length(v_reason) < 8 OR char_length(v_reason) > 500 THEN
    RAISE EXCEPTION 'Review reason must contain 8–500 characters' USING errcode = '22023';
  END IF;

  PERFORM 1
  FROM public.profiles p
  WHERE p.id = p_admin_id
    AND p.role = 'admin'::public.user_role
    AND p.status = 'active'::public.record_status
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'An active admin profile is required' USING errcode = '42501';
  END IF;

  SELECT f.* INTO v_flag
  FROM public.fraud_flags f
  WHERE f.id = p_flag_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Fraud flag not found' USING errcode = 'P0002';
  END IF;

  v_next_status := CASE
    WHEN p_decision = 'approve' THEN 'approved'::public.fraud_status
    ELSE 'rejected'::public.fraud_status
  END;

  -- Safe retry: identical terminal decision is idempotent and creates no second audit event.
  IF v_flag.status IN ('approved'::public.fraud_status, 'rejected'::public.fraud_status) THEN
    IF v_flag.status = v_next_status AND v_flag.reviewed_by = p_admin_id THEN
      RETURN jsonb_build_object(
        'flag_id', v_flag.id,
        'status', v_flag.status,
        'reviewed_at', v_flag.reviewed_at,
        'replayed', true
      );
    END IF;

    RAISE EXCEPTION 'Fraud flag has already received a final decision' USING errcode = '55000';
  END IF;

  IF v_flag.status NOT IN ('open'::public.fraud_status, 'reviewing'::public.fraud_status) THEN
    RAISE EXCEPTION 'Fraud flag is not reviewable from its current state' USING errcode = '55000';
  END IF;

  UPDATE public.fraud_flags
  SET status = v_next_status,
      reviewed_at = now(),
      reviewed_by = p_admin_id,
      metadata = metadata || jsonb_build_object(
        'review_decision', p_decision,
        'review_reason', v_reason
      )
  WHERE id = p_flag_id
  RETURNING * INTO v_flag;

  INSERT INTO public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  VALUES (
    p_admin_id,
    CASE WHEN p_decision = 'approve' THEN 'fraud_flag_approved' ELSE 'fraud_flag_rejected' END,
    'fraud_flag',
    v_flag.id,
    jsonb_build_object(
      'previous_status', 'open_or_reviewing',
      'status', v_flag.status,
      'risk_type', v_flag.risk_type,
      'severity', v_flag.severity,
      'review_reason', v_reason
    )
  );

  RETURN jsonb_build_object(
    'flag_id', v_flag.id,
    'status', v_flag.status,
    'reviewed_at', v_flag.reviewed_at,
    'replayed', false
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.review_fraud_flag(uuid, uuid, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.review_fraud_flag(uuid, uuid, text, text) TO service_role;

COMMENT ON FUNCTION public.review_fraud_flag(uuid, uuid, text, text) IS
  'Service-role-only fraud review mutation. Call only after a trusted backend verifies the caller is an active admin. Decision and audit log are atomic.';
