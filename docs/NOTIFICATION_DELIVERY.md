# Phase 13 — Customer Request Notification Delivery

## What is deployed

- Edge Function: `deliver-customer-request-notifications` (JWT verification enabled, plus an in-function exact service-role bearer check).
- Database queue migration: `20261009170000_phase13_fcm_delivery_queue.sql`.
- Authenticated token RPC migrations: `20261009190000_phase13_device_token_registration.sql` and `20261009200000_phase13_device_token_invoker_security.sql`.
- Atomic claim uses `FOR UPDATE SKIP LOCKED`, sets a two-minute processing lease, increments delivery attempts, and only claims due customer-request notifications whose request is still pending and unexpired.
- FCM HTTP v1 delivery uses a Firebase service account supplied through the `FCM_SERVICE_ACCOUNT_JSON` Edge Function secret. Credentials are not stored in GitHub or database source.
- Supports high-priority request alerts, 3-minute reminders, and 8-minute final reminders; payload contains a request deep-link path.
- Delivery is marked `sent` only after FCM accepts at least one active device token. Failed attempts are retried with bounded exponential backoff and transition to `failed` after five attempts. Invalid/unregistered tokens are deactivated.
- User notification preferences are checked before sending.
- Missing FCM credentials return a preflight error before claiming any queue rows.

## Required before real push delivery is live

1. In Firebase Console, enable Firebase Cloud Messaging for the Android/iOS app's Firebase project and create a service account with the least privilege required to send FCM messages.
2. Add the full service-account JSON as Supabase Edge Function secret `FCM_SERVICE_ACCOUNT_JSON`. Do not commit the JSON, private key, or any service-role key.
3. Flutter now includes `firebase_core` / `firebase_messaging`, optional initialization, permission request, token refresh registration through authenticated `register_device_token`, and token removal before sign-out through `unregister_device_token`. These RPCs run as `SECURITY INVOKER` under the existing owner RLS policy. **Still required:** run `flutterfire configure` for the real Firebase project and commit only the generated non-secret platform configuration files (never service-account JSON/private keys). This repository currently does not contain the generated Android/iOS platform folders or Firebase configuration, so push token registration remains inactive until platform setup is completed.
4. Add a secure scheduled invocation (for example, `pg_cron` + `pg_net` + Supabase Vault) that POSTs to the deployed function every minute using the service-role bearer secret. In the current project, `pg_net` is not installed and `vault.secrets` is empty, so this scheduler is not yet configured. Never hardcode the service-role key into a migration or repository.
5. The app now reads `requestId` from notification taps, resolves the request's business under the signed-in user's RLS permissions, opens that business's Customer Requests screen, and shows the exact request in an action dialog. Foreground pushes show a tappable in-app alert. Still required: create/register the Android notification channel `local_request` in native Android setup. APNs configuration is separately required for iOS.
6. Run a real-device test for T+0, T+3m, T+8m, accept/decline cancellation, expiry, no-token retry, invalid token deactivation, and user preference suppression.

## Current limitation

The worker and Flutter registration/routing code are deployed, but **push delivery is not yet live**: the live database currently has 0 registered device tokens, Firebase platform configuration and `FCM_SERVICE_ACCOUNT_JSON` have not been configured, the secure scheduled invocation is not installed, and native Android notification-channel/iOS APNs setup is outstanding. Do not describe this phase as end-to-end complete until these steps and real-device tests pass.

## Security and validation notes

- Function has Supabase JWT verification enabled and additionally requires the Authorization bearer value to equal the server-side `SUPABASE_SERVICE_ROLE_KEY`.
- Database queue RPCs revoke execution from `public`, `anon`, and `authenticated`; only `service_role` can claim or finish delivery.
- Queue and token-registration migrations were applied to the RDS STUDIO ACCOUNT project. Live token-RPC privileges and the security advisor were checked after the changes.
- Flutter/Next.js build checks and device-level FCM tests have not been run in this environment.
