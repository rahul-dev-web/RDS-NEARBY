# Campaign System

## Only two promotion products

### Boost Shop
- Cost: 50 Marketing Credits
- Duration: 24 hours
- Promotes the business

### Promote Offer
- Cost: 100 Marketing Credits
- Duration: 3 days
- Promotes one offer

No additional V1 ad formats.

## Rules

- Campaign creation is server-controlled.
- Balance must be checked and deducted atomically.
- Every spend has an idempotency key.
- Sponsored results must be clearly labelled.
- Sponsored signal is moderate; it cannot create an absolute monopoly over discovery.
- Expired campaigns must stop affecting ranking.

## Campaign types

BOOST_SHOP
PROMOTE_OFFER

## Required fields

campaigns:
- business_id
- campaign_type
- credit_cost
- starts_at
- ends_at
- status
- target_radius_km
- offer_id for Promote Offer

## Failure safety

Rapid duplicate clicks must produce one campaign and one ledger deduction.
