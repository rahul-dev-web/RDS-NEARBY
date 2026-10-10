-- Phase 17: prevent clients from changing trusted identity/publication fields.
-- RLS scopes rows; column privileges constrain which fields an owner may mutate.
-- Admin/service workflows continue to use their trusted database credentials.

REVOKE UPDATE ON TABLE public.profiles FROM authenticated;
GRANT UPDATE (name, phone, avatar_url) ON TABLE public.profiles TO authenticated;

REVOKE UPDATE ON TABLE public.businesses FROM authenticated;
GRANT UPDATE (
  name,
  slug,
  category_id,
  description,
  phone,
  whatsapp,
  lat,
  lng,
  address,
  locality_id,
  opening_hours,
  accepting_requests,
  logo_url,
  local_rewards_enabled,
  rewards_min_bill,
  rewards_max_discount
) ON TABLE public.businesses TO authenticated;

COMMENT ON TABLE public.profiles IS
  'Client updates are column-limited; role and status are trusted-server controlled.';

COMMENT ON TABLE public.businesses IS
  'Client updates are column-limited; owner_id, status, verification_status, is_open, and timestamps are trusted-server controlled.';
