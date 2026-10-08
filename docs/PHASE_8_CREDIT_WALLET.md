# Phase 8 — Merchant Credit Wallet

## Goal

Give each merchant a transparent, read-only wallet view for Marketing Credits while keeping every balance mutation server-owned.

## User-facing surface

Merchant → Business → Marketing Credits

The wallet shows:
- current balance
- 2,000-credit maximum
- qualified referral earning rule (+10)
- Boost Shop cost (50 / 24 hours)
- Promote Offer cost (100 / 3 days)
- latest ledger activity

## Security

The Flutter client may only read:
- its own merchant wallet
- its own merchant credit ledger

The client must never:
- insert ledger rows
- update wallet balance
- delete ledger rows
- choose reward amounts
- deduct credits directly

RLS ownership remains the access boundary. Reward/spend operations remain PostgreSQL/Edge Function responsibilities.

## Invariants

- balance >= 0
- balance <= 2,000
- every balance mutation has one immutable ledger row
- every balance mutation uses an idempotency key
- duplicate requests produce one economic outcome
- corrections use REVERSAL or ADMIN_ADJUSTMENT; historical rows are not edited

## Acceptance checks

1. A merchant with no wallet sees 0 credits.
2. A qualified referral increases the wallet by exactly 10.
3. Ledger order is newest first.
4. A merchant cannot read another merchant's wallet.
5. A merchant cannot write wallet or ledger rows through the client.
6. Wallet UI never contains a direct balance mutation path.

## Next

Phase 9 implements the server-owned Boost Shop campaign flow:
- active/verified merchant validation
- 50-credit atomic deduction
- 24-hour campaign
- idempotency protection
- one active/conflicting campaign rule
- campaign lifecycle and audit events
