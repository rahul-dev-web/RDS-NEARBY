# Phase 0 — Product Freeze

Status: FROZEN

This repository now treats the Local Commerce Master Implementation Blueprint as the source of truth.

## Frozen proposition
> **जो चाहिए, पहले अपने आस-पास देखो।**

Customer loop: **Need → Nearby shop → Availability/price → Contact/reserve → Buy → Reward → Repeat**
Merchant loop: **Join → Get QR → Bring customers → Earn Marketing Credits → Promote shop/offer → Get more customers**

## Frozen terminology
- Customer reward: Local Points
- Merchant reward: Marketing Credits
- Free visibility: Organic Listing
- Shop promotion: Boost Shop
- Offer promotion: Promote Offer
- Paid merchant plan: Local Business Growth
- User request: Customer Request
- Merchant request availability: Accepting Requests
- The word Feature is not a product term.

## Frozen economics
- Qualified merchant referral: +10 Marketing Credits.
- Merchant credit maximum: 2,000.
- Credits do not expire.
- Boost Shop: 50 credits / 24 hours.
- Promote Offer: 100 credits / 3 days.
- Customer points: 100 points = ₹10 reward value by default.
- Customer rewards are merchant-funded.
- Growth membership: ₹99/month, introduced only after pilot evidence.
- Pilot can run 30–60 days free.

## Frozen referral lifecycle
PENDING → QUALIFIED | REJECTED | EXPIRED

Qualification requires referral attribution, signup, OTP verification, onboarding completion, meaningful activity and validation within 48 hours.
No activity within 48 hours expires the referral.

## Frozen request lifecycle
PENDING → ACCEPTED | DECLINED | EXPIRED | CANCELLED | COMPLETED

- Merchant eligibility requires an active business and accepting_requests = true.
- Reminder at +3 minutes.
- Final reminder at +8 minutes.
- Expiry at +10 minutes.
- Inbox is the source of truth.

## Frozen V1 non-goals
No delivery infrastructure, cash withdrawal, merchant-to-merchant credit transfer, full ERP, complicated checkout, social feed, live chat/video, full marketplace logistics or multiple promotion formats.

## Frozen build order
0. Product Freeze
1. Foundation
2. Auth + Roles
3. Business Onboarding
4. Public Shop/Web
5. Customer Discovery
6. Merchant Referral
7. Customer Referral + Points
8. Merchant Credit Wallet
9. Boost Shop
10. Promote Offer
11. Campaign Ranking
12. Customer Requests + Notifications
13. Today's Near You
14. Points Redemption
15. Business Analytics
16. Fraud + Security Hardening
17. ₹99 Growth Membership
18. Ask Nearby Shops
19. Pilot Expansion

## Phase 0 exit condition
No unresolved core business rule before implementing reward, wallet, campaign or request mutations.

## Implementation guardrail
Every new feature must answer at least one: does this solve a customer's local need, or does it help a merchant acquire/retain customers? If neither is true, it is not part of V1.