-- Phase 12: Customer Requests — secure server-side state transitions and reminder queue.
begin;

-- Requests and responses must be changed through the security-definer RPCs below.
drop policy if exists requests_customer_update on public.customer_requests;
drop policy if exists requests_customer_insert on public.customer_requests;
drop policy if exists responses_merchant_manage on public.request_responses;
revoke insert, update, delete on public.customer_requests from authenticated;
revoke insert, update, delete on public.request_responses from authenticated;

create or replace function public.create_customer_request(
  p_business_id uuid,
  p_request_type public.request_type,
  p_title text,
  p_description text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_customer_id uuid := auth.uid();
  v_owner_id uuid;
  v_business_name text;
  v_request_id uuid;
  v_title text := btrim(coalesce(p_title, ''));
  v_description text := nullif(btrim(coalesce(p_description, '')), '');
begin
  if v_customer_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_business_id is null then
    raise exception 'Business is required' using errcode = '22023';
  end if;
  if v_title = '' or char_length(v_title) > 120 then
    raise exception 'Title must contain 1–120 characters' using errcode = '22023';
  end if;
  if v_description is not null and char_length(v_description) > 1000 then
    raise exception 'Description must be at most 1000 characters' using errcode = '22023';
  end if;

  select b.owner_id, b.name
    into v_owner_id, v_business_name
  from public.businesses b
  where b.id = p_business_id
    and b.status = 'active'::public.record_status
    and b.verification_status = 'verified'::public.verification_status
    and b.accepting_requests = true;

  if not found then
    raise exception 'This business is not currently accepting requests' using errcode = 'P0002';
  end if;
  if v_owner_id = v_customer_id then
    raise exception 'You cannot send a customer request to your own business' using errcode = '42501';
  end if;

  insert into public.customer_requests(customer_id, business_id, request_type, title, description, status, expires_at)
  values (v_customer_id, p_business_id, p_request_type, v_title, v_description, 'pending'::public.request_status, now() + interval '10 minutes')
  returning id into v_request_id;

  insert into public.notifications(user_id, title, message, priority, type, related_entity_type, related_entity_id, status, scheduled_at)
  values
    (v_owner_id, 'New customer request', left(v_title || ' · ' || coalesce(v_description, 'Please respond within 10 minutes.'), 500),
     'high'::public.notification_priority, 'customer_request_created', 'customer_request', v_request_id, 'queued'::public.notification_status, now()),
    (v_owner_id, 'Customer request reminder', left('A customer request for ' || v_business_name || ' is still awaiting a response.', 500),
     'high'::public.notification_priority, 'customer_request_reminder_3m', 'customer_request_reminder', v_request_id, 'queued'::public.notification_status, now() + interval '3 minutes'),
    (v_owner_id, 'Final customer request reminder', left('Final reminder: respond to the customer request for ' || v_business_name || '.', 500),
     'high'::public.notification_priority, 'customer_request_reminder_8m', 'customer_request_reminder', v_request_id, 'queued'::public.notification_status, now() + interval '8 minutes');

  return v_request_id;
end;
$$;

create or replace function public.respond_customer_request(
  p_request_id uuid,
  p_decision text,
  p_message text default null,
  p_price numeric default null
)
returns public.request_status
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
  v_request public.customer_requests%rowtype;
  v_business public.businesses%rowtype;
  v_response_status public.request_status;
  v_message text := nullif(btrim(coalesce(p_message, '')), '');
begin
  if v_actor_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_decision not in ('accept', 'decline') then
    raise exception 'Decision must be accept or decline' using errcode = '22023';
  end if;
  if p_request_id is null then
    raise exception 'Request is required' using errcode = '22023';
  end if;
  if v_message is not null and char_length(v_message) > 1000 then
    raise exception 'Message must be at most 1000 characters' using errcode = '22023';
  end if;
  if p_price is not null and p_price < 0 then
    raise exception 'Price cannot be negative' using errcode = '22023';
  end if;

  select * into v_request
  from public.customer_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Request not found' using errcode = 'P0002';
  end if;

  select * into v_business
  from public.businesses
  where id = v_request.business_id and owner_id = v_actor_id;

  if not found then
    raise exception 'You do not own this request''s business' using errcode = '42501';
  end if;
  if v_request.status <> 'pending'::public.request_status then
    raise exception 'Request is no longer pending' using errcode = '55000';
  end if;
  if v_request.expires_at <= now() then
    update public.customer_requests set status = 'expired'::public.request_status where id = v_request.id;
    delete from public.notifications
    where related_entity_type = 'customer_request_reminder'
      and related_entity_id = v_request.id
      and status = 'queued'::public.notification_status;
    return 'expired'::public.request_status;
  end if;

  v_response_status := case when p_decision = 'accept' then 'accepted'::public.request_status else 'declined'::public.request_status end;

  insert into public.request_responses(request_id, business_id, response_type, price, message, status)
  values (v_request.id, v_request.business_id, p_decision, p_price, v_message, v_response_status);

  update public.customer_requests
  set status = v_response_status
  where id = v_request.id;

  insert into public.notifications(user_id, title, message, priority, type, related_entity_type, related_entity_id, status, scheduled_at)
  values (v_request.customer_id,
          case when p_decision = 'accept' then 'Your request was accepted' else 'Your request was declined' end,
          left(coalesce(v_message, v_business.name || case when p_decision = 'accept' then ' accepted your request.' else ' declined your request.' end), 500),
          'high'::public.notification_priority, 'customer_request_response', 'customer_request', v_request.id,
          'queued'::public.notification_status, now());

  delete from public.notifications
  where related_entity_type = 'customer_request_reminder'
    and related_entity_id = v_request.id
    and status = 'queued'::public.notification_status;

  return v_response_status;
end;
$$;

create or replace function public.cancel_customer_request(p_request_id uuid)
returns public.request_status
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_customer_id uuid := auth.uid();
  v_request public.customer_requests%rowtype;
begin
  if v_customer_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select * into v_request
  from public.customer_requests
  where id = p_request_id and customer_id = v_customer_id
  for update;

  if not found then
    raise exception 'Request not found' using errcode = 'P0002';
  end if;
  if v_request.status <> 'pending'::public.request_status then
    raise exception 'Only pending requests can be cancelled' using errcode = '55000';
  end if;

  update public.customer_requests
  set status = 'cancelled'::public.request_status
  where id = v_request.id;

  delete from public.notifications
  where related_entity_type = 'customer_request_reminder'
    and related_entity_id = v_request.id
    and status = 'queued'::public.notification_status;

  return 'cancelled'::public.request_status;
end;
$$;

-- Only authenticated users may call these RPCs; function bodies enforce ownership and state.
revoke all on function public.create_customer_request(uuid, public.request_type, text, text) from public, anon;
grant execute on function public.create_customer_request(uuid, public.request_type, text, text) to authenticated;
revoke all on function public.respond_customer_request(uuid, text, text, numeric) from public, anon;
grant execute on function public.respond_customer_request(uuid, text, text, numeric) to authenticated;
revoke all on function public.cancel_customer_request(uuid) from public, anon;
grant execute on function public.cancel_customer_request(uuid) to authenticated;

-- A resolved request must not leave queued 3m/8m reminder notifications behind.
create or replace function public.cancel_customer_request_reminders()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if old.status = 'pending'::public.request_status and new.status <> 'pending'::public.request_status then
    delete from public.notifications
    where related_entity_type = 'customer_request_reminder'
      and related_entity_id = new.id
      and status = 'queued'::public.notification_status;
  end if;
  return new;
end;
$$;

drop trigger if exists customer_request_cancel_reminders on public.customer_requests;
create trigger customer_request_cancel_reminders
after update of status on public.customer_requests
for each row execute function public.cancel_customer_request_reminders();

commit;
