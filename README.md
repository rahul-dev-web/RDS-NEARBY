# RDS Nearby

RDS Nearby is a local-commerce discovery platform built around:

> **जो चाहिए, पहले अपने आस-पास देखो।**

## Repository layout

- `mobile/` — Flutter customer + merchant application
- `web/` — Next.js public shop/referral surfaces
- `supabase/` — database and Edge Function configuration
- `docs/` — product, architecture, security and launch specifications

## Stack

Flutter · Supabase · PostgreSQL · Next.js · FCM

## Product baseline

- `docs/PRODUCT_SPEC.md` — scope, terminology and MVP boundary
- `docs/PRODUCT_RULES.md` — frozen reward, credit and request rules
- `docs/ROLES.md` — roles and access boundaries
- `docs/REFERRAL_RULES.md` and `docs/CREDIT_RULES.md` — acquisition and credit economics
- `docs/NOTIFICATION_SPEC.md` — priority, timing, deep links and delivery acceptance tests
- `docs/DATABASE.md` — live table inventory and logical ERD
- `docs/ARCHITECTURE.md` — system boundaries and server-owned workflows

## Development

Mobile:

```bash
cd mobile
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=<your-project-url> \
  --dart-define=SUPABASE_ANON_KEY=<your-publishable-key> \
  --dart-define=PUBLIC_WEB_URL=<your-public-web-origin>
```

`PUBLIC_WEB_URL` must point to the deployed Next.js web origin so merchant referral QR codes resolve to `/r/<opaque-token>`.

Web:

```bash
cd web
npm install
npm run dev
```

Never commit real environment variables or Supabase service-role credentials.
