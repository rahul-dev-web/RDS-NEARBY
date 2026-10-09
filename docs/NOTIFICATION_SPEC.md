# RDS Nearby — Notification Specification

Status: Frozen V1 behaviour. This is a specification, not a claim that every delivery path is live.

## Purpose and priority

Notifications are an attention mechanism. The Merchant Request Inbox is the source of truth. A missed or delayed push must never erase a Customer Request.

| Priority | Examples | V1 intent |
|---|---|---|
| High | New Customer Request, customer waiting, urgent service request, T+3/T+8 reminders | Prompt merchant action while the request is actionable |
| Normal | Offer published, Marketing Credits earned, reviews, weekly analytics, membership and campaign events | Informational; must respect user preferences |

Customer Request delivery is the first implementation target. Other notification classes remain planned until their producers and acceptance tests exist.

## Customer Request lifecycle

1. Backend validates customer identity, business eligibility, and Accepting Requests.
2. The server creates a request with a 10-minute expiry and queues a high-priority notification.
3. At T+3 minutes, queue a reminder only if the request remains PENDING and unexpired.
4. At T+8 minutes, queue the final reminder only if it remains PENDING and unexpired.
5. At T+10 minutes, transition a still-pending request to EXPIRED.
6. Accept, decline, or customer cancellation suppresses all unsent reminders.
7. Closed, inactive, unverified, or non-accepting businesses must not receive new request alerts. Request creation itself must enforce eligibility; the push worker is not the only guard.

All state transitions and timing are server-owned. Client code cannot extend deadlines or decide eligibility.

## Recipient eligibility

Immediately before sending, the backend checks:
- request remains PENDING and unexpired;
- business is active, verified, open, and accepting requests;
- recipient is the owner of that business;
- relevant notification preference is enabled;
- an active device token exists.

If the request or eligibility changes, do not send the push. Do not mark a notification SENT unless the provider accepted a send.

## Preferences and device behaviour

V1 preference categories: Customer Requests (default ON), Urgent Requests (default ON), Reviews, Marketing Credits, and Offers (the latter categories user-configurable).

Desired controls: quiet hours 22:00–08:00, vibration, Android sound channel `local_request`, and reminder preferences. These controls are not complete until persisted and verified on-device. Quiet hours must never delay a request past its expiry.

## Payload and deep link

Data payload may contain `notificationId`, `notificationType`, `requestId`, and a deep-link path such as `/merchant/requests/<id>`. Never put private customer contact data, credentials, or full profile details in push payloads.

Tapping a request push opens that exact request after authentication and access checks. It must not merely open Merchant Home. If the session is absent or the request is no longer actionable, route to the inbox and show its current state. A push payload never grants authorization.

## Reliability, security and idempotency

- Queue claims are atomic and safe under concurrent workers.
- Delivery attempts have bounded retry/backoff and an observable terminal failure state.
- Mark SENT only after FCM accepts a send.
- Deactivate tokens only for a confirmed unregistered-token response, not generic HTTP errors.
- Repeated worker invocations must not duplicate request state transitions or economic outcomes.
- Re-check request state and preferences at delivery time.
- Never log service-account credentials, service-role keys, full FCM tokens, or unnecessary personal data.
- Only trusted backend workers can claim/finish delivery queue records.

## Acceptance tests

1. Eligible request queues immediate high-priority notification.
2. T+3 and T+8 reminders send only while request is pending and unexpired.
3. Accept/decline/cancel suppresses queued reminders.
4. Request expires at T+10 and remains visible in the inbox.
5. `accepting_requests = false` prevents new request alerts.
6. Closed, inactive, or unverified business receives no request push.
7. Disabled preference suppresses delivery.
8. Missing FCM credentials or no active token never falsely marks delivery SENT.
9. Transient FCM errors retry; confirmed unregistered token is deactivated.
10. Notification tap opens the exact request under the signed-in merchant's access scope.
11. Customer or another merchant cannot read/respond to another user's request through a crafted deep link.

## Current implementation status (verified 2026-10-09)

Implemented in repository/live project: request notification queue and claim/finish RPCs, request-expiry cron, device-token registration RPCs, Edge Function source/deployment, and Flutter notification routing.

**Push delivery is not yet end-to-end live.** Native Android/iOS project configuration, Firebase app configuration and service-account secret, secure scheduled worker invocation, native notification channel/APNs setup, active device tokens, and physical-device acceptance tests remain release blockers. Do not describe this phase as complete until those tests pass.
