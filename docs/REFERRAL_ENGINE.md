# RDS Nearby — Referral Engine Implementation

The Phase 6 merchant referral path is now represented in the repository as server-owned infrastructure.

## Server flow

1. Merchant QR contains the opaque `merchant_referral_tokens.token`.
2. Public referral route forwards the token into the app.
3. Authenticated app calls `create-referral` after the referred customer is signed in/onboarded.
4. The function creates exactly one attribution for the referred account.
5. Customer activity is sent through `record-referral-activity`.
6. The function records a meaningful activity event and calls the database `qualify_referral` function.
7. The database transaction locks the referral and merchant wallet, awards at most the allowed reward, writes an idempotent ledger row, and marks the referral QUALIFIED.
8. A pending referral expires after 48 hours through the backend expiry function.

## Server-owned invariants

- Flutter never awards credits.
- Self-referral is rejected.
- One referred account can have only one referral attribution.
- Reward operations require an idempotency key.
- Credit history is append-only.
- Referral states are PENDING, QUALIFIED, REJECTED or EXPIRED.
- Expired/rejected referrals cannot be rewarded later.

## Edge Functions

- `create-referral`
- `record-referral-activity`

The qualification and expiry primitives are PostgreSQL functions invoked by trusted server-side code.

## Mobile integration

- `MerchantReferralScreen` reads the merchant-owned opaque token and renders the QR.
- The QR URL is built from the `PUBLIC_WEB_URL` Dart define; the production domain is never hardcoded in the app.
- Merchant home exposes the screen as `Invite Customers`.
- Customer discovery records `SEARCH` as meaningful referral activity through `ReferralActivityService`.
- Referral activity failures are intentionally non-blocking so discovery remains usable even if the referral service is temporarily unavailable.

## Deployment note

The repository implementation is ready for Supabase deployment. Live migration/function deployment still requires an eligible Supabase RDS connector; the current connected RDS account is not accepted by the Supabase connector, so no live production mutation is claimed from this commit.
