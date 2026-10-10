# Phase 17 — Fraud & Security Hardening

Status: implementation started. This phase is not production-ready until the acceptance tests below pass with separate customer, merchant, and admin/service contexts.

## Live baseline verified (2026-10-10)

- Supabase project: `RDS-NEARBY` in the RDS STUDIO ACCOUNT / Rahul Dev Studio organization.
- Live project ref: `kkgkvpjcmwfarkdkhcme` (ap-south-1).
- Phase 16 analytics migrations are recorded in the live database.
- Core tables have RLS enabled.
- Fraud review records currently have a client-facing `fraud_own_read` policy. Fraud flags are operational risk signals and should not be exposed to the account being reviewed; Phase 17 removes that policy and revokes direct client table access.
- Several public SECURITY DEFINER RPCs exist for customer requests and redemption. They contain ownership/authentication checks, but must be verified through negative integration tests, not by the Security Advisor warning count alone.
- The live database currently has no business rows and no analytics events, so populated-data behaviour has not been proven.

## Security goals

1. Keep fraud signals and review metadata private to trusted server-side/admin workflows.
2. Prevent customers and merchants from reading or writing fraud flags directly.
3. Verify every SECURITY DEFINER RPC has a fixed search path, explicit caller authentication, ownership/role checks, validated inputs, and least-privilege EXECUTE grants.
4. Ensure wallet/ledger writes remain server-only and idempotent.
5. Ensure admin decisions are auditable and cannot be authorized from user-editable profile metadata.
6. Add fraud detection incrementally; never automatically accuse/suspend a user solely from a weak heuristic.

## Initial database hardening

Migration: `20261010170000_phase17_private_fraud_flags.sql`

- Drops `fraud_own_read`.
- Revokes direct `anon` and `authenticated` privileges on `public.fraud_flags`.
- Keeps RLS enabled and documents the intended access boundary.
- Trusted backend workflows using `service_role` / database owner continue to perform fraud review operations.

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

## SECURITY DEFINER RPC review

For each exposed RPC, verify:
- fixed `search_path` (prefer empty path and schema-qualified references, or a tightly controlled path);
- no caller-controlled identity parameter is trusted without checking it against `auth.uid()`;
- explicit `auth.uid() IS NOT NULL` and active profile/role checks where applicable;
- object ownership and valid state transition are checked under row lock where concurrent calls matter;
- all arguments are bounded and enum/state inputs allowlisted;
- EXECUTE is revoked from `PUBLIC` and `anon` unless a documented public use case exists;
- direct writes to protected tables are revoked from client roles;
- retries cannot duplicate rewards, refunds, campaign spends, or request responses.

Known functions requiring focused negative tests include `create_customer_request`, `cancel_customer_request`, `respond_customer_request`, `redeem_customer_points`, and `respond_to_point_redemption`. Service-only campaign and credit functions must remain inaccessible to direct authenticated callers.

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
8. Suspended profiles cannot perform customer/merchant actions.

### Release gate
- Apply migration through versioned migration tooling and verify the migration is recorded.
- Re-run Security and Performance Advisors.
- Run Flutter analyze/tests and Next.js typecheck/build.
- Run authenticated integration tests with separate customer and merchant test accounts in a non-production environment.
- Do not call Phase 17 complete until results are recorded here.
