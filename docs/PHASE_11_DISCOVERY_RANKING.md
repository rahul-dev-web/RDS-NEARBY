# Phase 11 — Discovery Ranking

## Status
Implemented search-first discovery for matching shops, products, services, and offers in public web search and Flutter customer discovery; moderate sponsored ranking is applied to business results and offer-specific sponsored labels to offers.

## Frozen behavior
- Keep search-first local discovery and existing public eligibility rules.
- Rank matching business names by relevance (exact name, name prefix, name contains, description, then address); use open status and name as tie-breakers.
- Only an active Boost Shop campaign on a query-matching active, verified business adds a sponsored signal.
- Interleave up to three organic results before each sponsored result, limiting sponsored density to roughly 1 in 4 slots when organic results are available.
- For offers, only active offers inside their start/end window from active, verified businesses are eligible; active Promote Offer campaigns label the matching offer only.
- Interleave up to three organic offers before each promoted offer, and deduplicate offer cards by offer ID.
- Label sponsored results `SPONSORED`.
- Never let paid promotion introduce unrelated businesses or displace the organic discovery model.
- Campaign is valid only when `starts_at <= now < ends_at`.

## Files
- `web/app/search/page.tsx`
- `mobile/lib/features/customer/customer_discovery_screen.dart`
- `docs/SEARCH_RANKING.md`
- `supabase/migrations/20261009100000_phase11_discovery_ranking.sql`

## Product and service discovery
- Search includes matching active, available products by name/description and shows price/unit plus the associated shop.
- Search includes matching active, available services by name/description and shows price/duration plus the associated provider.
- Existing RLS on `business_products` and `business_services` restricts public rows to active, available inventory owned by active, verified businesses.
- Inventory results are supplementary and do not carry paid sponsor labels; Boost Shop remains a business-card promotion and Promote Offer remains offer-card-only.

## Offer discovery
- Search includes matching active offers by title/description, alongside matching shops.
- Offer queries explicitly require an active, verified associated business. A `promote_offer` campaign labels only its matching offer card `SPONSORED`; it never marks the entire business as sponsored.
- Offer ranking balances organic and promoted cards in a 3:1 cadence and removes duplicate offer IDs before rendering.
- Offer cards are supplementary results; if the campaign lookup fails, matching offers remain visible as organic results.
- Public offer reads remain constrained by existing RLS: active, time-valid offers from active, verified businesses.
- This slice does not implement the Phase 13 Today's Near You feed, geo-distance ranking, or offer redemption.

## Validation notes
- Live migration adds partial indexes for active Boost Shop and Promote Offer lookup paths.
- Live indexes for active Boost Shop and Promote Offer lookups were verified; existing offer time-window/business indexes were also inspected.
- Supabase Security Advisor returned no findings at the previous Phase 11 check; performance advisor has existing unused-index and multiple-permissive-policy notices.
- Flutter static analysis/build and Next.js production build have not been run in this environment; GitHub commits alone do not establish compile success.
- Flutter static analysis/build and Next.js production build have not been run in this environment; GitHub commits alone do not establish compile success.
