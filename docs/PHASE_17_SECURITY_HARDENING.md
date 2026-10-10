# Phase 17 — Fraud & Security Hardening

Status: implementation in progress. The trusted fraud-review mutation is now deployed, but this phase is not production-ready until authorization and business-flow integration tests pass with separate customer, merchant, and admin/service contexts.

## Live baseline verified (2026-10-10)

- Supabase project: `RDS-NEARBY` in the RDS STUDIO ACCOUNT.
- Live project ref: `kkgkvpjcmwfarkdkhcme` (ap-south-1).
- Phase 16 analytics migrations and Phase 17 hardening migrations are recorded in the live database.
- Core tables have RLS enabled.
- Fraud review records had a client-facing `fraud_own_read` policy. It has been removed and direct `anon`/`authenticated` table privileges revoked.
- The live database had no business rows or analytics events at the initial review; populated-data behavior must be verified in a non-production test environment.

## Security goals

1. Keep fraud signals and review metadata private to trusted server-side/admin workflows.
2. Prevent customers and merchants from reading or writing fraud flags directly.
3. Verify every `SECURITY DEFINER` RPC has a fixed search path, explicit caller authentication or a trusted service-only boundary, active profile/role checks, ownership checks, validated inputs, and least-privilege EXECUTE grants.
4. Ensure wallet/ledger writes remain server-owned and idempotent.
5. Ensure admin decisions are auditable and cannot be authorized from user-editable profile metadata.
6. Add fraud detection incrementally; never automatically accuse/suspend a user solely from a weak heuristic.

## Initial database hardening

Migration: `20261010041244_phase17_private_fraud_flags.sql`.

- Drops `fraud_own_read`.
- Revokes direct `anon` and `authenticated` privileges on `public.fraud_flags`.
- Keeps RLS enabled with no client policies, so direct client access is blocked.
- Security Advisor's informational `rls_enabled_no_policy` finding is intentional for this private table; access is via trusted server-side workflows only.

## SECURITY DEFINER RPC review

For each privileged RPC, verify:
- fixed `search_path` (prefer empty path and schema-qualified references);
- no caller-controlled identity parameter is trusted without validation;
- explicit authentication and active profile/role checks where applicable;
- ownership and valid state transition are checked under row lock where concurrent calls matter;
- arguments are bounded and state inputs allowlisted;
- EXECUTE is revoked from `PUBLIC` and `anon` unless a documented public use case exists;
- direct writes to protected tables are revoked from client roles;
- retries cannot duplicate rewards, refunds, campaign spends, or request responses.

### Live RPC hardening applied

1. `20261010042216_phase17_rpc_search_path_hardening` — fixed search path on the five request/redemption RPCs.
2. `20261010045002_phase17_rpc_role_authorization` — active profile/role checks for customer and merchant actions; null decisions and non-finite/negative/excessive prices rejected.
3. `20261010045134_phase17_service_rpc_search_path` — fixed search path on seven service-only campaign, credit, request-queue and trigger helper functions.
4. `20261010050002_phase17_fraud_review_rpc` — added a service-role-only `review_fraud_flag` RPC. It validates an active admin profile, row-locks the flag, permits only `open/reviewing → approved/rejected`, stores a bounded review reason, writes an audit event atomically, rejects conflicting terminal decisions, and makes an identical decision by the same reviewer idempotent.

The `review-fraud-flag` Edge Function is deployed with JWT verification enabled. All 13 public SECURITY DEFINER functions have an empty search path. It reads the authenticated user's profile from the database (not user-editable metadata), requires an active `admin` role, validates the payload, and invokes the service-only RPC. The service-role key is never returned to the caller.

### Advisor interpretation

- Five request/redemption RPCs remain executable by `authenticated` because the Flutter app calls them directly and they contain explicit auth, active-role, ownership, state and input checks. The Advisor warning is therefore a deliberate, documented trade-off—not proof the functions are safe by itself. Integration tests are still required.
- The private `fraud_flags` table has RLS enabled with no client policies by design.
- Performance Advisor's unused-index findings are not acted on during an empty/early pilot; do not drop potentially useful indexes before representative query traffic exists. Multiple permissive-policy warnings are a separate optimization review.

