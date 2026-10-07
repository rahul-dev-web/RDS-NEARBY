# RDS Nearby — Marketing Credit Rules

## Canonical terminology

Merchant reward currency is Marketing Credits.

## Earning

- 1 qualified customer referral = +10 Marketing Credits.
- Credits do not expire.
- Maximum merchant balance = 2,000 credits.

## Spending

| Product | Cost | Duration |
|---|---:|---:|
| Boost Shop | 50 credits | 24 hours |
| Promote Offer | 100 credits | 3 days |

Only these two promotional products exist in V1.

## Wallet invariants

- Balance must never become negative.
- Every balance-changing operation creates an immutable ledger entry.
- Every reward/spend/reversal requires a deterministic idempotency key.
- Historical ledger rows are never edited to repair balances; corrections use reversal/adjustment entries.
- The client cannot directly award, deduct, reverse or set a balance.
- Server-side operations are atomic: validate eligibility → write ledger → update balance/campaign state in one transaction boundary.
- A duplicate request must produce one economic outcome.

## Transaction types

REFERRAL_REWARD, BOOST_SPEND, PROMOTE_OFFER_SPEND, ADMIN_ADJUSTMENT, REVERSAL.

## Boost Shop

Requirements:
- active merchant business
- sufficient balance
- no conflicting active Boost Shop campaign unless the product rules explicitly allow extension
- exactly 50 credits deducted
- campaign active for 24 hours

## Promote Offer

Requirements:
- active merchant business
- eligible offer owned by the merchant
- sufficient balance
- exactly 100 credits deducted
- campaign active for 3 days

## Acceptance tests

- 120 credits + Boost Shop → 70 credits and one campaign.
- Double-click Boost Shop → one campaign and one 50-credit deduction.
- 40 credits + Boost Shop → rejected with no balance change.
- 150 credits + Promote Offer → 50 credits and one campaign.
- Duplicate idempotency key → no second ledger entry or campaign.
