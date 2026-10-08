-- Phase 10: Promote Offer + live-safe campaign hardening
-- Live RDS uses lowercase campaign enums and scheduled/active/completed/cancelled statuses.

begin;

alter table public.campaigns
  add column if not exists idempotency_key text;

create unique index if not exists campaigns_idempotency_key_uidx
  on public.campaigns(idempotency_key)
  where idempotency_key is not null;

create index if not exists campaigns_business_status_idx
  on public.campaigns(business_id, status, ends_at desc);

create index if not exists campaigns_active_window_idx
  on public.campaigns(status, starts_at, ends_at);

create unique index if not exists campaigns_active_boost_business_uidx
  on public.campaigns(business_id)
  where campaign_type = 'boost_shop'::public.campaign_type
    and status = 'active'::public.campaign_status;

create unique index if not exists campaigns_active_offer_uidx
  on public.campaigns(offer_id)
  where campaign_type = 'promote_offer'::public.campaign_type
    and status = 'active'::public.campaign_status
    and offer_id is not null;

drop policy if exists campaign_public_read on public.campaigns;
drop policy if exists campaigns_public_active_read on public.campaigns;
create policy campaigns_public_active_read
on public.campaigns for select to anon, authenticated
using (
  status = 'active'::public.campaign_status
  and starts_at <= now()
  and ends_at > now()
  and exists (
    select 1 from public.businesses b
    where b.id = campaigns.business_id
      and b.status = 'active'::public.record_status
      and b.verification_status = 'verified'::public.verification_status
  )
);

drop policy if exists campaign_owner_read on public.campaigns;
drop policy if exists campaigns_owner_read on public.campaigns;
create policy campaigns_owner_read
on public.campaigns for select to authenticated
using (
  exists (
    select 1 from public.businesses b
    where b.id = campaigns.business_id
      and b.owner_id = (select auth.uid())
  )
);

revoke insert, update, delete on public.campaigns from anon, authenticated;
grant select on public.campaigns to anon, authenticated;

