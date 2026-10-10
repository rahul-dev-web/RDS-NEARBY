-- Correct referral enum casing in Phase 16 merchant analytics.
create or replace function public.get_merchant_business_analytics(
  p_business_id uuid,
  p_days integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_days integer := greatest(1, least(coalesce(p_days, 30), 90));
  v_since timestamptz;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.businesses b
    where b.id = p_business_id and b.owner_id = v_user_id
  ) then
    raise exception 'business_access_denied' using errcode = '42501';
  end if;

  v_since := now() - make_interval(days => v_days);

  select jsonb_build_object(
    'business_id', p_business_id,
    'days', v_days,
    'since', v_since,
    'shop_views', (select count(*) from public.analytics_events e where e.business_id = p_business_id and e.event_name = 'shop_view' and e.created_at >= v_since),
    'search_matches', (select count(*) from public.analytics_events e where e.business_id = p_business_id and e.event_name = 'search_result_click' and e.created_at >= v_since),
    'offers_viewed', (select count(*) from public.analytics_events e where e.business_id = p_business_id and e.event_name = 'offer_view' and e.created_at >= v_since),
    'offers_claimed', (select count(*) from public.analytics_events e where e.business_id = p_business_id and e.event_name = 'reserve' and e.metadata->>'action' = 'offer_claim' and e.created_at >= v_since),
    'call_clicks', (select count(*) from public.analytics_events e where e.business_id = p_business_id and e.event_name = 'call_click' and e.created_at >= v_since),
    'whatsapp_clicks', (select count(*) from public.analytics_events e where e.business_id = p_business_id and e.event_name = 'whatsapp_click' and e.created_at >= v_since),
    'saved_count', (select count(*) from public.analytics_events e where e.business_id = p_business_id and e.event_name = 'shop_saved' and e.created_at >= v_since),
    'requests_received', (select count(*) from public.customer_requests r where r.business_id = p_business_id and r.created_at >= v_since),
    'requests_responded', (select count(*) from public.customer_requests r where r.business_id = p_business_id and r.created_at >= v_since and r.status::text in ('accepted','declined','completed')),
    'new_referral_customers', (select count(*) from public.referrals r where r.referrer_business_id = p_business_id and lower(r.status::text) = 'qualified' and r.qualified_at >= v_since),
    'credits_earned', (select coalesce(sum(l.amount), 0) from public.merchant_credit_ledger l where l.merchant_id = p_business_id and l.transaction_type::text = 'referral_reward' and l.created_at >= v_since),
    'credits_spent', (select coalesce(abs(sum(l.amount)), 0) from public.merchant_credit_ledger l where l.merchant_id = p_business_id and l.transaction_type::text in ('boost_spend', 'promote_offer_spend') and l.created_at >= v_since),
    'current_marketing_credits', (select coalesce(w.balance, 0) from public.merchant_wallets w where w.merchant_id = p_business_id),
    'boost_campaigns_created', (select count(*) from public.campaigns c where c.business_id = p_business_id and c.campaign_type::text = 'boost_shop' and c.created_at >= v_since),
    'promoted_offers_created', (select count(*) from public.campaigns c where c.business_id = p_business_id and c.campaign_type::text = 'promote_offer' and c.created_at >= v_since),
    'redemptions_approved', (select count(*) from public.redemptions d where d.business_id = p_business_id and d.status::text = 'active' and d.created_at >= v_since),
    'redemption_discount_total', (select coalesce(sum(d.discount_value), 0) from public.redemptions d where d.business_id = p_business_id and d.status::text = 'active' and d.created_at >= v_since)
  ) into v_result;

  return v_result;
end;
$$;
