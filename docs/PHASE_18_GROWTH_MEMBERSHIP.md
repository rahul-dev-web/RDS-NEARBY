# Phase 18 — Local Business Growth Membership

## Frozen business rules

- Basic: ₹0, basic business profile and organic listing.
- Local Business Growth: ₹99/month, planned to include referral QR, Marketing Credits, Boost Shop, Promote Offer, offers, Customer Requests, analytics, and Local Points participation.
- Paid launch is gated on pilot evidence showing measurable customer acquisition/value; do not start billing immediately after code is complete.
- A 30–60 day free pilot is the intended launch approach.
- The existing `public.memberships` table is the source of truth. Do not create a duplicate membership table.
- Payment integration remains inactive until the provider and launch decision are approved.

## Implemented in this slice

- Added `MerchantMembershipScreen` at `mobile/lib/features/merchant/merchant_membership_screen.dart`.
- Added Membership to each merchant business' action menu in `mobile/lib/features/auth/auth_gate.dart`.
- The screen reads the most recently created membership row for the selected business and displays plan, status, start date, and expiry when present.
- When no membership row exists, the screen displays Basic / ₹0 without inserting a row or fabricating a subscription.
- Displays the frozen Basic and Growth benefits.
- Subscription activation is intentionally disabled. The screen does not collect payment details, create a paid membership, or claim a payment succeeded.
- Membership read failures have an explicit retry state.

## Access-control boundary

This is a pilot-safe membership visibility foundation, not the full paid entitlement rollout. Existing merchant features must remain usable during the free pilot unless a separately approved pilot rule says otherwise. Do not enforce paid feature restrictions or alter membership records from the Flutter client.

Before enabling subscriptions, implement a trusted server-side payment-provider abstraction that verifies provider webhooks and transitions membership state idempotently. The client must never be the authority for a paid/active status.

## Next implementation work

1. Define a provider-neutral subscription lifecycle contract (create checkout, verify webhook, cancel, renew, past-due, expire).
2. Add trusted server-side processing with signature verification and idempotent provider-event storage.
3. Define feature entitlements centrally and enforce them server-side where a paid entitlement matters; keep free pilot access explicit.
4. Add merchant cancellation/manage-subscription flow only when the provider and commercial launch decision are selected.
5. Enable paid activation only after pilot evidence and real integration testing.

## Validation status

- No Flutter build, static analysis, or UI tests were run for this slice, per the instruction to defer polishing/testing until feature implementation progresses.
- No membership rows, business rows, or payment state were modified in the live database.
- Do not treat this slice as production-ready billing or as completion of the full membership phase.
