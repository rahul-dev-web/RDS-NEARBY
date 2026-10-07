alter table public.businesses
  add column if not exists logo_url text,
  add column if not exists local_rewards_enabled boolean not null default false,
  add column if not exists rewards_min_bill numeric(12,2),
  add column if not exists rewards_max_discount numeric(12,2);

alter table public.businesses
  drop constraint if exists businesses_rewards_min_bill_check;

alter table public.businesses
  add constraint businesses_rewards_min_bill_check
  check (rewards_min_bill is null or rewards_min_bill >= 0);

alter table public.businesses
  drop constraint if exists businesses_rewards_max_discount_check;

alter table public.businesses
  add constraint businesses_rewards_max_discount_check
  check (rewards_max_discount is null or rewards_max_discount >= 0);

create table if not exists public.merchant_referral_tokens (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  token text not null unique default substr(replace(gen_random_uuid()::text, '-', ''), 1, 16),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index if not exists merchant_referral_tokens_business_id_key
  on public.merchant_referral_tokens(business_id);

alter table public.merchant_referral_tokens enable row level security;

grant select on public.merchant_referral_tokens to authenticated;

drop policy if exists merchant_referral_tokens_owner_read on public.merchant_referral_tokens;
create policy merchant_referral_tokens_owner_read
on public.merchant_referral_tokens
for select to authenticated
using (
  exists (
    select 1
    from public.businesses b
    where b.id = merchant_referral_tokens.business_id
      and b.owner_id = (select auth.uid())
  )
);

revoke insert, update, delete on public.merchant_referral_tokens from authenticated;
revoke all on public.merchant_referral_tokens from anon;
