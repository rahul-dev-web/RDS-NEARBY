-- Phase 14: Today's Near You feed (location-aware offers + Boost Shop placements).
-- Uses caller privileges so existing public discovery RLS remains authoritative.
create or replace function public.get_todays_near_you(
  p_lat double precision default null,
  p_lng double precision default null,
  p_locality text default null,
  p_limit integer default 30
)
returns table (
  item_type text,
  item_id uuid,
  business_id uuid,
  title text,
  description text,
  offer_price numeric,
  regular_price numeric,
  image_url text,
  business_name text,
  business_slug text,
  category_name text,
  address text,
  locality_id text,
  is_open boolean,
  distance_km double precision,
  is_sponsored boolean,
  campaign_type text,
  ends_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $function$
  with params as (
    select
      case when p_lat between -90 and 90 then p_lat else null end as lat,
      case when p_lng between -180 and 180 then p_lng else null end as lng,
      nullif(left(trim(coalesce(p_locality, '')), 120), '') as locality,
      least(greatest(coalesce(p_limit, 30), 1), 50) as row_limit
  ),
  eligible_businesses as (
    select
      b.id, b.name, b.slug, b.category_id, b.address, b.locality_id,
      b.lat, b.lng, b.is_open,
      c.name as category_name,
      case
        when p.lat is not null and p.lng is not null then
          6371.0 * 2 * asin(sqrt(least(1.0, greatest(0.0,
            power(sin(radians(b.lat - p.lat) / 2), 2)
            + cos(radians(p.lat)) * cos(radians(b.lat))
            * power(sin(radians(b.lng - p.lng) / 2), 2)
          ))))
        else null
      end as distance_km,
      p.locality, p.lat as customer_lat, p.lng as customer_lng, p.row_limit
    from public.businesses b
    left join public.categories c on c.id = b.category_id
    cross join params p
    where b.status = 'active'::public.record_status
      and b.verification_status = 'verified'::public.verification_status
      and (
        (p.lat is not null and p.lng is not null)
        or (
          p.locality is not null
          and (
            lower(replace(coalesce(b.locality_id, ''), '-', ' ')) = lower(replace(p.locality, '-', ' '))
            or coalesce(b.address, '') ilike '%' || replace(replace(replace(p.locality, chr(92), chr(92) || chr(92)), '%', chr(92) || '%'), '_', chr(92) || '_') || '%' escape chr(92)
          )
        )
      )
  ),
  offer_items as (
    select
      'offer'::text as item_type,
      o.id as item_id,
      b.id as business_id,
      o.title,
      o.description,
      o.offer_price,
      o.regular_price,
      o.image_url,
      b.name as business_name,
      b.slug as business_slug,
      b.category_name,
      b.address,
      b.locality_id,
      b.is_open,
      b.distance_km,
      exists (
        select 1 from public.campaigns pc
        where pc.offer_id = o.id
          and pc.business_id = b.id
          and pc.campaign_type = 'promote_offer'::public.campaign_type
          and pc.status = 'active'::public.campaign_status
          and pc.starts_at <= now()
          and pc.ends_at > now()
          and (
            b.distance_km is null
            or pc.target_radius_km is null
            or b.distance_km <= pc.target_radius_km
          )
      ) as is_sponsored,
      case when exists (
        select 1 from public.campaigns pc
        where pc.offer_id = o.id
          and pc.business_id = b.id
          and pc.campaign_type = 'promote_offer'::public.campaign_type
          and pc.status = 'active'::public.campaign_status
          and pc.starts_at <= now()
          and pc.ends_at > now()
      ) then 'promote_offer' else null end as campaign_type,
      o.ends_at
    from public.offers o
    join eligible_businesses b on b.id = o.business_id
    where o.status = 'active'::public.record_status
      and o.starts_at <= now()
      and o.ends_at > now()
      and (
        (b.customer_lat is not null and b.customer_lng is not null and b.distance_km <= 15)
        or (b.customer_lat is null and b.locality is not null)
      )
  ),
  boosted_shop_items as (
    select
      'shop'::text as item_type,
      c.id as item_id,
      b.id as business_id,
      b.name as title,
      null::text as description,
      null::numeric as offer_price,
      null::numeric as regular_price,
      null::text as image_url,
      b.name as business_name,
      b.slug as business_slug,
      b.category_name,
      b.address,
      b.locality_id,
      b.is_open,
      b.distance_km,
      true as is_sponsored,
      'boost_shop'::text as campaign_type,
      c.ends_at
    from public.campaigns c
    join eligible_businesses b on b.id = c.business_id
    where c.campaign_type = 'boost_shop'::public.campaign_type
      and c.status = 'active'::public.campaign_status
      and c.starts_at <= now()
      and c.ends_at > now()
      and (
        (b.customer_lat is not null and b.customer_lng is not null
          and b.distance_km <= 15
          and (c.target_radius_km is null or b.distance_km <= c.target_radius_km))
        or (b.customer_lat is null and b.locality is not null)
      )
  ),
  combined as (
    select * from offer_items
    union all
    select * from boosted_shop_items
  )
  select
    combined.item_type, combined.item_id, combined.business_id,
    combined.title, combined.description, combined.offer_price,
    combined.regular_price, combined.image_url, combined.business_name,
    combined.business_slug, combined.category_name, combined.address,
    combined.locality_id, combined.is_open, combined.distance_km,
    combined.is_sponsored, combined.campaign_type, combined.ends_at
  from combined
  cross join params
  order by
    case when combined.distance_km is null then 1 else 0 end,
    combined.distance_km asc nulls last,
    combined.is_open desc,
    combined.is_sponsored desc,
    combined.ends_at asc
  limit (select row_limit from params);
$function$;

revoke all on function public.get_todays_near_you(double precision, double precision, text, integer) from public;
grant execute on function public.get_todays_near_you(double precision, double precision, text, integer) to anon, authenticated;
