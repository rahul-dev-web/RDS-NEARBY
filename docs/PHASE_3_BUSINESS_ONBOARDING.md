# Phase 3 — Business Onboarding

## Implemented

- Merchant-only business creation workflow.
- Server-controlled create-business Edge Function.
- Active category validation against seeded categories.
- Business slug generation with collision handling.
- Mandatory latitude/longitude validation.
- Business phone and WhatsApp fields.
- Address and locality fields.
- Default opening-hours payload.
- New businesses start as pending / pending verification.
- Merchant can read and edit only owned business rows.
- Customer users cannot create businesses.
- Merchant cannot self-promote business status or verification status.
- Business creation is audited in audit_logs.

## Security contract

The Flutter client never decides verification or publication status. The Edge Function validates the authenticated profile and category, then writes the business using the server role.

The database also blocks non-service-role changes to owner_id, status, and verification_status.

## Current limitation

The Phase 3 foundation currently accepts business coordinates as latitude/longitude fields. A provider-abstracted GPS/location picker will be added before the discovery layer depends on live device location.

## Next Phase 3 layer

- Business logo/storage upload
- First products/services
- Business-hours editor
- Merchant business settings
- Verification/admin moderation UI
