create or replace function public.is_merchant()
returns boolean
language sql
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'merchant'::user_role
      and p.status = 'active'::record_status
  );
$$;

revoke all on function public.is_merchant() from public;
grant execute on function public.is_merchant() to authenticated;

drop policy if exists businesses_owner_insert on public.businesses;
create policy businesses_owner_insert on public.businesses for insert to authenticated
with check (
  (select auth.uid()) = owner_id
  and (select public.is_merchant())
  and status = 'pending'::record_status
  and verification_status = 'pending'::verification_status
);

drop policy if exists businesses_owner_select on public.businesses;
create policy businesses_owner_select on public.businesses for select to authenticated
using ((select auth.uid()) = owner_id);

create or replace function public.prevent_business_privilege_changes()
returns trigger language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.owner_id is distinct from old.owner_id
     or new.verification_status is distinct from old.verification_status
     or new.status is distinct from old.status then
    if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' then
      raise exception 'business ownership/status/verification changes must use server-controlled workflows';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_business_privilege_changes() from public;
revoke all on function public.prevent_business_privilege_changes() from anon;
revoke all on function public.prevent_business_privilege_changes() from authenticated;

drop trigger if exists prevent_business_privilege_changes on public.businesses;
create trigger prevent_business_privilege_changes
before update on public.businesses for each row
execute function public.prevent_business_privilege_changes();

drop policy if exists businesses_owner_update on public.businesses;
create policy businesses_owner_update on public.businesses for update to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);

create index if not exists businesses_owner_id_idx on public.businesses(owner_id);
create index if not exists businesses_category_id_idx on public.businesses(category_id);
