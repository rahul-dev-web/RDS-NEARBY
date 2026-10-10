# Phase 17 — Fraud & Security Hardening

Status: implementation started. This phase is not production-ready until the acceptance tests below pass with separate customer, merchant, and admin/service contexts.

## Live baseline verified (2026-10-10)

- Supabase project: `RDS-NEARBY` in the RDS STUDIO ACCOUNT / Rahul Dev Studio organization.
- Live project ref: `kkgkvpjcmwfarkdkhcme` (ap-south-1).
- Phase 16 analytics migrations are recorded in the live database.
- Core tables have RLS enabled.
- Fraud review records had a client-facing `fraud_own_read` policy. It has been removed and direct `anon`/`authenticated` table privileges revoked; fraud flags should not be exposed to the account being reviewed.
- The live database currently has no business rows and no analytics events, so populated-data behaviour has not been proven.

## Security goals

1. Keep fraud signals and review metadata private to trusted server-side/admin workflows.
2. Prevent customers and merchants from reading or writing fraud flags directly.
3. Verify every SECURITY DEFINER RPC has a fixed search path, explicit caller authentication, active profile/role checks, ownership checks, validated inputs, and least-privilege EXECUTE grants.
4. Ensure wallet/ledger writes remain server-only and idempotent.
5. Ensure admin decisions are auditable and cannot be authorized from user-editable profile metadata.
6. Add fraud detection incrementally; never automatically accuse/suspend a user solely from a weak heuristic.

## Initial database hardening

Migration: `20261010041244_phase17_private_fraud_flags.sql`.

- Drops `fraud_own_read`.
- Revokes direct `anon` and `authenticated` privileges on `public.fraud_flags`.
- Keeps RLS enabled with no client policies, so direct client access is blocked.
- Trusted backend workflows using `service_role` / database owner continue to perform fraud review operations.
- Live verification: `pg_policies` returned no policies for `public.fraud_flags`; Security Advisor reports the expected informational `rls_enabled_no_policy` finding.

## SECURITY DEFINER RPC review

For each exposed RPC, verify:
- fixed `search_path` (prefer empty path and schema-qualified references);
- no caller-controlled identity parameter is trusted without checking it against `auth.uid()`;
- explicit authentication and active profile/role checks where applicable;
- object ownership and valid state transition are checked under row lock where concurrent calls matter;
- arguments are bounded and enum/state inputs allowlisted;
- EXECUTE is revoked from `PUBLIC` and `anon` unless a documented public use case exists;
- direct writes to protected tables are revoked from client roles;
- retries cannot duplicate rewards, refunds, campaign spends, or request responses.

### Live RPC hardening applied

1. `20261010042216_phase17_rpc_search_path_hardening` — all five request/redemption SECURITY DEFINER RPCs have an empty `search_path`; live catalog confirmed `anon` and `PUBLIC` cannot execute them, while `authenticated` retains required app access.
2. `20261010045002_phase17_rpc_role_authorization` — added active profile/role checks to request creation/cancellation and merchant request/redemption responses. Also rejects a null request decision and non-finite/negative/excessive response prices.
3. `20261010045134_phase17_service_rpc_search_path` — pinned the remaining seven service-only campaign, credit, request-queue and trigger helper SECURITY DEFINER functions to an empty `search_path`. Their live grants remain service-only; authenticated/anon execution is false.

Live catalog verification confirms all 12 public SECURITY DEFINER functions now have `search_path=""`; no public/anon EXECUTE grants were found. Only the five intended request/redemption RPCs are executable by `authenticated`.

### Known functions requiring integration testing

- `create_customer_request`
- `cancel_customer_request`
- `respond_customer_request`
- `redeem_customer_points`
- `respond_to_point_redemption`

The catalog regression test in `supabase/tests/phase17_rpc_security.sql` checks empty search paths, grants, and expected role/input-guard markers. These catalog checks do not replace negative integration tests with real customer and merchant JWTs.

## Required fraud checks

- Self-referral and referral to an existing account.
- Duplicate attribution or duplicate reward.
- Referral expiry before qualification.
- One referred account qualifying multiple referrals.
- Merchant credit cap (2,000) and customer/merchant wallet separation.
- Repeated referral velocity and suspicious repeated reward patterns.
- Reversal must reference a prior transaction and be idempotent.
- Admin review actions must record actor, action, entity, reason, and timestamp.

Use deterministic rule-based flags first. Device fingerprinting is not required for MVP and must not collect invasive identifiers without a separately reviewed privacy basis.

## Acceptance tests

### Fraud table privacy
1. `anon` cannot select, insert, update, or delete `fraud_flags`.
2. An authenticated customer cannot read or mutate fraud flags.
3. An authenticated merchant cannot read or mutate fraud flags.
4. Trusted server-side fraud review remains possible.
5. Security Advisor no longer reports a client-readable fraud-flags policy.

### Authorization regression tests
1. Customer A cannot cancel Customer B's request.
2. Merchant A cannot accept/decline a request assigned to Merchant B.
3. Customer cannot redeem points from another customer's wallet or at their own business.
4. Merchant cannot approve/reject another merchant's redemption.
5. Authenticated clients cannot call campaign-spend RPCs directly.
6. Anonymous clients cannot execute private reward/request RPCs.
7. Replayed idempotency keys do not duplicate deductions/refunds/rewards.
8. Suspended profiles and wrong-role profiles cannot perform customer/merchant actions.
9. Null request decisions and NaN/infinite/negative/excessive prices are rejected.

## Release gate

- Verify migration history and ensure the checked-in migration version matches the live version.
- Re-run Security and Performance Advisors.
- Run Flutter analyze/tests and Next.js typecheck/build.
- Run authenticated integration tests with separate customer and merchant test accounts in a non-production environment.
- Do not call Phase 17 complete until results are recorded here.
