# RDS Nearby — Local Points System

## Purpose

Local Points are the customer-side, non-cash reward currency. They encourage genuine local discovery and referrals without creating a cash-withdrawal wallet.

## Canonical value

**100 Local Points = ₹10 reward value**

Points do not represent cash and cannot be withdrawn.

## Earning

Phase 7 starts with customer referral rewards:
- 1 qualified customer referral = +10 Local Points to the referring customer.
- Reward is issued only after the referred account passes the same 48-hour qualification flow used for merchant referrals.
- Reward operations are server-owned and idempotent.

Future earning source:
- PURCHASE_REWARD may be added only when the corresponding merchant-funded purchase/reward flow is implemented.

## Wallet

`customer_wallets` stores the current balance.

`customer_points_ledger` is append-only and records REFERRAL_REWARD, PURCHASE_REWARD, POINT_REDEMPTION, REVERSAL and ADMIN_ADJUSTMENT.

Clients can read their own wallet and ledger but cannot insert, update, delete or set balances.

## Redemption economics

Default value: 100 points = ₹10 reward value.

Merchant controls Local Rewards ON/OFF, minimum bill and maximum discount.

Example: Bill ₹400, customer has 250 points, merchant maximum discount ₹20 → maximum applied discount ₹20 → final bill ₹380.

The platform does not permanently subsidize these discounts.

## Security

- Customer wallet is isolated from merchant Marketing Credits.
- Every balance-changing operation uses an idempotency key.
- Historical ledger entries are never edited to repair balances.
- Redemption must be server-side and atomic.
- No cash-out endpoint exists in V1.
