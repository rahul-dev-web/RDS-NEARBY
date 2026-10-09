-- Phase 11: Discovery ranking indexes
begin;
create index if not exists campaigns_active_boost_discovery_idx
  on public.campaigns (starts_at, ends_at, business_id)
  where campaign_type = 'boost_shop'::public.campaign_type
    and status = 'active'::public.campaign_status;
create index if not exists campaigns_active_promote_offer_discovery_idx
  on public.campaigns (starts_at, ends_at, offer_id, business_id)
  where campaign_type = 'promote_offer'::public.campaign_type
    and status = 'active'::public.campaign_status
    and offer_id is not null;
commit;
