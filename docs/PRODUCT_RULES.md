# RDS Nearby — Product Rules

## Rewards
- Merchant: 1 qualified customer = +10 Marketing Credits.
- Merchant credit balance maximum = 2,000.
- Marketing Credits do not expire.
- Customer: 100 Local Points = ₹10 reward value.
- Customer points are non-cash and merchant-funded at redemption.

## Redemption
Merchant configures minimum bill and maximum discount.
Platform does not permanently subsidize merchant-funded rewards.
Example: 250 points on a ₹400 bill with ₹20 maximum discount produces at most ₹20 discount.

## Referral validation
1. QR/referral link attribution
2. Signup
3. OTP verification
4. Onboarding complete
5. PENDING
6. Meaningful activity
7. 48-hour validation
8. QUALIFIED and reward, or REJECTED/EXPIRED

All reward decisions are backend-controlled and idempotent.

## Requests
Customer requests expire after 10 minutes unless acted upon.
Merchant eligibility requires the business to be active and Accepting Requests.
Notification reminders: immediate, +3 minutes, +8 minutes; expiry at +10 minutes.
The request inbox is the source of truth; push notifications are an attention mechanism.

## Security
Flutter clients must never directly award/reverse credits or points, redeem points, or create paid campaigns without server-side validation.
Every reward/financial mutation requires an idempotency key.
