# Local Points System

## Economics

- 100 Local Points = ₹10 reward value.
- Points are non-cash.
- Cash withdrawal is not supported.
- Merchant-funded redemption only.
- Platform does not permanently subsidize discounts.

## Merchant controls

Each business can configure:
- Local Rewards: ON/OFF
- Minimum bill
- Maximum discount

A redemption must satisfy the merchant's active limits.

Example:
- Bill = ₹400
- Customer balance = 250 points
- Nominal value = ₹25
- Merchant maximum discount = ₹20
- Maximum discount applied = ₹20
- Customer pays = ₹380

## Ledger

customer_points_ledger is append-only from clients.

Transaction types:
- REFERRAL_REWARD
- PURCHASE_REWARD
- POINT_REDEMPTION
- REVERSAL
- ADMIN_ADJUSTMENT

Every mutation requires an idempotency key.

## Redemption

redeem_points validates:
1. authenticated customer
2. active customer wallet
3. active merchant reward configuration
4. minimum bill
5. maximum discount
6. sufficient point balance
7. idempotency key

Then atomically:
- deduct points
- create redemption record
- record ledger balance_after

Double spending must be impossible.
