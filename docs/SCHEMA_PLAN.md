# RDS Nearby — Database Schema Plan

This document converts the frozen product blueprint into implementation constraints. It is a planning contract; the live Supabase database remains the source of truth for deployed schema.

## Identity

- profiles: auth identity, role, public profile and account status.
- Roles: customer, merchant, admin.
- Authorization is never derived from editable user metadata.

## Supply / discovery

- categories: hierarchical category tree.
- businesses: merchant-owned public business profile, location, hours, request availability and verification state.
- business_products: lightweight product catalogue.
- business_services: lightweight service catalogue.
- offers: merchant-funded offers with validity windows.
- saved_businesses: customer saved shops.

Public discovery must expose only active + verified businesses and valid public content.

## Growth / referrals

- merchant_referral_tokens: one opaque permanent QR identity per business.
- referrals: referral session, attribution, referred user, lifecycle and expiry.
- referral_events: immutable referral audit trail.

Referral state machine: PENDING → QUALIFIED | REJECTED | EXPIRED

## Merchant credits

- merchant_wallets: current balance.
- merchant_credit_ledger: append-only economic history.
- Unique idempotency key per economic mutation.
- Maximum balance: 2,000.

## Customer points

- customer_wallets: current points balance.
- customer_points_ledger: append-only points history.
- redemptions: one auditable redemption record per spend operation.
- Points are non-cash and merchant-funded.

## Customer demand

- customer_requests: direct request to a selected merchant in V1.
- request_responses: future-ready for Ask Nearby Shops.
- Request lifecycle: PENDING → ACCEPTED | DECLINED | EXPIRED | CANCELLED | COMPLETED.

Requests expire at T+10 minutes unless acted upon.

## Promotion

- campaigns: BOOST_SHOP or PROMOTE_OFFER.
- Boost Shop: 50 credits / 24 hours.
- Promote Offer: 100 credits / 3 days.
- Sponsored visibility is a ranking signal, not an absolute first-position guarantee.

## Membership

- memberships: BASIC / GROWTH lifecycle.
- ₹99 Growth activation is deferred until pilot evidence.
- Payment provider fields remain abstract.

## Notifications

- notifications
- notification_preferences
- device_tokens

Customer Request notification eligibility requires an active business, Accepting Requests, an unexpired request and an eligible active device token.

## Trust / audit

- fraud_flags
- audit_logs

Reward reversals and admin corrections create new records; historical economic records are not mutated.

## Analytics

analytics_events records product and business events needed for Local Need Solved and merchant acquisition metrics.

## Security boundary

RLS is mandatory on every exposed table. Customer and merchant ownership is enforced with row predicates. Wallet, reward, redemption, campaign-spend, verification and privileged notification decisions are server-owned.

## Migration discipline

1. Every deployed schema change has a timestamped SQL migration.
2. Prefer additive migrations.
3. Validate existing data before adding restrictive constraints.
4. Run Supabase security/performance advisors after DDL changes.
5. Verify critical invariants with SQL/integration tests.
