# Phase 15 — Local Points Redemption

Status: Initial customer redemption and merchant resolution flows implemented; populated-data and device acceptance tests remain required.

## Frozen economics

- 100 Local Points = ₹10 of reward value.
- Customer points are non-cash and cannot be withdrawn.
- Each business funds its own discount.
- Only active, verified businesses with Local Rewards enabled and valid reward limits can accept redemptions.
- Bill amount must meet the merchant's configured minimum bill.
- Discount is capped by requested point value, merchant maximum discount, and bill amount. Whole-point rounding rounds down to the nearest 10 paise so the final discount never exceeds the configured cap.
- Only the points corresponding to the actual discount are deducted. Example: a requested 250 points at a shop with a ₹20 cap results in ₹20 discount and 200 points spent.
- Customer cannot redeem at their own business.

## Database contract

Migrations:
- `20261010120000_phase15_points_redemption.sql`
- `20261010121000_phase15_redemption_resolution.sql`
- `20261010122000_phase15_redemption_action_validation.sql` (rejects null/invalid merchant actions)
- `20261010123000_phase15_discount_rounding.sql` (ensures whole-point rounding never exceeds the merchant cap)

RPCs:
- `public.redeem_customer_points(p_business_id, p_bill_amount, p_points_to_redeem, p_idempotency_key)`
- `public.respond_to_point_redemption(p_redemption_id, p_action)`

Both are restricted to authenticated callers, use a fixed empty search path, verify ownership/eligibility, and perform writes inside a database transaction. The first RPC uses a customer-wallet row lock, a unique customer/idempotency key, and a unique ledger key so a retry does not spend points twice. Direct client writes to wallet, points ledger, and redemption tables are revoked.

## State and merchant flow

- New redemption: `pending`.
- Merchant approves: `active`.
- Merchant rejects: `inactive`, and the points are returned through a positive `reversal` ledger entry.
- Only the owner of the target business can approve or reject its redemption.
- Repeated responses do not repeat a refund. Critical decisions are written to `audit_logs`.

## Flutter

- Customer's Local Points & Referral screen displays wallet balance and participating shops.
- Customer enters the bill and points; server calculates the actual discount and returns a redemption code.
- Customer shows the code to the shop for confirmation.
- Merchant inbox lets the owner review pending redemptions and approve/reject them.
- Wallet reads use the actual `customer_wallets.customer_id` column.

## Acceptance tests still required

1. Reject unauthenticated, non-customer, suspended, unverified, inactive, and non-participating business requests.
2. Reject bills below minimum and points above wallet balance.
3. 250 points + ₹400 bill + ₹20 cap → ₹20 discount, 200 points spent.
4. Two simultaneous requests cannot produce a negative wallet balance.
5. Repeating the same idempotency key returns the original redemption without another ledger entry.
6. Only the owning merchant can resolve a redemption.
7. Merchant rejection refunds once; repeated rejection does not add another refund.
8. Merchant approval cannot be applied to a resolved redemption.
9. Verify wallet/ledger/redemption rows and audit events in a non-production test account.
10. Flutter analyze, unit/widget tests, and device testing are required before production readiness.

## Known boundary

This phase records a pending redemption before merchant confirmation, as specified in the current product flow. The merchant must approve the code before applying the discount at checkout. No platform-funded subsidy or cash-out is implemented.
