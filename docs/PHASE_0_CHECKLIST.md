# Phase 0–3 Implementation Checklist

## Phase 0 — Product Freeze
- [x] Terminology frozen
- [x] Reward rules frozen
- [x] 48-hour referral rule frozen
- [x] Promotion products frozen
- [x] Request states frozen
- [x] Notification priority model frozen
- [x] Core database domain model defined
- [x] Product specification documented
- [x] Product rules documented
- [x] Architecture documented
- [x] Database / ERD baseline documented
- [x] RLS contract documented
- [x] Referral, credit, points, campaign, notification, analytics and fraud docs documented

## Phase 1 — Foundation
- [x] GitHub repository verified
- [x] Supabase project verified
- [x] Core schema applied
- [x] RLS enabled across core public tables
- [x] Security advisor checked
- [x] Flutter application shell
- [x] Next.js web shell
- [x] Supabase client configuration
- [x] Environment example files
- [x] CI foundation
- [x] Auth implementation
- [x] Seed categories
- [x] Initial Edge Function workflow

## Phase 2 — Authentication + Roles
- [x] Phone OTP flow
- [x] Profile bootstrap trigger
- [x] Customer / Merchant initial role workflow
- [x] Server-controlled role transition
- [x] Role-aware Flutter auth gate

## Phase 3 — Business Onboarding
- [x] Merchant-only business creation
- [x] Category validation
- [x] Business profile fields
- [x] Location coordinates required
- [x] Phone / WhatsApp
- [x] Address / locality
- [x] Default opening-hours payload
- [x] Pending verification state
- [x] Ownership RLS
- [x] Status / verification privilege protection
- [x] Business creation audit log
- [x] Logo URL schema field
- [x] Local Rewards configuration schema
- [x] Permanent opaque merchant QR identity schema
- [x] create-business Edge Function v2 creates merchant QR identity
- [ ] Logo storage/upload UI
- [x] Product/service onboarding UI
- [x] Hours editor UI
- [x] Merchant settings UI
- [ ] Admin verification UI
- [ ] Provider-abstracted location picker

## Database hardening
- [x] Missing foreign-key indexes added
- [x] Business ownership indexes reviewed
- [x] Security Advisor checked after Phase 3 schema
- [ ] RLS policy consolidation review
- [ ] Search/ranking indexes after real query patterns exist

## Current status

Phase 0 documentation and the Phase 1–3 backend foundation are in place. Merchant onboarding UI is now complete for products/services, settings, and weekly hours. The next implementation target is the provider-abstracted location layer and Phase 4 public shop/web.
