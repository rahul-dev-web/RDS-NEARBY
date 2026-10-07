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
flutter run \\
  --dart-define=SUPABASE_URL=<your-project-url> \\
  --dart-define=SUPABASE_ANON_KEY=<your-publishable-key> \\
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
