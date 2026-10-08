# Phase 10 — Promote Offer

Status: IMPLEMENTED

## Frozen behavior

- Merchant promotion type: **Promote Offer**
- Cost: **100 Marketing Credits**
- Duration: **3 days**
- Target: one specific merchant-owned offer
- Business must be active and verified.
- Offer must belong to the merchant, be active, and be inside its valid start/end window.
- One active Promote Offer campaign is allowed per offer.
- Expired campaign rows are moved to the existing `completed` campaign status before a new promotion can start.
- Client never writes campaign rows or merchant balances directly.

## Atomic backend flow

1. Authenticated merchant calls `create-campaign`.
2. Edge Function validates merchant role, active profile and business ownership.
3. Edge Function invokes `create_promote_offer_campaign` with the service role.
4. PostgreSQL locks the business and target offer.
5. Existing expired promotion is completed.
6. Existing active promotion returns an idempotent/non-duplicate result.
7. New campaign is created for 3 days.
8. `consume_merchant_credits` locks the wallet and deducts exactly 100 credits.
9. Credit ledger stores `promote_offer_spend` with the same idempotency key.
10. Audit log records the campaign creation.

## Idempotency

Campaigns have a unique partial index on non-null `idempotency_key`.

A duplicate client submission cannot create another campaign or another ledger deduction.

## Security

The campaign mutation RPCs are SECURITY DEFINER but explicitly executable only by `service_role`. Anonymous and authenticated clients cannot call the privileged RPCs through the Data API.

## Mobile

Merchant mode now has **Offers & Promotions**:

- Create an offer.
- View merchant offers.
- Promote an active offer for 100 credits.
- Show active promotion state and end date.
- Surface insufficient-credit and ownership/eligibility failures.

## Acceptance tests

1. Merchant with 120 credits promotes an eligible offer → balance becomes 20.
2. Double submission with the same idempotency key → one campaign and one deduction.
3. Different request against an already-promoted offer → no second active promotion.
4. Offer from another business → rejected.
5. Inactive/expired offer → rejected.
6. Unverified/inactive business → rejected.
7. Promotion ends after 3 days.
8. Public campaign reads expose only active campaigns belonging to active + verified businesses.

## Live RDS

Project: `RDS-NEARBY`

Migrations recorded:
- `phase10_promote_offer`
- `phase10_campaign_rpc_security`

Security Advisor after hardening: no findings.
