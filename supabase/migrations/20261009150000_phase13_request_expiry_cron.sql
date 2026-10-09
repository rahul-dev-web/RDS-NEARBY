-- Phase 13 foundation: expire stale customer requests automatically.
begin;

create extension if not exists pg_cron with schema pg_catalog;

create or replace function public.expire_stale_customer_requests()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_expired_count integer := 0;
  v_deleted_reminders integer := 0;
begin
  update public.customer_requests
  set status = 'expired'::public.request_status,
      updated_at = now()
  where status = 'pending'::public.request_status
    and expires_at <= now();

  get diagnostics v_expired_count = row_count;

  delete from public.notifications n
  where n.related_entity_type = 'customer_request_reminder'
    and n.status = 'queued'::public.notification_status
    and exists (
      select 1
      from public.customer_requests r
      where r.id = n.related_entity_id
        and r.status <> 'pending'::public.request_status
    );

  get diagnostics v_deleted_reminders = row_count;

  return jsonb_build_object(
    'expired_requests', v_expired_count,
    'cancelled_queued_reminders', v_deleted_reminders,
    'processed_at', now()
  );
end;
$$;

revoke all on function public.expire_stale_customer_requests() from public, anon, authenticated;
grant execute on function public.expire_stale_customer_requests() to service_role;

-- Replacing the named job makes this migration safe to re-run after a partial deployment.
do $$
declare
  v_job_id bigint;
begin
  if to_regclass('cron.job') is not null then
    for v_job_id in select jobid from cron.job where jobname = 'expire-stale-customer-requests'
    loop
      perform cron.unschedule(v_job_id);
    end loop;
  end if;
end;
$$;

select cron.schedule(
  'expire-stale-customer-requests',
  '* * * * *',
  $$select public.expire_stale_customer_requests();$$
);

commit;
