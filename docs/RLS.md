# RDS Nearby — RLS Contract

## Authorization model

RLS is mandatory on every exposed table.

### Customer
- Can read/update own profile fields permitted by product rules.
- Can read own wallet and points ledger.
- Can create/read/update own customer requests within allowed state transitions.
- Can read own referrals and referral events.
- Can create/read own saved businesses.
- Can read public active + verified business data, offers and eligible discovery data.

### Merchant
- Can read/update only businesses they own.
- Can manage only products, services and offers belonging to owned businesses.
- Can read requests assigned to owned businesses.
- Can read/manage campaigns for owned businesses through server-controlled campaign operations.
- Can read own wallet/ledger and referral QR identity.
- Cannot directly mutate reward balances, ledger rows, verification status or publication status.

### Admin
Administrative access is server-controlled and audited. Do not authorize admin access from user-editable metadata.

## Sensitive mutations

The following are backend-only operations:
- referral qualification/reward
- merchant credit award/spend/reversal
- customer point award/redeem/reversal
- campaign creation/spend
- request expiry
- notification dispatch
- membership state changes
- business verification/moderation

## Public discovery

Only businesses that are both:
- status = active
- verification_status = verified

may appear through public discovery policies.

## Security requirements

- Use auth.uid() ownership predicates.
- Use TO authenticated / TO anon rather than auth.role().
- UPDATE policies require both USING and WITH CHECK.
- Never use user_metadata for authorization.
- Service/secret keys never enter Flutter or browser code.
- Reward and wallet tables are not client-writable.
