-- Phase 15 follow-up: merchant confirmation/rejection of pending Local Points redemptions.

create or replace function public.respond_to_point_redemption(
  p_redemption_id uuid,
  p_action text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_redemption public.redemptions%rowtype;
  v_owner_id uuid;
  v_balance integer;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if p_redemption_id is null or p_action not in ('approve', 'reject') then
    raise exception 'Invalid redemption response' using errcode = '22023';
  end if;

  select r.* into v_redemption
  from public.redemptions r
  where r.id = p_redemption_id
  for update;

  if not found then
    raise exception 'Redemption not found' using errcode = 'P0002';
  end if;

  select b.owner_id into v_owner_id
  from public.businesses b
  where b.id = v_redemption.business_id;

  if v_owner_id is distinct from v_actor then
    raise exception 'Only the business owner can respond to this redemption' using errcode = '42501';
  end if;

  if v_redemption.status <> 'pending'::public.record_status then
    return jsonb_build_object(
      'redemption_id', v_redemption.id,
      'status', v_redemption.status,
      'replayed', true
    );
  end if;

  if p_action = 'approve' then
    update public.redemptions
    set status = 'active'::public.record_status
    where id = v_redemption.id;

    insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
    values (
      v_actor, 'point_redemption_approved', 'redemption', v_redemption.id,
      jsonb_build_object('business_id', v_redemption.business_id, 'points_used', v_redemption.points_used)
    );

    return jsonb_build_object(
      'redemption_id', v_redemption.id,
      'status', 'active',
      'replayed', false
    );
  end if;

  insert into public.customer_wallets (customer_id, balance)
  values (v_redemption.customer_id, 0)
  on conflict (customer_id) do nothing;

  select w.balance into v_balance
  from public.customer_wallets w
  where w.customer_id = v_redemption.customer_id
  for update;

  update public.customer_wallets
  set balance = balance + v_redemption.points_used,
      updated_at = now()
  where customer_id = v_redemption.customer_id
  returning balance into v_balance;

  insert into public.customer_points_ledger (
    customer_id, amount, transaction_type, reference_id, balance_after, idempotency_key
  ) values (
    v_redemption.customer_id,
    v_redemption.points_used,
    'reversal'::public.point_transaction_type,
    v_redemption.id,
    v_balance,
    'redemption-reversal:' || v_redemption.id::text
  );

  update public.redemptions
  set status = 'inactive'::public.record_status
  where id = v_redemption.id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values (
    v_actor, 'point_redemption_rejected_refunded', 'redemption', v_redemption.id,
    jsonb_build_object(
      'business_id', v_redemption.business_id,
      'customer_id', v_redemption.customer_id,
      'points_refunded', v_redemption.points_used
    )
  );

  return jsonb_build_object(
    'redemption_id', v_redemption.id,
    'status', 'inactive',
    'points_refunded', v_redemption.points_used,
    'customer_balance_after', v_balance,
    'replayed', false
  );
end;
$function$;

revoke all on function public.respond_to_point_redemption(uuid, text) from public, anon;
grant execute on function public.respond_to_point_redemption(uuid, text) to authenticated;
