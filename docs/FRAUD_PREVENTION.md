# Fraud Prevention

Credits and points have economic value, so reward abuse is a first-class security concern.

## Referral checks

- self-referral
- existing-account attribution
- duplicate referral
- duplicate reward
- rapid referral velocity
- suspicious device/account patterns
- repeated reward patterns
- referral activity quality

## Referral lifecycle

PENDING
→ QUALIFIED
or REJECTED
or EXPIRED

No reward may be issued from an EXPIRED or REJECTED referral.

## Fraud workflow

Flagged
→ Review
→ Approve / Reject
→ Reverse reward when required

## Data

fraud_flags records:
- user
- referral
- business
- risk type
- severity
- reason
- metadata
- reviewer
- review time

All privileged fraud decisions are audited.
