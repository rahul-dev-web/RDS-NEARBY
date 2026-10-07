# RDS Nearby — Referral Rules

## Purpose

Referrals are a merchant-led and customer-led acquisition mechanism. An install alone never earns a reward.

## Canonical lifecycle

PENDING → QUALIFIED | REJECTED | EXPIRED

All state transitions and rewards are backend-controlled.

## Merchant referral

1. Merchant has one permanent QR identity represented by an opaque referral token.
2. QR opens the public referral route, never a raw database ID.
3. The visitor is attributed to the merchant referral session.
4. Visitor signs up, verifies OTP and completes onboarding.
5. Referral becomes PENDING.
6. Within 48 hours the referred customer must perform at least one meaningful activity.
7. Valid activity: search, shop view, offer view, offer claim, Customer Request, save/favourite, call or WhatsApp.
8. A valid referral becomes QUALIFIED and awards exactly +10 Marketing Credits to the merchant.
9. No qualifying activity by the deadline becomes EXPIRED.
10. Fraud or policy violation becomes REJECTED.

## Customer referral

The same validation model applies. A qualifying friend earns the configured Local Points referral reward exactly once.

## Anti-abuse invariants

- A referred account cannot generate multiple rewards from the same referral attribution.
- Self-referral is rejected.
- Existing-account abuse is rejected according to server-side identity checks.
- Duplicate qualification attempts are idempotent.
- Referral reward cannot exceed the merchant credit balance maximum of 2,000.
- Expired or rejected referrals can never be rewarded later.
- Flutter never calculates or decides reward eligibility.

## Referral events

The immutable event trail includes: QR_SCANNED, SIGNUP, OTP_VERIFIED, ONBOARDING_COMPLETED, MEANINGFUL_ACTIVITY, QUALIFIED, REJECTED, EXPIRED.

## Expiry

The referral qualification window is 48 hours from the server-defined referral expiry timestamp. Expiry processing is backend-owned and must be idempotent.

## Acceptance tests

- New customer completes onboarding and meaningful activity → exactly +10 merchant credits.
- Duplicate qualification request → no second reward.
- No meaningful activity for 48 hours → EXPIRED.
- Fraud/self-referral → REJECTED and no reward.
