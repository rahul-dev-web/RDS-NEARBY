# RDS Nearby — Implementation ERD

Status: Phase 0 schema baseline. Relationships below were cross-checked against the live RDS STUDIO Supabase project's public-schema foreign keys on 2026-10-09. This document describes the current schema plus clearly labelled planned scope; it is not a migration.

## Identity and discovery

- `profiles.id → auth.users.id`
- `businesses.owner_id → profiles.id`
- `businesses.category_id → categories.id`
- `categories.parent_id → categories.id`
- `business_products.business_id → businesses.id`
- `business_services.business_id → businesses.id`
- `offers.business_id → businesses.id`
- `campaigns.business_id → businesses.id`
- `campaigns.offer_id → offers.id`

Public discovery must be limited to active + verified businesses and valid public inventory/offers. Business coordinates are required; customer location remains transient unless a future approved use case needs persistence.

## Referral and rewards

- `merchant_referral_tokens.business_id → businesses.id`
- `referrals.referrer_business_id → businesses.id`
- `referrals.referrer_user_id → profiles.id`
- `referrals.referred_user_id → profiles.id`
- `referral_events.referral_id → referrals.id`

Referral lifecycle: PENDING → QUALIFIED | REJECTED | EXPIRED. QR codes use opaque tokens, never raw database IDs. The current public table inventory contains `merchant_referral_tokens`; a separate `customer_referral_tokens` table is **not present in the live schema** and must not be assumed to exist.

Merchant credits:
- `merchant_wallets.merchant_id → businesses.id`
- `merchant_credit_ledger.merchant_id → businesses.id`

Ledger types: REFERRAL_REWARD, BOOST_SPEND, PROMOTE_OFFER_SPEND, ADMIN_ADJUSTMENT, REVERSAL. Balance maximum: 2,000. Credits do not expire. Every reward/spend mutation requires an idempotency key.

Customer points:
- `customer_wallets.customer_id → profiles.id`
- `customer_points_ledger.customer_id → profiles.id`
- `redemptions.customer_id → profiles.id`
- `redemptions.business_id → businesses.id`

Merchant credits and Local Points are separate ledgers. 100 Local Points represent ₹10 reward value, subject to merchant-funded redemption rules.

## Customer requests

- `customer_requests.customer_id → profiles.id`
- `customer_requests.business_id → businesses.id`
- `request_responses.request_id → customer_requests.id`
- `request_responses.business_id → businesses.id`

Request lifecycle: PENDING → ACCEPTED | DECLINED | EXPIRED | CANCELLED | COMPLETED. Requests expire at T+10 minutes unless resolved. The inbox is the source of truth. Request creation/response/cancellation uses ownership-checked backend RPCs.

## Notifications

- `device_tokens.user_id → profiles.id`
- `notification_preferences.user_id → profiles.id`
- `notifications.user_id → profiles.id`

Push is an attention mechanism. `customer_requests` remains the source of truth. High-priority flow: request created → eligibility → notification → T+3 reminder → T+8 reminder → T+10 expiry. FCM end-to-end delivery is not live until Firebase app config, service credentials, secure scheduling, native setup, active tokens and physical-device tests are complete.

## Membership, trust, audit and analytics

- `memberships.business_id → businesses.id`
- `fraud_flags.user_id / reviewed_by → profiles.id`
- `fraud_flags.business_id → businesses.id`
- `fraud_flags.referral_id → referrals.id`
- `audit_logs.actor_id → profiles.id`
- `analytics_events.user_id → profiles.id`
- `analytics_events.business_id → businesses.id`
- `saved_businesses.user_id → profiles.id`
- `saved_businesses.business_id → businesses.id`

## Frozen promotion rules

- `BOOST_SHOP`: 50 Marketing Credits / 24 hours.
- `PROMOTE_OFFER`: 100 Marketing Credits / 3 days.
- Sponsored visibility is labelled and is not an absolute first-position guarantee.
- Campaign spend and campaign creation must be atomic and idempotent.

## Planned scope versus live schema

The table inventory currently includes the core identity, discovery, campaign, referral, wallet/ledger, request, notification, membership, fraud, audit and analytics tables. The following remain feature work even where supporting tables already exist: a complete customer referral UX and reward path, fully tested points redemption, Today's Near You feed with locality/distance handling, analytics completeness, fraud review operations, and membership billing.

## Security boundaries

- RLS is mandatory for exposed public tables.
- Customers access only their own private records.
- Merchants access only their own business records and requests assigned to their businesses.
- Public users read only eligible public discovery content.
- Wallet, ledger, reward, redemption and campaign-spend decisions are server-owned.
- Service-role credentials never enter Flutter or browser code.
- Review authenticated SECURITY DEFINER request RPCs with their grants and body-level authorization checks; do not blindly convert them to SECURITY INVOKER.

## Migration discipline

1. Every schema change is represented by a timestamped SQL migration in `supabase/migrations/`.
2. Migrations are additive by default and preserve existing data.
3. Verify applied migration history against the live database.
4. Enforce financial/reward invariants in PostgreSQL/Edge Functions, not UI.
5. Re-run security and performance advisors after DDL changes.
