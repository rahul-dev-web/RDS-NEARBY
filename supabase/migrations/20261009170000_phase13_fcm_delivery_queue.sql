-- Phase 13: notification delivery queue primitives for the FCM worker.
begin;

alter table public.notifications
  add column if not exists delivery_attempts integer not null default 0,
  add column if not exists delivery_error text,
  add column if not exists processing_started_at timestamptz;

create index if not exists notifications_due_push_idx
  on public.notifications (scheduled_at, created_at)
  where status = 'queued'::public.notification_status
    and type in (
      'customer_request_created',
      'customer_request_reminder_3m',
      'customer_request_reminder_8m'
    );

create or replace function public.claim_due_customer_request_notifications(p_batch_size integer default 25)
returns table (
  id uuid,
  user_id uuid,
  title text,
  message text,
  priority public.notification_priority,
  type text,
  related_entity_type text,
  related_entity_id uuid,
  delivery_attempts integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_batch_size < 1 or p_batch_size > 100 then
    raise exception 'Batch size must be between 1 and 100' using errcode = '22023';
  end if;

  -- Never push a request alert/reminder after its request has resolved or expired.
  delete from public.notifications n
  where n.status = 'queued'::public.notification_status
    and n.type in (
      'customer_request_created',
      'customer_request_reminder_3m',
      'customer_request_reminder_8m'
    )
    and exists (
      select 1
      from public.customer_requests r
      where r.id = n.related_entity_id
        and (
          r.status <> 'pending'::public.request_status
          or r.expires_at <= now()
        )
    );

  return query
  with candidates as (
    select n.id
    from public.notifications n
    join public.customer_requests r
      on r.id = n.related_entity_id
    where n.status = 'queued'::public.notification_status
      and n.type in (
        'customer_request_created',
        'customer_request_reminder_3m',
        'customer_request_reminder_8m'
      )
      and coalesce(n.scheduled_at, n.created_at) <= now()
      and r.status = 'pending'::public.request_status
      and r.expires_at > now()
      and (
        n.processing_started_at is null
        or n.processing_started_at < now() - interval '2 minutes'
      )
    order by coalesce(n.scheduled_at, n.created_at), n.created_at
    for update of n skip locked
    limit p_batch_size
  )
  update public.notifications n
     set processing_started_at = now(),
         delivery_attempts = n.delivery_attempts + 1,
         delivery_error = null
    from candidates c
   where n.id = c.id
  returning n.id, n.user_id, n.title, n.message, n.priority, n.type,
            n.related_entity_type, n.related_entity_id, n.delivery_attempts;
end;
$$;

create or replace function public.finish_customer_request_notification(
  p_notification_id uuid,
  p_success boolean,
  p_error text default null,
  p_max_attempts integer default 5
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_attempts integer;
begin
  if p_max_attempts < 1 or p_max_attempts > 10 then
    raise exception 'Max attempts must be between 1 and 10' using errcode = '22023';
  end if;

  select n.delivery_attempts into v_attempts
  from public.notifications n
  where n.id = p_notification_id
    and n.status = 'queued'::public.notification_status
  for update;

  if not found then
    return;
  end if;

  if p_success then
    update public.notifications
       set status = 'sent'::public.notification_status,
           sent_at = now(),
           processing_started_at = null,
           delivery_error = null
     where id = p_notification_id;
  elsif v_attempts >= p_max_attempts then
    update public.notifications
       set status = 'failed'::public.notification_status,
           processing_started_at = null,
           delivery_error = left(coalesce(p_error, 'FCM delivery failed'), 1000)
     where id = p_notification_id;
  else
    update public.notifications
       set status = 'queued'::public.notification_status,
           scheduled_at = now() + make_interval(secs => least(300, 15 * power(2, greatest(v_attempts - 1, 0))::integer)),
           processing_started_at = null,
           delivery_error = left(coalesce(p_error, 'FCM delivery failed'), 1000)
     where id = p_notification_id;
  end if;
end;
$$;

revoke all on function public.claim_due_customer_request_notifications(integer) from public, anon, authenticated;
revoke all on function public.finish_customer_request_notification(uuid, boolean, text, integer) from public, anon, authenticated;
grant execute on function public.claim_due_customer_request_notifications(integer) to service_role;
grant execute on function public.finish_customer_request_notification(uuid, boolean, text, integer) to service_role;

commit;
