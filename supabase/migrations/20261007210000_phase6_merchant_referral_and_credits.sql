-- Phase 6: merchant referral + merchant credit foundation
-- Additive migration. Reward decisions remain server-owned.

create table if not exists public.referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_type text not null check (referrer_type in ('merchant','customer')),
  referrer_user_id uuid references public.profiles(id) on delete set null,
  referrer_business_id uuid references public.businesses(id) on delete set null,
  referred_user_id uuid references public.profiles(id) on delete cascade,
  referral_token text,
  status text not null default 'PENDING'
    check (status in ('PENDING','QUALIFIED','REJECTED','EXPIRED')),
  created_at timestamptz not null default now(),
  qualified_at timestamptz,
  expires_at timestamptz not null default (now() + interval '48 hours')
);

create unique index if not exists referrals_one_attribution_per_user
  on public.referrals(referred_user_id)
  where referred_user_id is not null;

create index if not exists referrals_pending_expiry_idx
  on public.referrals(status, expires_at);

create table if not exists public.referral_events (
  id uuid primary key default gen_random_uuid(),
  referral_id uuid not null references public.referrals(id) on delete cascade,
  event_type text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists referral_events_referral_created_idx
  on public.referral_events(referral_id, created_at desc);

create table if not exists public.merchant_wallets (
  merchant_id uuid primary key references public.businesses(id) on delete cascade,
  balance integer not null default 0 check (balance >= 0 and balance <= 2000),
  updated_at timestamptz not null default now()
);

create table if not exists public.merchant_credit_ledger (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references public.businesses(id) on delete cascade,
  amount integer not null,
  transaction_type text not null check (
    transaction_type in (
      'REFERRAL_REWARD','BOOST_SPEND','PROMOTE_OFFER_SPEND',
      'ADMIN_ADJUSTMENT','REVERSAL'
    )
  ),
  reference_id uuid,
  balance_after integer not null check (balance_after >= 0 and balance_after <= 2000),
  idempotency_key text not null unique,
  created_at timestamptz not null default now()
);

create index if not exists merchant_credit_ledger_merchant_created_idx
  on public.merchant_credit_ledger(merchant_id, created_at desc);

alter table public.referrals enable row level security;
alter table public.referral_events enable row level security;
alter table public.merchant_wallets enable row level security;
alter table public.merchant_credit_ledger enable row level security;

grant select on public.referrals to authenticated;
grant select on public.referral_events to authenticated;
grant select on public.merchant_wallets to authenticated;
grant select on public.merchant_credit_ledger to authenticated;

drop policy if exists referrals_owner_read on public.referrals;
create policy referrals_owner_read on public.referrals
for select to authenticated
using (
  referred_user_id = (select auth.uid())
  or referrer_user_id = (select auth.uid())
  or exists (
    select 1 from public.businesses b
    where b.id = referrals.referrer_business_id
      and b.owner_id = (select auth.uid())
  )
);

drop policy if exists referral_events_owner_read on public.referral_events;
create policy referral_events_owner_read on public.referral_events
for select to authenticated
using (
  exists (
    select 1 from public.referrals r
    where r.id = referral_events.referral_id
      and (
        r.referred_user_id = (select auth.uid())
        or r.referrer_user_id = (select auth.uid())
        or exists (
          select 1 from public.businesses b
          where b.id = r.referrer_business_id
            and b.owner_id = (select auth.uid())
        )
      )
  )
);

drop policy if exists merchant_wallet_owner_read on public.merchant_wallets;
create policy merchant_wallet_owner_read on public.merchant_wallets
for select to authenticated
using (
  exists (
    select 1 from public.businesses b
    where b.id = merchant_wallets.merchant_id
      and b.owner_id = (select auth.uid())
  )
);

drop policy if exists merchant_credit_ledger_owner_read on public.merchant_credit_ledger;
create policy merchant_credit_ledger_owner_read on public.merchant_credit_ledger
for select to authenticated
using (
  exists (
    select 1 from public.businesses b
    where b.id = merchant_credit_ledger.merchant_id
      and b.owner_id = (select auth.uid())
  )
);

revoke insert, update, delete on public.referrals from authenticated;
revoke insert, update, delete on public.referral_events from authenticated;
revoke insert, update, delete on public.merchant_wallets from authenticated;
revoke insert, update, delete on public.merchant_credit_ledger from authenticated;

create or replace function public.qualify_referral(p_referral_id uuid, p_idempotency_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.referrals%rowtype;
  wallet public.merchant_wallets%rowtype;
  ledger_id uuid;
  new_balance integer;
begin
  if p_idempotency_key is null or length(trim(p_idempotency_key)) < 8 then
    raise exception 'invalid_idempotency_key';
  end if;

  select * into r
  from public.referrals
  where id = p_referral_id
  for update;

  if not found then
    raise exception 'referral_not_found';
  end if;

  if r.status = 'QUALIFIED' then
    return jsonb_build_object('status','QUALIFIED','rewarded',false);
  end if;

  if r.status <> 'PENDING' then
    return jsonb_build_object('status',r.status,'rewarded',false);
  end if;

  if r.expires_at < now() then
    update public.referrals
      set status = 'EXPIRED'
      where id = r.id;
    insert into public.referral_events(referral_id,event_type)
      values (r.id,'EXPIRED');
    return jsonb_build_object('status','EXPIRED','rewarded',false);
  end if;

  if not exists (
    select 1 from public.referral_events
    where referral_id = r.id
      and event_type = 'MEANINGFUL_ACTIVITY'
  ) then
    return jsonb_build_object('status','PENDING','rewarded',false);
  end if;

  if r.referrer_business_id is null then
    update public.referrals set status='REJECTED' where id=r.id;
    insert into public.referral_events(referral_id,event_type)
      values (r.id,'REJECTED');
    return jsonb_build_object('status','REJECTED','rewarded',false);
  end if;

  insert into public.merchant_wallets(merchant_id,balance)
    values (r.referrer_business_id,0)
    on conflict (merchant_id) do nothing;

  select * into wallet
  from public.merchant_wallets
  where merchant_id = r.referrer_business_id
  for update;

  if wallet.balance > 1990 then
    return jsonb_build_object('status','QUALIFIED','rewarded',false,'reason','balance_cap');
  end if;

  new_balance := least(wallet.balance + 10, 2000);

  insert into public.merchant_credit_ledger(
    merchant_id,amount,transaction_type,reference_id,balance_after,idempotency_key
  )
  values (
    r.referrer_business_id, new_balance - wallet.balance,
    'REFERRAL_REWARD', r.id, new_balance, p_idempotency_key
  )
  on conflict (idempotency_key) do nothing
  returning id into ledger_id;

  if ledger_id is not null then
    update public.merchant_wallets
      set balance = new_balance, updated_at = now()
      where merchant_id = r.referrer_business_id;
  end if;

  update public.referrals
    set status='QUALIFIED', qualified_at=coalesce(qualified_at,now())
    where id=r.id;

  insert into public.referral_events(referral_id,event_type)
    values (r.id,'QUALIFIED');

  return jsonb_build_object(
    'status','QUALIFIED',
    'rewarded',ledger_id is not null,
    'credits_awarded',case when ledger_id is not null then new_balance-wallet.balance else 0 end
  );
end;
$$;

revoke all on function public.qualify_referral(uuid,text) from public;
grant execute on function public.qualify_referral(uuid,text) to service_role;
