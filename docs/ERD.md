# RDS Nearby — Implementation ERD

This document is the implementation baseline for the frozen Local Commerce blueprint.

## Identity
- profiles.id → auth.users.id
- profiles.role → customer | merchant | admin
- businesses.owner_id → profiles.id
- businesses.category_id → categories.id

## Supply / discovery
categories → businesses → business_products / business_services / offers / campaigns / customer_requests / request_responses / redemptions / memberships / merchant_referral_tokens

Public discovery reads only active/verified businesses and valid public content.

## Referral
merchant_referral_tokens → referrals → referral_events

Referral lifecycle: PENDING → QUALIFIED | REJECTED | EXPIRED.
The merchant QR stores an opaque token, never a raw database identifier.

## Merchant credits
businesses → merchant_wallets → merchant_credit_ledger

Ledger transaction types: REFERRAL_REWARD, BOOST_SPEND, PROMOTE_OFFER_SPEND, ADMIN_ADJUSTMENT, REVERSAL.
Balance maximum: 2,000. Credits do not expire.
Every reward/spend mutation requires an idempotency key.

## Customer points
profiles → customer_wallets → customer_points_ledger → redemptions

Points are non-cash. Default value is 100 points = ₹10 reward value, subject to merchant-funded minimum-bill and maximum-discount rules.

## Customer requests
profiles (customer) → customer_requests → request_responses

Request lifecycle: PENDING → ACCEPTED | DECLINED | EXPIRED | CANCELLED | COMPLETED.
Requests expire at T+10 minutes unless acted upon.
Merchant eligibility requires an active business and accepting_requests = true.

## Notifications
profiles → device_tokens / notification_preferences / notifications

Push is an attention mechanism. customer_requests remains the source of truth.
High priority flow: request_created → eligibility → notification → +3m reminder → +8m reminder → +10m expiry.

## Promotions
businesses → campaigns → optional offers

Campaign types are frozen to BOOST_SHOP (50 credits / 24 hours) and PROMOTE_OFFER (100 credits / 3 days).
Sponsored visibility is a ranking input, not an absolute first-position guarantee.

## Membership
businesses → memberships

Plans: BASIC ₹0 and GROWTH ₹99/month after pilot validation.
Payment integration is deferred until the pilot proves merchant value.

## Trust / audit
profiles → fraud_flags
profiles → audit_logs

Fraud and privileged actions must be auditable. Reward reversals create ledger/audit records rather than mutating historical entries.

## Analytics
profiles / businesses / offers → analytics_events

Core events cover search, shop view, contact, request lifecycle, referral lifecycle, credit/points lifecycle, campaign lifecycle and membership lifecycle.

## Security boundaries
- RLS is mandatory for exposed public tables.
- Customers can access only their own private records.
- Merchants can access only their owned business records.
- Public users can read only verified/active public discovery content.
- Wallet, ledger, reward, redemption and campaign-spend decisions are server-owned.
- Service-role credentials never enter Flutter or browser code.

## Migration discipline
1. Every schema change is represented by a timestamped SQL migration in supabase/migrations/.
2. Migrations are additive by default.
3. Existing data must remain valid.
4. Financial/reward invariants are enforced in PostgreSQL/Edge Functions, not UI.
5. After DDL changes, security/performance advisories must be checked.