-- Phase 17: pin SECURITY DEFINER RPCs to an empty search_path.
-- All relations/types/auth helpers in these functions are schema-qualified; pg_catalog
-- remains implicitly available for built-ins. This prevents object shadowing.
ALTER FUNCTION public.cancel_customer_request(uuid) SET search_path = '';
ALTER FUNCTION public.create_customer_request(uuid, public.request_type, text, text) SET search_path = '';
ALTER FUNCTION public.redeem_customer_points(uuid, numeric, integer, text) SET search_path = '';
ALTER FUNCTION public.respond_customer_request(uuid, text, text, numeric) SET search_path = '';
ALTER FUNCTION public.respond_to_point_redemption(uuid, text) SET search_path = '';
