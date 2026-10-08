-- Phase 10 security hardening: campaign SECURITY DEFINER RPCs are service-role only.

revoke execute on function public.consume_merchant_credits(uuid,integer,text,uuid,text)
  from public, anon, authenticated;
revoke execute on function public.create_boost_shop_campaign(uuid,text)
  from public, anon, authenticated;
revoke execute on function public.create_promote_offer_campaign(uuid,uuid,text)
  from public, anon, authenticated;

grant execute on function public.consume_merchant_credits(uuid,integer,text,uuid,text)
  to service_role;
grant execute on function public.create_boost_shop_campaign(uuid,text)
  to service_role;
grant execute on function public.create_promote_offer_campaign(uuid,uuid,text)
  to service_role;
