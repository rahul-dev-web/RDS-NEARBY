-- Phase 15: atomic, merchant-funded Local Points redemption.
-- Reward values and limits are validated on the server; clients cannot mutate wallets directly.

alter table public.redemptions
  add column if not exists idempotency_key text;

update public.redemptions
set idempotency_key = 'legacy:' || id::text
where idempotency_key is null;

alter table public.redemptions
  alter column idempotency_key set not null;

create unique index if not exists redemptions_customer_idempotency_key_uidx
  on public.redemptions (customer_id, idempotency_key);

create index if not exists redemptions_pending_business_created_idx
  on public.redemptions (business_id, created_at desc)
  where status = 'pending'::public.record_status;

revoke insert, update, delete on public.customer_wallets from anon, authenticated;
revoke insert, update, delete on public.customer_points_ledger from anon, authenticated;
revoke insert, update, delete on public.redemptions from anon, authenticated;

create or replace function public.redeem_customer_points(
  p_business_id uuid,
  p_bill_amount numeric,
  p_points_to_redeem integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_customer_id uuid := auth.uid();
  v_role public.user_role;
  v_business record;
  v_wallet_balance integer;
  v_existing public.redemptions%rowtype;
  v_discount numeric(12,2);
  v_points_used integer;
  v_redemption_id uuid;
  v_final_amount numeric(12,2);
  v_new_balance integer;
begin
  if v_customer_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if p_business_id is null
     or p_bill_amount is null
     or p_bill_amount <= 0
     or p_bill_amount > 100000000
     or p_points_to_redeem is null
     or p_points_to_redeem <= 0
     or p_idempotency_key is null
     or length(trim(p_idempotency_key)) < 8
     or length(p_idempotency_key) > 128 then
    raise exception 'Invalid redemption input' using errcode = '22023';
  end if;

  select pr.role into v_role
  from public.profiles pr
  where pr.id = v_customer_id
    and pr.status = 'active'::public.record_status
  for share;

  if not found or v_role <> 'customer'::public.user_role then
    raise exception 'An active customer profile is required' using errcode = '42501';
  end if;

  select b.id, b.name, b.owner_id, b.status, b.verification_status,
         b.local_rewards_enabled, b.rewards_min_bill, b.rewards_max_discount
  into v_business
  from public.businesses b
  where b.id = p_business_id
  for share;

  if not found
     or v_business.status <> 'active'::public.record_status
     or v_business.verification_status <> 'verified'::public.verification_status then
    raise exception 'This business is not eligible for Local Points redemption' using errcode = '22023';
  end if;

  if v_business.owner_id = v_customer_id then
    raise exception 'You cannot redeem points at your own business' using errcode = '22023';
  end if;

  if v_business.local_rewards_enabled is not true
     or v_business.rewards_min_bill is null
     or v_business.rewards_max_discount is null
     or v_business.rewards_min_bill <= 0
     or v_business.rewards_max_discount <= 0 then
    raise exception 'This business has not configured Local Rewards' using errcode = '22023';
  end if;

  if p_bill_amount < v_business.rewards_min_bill then
    raise exception 'Bill amount is below this business minimum bill' using errcode = '22023';
  end if;

  insert into public.customer_wallets (customer_id, balance)
  values (v_customer_id, 0)
  on conflict (customer_id) do nothing;

  select w.balance into v_wallet_balance
  from public.customer_wallets w
  where w.customer_id = v_customer_id
  for update;

  select r.* into v_existing
  from public.redemptions r
  where r.customer_id = v_customer_id
    and r.idempotency_key = p_idempotency_key;

  if found then
    return jsonb_build_object(
      'redemption_id', v_existing.id,
      'points_used', v_existing.points_used,
      'discount_value', v_existing.discount_value,
      'bill_amount', v_existing.bill_amount,
      'final_amount', v_existing.final_amount,
      'balance_after', v_wallet_balance,
      'replayed', true
    );
  end if;

  if v_wallet_balance < p_points_to_redeem then
    raise exception 'Insufficient Local Points balance' using errcode = '22023';
  end if;

  v_discount := least(
    round(p_points_to_redeem::numeric / 10, 2),
    v_business.rewards_max_discount,
    p_bill_amount
  );
  v_points_used := ceil(v_discount * 10)::integer;
  v_discount := round(v_points_used::numeric / 10, 2);
  v_final_amount := round(greatest(p_bill_amount - v_discount, 0), 2);

  if v_points_used <= 0 or v_points_used > v_wallet_balance then
    raise exception 'Insufficient Local Points balance' using errcode = '22023';
  end if;

  insert into public.redemptions (
    customer_id, business_id, points_used, discount_value,
    bill_amount, final_amount, status, idempotency_key
  ) values (
    v_customer_id, p_business_id, v_points_used, v_discount,
    round(p_bill_amount, 2), v_final_amount, 'pending'::public.record_status,
    p_idempotency_key
  )
  returning id into v_redemption_id;

  update public.customer_wallets
  set balance = balance - v_points_used,
      updated_at = now()
  where customer_id = v_customer_id
  returning balance into v_new_balance;

  insert into public.customer_points_ledger (
    customer_id, amount, transaction_type, reference_id, balance_after, idempotency_key
  ) values (
    v_customer_id, -v_points_used, 'point_redemption'::public.point_transaction_type,
    v_redemption_id, v_new_balance,
    'redemption:' || v_customer_id::text || ':' || p_idempotency_key
  );

  insert into public.audit_logs (
    actor_id, action, entity_type, entity_id, metadata
  ) values (
    v_customer_id,
    'customer_points_redeemed',
    'redemption',
    v_redemption_id,
    jsonb_build_object(
      'business_id', p_business_id,
      'points_used', v_points_used,
      'discount_value', v_discount,
      'bill_amount', round(p_bill_amount, 2),
      'final_amount', v_final_amount
    )
  );

  return jsonb_build_object(
    'redemption_id', v_redemption_id,
    'points_used', v_points_used,
    'discount_value', v_discount,
    'bill_amount', round(p_bill_amount, 2),
    'final_amount', v_final_amount,
    'balance_after', v_new_balance,
    'replayed', false
  );
end;
$function$;

revoke all on function public.redeem_customer_points(uuid, numeric, integer, text) from public, anon;
grant execute on function public.redeem_customer_points(uuid, numeric, integer, text) to authenticated;
