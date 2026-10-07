# Phase 0 / Phase 1 / Phase 2 / Phase 3 Checklist

## Phase 0 — Product Freeze
- [x] Terminology frozen
- [x] Reward rules frozen
- [x] 48-hour referral rule frozen
- [x] Promotion products frozen
- [x] Request states frozen
- [x] Notification priority model frozen
- [x] Core database domain model defined

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
- [x] Edge Functions (initial role workflow)

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
- [ ] Logo upload
- [ ] Product/service onboarding
- [ ] Hours editor
- [ ] Admin verification UI
- [ ] Provider-abstracted location picker

## Database hardening
- [x] Missing foreign-key indexes added
- [x] Business ownership indexes reviewed
- [ ] RLS policy consolidation review
- [ ] Search/ranking indexes after real query patterns exist

## Current status
Phase 3 foundation is implemented. Next: merchant catalog/settings, then Phase 4 public shop/web.
