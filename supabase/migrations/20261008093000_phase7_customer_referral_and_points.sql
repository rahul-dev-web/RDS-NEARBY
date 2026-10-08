-- Phase 7: customer referral + Local Points foundation
-- Additive migration. Customer rewards remain server-owned.

create table if not exists public.customer_referral_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  token text not null unique default substr(replace(gen_random_uuid()::text, '-', ''), 1, 16),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.customer_wallets (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  balance integer not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_points_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  amount integer not null,
  transaction_type text not null check (
    transaction_type in (
      'REFERRAL_REWARD','PURCHASE_REWARD','POINT_REDEMPTION',
      'REVERSAL','ADMIN_ADJUSTMENT'
    )
  ),
  reference_id uuid,
  balance_after integer not null check (balance_after >= 0),
  idempotency_key text not null unique,
  created_at timestamptz not null default now()
);

create index if not exists customer_points_ledger_user_created_idx
  on public.customer_points_ledger(user_id, created_at desc);

alter table public.customer_referral_tokens enable row level security;
alter table public.customer_wallets enable row level security;
alter table public.customer_points_ledger enable row level security;

grant select on public.customer_referral_tokens to authenticated;
grant select on public.customer_wallets to authenticated;
grant select on public.customer_points_ledger to authenticated;

drop policy if exists customer_referral_tokens_owner_read on public.customer_referral_tokens;
create policy customer_referral_tokens_owner_read
on public.customer_referral_tokens
for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists customer_wallet_owner_read on public.customer_wallets;
create policy customer_wallet_owner_read
on public.customer_wallets
for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists customer_points_ledger_owner_read on public.customer_points_ledger;
create policy customer_points_ledger_owner_read
on public.customer_points_ledger
for select to authenticated
using (user_id = (select auth.uid()));

revoke insert, update, delete on public.customer_referral_tokens from authenticated;
revoke insert, update, delete on public.customer_wallets from authenticated;
revoke insert, update, delete on public.customer_points_ledger from authenticated;

-- Extend the existing server-owned qualification operation to customer referrals.
create or replace function public.qualify_referral(p_referral_id uuid, p_idempotency_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.referrals%rowtype;
  merchant_wallet public.merchant_wallets%rowtype;
  customer_wallet public.customer_wallets%rowtype;
  ledger_id uuid;
  new_balance integer;
  reward_amount integer := 10;
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

  if r.referrer_type = 'merchant' then
    if r.referrer_business_id is null then
      update public.referrals set status='REJECTED' where id=r.id;
      insert into public.referral_events(referral_id,event_type)
        values (r.id,'REJECTED');
      return jsonb_build_object('status','REJECTED','rewarded',false);
    end if;

    insert into public.merchant_wallets(merchant_id,balance)
      values (r.referrer_business_id,0)
      on conflict (merchant_id) do nothing;

    select * into merchant_wallet
    from public.merchant_wallets
    where merchant_id = r.referrer_business_id
    for update;

    if merchant_wallet.balance > 1990 then
      return jsonb_build_object(
        'status','PENDING',
        'rewarded',false,
        'reason','balance_cap'
      );
    end if;

    new_balance := merchant_wallet.balance + reward_amount;

    insert into public.merchant_credit_ledger(
      merchant_id,amount,transaction_type,reference_id,balance_after,idempotency_key
    )
    values (
      r.referrer_business_id,reward_amount,
      'REFERRAL_REWARD',r.id,new_balance,p_idempotency_key
    )
    on conflict (idempotency_key) do nothing
    returning id into ledger_id;

    if ledger_id is not null then
      update public.merchant_wallets
        set balance = new_balance, updated_at = now()
        where merchant_id = r.referrer_business_id;
    end if;

  elsif r.referrer_type = 'customer' then
    if r.referrer_user_id is null then
      update public.referrals set status='REJECTED' where id=r.id;
      insert into public.referral_events(referral_id,event_type)
        values (r.id,'REJECTED');
      return jsonb_build_object('status','REJECTED','rewarded',false);
    end if;

    insert into public.customer_wallets(user_id,balance)
      values (r.referrer_user_id,0)
      on conflict (user_id) do nothing;

    select * into customer_wallet
    from public.customer_wallets
    where user_id = r.referrer_user_id
    for update;

    new_balance := customer_wallet.balance + reward_amount;

    insert into public.customer_points_ledger(
      user_id,amount,transaction_type,reference_id,balance_after,idempotency_key
    )
    values (
      r.referrer_user_id,reward_amount,
      'REFERRAL_REWARD',r.id,new_balance,p_idempotency_key
    )
    on conflict (idempotency_key) do nothing
    returning id into ledger_id;

    if ledger_id is not null then
      update public.customer_wallets
        set balance = new_balance, updated_at = now()
        where user_id = r.referrer_user_id;
    end if;

  else
    update public.referrals set status='REJECTED' where id=r.id;
    insert into public.referral_events(referral_id,event_type)
      values (r.id,'REJECTED');
    return jsonb_build_object('status','REJECTED','rewarded',false);
  end if;

  if ledger_id is not null then
    update public.referrals
      set status='QUALIFIED', qualified_at=coalesce(qualified_at,now())
      where id=r.id;

    insert into public.referral_events(referral_id,event_type)
      values (r.id,'QUALIFIED');

    return jsonb_build_object(
      'status','QUALIFIED',
      'rewarded',true,
      'reward_amount',reward_amount
    );
  end if;

  return jsonb_build_object('status','QUALIFIED','rewarded',false);
end;
$$;

revoke all on function public.qualify_referral(uuid,text) from public;
grant execute on function public.qualify_referral(uuid,text) to service_role;
