# Phase 11 — Discovery Ranking

## Status
Implemented initial moderate sponsored ranking for existing business-card search in the public web app and Flutter customer discovery.

## Frozen behavior
- Keep search-first local discovery and existing public eligibility rules.
- Preserve existing open-first baseline ordering.
- Only an active Boost Shop campaign on a query-matching active, verified business adds a sponsored signal.
- Interleave up to three organic results before each sponsored result, limiting sponsored density to roughly 1 in 4 slots when organic results are available.
- Label sponsored results `SPONSORED`.
- Never let paid promotion introduce unrelated businesses or displace the organic discovery model.
- Campaign is valid only when `starts_at <= now < ends_at`.

## Files
- `web/app/search/page.tsx`
- `mobile/lib/features/customer/customer_discovery_screen.dart`
- `docs/SEARCH_RANKING.md`
- `supabase/migrations/20261009100000_phase11_discovery_ranking.sql`

## Offer promotion boundary
The public search currently renders business cards rather than offer cards. Phase 11 adds an index for active `promote_offer` campaigns, but does not incorrectly label an entire business as sponsored due to an offer promotion. The offer ranking signal must be consumed when offer cards are included in discovery.

## Validation notes
- Live migration adds partial indexes for active Boost Shop and Promote Offer lookup paths.
- Verify the indexes and run Supabase Security and Performance Advisors after migration.
- Flutter static analysis/build and Next.js production build have not been run in this environment; GitHub commits alone do not establish compile success.
