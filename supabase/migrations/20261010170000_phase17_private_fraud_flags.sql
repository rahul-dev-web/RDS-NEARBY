-- Phase 17: keep internal fraud-review records private from customer/merchant clients.
-- Fraud flags are operational risk signals; they are not a customer-facing feature.
-- Access remains available to trusted server-side workflows using service_role/postgres.
drop policy if exists fraud_own_read on public.fraud_flags;

-- Do not allow client roles to read or mutate fraud flags directly.
revoke all on table public.fraud_flags from anon, authenticated;

-- Re-assert RLS as a defence-in-depth guard for this operational table.
alter table public.fraud_flags enable row level security;

comment on table public.fraud_flags is
  'Private operational fraud-review records. Access only through trusted server-side/admin workflows; never expose raw flags to customer or merchant clients.';
