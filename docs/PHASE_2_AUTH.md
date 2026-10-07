# Phase 2 — Authentication + Roles

## Implemented

- Phone OTP authentication through Supabase Auth.
- Automatic profile bootstrap after auth.users creation.
- Customer profile setup with name.
- Initial role selection: Customer or Merchant.
- Role changes are server-controlled through set-initial-role.
- Profile role and status cannot be changed by a normal authenticated client.
- Role-aware Flutter auth gate.
- Customer and Merchant app shells are separated by role.

## Security rules

- Flutter never writes a merchant/admin role directly.
- The set-initial-role Edge Function requires an authenticated user JWT.
- Only the initial customer -> merchant transition is allowed.
- Existing merchant/admin roles cannot be overwritten by the client flow.
- Profile privilege changes are blocked by a database trigger unless the request is service-role controlled.

## Remaining Phase 2 work

- Locality selection/fallback during discovery onboarding.
- Production SMS provider configuration and OTP delivery testing.
- Merchant onboarding/business creation belongs to Phase 3.
