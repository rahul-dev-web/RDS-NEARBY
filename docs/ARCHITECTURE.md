# RDS Nearby — Architecture

## Stack
- Flutter: customer + merchant modes in one app
- Supabase: Auth, PostgreSQL, Storage, Realtime, Edge Functions
- Next.js: public shop pages, referral landing pages, SEO and deep-link fallback
- FCM: push notifications

## Layers
Flutter → Supabase Auth/Data API → PostgreSQL/RLS
Flutter → Edge Functions → reward/wallet/request/notification workflows
Next.js → public business/referral surfaces → app deep links

## Server-owned workflows
- qualify_referral
- award_merchant_credit
- award_customer_points
- consume_merchant_credits
- create_campaign
- redeem_points
- expire_referral
- expire_request
- send_request_notification
- process_membership

These are domain operations, not client-side business rules.

## Repository
mobile/
web/
supabase/
docs/

Environments:
development, staging, production.

## Security principles
- RLS on every exposed public table.
- Use auth.uid() ownership predicates.
- Do not authorize from user-editable user_metadata.
- Never expose service/secret keys to Flutter or browser clients.
- Keep reward ledgers append-only from clients.
- Audit privileged mutations.
