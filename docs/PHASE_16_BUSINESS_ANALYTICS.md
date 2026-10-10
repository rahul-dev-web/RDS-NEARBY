# Phase 16 — Business Analytics

## Delivered

- Added `record_analytics_event(event_name, business_id, metadata)` as an authenticated, SECURITY INVOKER RPC.
- Event names are allowlisted; metadata must be a JSON object no larger than 2 KiB and cannot include keys used for sensitive personal data such as phone, email, customer name, message, address or device token.
- Added indexes for analytics queries by business/event/time and user/event/time.
- Added `get_merchant_business_analytics(business_id, days)`. The public API function is SECURITY INVOKER and delegates to a privileged implementation in the non-public `private` schema. The internal function checks `auth.uid()` against `businesses.owner_id` and returns aggregate metrics only.
- Added a Flutter Merchant → Business Analytics screen with 7-, 30-, and 90-day filters.
- Flutter telemetry currently records non-empty searches, call clicks, WhatsApp clicks and successful Customer Request creation.
- Authenticated visitors to the Next.js public shop page generate shop-view and active-offer exposure events.
- Updated `docs/ANALYTICS.md` and `docs/DATABASE.md`.

## Dashboard metrics

Customer activity:
- Shop views and tracked search-result clicks
- Offers viewed and offer claims
- Call / WhatsApp clicks and saved shops
- Customer Requests received/responded
- Qualified referral customers

Marketing value:
- Referral Marketing Credits earned
- Credits spent on Boost Shop / Promote Offer
- Current Marketing Credits balance
- Boost Shop and Promote Offer campaigns created
- Approved Local Points redemptions and total merchant-funded discounts

Transactional metrics are read from request, referral, wallet/ledger, campaign and redemption tables. They do not depend on client-submitted financial events.

## Migrations applied to RDS Supabase

- `20261010160000_phase16_business_analytics.sql`
- `20261010161000_phase16_analytics_referral_status_fix.sql`
- `20261010162000_phase16_analytics_private_rpc.sql`

Live checks confirmed both public RPCs exist, `record_analytics_event` and the public analytics wrapper are SECURITY INVOKER, authenticated execution is granted, anonymous execution is denied, both analytics indexes exist, and all three Phase 16 migrations are recorded. The aggregate SECURITY DEFINER implementation is in `private`, not the exposed `public` schema.

## Limitations / acceptance tests still needed

- There are currently no real businesses or analytics events in the live database, so populated-data dashboard totals and merchant ownership checks have not been validated with real customer/merchant sessions.
- Anonymous public shop visits are not tracked; current event RPC requires authentication.
- Search-result click tracking, shop-save events, Offer Claims and mobile shop/offer detail views are not fully wired. Corresponding cards may show zero until those product actions exist and emit events.
- Event telemetry is best-effort and client-originated; it can be duplicated or spoofed. Never use it as proof for billing, reward qualification, fraud decisions or membership entitlement.
- GitHub's commit status and PR-filtered workflow lookup returned no CI run for the latest changes. Flutter analyze/tests and web build have **not** been confirmed passing.
- Supabase Security Advisor no longer reports the new analytics aggregate function as an exposed SECURITY DEFINER function. Five older authenticated SECURITY DEFINER request/redemption RPC warnings remain and need separate authorization review.

## Suggested acceptance checks

1. Open a verified shop page while signed in and confirm one `shop_view` event appears.
2. Open a shop with an active offer and confirm an `offer_view` event appears for that business.
3. Use Call, WhatsApp and Customer Request from Flutter; verify the corresponding event or request row appears.
4. Sign in as the business owner and check 7/30/90-day dashboard totals.
5. Sign in as a different merchant and confirm the RPC rejects access to the first merchant's business.
6. Call the analytics RPC as anon and confirm permission is denied.
7. Test with real authenticated accounts in a staging/non-production environment before declaring Phase 16 production-ready.
