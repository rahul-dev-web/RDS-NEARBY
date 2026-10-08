-- Phase 9: Boost Shop campaign
-- Server-owned promotion spend. Client never writes campaigns or credit balances.

create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  campaign_type text not null check (campaign_type in ('BOOST_SHOP','PROMOTE_OFFER')),
  credit_cost integer not null check (credit_cost > 0),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  status text not null default 'ACTIVE'
    check (status in ('DRAFT','ACTIVE','EXPIRED','CANCELLED')),
  target_radius_km numeric(6,2) not null default 5.00
    check (target_radius_km > 0 and target_radius_km <= 50),
  offer_id uuid,
  idempotency_key text not null unique,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at),
  check (
    (campaign_type = 'BOOST_SHOP' and credit_cost = 50 and offer_id is null)
    or
    (campaign_type = 'PROMOTE_OFFER' and credit_cost = 100 and offer_id is not null)
  )
);

create index if not exists campaigns_business_status_idx
  on public.campaigns(business_id, status, ends_at desc);

create index if not exists campaigns_active_window_idx
  on public.campaigns(status, starts_at, ends_at);

alter table public.campaigns enable row level security;

grant select on public.campaigns to anon, authenticated;

drop policy if exists campaigns_public_active_read on public.campaigns;
create policy campaigns_public_active_read
on public.campaigns
for select
to anon, authenticated
using (
  status = 'ACTIVE'
  and starts_at <= now()
  and ends_at > now()
  and exists (
    select 1
    from public.businesses b
    where b.id = campaigns.business_id
      and b.status = 'active'
      and b.verification_status = 'verified'
  )
);

drop policy if exists campaigns_owner_read on public.campaigns;
create policy campaigns_owner_read
on public.campaigns
for select
to authenticated
using (
  exists (
    select 1
    from public.businesses b
    where b.id = campaigns.business_id
      and b.owner_id = (select auth.uid())
  )
);

revoke insert, update, delete on public.campaigns from anon, authenticated;

-- Atomic merchant-credit consumption primitive.
create or replace function public.consume_merchant_credits(
  p_merchant_id uuid,
  p_amount integer,
  p_transaction_type text,
  p_reference_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  wallet public.merchant_wallets%rowtype;
  ledger_id uuid;
  new_balance integer;
begin
  if p_merchant_id is null
     or p_amount <= 0
     or p_transaction_type not in ('BOOST_SPEND','PROMOTE_OFFER_SPEND')
     or p_idempotency_key is null
     or length(trim(p_idempotency_key)) < 8 then
    raise exception 'invalid_credit_consumption_request';
  end if;

  select * into wallet
  from public.merchant_wallets
  where merchant_id = p_merchant_id
  for update;

  if not found then
    insert into public.merchant_wallets(merchant_id,balance)
    values (p_merchant_id,0)
    on conflict (merchant_id) do nothing;

    select * into wallet
    from public.merchant_wallets
    where merchant_id = p_merchant_id
    for update;
  end if;

  if wallet.balance < p_amount then
    raise exception 'insufficient_marketing_credits';
  end if;

  new_balance := wallet.balance - p_amount;

  insert into public.merchant_credit_ledger(
    merchant_id,
    amount,
    transaction_type,
    reference_id,
    balance_after,
    idempotency_key
  )
  values (
    p_merchant_id,
    -p_amount,
    p_transaction_type,
    p_reference_id,
    new_balance,
    p_idempotency_key
  )
  on conflict (idempotency_key) do nothing
  returning id into ledger_id;

  if ledger_id is null then
    return jsonb_build_object(
      'deducted', false,
      'balance', wallet.balance,
      'reason', 'idempotent_replay'
    );
  end if;

  update public.merchant_wallets
  set balance = new_balance, updated_at = now()
  where merchant_id = p_merchant_id;

  return jsonb_build_object(
    'deducted', true,
    'balance', new_balance,
    'ledger_id', ledger_id
  );
end;
$$;

revoke all on function public.consume_merchant_credits(uuid,integer,text,uuid,text) from public;
grant execute on function public.consume_merchant_credits(uuid,integer,text,uuid,text) to service_role;

-- Boost Shop campaign creation. The Edge Function performs caller authentication/ownership checks.
create or replace function public.create_boost_shop_campaign(
  p_merchant_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  business_row public.businesses%rowtype;
  existing_campaign public.campaigns%rowtype;
  campaign_row public.campaigns%rowtype;
  spend_result jsonb;
begin
  if p_merchant_id is null
     or p_idempotency_key is null
     or length(trim(p_idempotency_key)) < 8 then
    raise exception 'invalid_campaign_request';
  end if;

  select * into business_row
  from public.businesses
  where id = p_merchant_id
  for update;

  if not found then
    raise exception 'business_not_found';
  end if;

  if business_row.status <> 'active'
     or business_row.verification_status <> 'verified' then
    raise exception 'business_not_eligible';
  end if;

  select * into existing_campaign
  from public.campaigns
  where idempotency_key = p_idempotency_key
  limit 1;

  if found then
    return jsonb_build_object(
      'created', false,
      'reason', 'idempotent_replay',
      'campaign', to_jsonb(existing_campaign)
    );
  end if;

  update public.campaigns
  set status = 'EXPIRED'
  where business_id = p_merchant_id
    and campaign_type = 'BOOST_SHOP'
    and status = 'ACTIVE'
    and ends_at <= now();

  select * into existing_campaign
  from public.campaigns
  where business_id = p_merchant_id
    and campaign_type = 'BOOST_SHOP'
    and status = 'ACTIVE'
    and starts_at <= now()
    and ends_at > now()
  order by ends_at desc
  limit 1;

  if found then
    return jsonb_build_object(
      'created', false,
      'reason', 'active_campaign_exists',
      'campaign', to_jsonb(existing_campaign)
    );
  end if;

  insert into public.campaigns(
    business_id,
    campaign_type,
    credit_cost,
    starts_at,
    ends_at,
    status,
    target_radius_km,
    idempotency_key
  )
  values (
    p_merchant_id,
    'BOOST_SHOP',
    50,
    now(),
    now() + interval '24 hours',
    'ACTIVE',
    5.00,
    p_idempotency_key
  )
  returning * into campaign_row;

  spend_result := public.consume_merchant_credits(
    p_merchant_id,
    50,
    'BOOST_SPEND',
    campaign_row.id,
    p_idempotency_key
  );

  if coalesce((spend_result->>'deducted')::boolean, false) = false then
    raise exception 'credit_deduction_failed';
  end if;

  insert into public.audit_logs(
    actor_id,
    action,
    entity_type,
    entity_id,
    metadata
  )
  values (
    business_row.owner_id,
    'boost_shop_created',
    'campaign',
    campaign_row.id,
    jsonb_build_object(
      'business_id', p_merchant_id,
      'credit_cost', 50,
      'duration_hours', 24,
      'target_radius_km', 5.00
    )
  );

  return jsonb_build_object(
    'created', true,
    'campaign', to_jsonb(campaign_row),
    'balance', spend_result->'balance'
  );
end;
$$;

revoke all on function public.create_boost_shop_campaign(uuid,text) from public;
grant execute on function public.create_boost_shop_campaign(uuid,text) to service_role;
