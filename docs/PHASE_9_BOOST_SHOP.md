# Phase 9 — Boost Shop

## Goal

Let an eligible merchant spend 50 Marketing Credits to promote the business for 24 hours.

## Frozen product rule

- Product: Boost Shop
- Cost: 50 Marketing Credits
- Duration: 24 hours
- V1 promotion type: BOOST_SHOP
- Sponsored visibility is a ranking signal, not a guaranteed first position.
- Credits never expire.
- Merchant balance cannot exceed 2,000.

## Server flow

1. Authenticated merchant selects Boost Shop for an owned business.
2. Edge Function validates the caller, merchant role/status and business ownership.
3. Edge Function calls the server-owned `create_boost_shop_campaign` operation.
4. The database locks the business and wallet rows.
5. Existing expired Boost Shop campaigns are marked EXPIRED.
6. An already-active Boost Shop returns without another deduction.
7. A new ACTIVE campaign is inserted for 24 hours.
8. Exactly 50 credits are deducted through `consume_merchant_credits`.
9. One immutable `BOOST_SPEND` ledger row is written with the same idempotency key.
10. An audit event is recorded.

## Security

- Client cannot insert/update/delete campaigns.
- Client cannot insert/update/delete merchant wallet rows.
- Client cannot insert/update/delete merchant credit ledger rows.
- Campaign creation requires an authenticated merchant and owned business.
- Economic mutation is server-owned and atomic.
- Duplicate idempotency keys produce one economic outcome.
- A second request while Boost Shop is already active does not deduct another 50 credits.

## Public discovery

Active campaigns for active + verified businesses are readable as public ranking inputs. Discovery should use the campaign only as a moderate sponsored signal and must continue to rank organic results meaningfully.

## Acceptance tests

- 120 credits + Boost Shop → 70 credits and one 24-hour campaign.
- 40 credits + Boost Shop → rejected, no campaign and no ledger mutation.
- Double-click / concurrent Boost Shop → one active campaign and one 50-credit deduction.
- Same idempotency key replay → no second campaign or ledger row.
- Unverified business → rejected.
- Merchant trying another merchant's business → rejected.
- Expired campaign no longer qualifies as active.
