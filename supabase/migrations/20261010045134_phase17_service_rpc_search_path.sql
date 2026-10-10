-- Pin remaining service-only SECURITY DEFINER functions to an empty search_path.
-- Function bodies already schema-qualify public tables, enums and internal RPC calls.
ALTER FUNCTION public.cancel_customer_request_reminders() SET search_path = '';
ALTER FUNCTION public.claim_due_customer_request_notifications(integer) SET search_path = '';
ALTER FUNCTION public.consume_merchant_credits(uuid, integer, text, uuid, text) SET search_path = '';
ALTER FUNCTION public.create_boost_shop_campaign(uuid, text) SET search_path = '';
ALTER FUNCTION public.create_promote_offer_campaign(uuid, uuid, text) SET search_path = '';
ALTER FUNCTION public.expire_stale_customer_requests() SET search_path = '';
ALTER FUNCTION public.finish_customer_request_notification(uuid, boolean, text, integer) SET search_path = '';
