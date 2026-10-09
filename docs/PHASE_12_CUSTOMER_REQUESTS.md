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
- Direct authenticated insert/update/delete on request tables is revoked; state changes use ownership-checked RPCs.
- Existing read policies are retained for customer/merchant request visibility and customer response visibility.

## Important integration note
The current Supabase project has no request/notification worker deployed yet. The 3m/8m reminders are queued in `notifications.scheduled_at`; Phase 13 must deliver due notifications and re-check that the related request is still pending and unexpired immediately before sending. Request expiry is also enforced when a merchant attempts to respond. A scheduled worker should mark remaining pending requests expired at 10m. This slice does not claim push delivery is already live.

## Validation
- Schema and RLS policies were inspected against the live RDS STUDIO ACCOUNT database before writing the migration.
- Run authenticated integration tests for create, cross-merchant response rejection, accept/decline, customer cancellation, and reminder cancellation before pilot use.
