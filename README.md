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

See `docs/PRODUCT_SPEC.md`, `docs/PRODUCT_RULES.md` and `docs/ARCHITECTURE.md`.

## Development

Mobile:

```bash
cd mobile
flutter pub get
flutter run
```

Web:

```bash
cd web
npm install
npm run dev
```

Never commit real environment variables or Supabase service-role credentials.
