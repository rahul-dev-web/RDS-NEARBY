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
- Public web shop pages now show an authenticated Customer Request form when the merchant has enabled `accepting_requests`.
- Flutter merchant menu now includes a Customer Requests inbox with pending requests and Accept/Decline actions.
- Direct authenticated insert/update/delete on request tables is revoked; state changes use ownership-checked RPCs.
- Existing read policies are retained for customer/merchant request visibility and customer response visibility.

## Important integration note
The current Supabase project has no request/notification worker deployed yet. The 3m/8m reminders are queued in `notifications.scheduled_at`; Phase 13 must deliver due notifications and re-check that the related request is still pending and unexpired immediately before sending. Request expiry is also enforced when a merchant attempts to respond. A scheduled worker should mark remaining pending requests expired at 10m. This slice does not claim push delivery is already live.

## Validation
- Schema and RLS policies were inspected against the live RDS STUDIO ACCOUNT database before writing the migration.
- Migrations were applied to the live RDS STUDIO ACCOUNT project; the request-expiry and due-notification queue indexes were verified by migration success.
- Security Advisor no longer reports the internal reminder-trigger function as callable by anon/authenticated. It still reports three intentional authenticated SECURITY DEFINER RPCs; each is restricted to authenticated callers and performs explicit identity, ownership, state, and input checks.
- Run authenticated integration tests for create, cross-merchant response rejection, accept/decline, customer cancellation, and reminder cancellation before pilot use.
