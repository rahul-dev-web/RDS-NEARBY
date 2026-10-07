# Referral System

## Token
Merchant QR uses an opaque referral token, never a raw database ID.

Example:
https://yourdomain.com/r/7F82K9X

## Flow
QR → public referral/shop page → app/deep link or web install → signup → OTP → onboarding → activity → 48h validation → reward.

## States
PENDING
QUALIFIED
REJECTED
EXPIRED

## Events
QR_SCANNED
SIGNUP
OTP_VERIFIED
ONBOARDING_COMPLETED
MEANINGFUL_ACTIVITY
QUALIFIED
REJECTED
EXPIRED

## Anti-abuse
- Unique attribution
- Self-referral detection
- Existing-account checks
- Device/account velocity checks
- Fraud flags
- Idempotent rewards
- Ledger/audit trail
