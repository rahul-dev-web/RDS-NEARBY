# RDS Nearby — Database & ERD Baseline

## Identity
`profiles`
- id → auth.users
- role: customer | merchant | admin
- name, phone, avatar_url, status

## Discovery supply
`categories`
- hierarchical category tree

`businesses`
- owner_id → profiles
- category_id → categories
- name, slug, description
- phone, whatsapp
- lat, lng, address, locality_id
- opening_hours
- is_open
- accepting_requests
- logo_url
- local_rewards_enabled
- rewards_min_bill
- rewards_max_discount
- status, verification_status

`business_products`
- business_id → businesses
- name, description, price, unit
- is_available, status

`business_services`
- business_id → businesses
- name, description, price, duration_minutes
- is_available, status

`offers`
- business_id → businesses
- title, description, regular_price, offer_price
- image_url, starts_at, ends_at, status

## Growth / referral
`merchant_referral_tokens`
- business_id → businesses
- opaque token
- one active QR identity per business

`referrals`
- referrer user/business
- referred user
- referral token/session
- PENDING / QUALIFIED / REJECTED / EXPIRED
- qualified_at / expires_at

`referral_events`
- referral_id
- event type + metadata
- immutable audit trail

## Rewards
`merchant_wallets`
`merchant_credit_ledger`

Merchant ledger types:
- REFERRAL_REWARD
- BOOST_SPEND
- PROMOTE_OFFER_SPEND
- ADMIN_ADJUSTMENT
- REVERSAL

`customer_wallets`
`customer_points_ledger`

Customer ledger types:
- REFERRAL_REWARD
- PURCHASE_REWARD
- POINT_REDEMPTION
- REVERSAL
- ADMIN_ADJUSTMENT

All financial/reward ledger mutations require idempotency keys.

## Promotions
`campaigns`
- business_id
- campaign_type: BOOST_SHOP | PROMOTE_OFFER
- credit_cost
- starts_at / ends_at
- status
- target_radius_km
- optional offer_id

## Customer demand
`customer_requests`
- customer_id → profiles
- business_id → businesses
- request_type
- title / description
- PENDING / ACCEPTED / DECLINED / EXPIRED / CANCELLED / COMPLETED
- expires_at

`request_responses`
- request_id
- business_id
- response type / price / message / status

`redemptions`
- customer_id
- business_id
- points_used
- discount_value
- bill_amount
- final_amount
- status

## Membership / trust
`memberships`
- business_id
- BASIC | GROWTH
- lifecycle status
- provider abstraction fields

`fraud_flags`
- user/referral/business risk records

`audit_logs`
- actor
- action
- entity
- metadata

## Notifications
`notification_preferences`
- customer requests
- urgent requests
- reviews
- credits
- offers
- vibration
- quiet hours

`device_tokens`
- user_id
- token
- platform
- app version
- active/last seen

`notifications`
- recipient
- priority
- type
- related entity
- scheduled/sent/read timestamps

## Analytics
`analytics_events`
- optional user/business
- event name
- metadata
- created_at

## Relationship map

```text
profiles
  ├──< businesses
  │      ├──< business_products
  │      ├──< business_services
  │      ├──< offers
  │      ├──< campaigns
  │      ├──< customer_requests
  │      ├──< request_responses
  │      ├──< redemptions
  │      ├──< memberships
  │      └── merchant_referral_tokens
  │
  ├── merchant_wallets ──< merchant_credit_ledger
  ├── customer_wallets ──< customer_points_ledger
  ├──< referrals ──< referral_events
  ├──< customer_requests
  ├──< saved_businesses >── businesses
  ├──< notifications
  ├── notification_preferences
  └──< device_tokens

businesses ──< analytics_events
profiles   ──< analytics_events
```

## Security boundary

All public discovery tables use RLS. Public discovery is limited to active + verified businesses and valid public content. Merchant-owned data uses ownership predicates. Wallet/ledger and privileged state mutations are backend-only.

## Current schema note

The current database already contains the core domain tables and indexes. Search/ranking indexes should be tuned after real query patterns exist rather than adding speculative indexes.
