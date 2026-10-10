# Phase 14 — Today's Near You

Status: Initial locality-based feed implemented; GPS-powered feed and production data validation remain follow-up work.

## User experience

- Customer Discovery now has a **Today's Near You** section.
- The customer enters a locality/area and requests today's local feed.
- The feed shows current, active offers and active Boost Shop placements.
- Promote Offer labels only the matching offer as **SPONSORED**.
- Boost Shop placements are shown as sponsored shop cards.
- The feed has explicit loading, error, empty-result, and locality-required states.
- Search and the existing organic discovery list remain available if the feed is empty or unavailable.

## Database contract

Migration: `20261010100000_phase14_todays_near_you_feed.sql`

RPC: `public.get_todays_near_you(p_lat, p_lng, p_locality, p_limit)`

- Uses `SECURITY INVOKER`; the caller's existing RLS permissions still apply.
- Public execution is granted to `anon` and `authenticated` for public discovery.
- Active + verified business eligibility is required.
- Offers must be active and within their start/end window.
- Active Promote Offer campaigns label only their associated offer.
- Active Boost Shop campaigns create a sponsored shop card.
- With coordinates, organic offers are limited to 15 km; campaign target radius further constrains sponsored visibility.
- Without coordinates, a locality must be provided; it matches the business locality ID or address.
- The query is capped at 50 results and sorts distance first, then open status, then sponsored signal. Sponsored content is not globally forced above closer organic results.
- No customer coordinates are persisted.

## Current limitations

- Flutter currently uses the locality fallback; automatic GPS permission/provider integration is not included in this change.
- Locality matching depends on the existing `businesses.locality_id` and `address` values; there is not yet a normalized locality directory.
- Live RDS Nearby currently has **0 active, verified businesses**, so the RPC correctly returns an empty feed until real business/offer data is onboarded.
- The SQL RPC was smoke-tested for no-location and locality calls. Those checks returned zero rows because the live project has no eligible businesses; a populated-data acceptance test is still required.
- End-to-end Flutter analyze/test and real-device UI testing must be confirmed by CI/device runs before calling the feature production-ready.

## Acceptance checks

1. No location and no locality returns no rows.
2. A locality query returns only eligible businesses matching locality/address.
3. Expired, future, inactive, or unverified records never appear.
4. Promoted offers show **SPONSORED** on the offer card, not the shop generally.
5. Boost Shop creates a clearly labelled sponsored shop card.
6. Distance is calculated only when coordinates are supplied and no customer location is stored.
7. Empty feed never blocks normal search and shop discovery.
8. Sponsored signal does not override distance ordering.

## Next work

- Add a populated fixture/test path for offers and campaigns in a non-production test database.
- Add a mapping/location provider abstraction and transient GPS support, retaining locality entry as fallback.
- Verify actual Flutter CI after these commits and add widget-level tests for loading/error/empty/feed states.