create or replace function public.consume_merchant_credits(
  p_merchant_id uuid,
  p_amount integer,
  p_transaction_type text,
  p_reference_id uuid,
  p_idempotency_key text
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  wallet public.merchant_wallets%rowtype;
  ledger_id uuid;
  new_balance integer;
begin
  if p_merchant_id is null or p_amount <= 0
     or p_transaction_type not in ('boost_spend','promote_offer_spend')
     or p_idempotency_key is null
     or length(trim(p_idempotency_key)) < 8 then
    raise exception 'invalid_credit_consumption_request';
  end if;

  select * into wallet from public.merchant_wallets
  where merchant_id = p_merchant_id for update;

  if not found then
    insert into public.merchant_wallets(merchant_id,balance)
    values (p_merchant_id,0)
    on conflict (merchant_id) do nothing;
    select * into wallet from public.merchant_wallets
    where merchant_id = p_merchant_id for update;
  end if;

  if wallet.balance < p_amount then
    raise exception 'insufficient_marketing_credits';
  end if;

  new_balance := wallet.balance - p_amount;

  insert into public.merchant_credit_ledger(
    merchant_id, amount, transaction_type, reference_id,
    balance_after, idempotency_key
  )
  values (
    p_merchant_id, -p_amount,
    p_transaction_type::public.credit_transaction_type,
    p_reference_id, new_balance, p_idempotency_key
  )
  on conflict (idempotency_key) do nothing
  returning id into ledger_id;

  if ledger_id is null then
    return jsonb_build_object('deducted',false,'balance',wallet.balance,
                              'reason','idempotent_replay');
  end if;

  update public.merchant_wallets
  set balance = new_balance, updated_at = now()
  where merchant_id = p_merchant_id;

  return jsonb_build_object('deducted',true,'balance',new_balance,
                            'ledger_id',ledger_id);
end;
$$;

revoke all on function public.consume_merchant_credits(uuid,integer,text,uuid,text) from public;
grant execute on function public.consume_merchant_credits(uuid,integer,text,uuid,text) to service_role;

create or replace function public.create_boost_shop_campaign(
  p_merchant_id uuid, p_idempotency_key text
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  business_row public.businesses%rowtype;
  existing_campaign public.campaigns%rowtype;
  campaign_row public.campaigns%rowtype;
  spend_result jsonb;
begin
  if p_merchant_id is null or p_idempotency_key is null
     or length(trim(p_idempotency_key)) < 8 then
    raise exception 'invalid_campaign_request';
  end if;

  select * into business_row from public.businesses
  where id = p_merchant_id for update;

  if not found then raise exception 'business_not_found'; end if;
  if business_row.status <> 'active'::public.record_status
     or business_row.verification_status <> 'verified'::public.verification_status then
    raise exception 'business_not_eligible';
  end if;

  select * into existing_campaign from public.campaigns
  where idempotency_key = p_idempotency_key limit 1;

  if found then
    return jsonb_build_object('created',false,'reason','idempotent_replay',
                              'campaign',to_jsonb(existing_campaign));
  end if;

  update public.campaigns set status='completed'::public.campaign_status
  where business_id=p_merchant_id
    and campaign_type='boost_shop'::public.campaign_type
    and status='active'::public.campaign_status
    and ends_at <= now();

  select * into existing_campaign from public.campaigns
  where business_id=p_merchant_id
    and campaign_type='boost_shop'::public.campaign_type
    and status='active'::public.campaign_status
    and starts_at <= now() and ends_at > now()
  order by ends_at desc limit 1;

  if found then
    return jsonb_build_object('created',false,'reason','active_campaign_exists',
                              'campaign',to_jsonb(existing_campaign));
  end if;

  insert into public.campaigns(
    business_id,campaign_type,credit_cost,starts_at,ends_at,status,target_radius_km,idempotency_key
  ) values (
    p_merchant_id,'boost_shop'::public.campaign_type,50,now(),now()+interval '24 hours',
    'active'::public.campaign_status,5.00,p_idempotency_key
  ) returning * into campaign_row;

  spend_result := public.consume_merchant_credits(
    p_merchant_id,50,'boost_spend',campaign_row.id,p_idempotency_key
  );

  if coalesce((spend_result->>'deducted')::boolean,false)=false then
    raise exception 'credit_deduction_failed';
  end if;

  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values (
    business_row.owner_id,'boost_shop_created','campaign',campaign_row.id,
    jsonb_build_object('business_id',p_merchant_id,'credit_cost',50,
                       'duration_hours',24,'target_radius_km',5.00)
  );

  return jsonb_build_object('created',true,'campaign',to_jsonb(campaign_row),
                            'balance',spend_result->'balance');
end;
$$;

revoke all on function public.create_boost_shop_campaign(uuid,text) from public;
grant execute on function public.create_boost_shop_campaign(uuid,text) to service_role;

create or replace function public.create_promote_offer_campaign(
  p_merchant_id uuid, p_offer_id uuid, p_idempotency_key text
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  business_row public.businesses%rowtype;
  offer_row public.offers%rowtype;
  existing_campaign public.campaigns%rowtype;
  campaign_row public.campaigns%rowtype;
  spend_result jsonb;
begin
  if p_merchant_id is null or p_offer_id is null
     or p_idempotency_key is null
     or length(trim(p_idempotency_key)) < 8 then
    raise exception 'invalid_campaign_request';
  end if;

  select * into business_row from public.businesses
  where id=p_merchant_id for update;

  if not found then raise exception 'business_not_found'; end if;
  if business_row.status <> 'active'::public.record_status
     or business_row.verification_status <> 'verified'::public.verification_status then
    raise exception 'business_not_eligible';
  end if;

  select * into offer_row from public.offers
  where id=p_offer_id and business_id=p_merchant_id for update;

  if not found then raise exception 'offer_not_owned'; end if;
  if offer_row.status <> 'active'::public.record_status
     or offer_row.starts_at > now() or offer_row.ends_at <= now() then
    raise exception 'offer_not_active';
  end if;

  select * into existing_campaign from public.campaigns
  where idempotency_key=p_idempotency_key limit 1;

  if found then
    return jsonb_build_object('created',false,'reason','idempotent_replay',
                              'campaign',to_jsonb(existing_campaign));
  end if;

  update public.campaigns set status='completed'::public.campaign_status
  where offer_id=p_offer_id
    and campaign_type='promote_offer'::public.campaign_type
    and status='active'::public.campaign_status
    and ends_at <= now();

  select * into existing_campaign from public.campaigns
  where offer_id=p_offer_id
    and campaign_type='promote_offer'::public.campaign_type
    and status='active'::public.campaign_status
    and starts_at <= now() and ends_at > now()
  order by ends_at desc limit 1;

  if found then
    return jsonb_build_object('created',false,'reason','active_campaign_exists',
                              'campaign',to_jsonb(existing_campaign));
  end if;

  insert into public.campaigns(
    business_id,campaign_type,credit_cost,starts_at,ends_at,status,target_radius_km,offer_id,idempotency_key
  ) values (
    p_merchant_id,'promote_offer'::public.campaign_type,100,now(),now()+interval '3 days',
    'active'::public.campaign_status,5.00,p_offer_id,p_idempotency_key
  ) returning * into campaign_row;

  spend_result := public.consume_merchant_credits(
    p_merchant_id,100,'promote_offer_spend',campaign_row.id,p_idempotency_key
  );

  if coalesce((spend_result->>'deducted')::boolean,false)=false then
    raise exception 'credit_deduction_failed';
  end if;

  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values (
    business_row.owner_id,'promote_offer_created','campaign',campaign_row.id,
    jsonb_build_object('business_id',p_merchant_id,'offer_id',p_offer_id,
                       'credit_cost',100,'duration_days',3,'target_radius_km',5.00)
  );

  return jsonb_build_object('created',true,'campaign',to_jsonb(campaign_row),
                            'balance',spend_result->'balance');
end;
$$;

revoke all on function public.create_promote_offer_campaign(uuid,uuid,text) from public;
grant execute on function public.create_promote_offer_campaign(uuid,uuid,text) to service_role;

commit;