### Profile and business column privileges (additional hardening)

Migration: `20261010070600_phase17_column_privilege_hardening.sql`.

The live RLS review found that row-ownership policies alone did not prevent an owner from attempting to update trusted fields on their own row. Authenticated users now have column-level UPDATE grants only:

- `profiles`: `name`, `phone`, and `avatar_url`.
- `businesses`: merchant-editable profile, location, hours, request-availability, and Local Rewards configuration fields.

Authenticated users cannot update profile `role/status`, business `owner_id/status/verification_status/is_open/updated_at`, or perform table-wide UPDATE. RLS ownership checks still apply to the permitted columns. Trusted admin/service workflows are unaffected. The schema test now asserts both denied protected columns and expected merchant-editable columns.

This closes an escalation path where an authenticated user might otherwise try to self-promote to admin or self-publish/unverify a business through a direct table update. Keep the mobile client aligned with these column grants; if a legitimate field needs to become client-editable, add it explicitly after review rather than restoring table-wide UPDATE.

### Regression test coverage

`supabase/tests/phase17_rpc_security.sql` is a read-only catalog test. It now verifies:
- all public SECURITY DEFINER functions have an empty search path;
- client roles cannot execute service-only RPCs;
- `fraud_flags` has RLS, no policies, and no client table privileges;
- the five app-facing RPCs contain role, ownership and input guards;
- fraud review validates active admins, row-locks the flag and writes audit logs;
- the fraud review RPC is executable only by `service_role`;
- redemption and points-ledger idempotency unique indexes exist.

This catalog test was executed against the live RDS STUDIO database after the fraud-review migration and passed (no exception). It does not substitute for authenticated negative integration tests.

## Required fraud checks

- Self-referral and referral to an existing account.
- Duplicate attribution or duplicate reward.
- Referral expiry before qualification.
- One referred account qualifying multiple referrals.
- Merchant credit cap (2,000) and customer/merchant wallet separation.
- Repeated referral velocity and suspicious repeated reward patterns.
- Reversal must reference a prior transaction and be idempotent.
- Admin review actions record actor, action, entity, reason, and timestamp.

Use deterministic rule-based flags first. Device fingerprinting is not required for MVP and must not collect invasive identifiers without a separately reviewed privacy basis.

## Acceptance tests

### Fraud table and review workflow
1. `anon`, customer and merchant cannot read or mutate `fraud_flags`.
2. Non-admin, inactive-admin, and wrong-role accounts receive 403 from `review-fraud-flag`.
3. A valid active admin can approve/reject an open/reviewing flag with a reason.
4. Same admin repeating the same terminal decision is idempotent and does not duplicate audit logs.
5. A conflicting second decision is rejected.
6. Every successful decision writes exactly one audit event.
7. The service-only RPC is not executable by client roles.

### Authorization regression tests
1. Customer A cannot cancel Customer B's request.
2. Merchant A cannot accept/decline a request assigned to Merchant B.
3. Customer cannot redeem points from another customer's wallet or at their own business.
4. Merchant cannot approve/reject another merchant's redemption.
5. Authenticated clients cannot call campaign-spend or fraud-review RPCs directly.
6. Anonymous clients cannot execute private reward/request RPCs.
7. Replayed idempotency keys do not duplicate deductions/refunds/rewards.
8. Suspended profiles and wrong-role profiles cannot perform customer/merchant actions.
9. Null request decisions and NaN/infinite/negative/excessive prices are rejected.

## Release gate

- Verify migration history and ensure checked-in migration versions match the live project.
- Re-run Security and Performance Advisors.
- Confirm GitHub CI after these commits.
- Run authenticated integration tests with separate customer, merchant, inactive-admin and admin test accounts in a non-production environment.
- Test Edge Function success/denial cases against seeded test flags only; do not create test flags or modify customer data in production.
- Do not call Phase 17 complete until results are recorded here.
