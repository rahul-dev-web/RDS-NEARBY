# RDS Nearby — Notification Specification

## Purpose

Notifications get a merchant's attention when a customer needs action. They are not the source of truth. The Merchant Request Inbox is.

## Priority classes

Normal: Offer published, Marketing Credits earned, reviews, weekly analytics, membership events, campaign events.

High priority: New Customer Request, Customer waiting, urgent service request.

High priority is reserved for actionable customer demand.

## Eligibility

A merchant receives a new Customer Request notification only when:
1. The business is active.
2. The business is verified/published according to visibility rules.
3. Accepting Requests is enabled.
4. The request has not expired.
5. The merchant has an active device token and has enabled the category.

Open/Closed is informational. Accepting Requests controls request eligibility.

## Request timing

- T+0: high-priority push
- T+3m: reminder if still PENDING
- T+8m: final reminder if still PENDING
- T+10m: expire if still PENDING

Every reminder re-checks request status and eligibility before sending.

## Inbox

The request remains in the inbox until terminal state: ACCEPTED, DECLINED, EXPIRED, CANCELLED or COMPLETED.

A missed push must never delete or hide the request.

## Deep links

A request notification opens the exact request detail screen, not Merchant Home. The detail should expose customer, product/service, quantity when available, expected price when available, status, Accept, Decline and Send Offer where supported.

## Notification settings

Customer Requests, Urgent Requests, Reviews, Marketing Credits, Offers, Sound, Vibration, Reminder and Quiet Hours.

## Backend ownership

Notification eligibility, priority, timing, reminder scheduling and expiry are backend-controlled. Flutter must not decide reward, campaign or notification entitlement.

## Idempotency

Notification creation and all reward/financial operations use deterministic idempotency keys wherever duplicate delivery could duplicate state or user-facing actions.

## Acceptance tests

1. New request + accepting_requests=true -> high-priority notification.
2. accepting_requests=false -> no new request alert.
3. Missed push -> request remains in inbox.
4. Pending at +3m -> one reminder.
5. Pending at +8m -> one final reminder.
6. Pending at +10m -> EXPIRED.
7. Accepted before reminder -> no later reminder.
8. Declined before expiry -> no later reminder.
9. Notification tap -> exact request detail.
