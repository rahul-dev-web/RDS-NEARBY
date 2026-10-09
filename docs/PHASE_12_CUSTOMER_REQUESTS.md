# Phase 12 — Customer Requests

## Scope from LOCAL_COMMERCE_MASTER_BLUEPRINT.md
- Customer creates a request for a business.
- Merchant receives a high-priority alert and can Accept or Decline; Ignore is handled by the reminder/expiry flow.
- Reminder milestones are 3 minutes, 8 minutes, and expiry at 10 minutes.
- Merchant availability uses the existing `accepting_requests` flag.
- Request access is limited to the requesting customer and the owner of the selected business.

## Implemented in this slice
- `create_customer_request` RPC validates authenticated customer, active + verified business, `accepting_requests = true`, title/description limits, and prevents a merchant from requesting their own business.
- New request expires after 10 minutes and queues a high-priority notification plus 3m/8m reminder notifications.
- `respond_customer_request` allows only the owning merchant to accept/decline a pending, unexpired request. It writes a response, transitions request state, notifies the customer, and clears queued reminders.
- `cancel_customer_request` lets only the requesting customer cancel their own pending request.
- Public web shop pages now show a Customer Request form when the merchant has enabled `accepting_requests`; submitting it requires an existing authenticated Supabase web session.
- Flutter customer discovery cards now expose a request dialog for businesses that are accepting requests.
- Flutter merchant menu now includes a Customer Requests inbox with pending requests and Accept/Decline actions.
- Direct authenticated insert/update/delete on request tables is revoked; state changes use ownership-checked RPCs.
- Existing read policies are retained for customer/merchant request visibility and customer response visibility.

## Important integration note
The current Supabase project has no request/notification worker deployed yet, and no web sign-in UI was confirmed in this slice. The 3m/8m reminders are queued in `notifications.scheduled_at`; Phase 13 must deliver due notifications and re-check that the related request is still pending and unexpired immediately before sending. Request expiry is also enforced when a merchant attempts to respond. A scheduled worker should mark remaining pending requests expired at 10m. This slice does not claim push delivery is already live.

## Validation
- Schema and RLS policies were inspected against the live RDS STUDIO ACCOUNT database before writing the migration.
- Migrations were applied to the live RDS STUDIO ACCOUNT project; the request-expiry and due-notification queue indexes were verified by migration success.
- Security Advisor no longer reports the internal reminder-trigger function as callable by anon/authenticated. It still reports three intentional authenticated SECURITY DEFINER RPCs; each is restricted to authenticated callers and performs explicit identity, ownership, state, and input checks.
- Run authenticated integration tests for create, cross-merchant response rejection, accept/decline, customer cancellation, and reminder cancellation before pilot use.

- Flutter static analysis/build and Next.js production build have not been run in this environment; GitHub commits and successful SQL migration application do not establish app compile success.


## Phase 13 progress — automatic expiry

- Added `public.expire_stale_customer_requests()`, which transitions pending requests whose `expires_at` has passed to `expired`, then removes queued reminder notifications for non-pending requests.
- Enabled `pg_cron` and registered active job `expire-stale-customer-requests` to run once per minute.
- The job was verified in `cron.job`; a manual execution returned successfully with zero overdue requests in the database at verification time.
- This is automatic expiry and reminder cleanup only. It does **not** deliver push notifications. The existing `device_tokens` table is present, but a verified FCM delivery implementation and credentials are not yet configured/validated.
