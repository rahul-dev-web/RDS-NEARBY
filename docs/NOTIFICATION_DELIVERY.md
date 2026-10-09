# Phase 13 — Customer Request Notification Delivery

## What is deployed

- Edge Function: `deliver-customer-request-notifications` (JWT verification enabled, plus an in-function exact service-role bearer check).
- Database queue migration: `20261009170000_phase13_fcm_delivery_queue.sql`.
- Atomic claim uses `FOR UPDATE SKIP LOCKED`, sets a two-minute processing lease, increments delivery attempts, and only claims due customer-request notifications whose request is still pending and unexpired.
- FCM HTTP v1 delivery uses a Firebase service account supplied through the `FCM_SERVICE_ACCOUNT_JSON` Edge Function secret. Credentials are not stored in GitHub or database source.
- Supports high-priority request alerts, 3-minute reminders, and 8-minute final reminders; payload contains a request deep-link path.
- Delivery is marked `sent` only after FCM accepts at least one active device token. Failed attempts are retried with bounded exponential backoff and transition to `failed` after five attempts. Invalid/unregistered tokens are deactivated.
- User notification preferences are checked before sending.
- Missing FCM credentials return a preflight error before claiming any queue rows.

## Required before real push delivery is live

1. In Firebase Console, enable Firebase Cloud Messaging for the Android/iOS app's Firebase project and create a service account with the least privilege required to send FCM messages.
2. Add the full service-account JSON as Supabase Edge Function secret `FCM_SERVICE_ACCOUNT_JSON`. Do not commit the JSON, private key, or any service-role key.
3. The current Flutter `pubspec.yaml` and app bootstrap do not yet include Firebase initialization or `firebase_messaging` token registration. Add the Firebase Android/iOS configuration, initialize Firebase, request notification permission, register/refresh FCM tokens in `public.device_tokens` using the authenticated user's session, and deactivate tokens on sign-out. Until this mobile work is complete, the worker will find no active device tokens for those users.
4. Add a secure scheduled invocation (for example, `pg_cron` + `pg_net` + Supabase Vault) that POSTs to the deployed function every minute using the service-role bearer secret. In the current project, `pg_net` is not installed and `vault.secrets` is empty, so this scheduler is not yet configured. Never hardcode the service-role key into a migration or repository.
5. Verify the app registers the Android notification channel `local_request` and routes the `deepLink` / `requestId` payload to the exact request screen. APNs configuration is separately required for iOS.
6. Run a real-device test for T+0, T+3m, T+8m, accept/decline cancellation, expiry, no-token retry, invalid token deactivation, and user preference suppression.

## Current limitation

The worker is deployed, but **push delivery is not yet live** because FCM credentials have not been verified/configured and the scheduled invocation is not installed. Do not describe this phase as end-to-end complete until both steps and real-device tests pass.

## Security and validation notes

- Function has Supabase JWT verification enabled and additionally requires the Authorization bearer value to equal the server-side `SUPABASE_SERVICE_ROLE_KEY`.
- Database queue RPCs revoke execution from `public`, `anon`, and `authenticated`; only `service_role` can claim or finish delivery.
- Database migration was applied to the RDS STUDIO ACCOUNT project. A live schema/grant verification and advisor review are the next validation step.
- Flutter/Next.js build checks and device-level FCM tests have not been run in this environment.
