# Phase 1 — Repository & Development Foundation

Status: IN PROGRESS

## Frozen repository contract

- `mobile/` is the single Flutter app for Customer + Merchant modes.
- `web/` is the Next.js public discovery, shop, referral and SEO surface.
- `supabase/` contains migrations, Edge Functions and Supabase configuration.
- `docs/` contains the frozen product and implementation contract.

## Environment contract

### Flutter

Runtime configuration is supplied only through Dart defines:

- `APP_ENVIRONMENT`: development | staging | production
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

The publishable/anon key is safe for client initialization only when paired with correct RLS. Service-role credentials must never enter Flutter.

### Web

Runtime configuration:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_APP_URL`

No service-role secret is allowed in browser code.

## CI contract

GitHub Actions validates:

1. Web dependency installation, TypeScript and production build.
2. Flutter dependency installation, static analysis and tests.
3. Presence of the frozen Phase 0 product documents.

The CI workflow pins Flutter to the repository's current 3.44.8 development baseline.

## Supabase contract

Project configuration is tracked in `supabase/config.toml`.

All database changes must be represented by timestamped migrations under `supabase/migrations/`.

Reward, wallet, campaign, redemption and request-expiry decisions remain server-owned.

## Phase 1 exit criteria

- Repository structure is stable.
- Environment configuration is documented.
- CI runs web + mobile validation.
- Supabase project configuration is tracked.
- No secret credentials are committed.

## Current blocker

The connected Supabase RDS STUDIO ACCOUNT is currently rejected by the Supabase connector as an ineligible linked account. Until that connector authorization is repaired, live RDS database introspection/migrations cannot be truthfully marked complete from ChatGPT. The implementation must not switch to another Supabase account or project.
