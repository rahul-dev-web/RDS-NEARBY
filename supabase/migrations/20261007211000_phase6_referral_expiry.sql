-- Phase 6 follow-up: deterministic referral expiry

create or replace function public.expire_pending_referrals()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  changed integer;
begin
  with expired as (
    update public.referrals
       set status = 'EXPIRED'
     where status = 'PENDING'
       and expires_at <= now()
    returning id
  )
  insert into public.referral_events(referral_id,event_type)
  select id,'EXPIRED' from expired;

  get diagnostics changed = row_count;
  return changed;
end;
$$;

revoke all on function public.expire_pending_referrals() from public;
grant execute on function public.expire_pending_referrals() to service_role;
